import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:smeet_app/core/services/posts_service.dart';
import 'package:smeet_app/features/profile/presentation/profile_post_detail_page.dart';
import 'package:smeet_app/services/block_service.dart';
import 'package:smeet_app/widgets/block_user_confirm_dialog.dart';
import 'package:smeet_app/widgets/profile_identity_section.dart';
import 'package:smeet_app/widgets/profile_posts_grid.dart';
import 'package:smeet_app/widgets/report_bottom_sheet.dart';

Widget _availabilityWidget(dynamic availability) {
  if (availability is Map) {
    final keys = availability.keys.map((k) => k.toString()).toList()..sort();
    if (keys.isEmpty) {
      return const Text('Not set');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: keys.map((day) {
        final slots = availability[day];
        final slotStr = slots is List
            ? slots.map((e) => e.toString()).join(', ')
            : slots?.toString() ?? '';
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            '$day: $slotStr',
            style: const TextStyle(height: 1.35),
          ),
        );
      }).toList(),
    );
  }
  return Text(availability.toString());
}

/// Read-only profile for another user: basics + recent posts / media (Phase 4).
class OtherProfilePage extends StatefulWidget {
  const OtherProfilePage({super.key, required this.userId});

  final String userId;

  @override
  State<OtherProfilePage> createState() => _OtherProfilePageState();
}

class _OtherProfilePageState extends State<OtherProfilePage> {
  bool _blockLoading = true;
  bool _iBlocked = false;
  bool _theyBlocked = false;
  bool _busy = false;

  final PostsService _postsService = PostsService();
  late Future<List<Map<String, dynamic>>> _postsFuture;

  @override
  void initState() {
    super.initState();
    _postsFuture = _postsService.fetchPostsForAuthor(widget.userId);
    _loadBlockState();
  }

  void _refreshPosts() {
    setState(() {
      _postsFuture = _postsService.fetchPostsForAuthor(widget.userId);
    });
  }

  Future<void> _loadBlockState() async {
    final me = Supabase.instance.client.auth.currentUser?.id;
    if (me == null || me == widget.userId) {
      if (mounted) {
        setState(() {
          _blockLoading = false;
          _iBlocked = false;
          _theyBlocked = false;
        });
      }
      return;
    }
    try {
      final s = await BlockService.fetchMyBlockSets();
      if (!mounted) return;
      setState(() {
        _iBlocked = s.iBlocked.contains(widget.userId);
        _theyBlocked = s.blockedMe.contains(widget.userId);
        _blockLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _blockLoading = false);
    }
  }

  Future<void> _blockPlayer(String displayName) async {
    if (_busy) return;
    final ok = await showBlockUserConfirmDialog(
      context,
      displayName: displayName,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await BlockService.blockUser(widget.userId);
      if (!mounted) return;
      setState(() => _iBlocked = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Player blocked')),
      );
    } on BlockActionException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unblockPlayer() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await BlockService.unblockUser(widget.userId);
      if (!mounted) return;
      setState(() => _iBlocked = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Player unblocked')),
      );
    } on BlockActionException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Map<String, dynamic>?> _loadProfile() {
    return Supabase.instance.client
        .from('profiles')
        .select(
          'display_name, city, intro, avatar_url, sport_levels, availability',
        )
        .eq('id', widget.userId)
        .maybeSingle();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final me = Supabase.instance.client.auth.currentUser?.id;

    if (_blockLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Player profile')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (me != null && _theyBlocked) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Player profile'),
          actions: [
            _ReportUserActionButton(targetUserId: widget.userId),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.visibility_off_outlined, size: 56, color: cs.outline),
                const SizedBox(height: 16),
                Text(
                  'This profile isn’t available.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  'You can’t view this player’s profile right now.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.75),
                        height: 1.4,
                      ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Player profile'),
        actions: [
          if (me != null && me != widget.userId) ...[
            _ReportUserActionButton(targetUserId: widget.userId),
            if (_busy)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (_iBlocked)
              IconButton(
                tooltip: 'Unblock user',
                icon: const Icon(Icons.undo),
                onPressed: _unblockPlayer,
              )
            else
              IconButton(
                tooltip: 'Block user',
                icon: const Icon(Icons.block),
                onPressed: () async {
                  final snap = await _loadProfile();
                  final name = (snap?['display_name'] ?? '').toString();
                  if (!mounted) return;
                  await _blockPlayer(name);
                },
              ),
          ],
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _loadProfile(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final p = snap.data;
          if (p == null) {
            return const Center(child: Text('Profile not found'));
          }

          final name = (p['display_name'] ?? '').toString();
          final city = (p['city'] ?? '').toString();
          final intro = (p['intro'] ?? '').toString();
          final avatar = (p['avatar_url'] ?? '').toString();
          final sportLevels = p['sport_levels'] as Map? ?? {};
          final availability = p['availability'];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_iBlocked) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cs.errorContainer.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: cs.error.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'You blocked this player',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Their posts are hidden. Unblock to restore full profile and chat access.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                height: 1.35,
                              ),
                        ),
                        const SizedBox(height: 10),
                        FilledButton.tonal(
                          onPressed: _busy ? null : _unblockPlayer,
                          child: const Text('Unblock'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                CircleAvatar(
                  radius: 48,
                  backgroundColor: cs.primary.withValues(alpha: 0.15),
                  backgroundImage:
                      avatar.isEmpty ? null : NetworkImage(avatar),
                  child: avatar.isEmpty
                      ? Icon(Icons.person, size: 40, color: cs.primary)
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  name.isEmpty ? 'Unnamed' : name,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                if (city.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(city, textAlign: TextAlign.center),
                ],
                if (intro.isNotEmpty && !_iBlocked) ...[
                  const SizedBox(height: 12),
                  Text(intro),
                ],
                if (!_iBlocked) ...[
                  const SizedBox(height: 16),
                  ProfileIdentitySection(
                    userId: widget.userId,
                    heading: 'Sports identity',
                  ),
                ],
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Sports & level',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 8),
                if (sportLevels.isEmpty)
                  const Text('No sports info')
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: sportLevels.entries.map<Widget>((e) {
                      return Chip(label: Text('${e.key}: ${e.value}'));
                    }).toList(),
                  ),
                if (availability != null && !_iBlocked) ...[
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Availability',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _availabilityWidget(availability),
                ],
                if (!_iBlocked) ...[
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Posts & media',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Recent clips and photos — get a feel for level and style.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.65),
                        ),
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _postsFuture,
                    builder: (context, postSnap) {
                      if (postSnap.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      if (postSnap.hasError) {
                        return Text('Could not load posts: ${postSnap.error}');
                      }
                      final posts = postSnap.data ?? [];
                      if (posts.isEmpty) {
                        return const Text('No posts yet.');
                      }
                      return ProfilePostsGrid(
                        shrinkWrap: true,
                        posts: posts,
                        onOpenPost: (post) {
                          Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) => UnifiedProfilePostDetailPage(
                                initialRow: post,
                                onDeleted: _refreshPosts,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// App bar action — hidden when viewing own profile or logged out.
class _ReportUserActionButton extends StatelessWidget {
  const _ReportUserActionButton({required this.targetUserId});

  final String targetUserId;

  @override
  Widget build(BuildContext context) {
    final me = Supabase.instance.client.auth.currentUser?.id;
    if (me == null || me == targetUserId) {
      return const SizedBox.shrink();
    }
    return IconButton(
      tooltip: 'Report user',
      icon: const Icon(Icons.flag_outlined),
      onPressed: () {
        showReportBottomSheet(
          context,
          title: 'Report user',
          subtitle:
              'Tell us what is wrong. We review reports to keep Smeet safe.',
          targetUserId: targetUserId,
        );
      },
    );
  }
}
