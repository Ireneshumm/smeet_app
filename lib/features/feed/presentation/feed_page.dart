import 'package:flutter/material.dart';

import 'package:smeet_app/features/feed/data/feed_repository.dart';
import 'package:smeet_app/features/feed/data/mock_feed_repository.dart';
import 'package:smeet_app/features/feed/data/supabase_feed_repository.dart';
import 'package:smeet_app/features/feed/models/feed_item.dart';
import 'package:smeet_app/features/feed/presentation/feed_detail_page.dart';
import 'package:smeet_app/widgets/app_page_states.dart';

/// Data source for the feed list (toggle without leaving the page).
enum FeedListDataSource {
  /// Real `games` rows from Supabase (upcoming only, v1).
  supabase,

  /// Local mock rows (mixed types).
  mock,
}

/// Feed list: mock or Supabase-backed (v1 = games only for live data).
class FeedPage extends StatefulWidget {
  const FeedPage({
    super.key,
    this.repository,
    this.initialSource = FeedListDataSource.supabase,
  });

  /// When non-null, used for both modes (caller must supply a composite); normally null.
  final FeedRepository? repository;

  /// Default segment when opening from the MVP launcher.
  final FeedListDataSource initialSource;

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  late FeedListDataSource _source = widget.initialSource;
  late final MockFeedRepository _mockRepo = MockFeedRepository();
  late final SupabaseFeedRepository _supabaseRepo = SupabaseFeedRepository();
  Future<List<FeedItem>>? _future;

  FeedRepository get _activeRepo {
    if (widget.repository != null) {
      return widget.repository!;
    }
    return _source == FeedListDataSource.mock ? _mockRepo : _supabaseRepo;
  }

  bool get _usesToggle => widget.repository == null;

  @override
  void initState() {
    super.initState();
    _future = _activeRepo.fetchFeed();
  }

  void _reload() {
    setState(() {
      _future = _activeRepo.fetchFeed();
    });
  }

  /// Pull-to-refresh — same [FeedRepository.fetchFeed] as initial load / toggle.
  Future<void> _refreshFeed() async {
    final items = await _activeRepo.fetchFeed();
    if (!mounted) return;
    setState(() {
      _future = Future.value(items);
    });
  }

  void _onSourceChanged(FeedListDataSource next) {
    if (!_usesToggle) return;
    if (_source == next) return;
    setState(() {
      _source = next;
      _future = _activeRepo.fetchFeed();
    });
  }

  static String _badge(FeedContentType t) {
    switch (t) {
      case FeedContentType.post:
        return 'Post';
      case FeedContentType.video:
        return 'Video';
      case FeedContentType.game:
        return 'Game';
    }
  }

  /// One-line meta: time / spots / venue / length — kept calm for Live placeholders.
  static String _keyInfoLine(FeedItem item) {
    final parts = <String>[];
    if (item.type == FeedContentType.video &&
        (item.durationLabel?.trim().isNotEmpty ?? false)) {
      parts.add(item.durationLabel!.trim());
    }
    final sub = item.subtitle.trim();
    if (sub.isNotEmpty) parts.add(sub);
    final venue = item.gameVenue?.trim();
    if (venue != null && venue.isNotEmpty) {
      if (!parts.any((p) => p.contains(venue))) parts.add(venue);
    }
    return parts.join(' · ');
  }

  /// Large word on gradient placeholder (sport name for games).
  static String _coverHeroWord(FeedItem item) {
    switch (item.type) {
      case FeedContentType.game:
        final t = item.title.split('·').first.trim();
        return t.isEmpty ? 'Game' : t;
      case FeedContentType.post:
        return 'Post';
      case FeedContentType.video:
        return 'Video';
    }
  }

  static List<Color> _coverGradient(FeedContentType type, ColorScheme cs) {
    switch (type) {
      case FeedContentType.game:
        return [
          cs.primary.withValues(alpha: 0.82),
          cs.primary.withValues(alpha: 0.52),
        ];
      case FeedContentType.post:
        return [
          cs.secondary.withValues(alpha: 0.72),
          cs.secondary.withValues(alpha: 0.48),
        ];
      case FeedContentType.video:
        return [
          cs.tertiary.withValues(alpha: 0.78),
          cs.tertiary.withValues(alpha: 0.52),
        ];
    }
  }

  static Color _typeChipBackground(FeedContentType t, ColorScheme cs) {
    switch (t) {
      case FeedContentType.game:
        return cs.primaryContainer;
      case FeedContentType.post:
        return cs.secondaryContainer;
      case FeedContentType.video:
        return cs.tertiaryContainer;
    }
  }

  static Color _typeChipForeground(FeedContentType t, ColorScheme cs) {
    switch (t) {
      case FeedContentType.game:
        return cs.onPrimaryContainer;
      case FeedContentType.post:
        return cs.onSecondaryContainer;
      case FeedContentType.video:
        return cs.onTertiaryContainer;
    }
  }

  void _openDetail(FeedItem item) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => FeedDetailPage(item: item),
      ),
    );
  }

  Widget _feedItemCard(ThemeData theme, FeedItem item) {
    final cs = theme.colorScheme;
    final url = item.coverImageUrl?.trim();
    final hasCover = url != null && url.isNotEmpty;
    final keyLine = _keyInfoLine(item);
    final hero = _coverHeroWord(item);

    return Material(
      color: cs.surface,
      elevation: 1.5,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openDetail(item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1.82,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasCover)
                    Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _FeedGradientCover(
                        gradientColors: _coverGradient(item.type, cs),
                        heroText: hero,
                        showHero: true,
                      ),
                    )
                  else
                    _FeedGradientCover(
                      gradientColors: _coverGradient(item.type, cs),
                      heroText: hero,
                      showHero: true,
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 76,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.5),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: _FeedTypeChip(
                      label: _badge(item.type),
                      backgroundColor:
                          _typeChipBackground(item.type, cs).withValues(
                        alpha: 0.94,
                      ),
                      foregroundColor: _typeChipForeground(item.type, cs),
                    ),
                  ),
                  if (item.type == FeedContentType.video &&
                      (item.durationLabel?.trim().isNotEmpty ?? false))
                    Positioned(
                      top: 10,
                      right: 10,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Text(
                            item.durationLabel!.trim(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (keyLine.isNotEmpty)
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 10,
                      child: Text(
                        keyLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontWeight: FontWeight.w600,
                          shadows: const [
                            Shadow(
                              blurRadius: 8,
                              color: Colors.black45,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                  ),
                  if (item.subtitle.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      item.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feed'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_usesToggle)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: SegmentedButton<FeedListDataSource>(
                segments: const [
                  ButtonSegment<FeedListDataSource>(
                    value: FeedListDataSource.supabase,
                    label: Text('Live'),
                    icon: Icon(Icons.cloud_outlined, size: 18),
                  ),
                  ButtonSegment<FeedListDataSource>(
                    value: FeedListDataSource.mock,
                    label: Text('Mock'),
                    icon: Icon(Icons.auto_awesome_outlined, size: 18),
                  ),
                ],
                selected: {_source},
                onSelectionChanged: (s) {
                  if (s.isEmpty) return;
                  _onSourceChanged(s.first);
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
            child: Text(
              !_usesToggle
                  ? 'Using a custom feed source for this screen.'
                  : _source == FeedListDataSource.supabase
                      ? 'Upcoming games from your project.'
                      : 'Preview: sample cards for layout.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant.withValues(alpha: 0.9),
                height: 1.35,
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<FeedItem>>(
              future: _future,
              builder: (context, snapshot) {
                final isMock = _source == FeedListDataSource.mock;
                final slivers = <Widget>[];

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
                } else {
                  final items = snapshot.data ?? const [];
                  if (items.isEmpty) {
                    slivers.add(
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: AppEmptyState(
                          title: isMock
                              ? 'Nothing to preview yet'
                              : 'Nothing to show yet',
                          subtitle: isMock
                              ? 'Sample cards will show when preview data is ready. Pull to refresh anytime.'
                              : 'No upcoming games right now. Check back later, or open Preview for sample cards.',
                          icon: isMock
                              ? Icons.auto_awesome_outlined
                              : Icons.sports_tennis,
                          actionLabel: 'Refresh',
                          onAction: _reload,
                        ),
                      ),
                    );
                  } else {
                    slivers.add(
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, i) => Padding(
                              padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
                              child: _feedItemCard(theme, items[i]),
                            ),
                            childCount: items.length,
                          ),
                        ),
                      ),
                    );
                  }
                }

                return RefreshIndicator(
                  onRefresh: _refreshFeed,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: slivers,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedGradientCover extends StatelessWidget {
  const _FeedGradientCover({
    required this.gradientColors,
    required this.heroText,
    required this.showHero,
  });

  final List<Color> gradientColors;
  final String heroText;
  final bool showHero;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors.length >= 2
              ? gradientColors
              : [gradientColors.first, gradientColors.first],
        ),
      ),
      child: showHero
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  heroText,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                        letterSpacing: -0.5,
                      ),
                ),
              ),
            )
          : null,
    );
  }
}

class _FeedTypeChip extends StatelessWidget {
  const _FeedTypeChip({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: foregroundColor,
              ),
        ),
      ),
    );
  }
}
