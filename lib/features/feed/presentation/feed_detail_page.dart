import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:smeet_app/features/feed/models/feed_item.dart';

/// Placeholder detail for any feed card (MVP).
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = DateFormat.yMMMd().add_jm().format(item.publishedAt.toLocal());

    return Scaffold(
      appBar: AppBar(
        title: Text(_typeLabel(item.type)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              item.title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.subtitle,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text('id: ${item.id}', style: theme.textTheme.bodySmall),
            Text('published: $dateStr', style: theme.textTheme.bodySmall),
            if (item.durationLabel != null)
              Text('duration: ${item.durationLabel}', style: theme.textTheme.bodySmall),
            if (item.gameVenue != null)
              Text('venue: ${item.gameVenue}', style: theme.textTheme.bodySmall),
            const SizedBox(height: 32),
            Text(
              'Detail content placeholder — connect real payload in a later iteration.',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
