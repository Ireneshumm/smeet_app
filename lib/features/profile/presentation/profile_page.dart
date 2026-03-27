import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:smeet_app/features/profile/data/mock_profile_repository.dart';
import 'package:smeet_app/features/profile/data/profile_repository.dart';
import 'package:smeet_app/features/profile/data/supabase_profile_hosted_repository.dart';
import 'package:smeet_app/features/profile/data/supabase_profile_joined_repository.dart';
import 'package:smeet_app/features/profile/data/supabase_profile_posts_repository.dart';
import 'package:smeet_app/features/profile/data/supabase_profile_repository.dart';
import 'package:smeet_app/features/profile/models/profile_summary.dart';
import 'package:smeet_app/features/profile/models/profile_tab_item.dart';
import 'package:smeet_app/features/profile/presentation/profile_game_detail_page.dart';
import 'package:smeet_app/features/profile/presentation/profile_post_detail_page.dart';
import 'package:smeet_app/features/profile/profile_routes.dart';
import 'package:smeet_app/widgets/post_media_display.dart';

/// Live vs mock source for the **header** only (Posts / Hosted / Joined tabs are live).
enum ProfileMvpSummarySource {
  supabase,
  mock,
}

/// Mock profile hub (MVP). Does not replace the shell [ProfilePage] in `main.dart`.
class ProfileMvpPage extends StatefulWidget {
  const ProfileMvpPage({
    super.key,
    this.summaryRepository,
    this.initialSummarySource = ProfileMvpSummarySource.supabase,
    this.initialTabIndex = 0,
    this.snackMessageOnOpen,
  });

  /// Optional override for tests (summary only; list tabs use live Supabase repos).
  final ProfileRepository? summaryRepository;

  final ProfileMvpSummarySource initialSummarySource;

  /// Bottom tab: 0 = Posts, 1 = Hosted, 2 = Joined (see [ProfileMvpInitialTabIndex]).
  final int initialTabIndex;

  /// Shown once on this route after the first frame (e.g. after create flows navigate here).
  final String? snackMessageOnOpen;

  @override
  State<ProfileMvpPage> createState() => _ProfileMvpPageState();
}

class _ProfileMvpPageState extends State<ProfileMvpPage>
    with SingleTickerProviderStateMixin {
  late final MockProfileRepository _mockRepo = MockProfileRepository();
  late final SupabaseProfilePostsRepository _postsRepo =
      SupabaseProfilePostsRepository();
  late final SupabaseProfileHostedRepository _hostedRepo =
      SupabaseProfileHostedRepository();
  late final SupabaseProfileJoinedRepository _joinedRepo =
      SupabaseProfileJoinedRepository();
  late final SupabaseProfileRepository _liveSummaryRepo =
      SupabaseProfileRepository();
  late ProfileMvpSummarySource _summarySource = widget.initialSummarySource;
  late final TabController _tabs;

  Future<ProfileSummary>? _summaryFuture;
  final Map<ProfileContentTab, Future<List<ProfileTabItem>>> _listFutures = {};

  bool get _usesSummaryToggle => widget.summaryRepository == null;

  ProfileRepository get _activeSummaryRepo {
    if (widget.summaryRepository != null) {
      return widget.summaryRepository!;
    }
    return _summarySource == ProfileMvpSummarySource.mock
        ? _mockRepo
        : _liveSummaryRepo;
  }

  @override
  void initState() {
    super.initState();
    final tab = widget.initialTabIndex.clamp(
      0,
      ProfileMvpInitialTabIndex.joined,
    );
    _tabs = TabController(length: 3, vsync: this, initialIndex: tab);
    _summaryFuture = _activeSummaryRepo.fetchSummary();
    _listFutures[ProfileContentTab.posts] = _postsRepo.fetchMyPostsTabItems();
    _listFutures[ProfileContentTab.hosted] = _hostedRepo.fetchHostedTabItems();
    _listFutures[ProfileContentTab.joined] = _joinedRepo.fetchJoinedTabItems();

    final snack = widget.snackMessageOnOpen;
    if (snack != null && snack.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(snack)),
        );
      });
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _reloadSummary() {
    setState(() {
      _summaryFuture = _activeSummaryRepo.fetchSummary();
    });
  }

  void _onSummarySourceChanged(ProfileMvpSummarySource next) {
    if (!_usesSummaryToggle) return;
    if (_summarySource == next) return;
    setState(() {
      _summarySource = next;
      _summaryFuture = _activeSummaryRepo.fetchSummary();
    });
  }

  /// Posts Tab only — re-fetches via [SupabaseProfilePostsRepository] (same as initial load).
  Future<void> _refreshPostsTab() async {
    final items = await _postsRepo.fetchMyPostsTabItems();
    if (!mounted) return;
    setState(() {
      _listFutures[ProfileContentTab.posts] = Future.value(items);
    });
  }

  /// Joined Tab only — same data path as [JoinedGamesService] / My Game list.
  Future<void> _refreshJoinedTab() async {
    final items = await _joinedRepo.fetchJoinedTabItems();
    if (!mounted) return;
    setState(() {
      _listFutures[ProfileContentTab.joined] = Future.value(items);
    });
  }

  /// Hosted Tab only — [HostedGamesService] / `games.created_by`.
  Future<void> _refreshHostedTab() async {
    final items = await _hostedRepo.fetchHostedTabItems();
    if (!mounted) return;
    setState(() {
      _listFutures[ProfileContentTab.hosted] = Future.value(items);
    });
  }

  void _open(ProfileTabItem item) {
    debugPrint(
      '[Profile MVP] open id=${item.id} tab=${item.tab.name}',
    );
    switch (item.tab) {
      case ProfileContentTab.posts:
        Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (context) => ProfileMvpPostDetailPage(item: item),
          ),
        );
        return;
      case ProfileContentTab.joined:
      case ProfileContentTab.hosted:
        Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (context) => ProfileMvpGameDetailPage(item: item),
          ),
        );
    }
  }

  Widget _header(ProfileSummary s) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final inner = Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: cs.primary.withValues(alpha: 0.22),
                width: 2,
              ),
            ),
            child: CircleAvatar(
              radius: 40,
              backgroundColor: cs.primaryContainer,
              backgroundImage: s.avatarUrl != null && s.avatarUrl!.isNotEmpty
                  ? NetworkImage(s.avatarUrl!)
                  : null,
              onBackgroundImageError: (Object? error, StackTrace? stackTrace) {},
              child: s.avatarUrl != null && s.avatarUrl!.isNotEmpty
                  ? null
                  : Icon(
                      s.isGuest ? Icons.person_off_outlined : Icons.person,
                      size: 42,
                      color: cs.onPrimaryContainer,
                    ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.displayName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.place_outlined,
                      size: 18,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        s.city.isEmpty ? 'Add your city' : s.city,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                if (s.sportsSummary.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      s.sportsSummary,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.4,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    final shell = DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.65)),
        ),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: inner,
    );

    if (!s.isGuest) {
      return shell;
    }

    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
      child: shell,
    );
  }

  Widget _listFor(ProfileContentTab tab) {
    switch (tab) {
      case ProfileContentTab.posts:
        return _postsTabList();
      case ProfileContentTab.hosted:
        return _hostedTabList();
      case ProfileContentTab.joined:
        return _joinedTabList();
    }
  }

  Widget _postsTabList() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    const pad = EdgeInsets.fromLTRB(16, 8, 16, 12);

    return FutureBuilder<List<ProfileTabItem>>(
      future: _listFutures[ProfileContentTab.posts],
      builder: (context, snapshot) {
        final loggedIn = Supabase.instance.client.auth.currentUser != null;
        final slivers = <Widget>[];

        if (snapshot.connectionState != ConnectionState.done) {
          slivers.add(
            SliverPadding(
              padding: pad,
              sliver: SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
          );
        } else if (snapshot.hasError) {
          slivers.add(
            SliverPadding(
              padding: pad,
              sliver: SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'We couldn’t load posts. Pull to refresh.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        } else {
          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            slivers.add(
              SliverPadding(
                padding: pad,
                sliver: SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          loggedIn
                              ? Icons.post_add_outlined
                              : Icons.lock_outline,
                          size: 48,
                          color: cs.outline,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          loggedIn
                              ? 'No posts yet'
                              : 'Sign in to see your posts',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          loggedIn
                              ? 'Create a post from the main Profile tab or pull to refresh.'
                              : 'Your published posts will appear here.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          } else {
            slivers.add(
              SliverPadding(
                padding: pad,
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => Padding(
                      padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
                      child: _postCard(items[i]),
                    ),
                    childCount: items.length,
                  ),
                ),
              ),
            );
          }
        }

        return RefreshIndicator(
          onRefresh: _refreshPostsTab,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: slivers,
          ),
        );
      },
    );
  }

  Widget _joinedTabList() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    const pad = EdgeInsets.fromLTRB(16, 8, 16, 12);

    return FutureBuilder<List<ProfileTabItem>>(
      future: _listFutures[ProfileContentTab.joined],
      builder: (context, snapshot) {
        final loggedIn = Supabase.instance.client.auth.currentUser != null;
        final slivers = <Widget>[];

        if (snapshot.connectionState != ConnectionState.done) {
          slivers.add(
            SliverPadding(
              padding: pad,
              sliver: SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
          );
        } else if (snapshot.hasError) {
          slivers.add(
            SliverPadding(
              padding: pad,
              sliver: SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'We couldn’t load joined games. Pull to refresh.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        } else {
          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            slivers.add(
              SliverPadding(
                padding: pad,
                sliver: SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          loggedIn
                              ? Icons.sports_outlined
                              : Icons.lock_outline,
                          size: 48,
                          color: cs.outline,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          loggedIn
                              ? 'No joined games yet'
                              : 'Sign in to see joined games',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          loggedIn
                              ? 'Join a game from the Home tab or pull to refresh.'
                              : 'Games you join will appear here.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          } else {
            slivers.add(
              SliverPadding(
                padding: pad,
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => Padding(
                      padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
                      child: _postCard(items[i]),
                    ),
                    childCount: items.length,
                  ),
                ),
              ),
            );
          }
        }

        return RefreshIndicator(
          onRefresh: _refreshJoinedTab,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: slivers,
          ),
        );
      },
    );
  }

  Widget _hostedTabList() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    const pad = EdgeInsets.fromLTRB(16, 8, 16, 12);

    return FutureBuilder<List<ProfileTabItem>>(
      future: _listFutures[ProfileContentTab.hosted],
      builder: (context, snapshot) {
        final loggedIn = Supabase.instance.client.auth.currentUser != null;
        final slivers = <Widget>[];

        if (snapshot.connectionState != ConnectionState.done) {
          slivers.add(
            SliverPadding(
              padding: pad,
              sliver: SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
          );
        } else if (snapshot.hasError) {
          slivers.add(
            SliverPadding(
              padding: pad,
              sliver: SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'We couldn’t load hosted games. Pull to refresh.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        } else {
          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            slivers.add(
              SliverPadding(
                padding: pad,
                sliver: SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          loggedIn
                              ? Icons.add_location_alt_outlined
                              : Icons.lock_outline,
                          size: 48,
                          color: cs.outline,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          loggedIn
                              ? 'No hosted games yet'
                              : 'Sign in to see games you host',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          loggedIn
                              ? 'Create a game from the Home tab or pull to refresh.'
                              : 'Games you create will appear here.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          } else {
            slivers.add(
              SliverPadding(
                padding: pad,
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => Padding(
                      padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
                      child: _postCard(items[i]),
                    ),
                    childCount: items.length,
                  ),
                ),
              ),
            );
          }
        }

        return RefreshIndicator(
          onRefresh: _refreshHostedTab,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: slivers,
          ),
        );
      },
    );
  }

  IconData _leadingIconForTab(ProfileContentTab tab) {
    switch (tab) {
      case ProfileContentTab.posts:
        return Icons.article_outlined;
      case ProfileContentTab.hosted:
        return Icons.event_available_outlined;
      case ProfileContentTab.joined:
        return Icons.sports_tennis;
    }
  }

  Widget _postCard(ProfileTabItem item) {
    final cs = Theme.of(context).colorScheme;
    final isPost = item.tab == ProfileContentTab.posts;
    final thumbUrl = item.previewMediaUrl;
    final hasThumb = isPost &&
        thumbUrl != null &&
        thumbUrl.trim().isNotEmpty;
    final isVideoThumb =
        (item.previewMediaType ?? '').toLowerCase() == 'video';

    final Widget leading = hasThumb
        ? PostMediaMvpLeading(
            url: thumbUrl.trim(),
            isVideo: isVideoThumb,
          )
        : CircleAvatar(
            backgroundColor: cs.primary.withValues(alpha: 0.12),
            child: Icon(
              _leadingIconForTab(item.tab),
              color: cs.primary,
            ),
          );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _open(item),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cs.primary.withValues(alpha: 0.10)),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            leading: leading,
            title: Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                item.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  height: 1.25,
                ),
              ),
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: cs.outline,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_usesSummaryToggle)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: SegmentedButton<ProfileMvpSummarySource>(
                segments: const [
                  ButtonSegment<ProfileMvpSummarySource>(
                    value: ProfileMvpSummarySource.supabase,
                    label: Text('Live'),
                    icon: Icon(Icons.cloud_outlined, size: 18),
                  ),
                  ButtonSegment<ProfileMvpSummarySource>(
                    value: ProfileMvpSummarySource.mock,
                    label: Text('Mock'),
                    icon: Icon(Icons.auto_awesome_outlined, size: 18),
                  ),
                ],
                selected: {_summarySource},
                onSelectionChanged: (s) {
                  if (s.isEmpty) return;
                  _onSummarySourceChanged(s.first);
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              !_usesSummaryToggle
                  ? 'Using a custom summary source. Posts, hosted, and joined lists stay live.'
                  : _summarySource == ProfileMvpSummarySource.supabase
                      ? 'Live: profile header from your account. Posts, hosted games, and joined games load from the server.'
                      : 'Preview header only. Posts, hosted games, and joined games still load live.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          FutureBuilder<ProfileSummary>(
            future: _summaryFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Summary error: ${snapshot.error}',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _reloadSummary,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }
              final summary = snapshot.data;
              if (summary == null) {
                return const SizedBox.shrink();
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(summary),
                  if (summary.isGuest)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: OutlinedButton.icon(
                        onPressed: _reloadSummary,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry after sign-in'),
                      ),
                    ),
                ],
              );
            },
          ),
          Material(
            color: theme.colorScheme.surface,
            child: TabBar(
              controller: _tabs,
              dividerColor: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              labelStyle: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              unselectedLabelStyle: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              tabs: const [
                Tab(text: 'Posts'),
                Tab(text: 'Hosted'),
                Tab(text: 'Joined'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _listFor(ProfileContentTab.posts),
                _listFor(ProfileContentTab.hosted),
                _listFor(ProfileContentTab.joined),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
