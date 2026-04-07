import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:smeet_app/features/feed/models/feed_item.dart';
import 'package:smeet_app/features/feed/widgets/feed_detail_video.dart';
import 'package:smeet_app/widgets/adaptive_media.dart';
import 'package:smeet_app/features/profile/models/profile_tab_item.dart';
import 'package:smeet_app/features/profile/presentation/profile_game_detail_page.dart';

/// Detail screen for a feed card — content-forward layout aligned with [FeedPage] cards.
class FeedDetailPage extends StatelessWidget {
  const FeedDetailPage({super.key, required this.item});

  final FeedItem item;

  static String _typeBadge(FeedContentType t) {
    switch (t) {
      case FeedContentType.post:
        return 'Post';
      case FeedContentType.video:
        return 'Video';
      case FeedContentType.game:
        return 'Game';
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

  void _openGameDetail(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => ProfileMvpGameDetailPage(
          item: ProfileTabItem(
            id: item.id,
            tab: ProfileContentTab.posts,
            title: item.title,
            subtitle: item.subtitle,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dateStr =
        DateFormat.yMMMd().add_jm().format(item.publishedAt.toLocal());

    return Scaffold(
      appBar: AppBar(
        title: Text(_typeBadge(item.type)),
      ),
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _FeedDetailCoverBanner(item: item),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      Text(
                        item.title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      if (item.subtitle.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          item.subtitle,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: cs.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      Text(
                        'At a glance',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _DetailFactRow(
                        icon: Icons.schedule_rounded,
                        text: dateStr,
                      ),
                      if (item.durationLabel != null &&
                          item.durationLabel!.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _DetailFactRow(
                          icon: Icons.timer_outlined,
                          text: item.durationLabel!.trim(),
                        ),
                      ],
                      if (item.gameVenue != null &&
                          item.gameVenue!.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _DetailFactRow(
                          icon: Icons.place_outlined,
                          text: item.gameVenue!.trim(),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Text(
                        _footerHint(item.type),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
          Material(
            elevation: 6,
            shadowColor: Colors.black26,
            color: cs.surface,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: _FeedDetailCtaBar(
                  item: item,
                  onOpenGame: () => _openGameDetail(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _footerHint(FeedContentType type) {
    switch (type) {
      case FeedContentType.game:
        return 'Schedules and spots can change — open the game for the latest details.';
      case FeedContentType.video:
        return 'Video plays above when available. Schedules and details may change.';
      case FeedContentType.post:
        return 'This is a preview card. A full article view will arrive when posts go live in the app.';
    }
  }
}

String _feedDetailFirstMediaUrl(FeedItem item) {
  final list = item.mediaUrls;
  if (list != null && list.isNotEmpty) {
    final s = list.first.trim();
    if (s.isNotEmpty) return s;
  }
  return item.coverImageUrl?.trim() ?? '';
}

/// Same cover language as feed cards: image, gradient fallback, type chip, key line.
class _FeedDetailCoverBanner extends StatelessWidget {
  const _FeedDetailCoverBanner({required this.item});

  final FeedItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final videoUrl = item.videoUrl?.trim();
    final hasVideo = videoUrl != null && videoUrl.isNotEmpty;
    final mediaUrl = _feedDetailFirstMediaUrl(item);
    final hasCover = mediaUrl.isNotEmpty;
    final keyLine = FeedDetailPage._keyInfoLine(item);
    final hero = FeedDetailPage._coverHeroWord(item);
    final gradient = FeedDetailPage._coverGradient(item.type, cs);

    if (hasVideo) {
      return FeedDetailVideo(url: videoUrl);
    }

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        if (hasCover)
          AdaptiveNetworkImage(
            imageUrl: mediaUrl,
            errorBuilder: (context) => _FdGradientCover(
              gradientColors: gradient,
              heroText: hero,
            ),
          )
        else
          AspectRatio(
            aspectRatio: 16 / 9,
            child: _FdGradientCover(
              gradientColors: gradient,
              heroText: hero,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 88,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.52),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            child: _FdTypeChip(
              label: FeedDetailPage._typeBadge(item.type),
              backgroundColor: FeedDetailPage._typeChipBackground(item.type, cs)
                  .withValues(alpha: 0.94),
              foregroundColor:
                  FeedDetailPage._typeChipForeground(item.type, cs),
            ),
          ),
          if (item.type == FeedContentType.video &&
              (item.durationLabel?.trim().isNotEmpty ?? false))
            Positioned(
              top: 12,
              right: 12,
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
              left: 14,
              right: 14,
              bottom: 12,
              child: Text(
                keyLine,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                  shadows: const [
                    Shadow(blurRadius: 8, color: Colors.black45),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

class _FdGradientCover extends StatelessWidget {
  const _FdGradientCover({
    required this.gradientColors,
    required this.heroText,
  });

  final List<Color> gradientColors;
  final String heroText;

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
      child: Center(
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
      ),
    );
  }
}

class _FdTypeChip extends StatelessWidget {
  const _FdTypeChip({
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

class _DetailFactRow extends StatelessWidget {
  const _DetailFactRow({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: cs.primary.withValues(alpha: 0.85)),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.35,
                  ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FeedDetailCtaBar extends StatelessWidget {
  const _FeedDetailCtaBar({
    required this.item,
    required this.onOpenGame,
  });

  final FeedItem item;
  final VoidCallback onOpenGame;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (item.type == FeedContentType.game) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: onOpenGame,
          child: const Text('View game'),
        ),
      );
    }

    final copy = item.type == FeedContentType.video
        ? (item.videoUrl != null && item.videoUrl!.trim().isNotEmpty
            ? 'Use the system controls on the clip above. Pull down or go back to keep browsing.'
            : 'Video URL missing — you can still browse other feed items.')
        : 'Posts will get a richer reading experience soon. For now, keep exploring the feed.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          copy,
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: const Text('Back to feed'),
        ),
      ],
    );
  }
}
