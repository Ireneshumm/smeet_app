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
  });

  /// Optional override for tests (summary only; list tabs use live Supabase repos).
  final ProfileRepository? summaryRepository;

  final ProfileMvpSummarySource initialSummarySource;

  /// Bottom tab: 0 = Posts, 1 = Hosted, 2 = Joined (see [ProfileMvpInitialTabIndex]).
  final int initialTabIndex;

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

    final child = Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: cs.primaryContainer,
            backgroundImage: s.avatarUrl != null && s.avatarUrl!.isNotEmpty
                ? NetworkImage(s.avatarUrl!)
                : null,
            onBackgroundImageError: (Object? error, StackTrace? stackTrace) {},
            child: s.avatarUrl != null && s.avatarUrl!.isNotEmpty
                ? null
                : Icon(
                    s.isGuest ? Icons.person_off_outlined : Icons.person,
                    size: 40,
                    color: cs.onPrimaryContainer,
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.displayName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.place_outlined,
                      size: 18,
                      color: cs.outline,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        s.city,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  s.sportsSummary,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (!s.isGuest) {
      return child;
    }

    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.65),
      child: child,
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
    const pad = EdgeInsets.symmetric(horizontal: 12, vertical: 8);

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
                      'Couldn’t load posts. Pull to try again.',
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
    const pad = EdgeInsets.symmetric(horizontal: 12, vertical: 8);

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
                      'Couldn’t load joined games. Pull to try again.',
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
    const pad = EdgeInsets.symmetric(horizontal: 12, vertical: 8);

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
                      'Couldn’t load hosted games. Pull to try again.',
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

  Widget _postCard(ProfileTabItem item) {
    return Card(
      child: ListTile(
        title: Text(
          item.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            item.subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _open(item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile (MVP)')),
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
                  ? 'Custom summary repository (Posts / Hosted / Joined still live).'
                  : _summarySource == ProfileMvpSummarySource.supabase
                      ? 'Live: header from `profiles`. Posts from `posts`; Hosted from `games.created_by`; Joined from `game_participants`.'
                      : 'Mock: sample header. Posts + Hosted + Joined still live.',
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
          TabBar(
            controller: _tabs,
            tabs: const [
              Tab(text: 'Posts'),
              Tab(text: 'Hosted'),
              Tab(text: 'Joined'),
            ],
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
