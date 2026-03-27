import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:smeet_app/features/notifications/data/mock_notifications_repository.dart';
import 'package:smeet_app/features/notifications/models/notification_item.dart';
import 'package:smeet_app/features/notifications/presentation/notification_detail_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key, this.repository});

  final MockNotificationsRepository? repository;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late final MockNotificationsRepository _repo =
      widget.repository ?? MockNotificationsRepository();
  Future<List<NotificationItem>>? _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.fetchNotifications();
  }

  IconData _iconFor(NotificationKind k) {
    switch (k) {
      case NotificationKind.like:
        return Icons.favorite_outline;
      case NotificationKind.match:
        return Icons.handshake_outlined;
      case NotificationKind.comment:
        return Icons.chat_bubble_outline;
      case NotificationKind.joinRequest:
        return Icons.person_add_alt_1_outlined;
      case NotificationKind.gameReminder:
        return Icons.event_available_outlined;
      case NotificationKind.message:
        return Icons.mail_outline;
      case NotificationKind.follow:
        return Icons.person_add_outlined;
      case NotificationKind.nearbyGame:
        return Icons.place_outlined;
    }
  }

  void _open(NotificationItem item) {
    if (kDebugMode) {
      debugPrint(
        '[Notifications] open id=${item.id} kind=${item.kind.name} read=${item.isRead}',
      );
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => NotificationDetailPage(item: item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: FutureBuilder<List<NotificationItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            if (kDebugMode) {
              debugPrint('[Notifications] load failed: ${snapshot.error}');
            }
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Couldn’t load notifications.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            );
          }
          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return Center(
              child: Text(
                'No notifications yet',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 6),
            itemBuilder: (context, i) {
              final item = items[i];
              final timeStr =
                  DateFormat.MMMd().add_jm().format(item.createdAt.toLocal());
              final unread = !item.isRead;

              return Material(
                color: unread
                    ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
                    : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _open(item),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _iconFor(item.kind),
                          color: unread
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight:
                                      unread ? FontWeight.w800 : FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.body,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(
                                    timeStr,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.outline,
                                    ),
                                  ),
                                  if (unread) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
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
            },
          );
        },
      ),
    );
  }
}
