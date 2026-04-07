import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:smeet_app/core/constants/sports.dart';
import 'package:smeet_app/core/services/activity_summary_service.dart';
import 'package:smeet_app/core/services/location_service.dart';
import 'package:smeet_app/features/feed/data/feed_repository.dart';
import 'package:smeet_app/features/feed/data/supabase_feed_repository.dart';
import 'package:smeet_app/features/feed/models/feed_item.dart';
import 'package:smeet_app/core/services/app_notification_badges.dart';
import 'package:smeet_app/features/feed/presentation/feed_detail_page.dart';
import 'package:smeet_app/features/feed/widgets/activity_banner.dart';
import 'package:smeet_app/features/feed/widgets/feed_game_card.dart';
import 'package:smeet_app/features/feed/widgets/feed_post_card.dart';
import 'package:smeet_app/features/notifications/notifications.dart';
import 'package:smeet_app/widgets/app_page_states.dart';

/// Feed list: Supabase-backed games + posts (or injected [repository] for tests).
class FeedPage extends StatefulWidget {
  const FeedPage({
    super.key,
    this.repository,
    this.onOpenLikesYou,
    this.onOpenMatches,
    this.onOpenMyGame,
    this.onOpenHome,
    this.onEnsureLoggedIn,
  });

  final FeedRepository? repository;

  final void Function(BuildContext)? onOpenLikesYou;
  final void Function(BuildContext)? onOpenMatches;
  final void Function(BuildContext)? onOpenMyGame;
  final void Function(BuildContext)? onOpenHome;

  /// Join / gated actions: push auth if needed. From shell (`_ensureLoginAndPrompt`).
  final Future<bool> Function(BuildContext context)? onEnsureLoggedIn;

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  late final SupabaseFeedRepository _defaultRepo = SupabaseFeedRepository();

  FeedRepository get _activeRepo => widget.repository ?? _defaultRepo;

  Future<List<FeedItem>>? _future;
  Future<({double lat, double lng})?>? _locationFuture;
  Future<ActivitySummary>? _activityFuture;

  /// `null` = All sports.
  String? _sportFilter;

  /// Active `game_participants` rows (status joined) for AppBar badge.
  int _joinedGameCount = 0;

  Future<void> _loadJoinedCount() async {
    final u = Supabase.instance.client.auth.currentUser;
    if (u == null) {
      if (mounted) setState(() => _joinedGameCount = 0);
      return;
    }
    try {
      final rows = await Supabase.instance.client
          .from('game_participants')
          .select('game_id')
          .eq('user_id', u.id)
          .eq('status', 'joined');
      if (!mounted) return;
      setState(() => _joinedGameCount = (rows as List).length);
    } catch (_) {}
  }

  void _bindActivityFuture() {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    _activityFuture =
        uid != null ? ActivitySummaryService(client).fetch(uid) : null;
  }

  Future<List<FeedItem>> _loadFeed() async {
    final pos = kIsWeb
        ? null
        : await (_locationFuture ??
            SmeetLocationService.getCurrentPosition());
    return _activeRepo.fetchFeed(
      userLat: pos?.lat,
      userLng: pos?.lng,
      sport: _sportFilter,
    );
  }

  @override
  void initState() {
    super.initState();
    _locationFuture =
        kIsWeb ? Future.value(null) : SmeetLocationService.getCurrentPosition();
    _future = _loadFeed();
    _bindActivityFuture();
    _loadJoinedCount();
  }

  void _reload() {
    setState(() {
      _future = _loadFeed();
      _bindActivityFuture();
    });
  }

  Future<void> _refreshFeed() async {
    final items = await _loadFeed();
    if (!mounted) return;
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    setState(() {
      _future = Future.value(items);
      _activityFuture =
          uid != null ? ActivitySummaryService(client).fetch(uid) : null;
    });
    await _loadJoinedCount();
  }

  void _onSportChipTap(String? key) {
    if (key == null) {
      if (_sportFilter == null) return;
      setState(() {
        _sportFilter = null;
        _future = _loadFeed();
      });
      return;
    }
    final next = _sportFilter == key ? null : key;
    setState(() {
      _sportFilter = next;
      _future = _loadFeed();
    });
  }

  void _openDetail(FeedItem item) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => FeedDetailPage(item: item),
      ),
    );
  }

  void _shareMoment() {
    final fn = widget.onOpenHome;
    if (fn != null) {
      fn(context);
    }
  }

  Widget _feedPost(ThemeData theme, FeedItem item) {
    return FeedPostCard(
      item: item,
      onTap: () => _openDetail(item),
    );
  }

  Widget _buildFeedEntry(ThemeData theme, FeedItem item) {
    if (item.type == FeedContentType.game) {
      return FeedGameCard(
        item: item,
        onTap: () => _openDetail(item),
        onEnsureLoggedIn: widget.onEnsureLoggedIn,
        onOpenMyGame: widget.onOpenMyGame,
        onRefresh: () {
          _reload();
          _loadJoinedCount();
        },
      );
    }
    return _feedPost(theme, item);
  }

  /// Sports present in the current feed payload (posts + games).
  static Set<String> _distinctSportKeys(List<FeedItem> items) {
    final s = <String>{};
    for (final it in items) {
      final raw = it.sport.trim();
      if (raw.isEmpty) continue;
      s.add(canonicalSportKey(raw));
    }
    return s;
  }

  static int _nearbyGamesTodayCount(List<FeedItem> items) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return items.where((e) {
      if (e.type != FeedContentType.game) return false;
      if (e.distanceKm == null) return false;
      final t = e.publishedAt.toLocal();
      return !t.isBefore(start) && t.isBefore(end);
    }).length;
  }

  Widget _buildSportFilterChips(ColorScheme cs, List<FeedItem> items) {
    final keys = _distinctSportKeys(items).toList()
      ..sort(
        (a, b) =>
            sportLabelForKey(a).toLowerCase().compareTo(
                  sportLabelForKey(b).toLowerCase(),
                ),
      );

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _SportFilterChip(
            label: '🏃 All',
            selected: _sportFilter == null,
            onTap: () => _onSportChipTap(null),
          ),
          ...keys.map(
            (k) => _SportFilterChip(
              label: '${sportEmojiForKey(k)} ${sportLabelForKey(k)}',
              selected: _sportFilter == k,
              onTap: () => _onSportChipTap(k),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildNearbyGamesBanner(ColorScheme cs, List<FeedItem> items) {
    final n = _nearbyGamesTodayCount(items);
    if (n <= 0) return null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => widget.onOpenHome?.call(context),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                cs.primary,
                cs.primary.withValues(alpha: 0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Text('⚡', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  n == 1
                      ? '1 game happening near you today'
                      : '$n games happening near you today',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Games full-width; posts in 2-column masonry (variable row heights).
  void _appendFeedBodySlivers(
    List<Widget> slivers,
    ThemeData theme,
    List<FeedItem> items,
  ) {
    var i = 0;
    var segmentIndex = 0;
    while (i < items.length) {
      final it = items[i];
      if (it.isGameContent) {
        final top = segmentIndex == 0 ? 4.0 : 0.0;
        final isLast = i == items.length - 1;
        slivers.add(
          SliverPadding(
            padding: EdgeInsets.fromLTRB(12, top, 12, isLast ? 80 : 8),
            sliver: SliverToBoxAdapter(
              child: FeedGameCard(
                item: it,
                onTap: () => _openDetail(it),
                onEnsureLoggedIn: widget.onEnsureLoggedIn,
                onOpenMyGame: widget.onOpenMyGame,
                onRefresh: () {
                  _reload();
                  _loadJoinedCount();
                },
              ),
            ),
          ),
        );
        segmentIndex++;
        i++;
      } else {
        final chunk = <FeedItem>[];
        while (i < items.length && !items[i].isGameContent) {
          chunk.add(items[i]);
          i++;
        }
        final top = segmentIndex == 0 ? 4.0 : 0.0;
        final isLast = i >= items.length;
        slivers.add(
          SliverPadding(
            padding: EdgeInsets.fromLTRB(12, top, 12, isLast ? 80 : 8),
            sliver: SliverMasonryGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childCount: chunk.length,
              itemBuilder: (context, index) =>
                  _buildFeedEntry(theme, chunk[index]),
            ),
          ),
        );
        segmentIndex++;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: _refreshFeed,
        child: FutureBuilder<List<FeedItem>>(
          future: _future,
          builder: (context, snapshot) {
            final loaded = snapshot.connectionState == ConnectionState.done;
            final items = snapshot.data ?? const <FeedItem>[];
            final chipItems = loaded ? items : const <FeedItem>[];

            final slivers = <Widget>[
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 56,
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Text(
                          'Smeet',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: cs.primary,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(Icons.sports_rounded),
                            if (_joinedGameCount > 0)
                              Positioned(
                                right: -4,
                                top: -4,
                                child: Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: cs.error,
                                    shape: BoxShape.circle,
                                  ),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      _joinedGameCount > 9
                                          ? '9+'
                                          : '$_joinedGameCount',
                                      style: const TextStyle(
                                        fontSize: 9,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        tooltip: 'My Game',
                        onPressed: () {
                          widget.onOpenMyGame?.call(context);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.search_rounded),
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined),
                        onPressed: () async {
                          await Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) => const NotificationsPage(),
                            ),
                          );
                          await refreshAppNotificationBadges();
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _buildSportFilterChips(cs, chipItems),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              if (loaded) ...[
                SliverToBoxAdapter(
                  child: _buildNearbyGamesBanner(cs, items) ??
                      const SizedBox.shrink(),
                ),
              ],
              if (widget.repository == null && _activityFuture != null)
                SliverToBoxAdapter(
                  child: FutureBuilder<ActivitySummary>(
                    future: _activityFuture,
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return const SizedBox.shrink();
                      }
                      final s = snap.data!;
                      return ActivityBanner(
                        incomingLikes: s.incomingLikes,
                        todayGames: s.todayGames,
                        onTapLikes: widget.onOpenLikesYou == null
                            ? null
                            : () => widget.onOpenLikesYou!(context),
                        onTapGames: widget.onOpenHome == null
                            ? null
                            : () => widget.onOpenHome!(context),
                      );
                    },
                  ),
                ),
              if (widget.repository != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                    child: Text(
                      'Using a custom feed source for this screen.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ),
            ];

            if (snapshot.connectionState != ConnectionState.done) {
              slivers.add(
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: AppLoadingState(
                    message: 'Loading feed…',
                  ),
                ),
              );
            } else if (snapshot.hasError) {
              slivers.add(
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: AppErrorState(
                    message: 'We couldn’t load the feed',
                    detail:
                        'Check your connection, pull down to refresh, or tap Retry.',
                    onRetry: _reload,
                    retryLabel: 'Retry',
                  ),
                ),
              );
            } else if (items.isEmpty) {
              slivers.add(
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: AppEmptyState(
                    icon: Icons.dynamic_feed_outlined,
                    title: 'No posts yet',
                    subtitle:
                        'Be the first to share a sports moment.',
                    actionLabel: 'Share a moment',
                    onAction: _shareMoment,
                  ),
                ),
              );
            } else {
              _appendFeedBodySlivers(slivers, theme, items);
            }

            return CustomScrollView(
              primary: true,
              cacheExtent: 1200,
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics(),
              ),
              slivers: slivers,
            );
          },
        ),
      ),
    );
  }
}

class _SportFilterChip extends StatelessWidget {
  const _SportFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? cs.primary : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(100),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : cs.onSurface,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
