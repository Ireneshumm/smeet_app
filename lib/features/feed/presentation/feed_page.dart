import 'package:flutter/material.dart';

import 'package:smeet_app/features/feed/data/feed_repository.dart';
import 'package:smeet_app/features/feed/data/mock_feed_repository.dart';
import 'package:smeet_app/features/feed/data/supabase_feed_repository.dart';
import 'package:smeet_app/features/feed/models/feed_item.dart';
import 'package:smeet_app/features/feed/presentation/feed_detail_page.dart';

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

  IconData _iconFor(FeedContentType t) {
    switch (t) {
      case FeedContentType.post:
        return Icons.article_outlined;
      case FeedContentType.video:
        return Icons.play_circle_outline;
      case FeedContentType.game:
        return Icons.sports_tennis;
    }
  }

  String _badge(FeedContentType t) {
    switch (t) {
      case FeedContentType.post:
        return 'Post';
      case FeedContentType.video:
        return 'Video';
      case FeedContentType.game:
        return 'Game';
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
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openDetail(item),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _iconFor(item.type),
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _badge(item.type),
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (item.durationLabel != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            item.durationLabel!,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (item.gameVenue != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.gameVenue!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.outline,
              ),
            ],
          ),
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
        title: const Text('Feed (MVP)'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_usesToggle)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              !_usesToggle
                  ? 'Custom repository (tests).'
                  : _source == FeedListDataSource.supabase
                      ? 'Live: upcoming games from Supabase (v1).'
                      : 'Mock: sample post / video / game cards.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
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
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: cs.primary,
                        ),
                      ),
                    ),
                  );
                } else if (snapshot.hasError) {
                  slivers.add(
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Couldn’t load feed. Pull to try again.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
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
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyFeedState(
                          isMock: isMock,
                          onRetry: _reload,
                        ),
                      ),
                    );
                  } else {
                    slivers.add(
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12,
                        ),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, i) => Padding(
                              padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
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

class _EmptyFeedState extends StatelessWidget {
  const _EmptyFeedState({
    required this.isMock,
    required this.onRetry,
  });

  final bool isMock;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isMock ? Icons.auto_awesome_outlined : Icons.sports_tennis,
              size: 56,
              color: cs.outline,
            ),
            const SizedBox(height: 16),
            Text(
              isMock ? 'No mock items' : 'No upcoming games',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isMock
                  ? 'Mock data should always show rows — try again.'
                  : 'No rows returned (empty DB, filters, or access). Switch to Mock to preview UI.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Pull down to refresh.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
