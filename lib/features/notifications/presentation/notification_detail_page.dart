import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:smeet_app/features/notifications/models/notification_item.dart';

class NotificationDetailPage extends StatelessWidget {
  const NotificationDetailPage({super.key, required this.item});

  final NotificationItem item;

  static String _kindLabel(NotificationKind k) {
    switch (k) {
      case NotificationKind.like:
        return 'Like';
      case NotificationKind.match:
        return 'Match';
      case NotificationKind.comment:
        return 'Comment';
      case NotificationKind.joinRequest:
        return 'Join request';
      case NotificationKind.gameReminder:
        return 'Game reminder';
      case NotificationKind.message:
        return 'Message';
      case NotificationKind.follow:
        return 'Follow';
      case NotificationKind.nearbyGame:
        return 'Nearby game';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final when = DateFormat.yMMMd().add_jm().format(item.createdAt.toLocal());

    return Scaffold(
      appBar: AppBar(
        title: Text(_kindLabel(item.kind)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              item.title,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(item.body, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 16),
            Text('Created: $when', style: theme.textTheme.bodySmall),
            Text('Read (mock): ${item.isRead}', style: theme.textTheme.bodySmall),
            Text('id: ${item.id}', style: theme.textTheme.bodySmall),
            const SizedBox(height: 28),
            Text(
              'Placeholder — no FCM / Supabase / push yet.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
