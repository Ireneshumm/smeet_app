import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:smeet_app/features/feed/models/feed_item.dart';

/// Detail screen for a feed card — shows only fields present on [FeedItem].
class FeedDetailPage extends StatelessWidget {
  const FeedDetailPage({super.key, required this.item});

  final FeedItem item;

  static String _typeLabel(FeedContentType t) {
    switch (t) {
      case FeedContentType.post:
        return 'Post';
      case FeedContentType.video:
        return 'Video';
      case FeedContentType.game:
        return 'Game';
    }
  }

  static Widget _metaRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
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
        title: const Text('Details'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                visualDensity: VisualDensity.compact,
                label: Text(
                  _typeLabel(item.type),
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                backgroundColor: cs.surfaceContainerHighest,
                side: BorderSide.none,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              item.title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (item.subtitle.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                item.subtitle,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              'Info',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _metaRow(theme, 'When', dateStr),
            if (item.durationLabel != null && item.durationLabel!.isNotEmpty)
              _metaRow(theme, 'Length', item.durationLabel!),
            if (item.gameVenue != null && item.gameVenue!.trim().isNotEmpty)
              _metaRow(theme, 'Where', item.gameVenue!.trim()),
            const SizedBox(height: 8),
            Text(
              'That’s everything we can show for this item right now.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
