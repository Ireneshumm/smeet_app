import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:smeet_app/core/services/app_notification_badges.dart';
import 'package:smeet_app/core/services/user_notifications_repository.dart';
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
  late final MockNotificationsRepository _mockRepo =
      widget.repository ?? MockNotificationsRepository();
  final UserNotificationsRepository _liveRepo = UserNotificationsRepository();

  Future<List<NotificationItem>>? _mockFuture;
  Future<List<Map<String, dynamic>>>? _liveFuture;
  StreamSubscription<List<Map<String, dynamic>>>? _liveNotifSub;

  bool get _useLive =>
      widget.repository == null &&
      Supabase.instance.client.auth.currentUser != null;

  @override
  void initState() {
    super.initState();
    _reload();
    if (widget.repository == null &&
        Supabase.instance.client.auth.currentUser != null) {
      _liveNotifSub = _liveRepo.watchMine().listen((_) {
        if (!mounted) return;
        setState(() {
          _liveFuture = _liveRepo.fetchRecent(limit: 80);
        });
        unawaited(refreshAppNotificationBadges());
      });
    }
  }

  @override
  void dispose() {
    _liveNotifSub?.cancel();
    super.dispose();
  }

  void _reload() {
    if (_useLive) {
      setState(() {
        _liveFuture = _liveRepo.fetchRecent(limit: 80);
      });
    } else {
      setState(() {
        _mockFuture = _mockRepo.fetchNotifications();
      });
    }
  }

  (String title, String body) _mapLiveRow(Map<String, dynamic> row) {
    final type = row['type']?.toString() ?? '';
    final payload = row['payload'];
    Map<String, dynamic> pl = {};
    if (payload is Map) {
      pl = Map<String, dynamic>.from(payload);
    }
    switch (type) {
      case 'incoming_like':
        return ('Someone liked you', 'Open Swipe → Likes you to respond.');
      case 'mutual_match':
        return ('New match', 'You both liked each other — say hi in Chat.');
      case 'game_last_spot':
        return ('Last spot', pl['game_id'] != null ? 'A game you joined is almost full.' : 'A game is almost full.');
      case 'game_almost_full':
        return ('Almost full', 'Only a couple of spots left in your game.');
      case 'game_starting_soon':
        return ('Starting soon', 'One of your games begins within the next 30 minutes.');
      case 'post_game_share_prompt':
        return ('Share your session', 'Post a photo or recap from your last game.');
      default:
        return ('Update', type);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_useLive) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
          actions: [
            IconButton(
              onPressed: _reload,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _liveFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Couldn’t load notifications.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            }
            final rows = snapshot.data ?? [];
            if (rows.isEmpty) {
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
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, i) {
                final row = rows[i];
                final id = row['id'].toString();
                final isRead = row['is_read'] == true;
                final created = DateTime.tryParse(
                      row['created_at']?.toString() ?? '',
                    )?.toLocal() ??
                    DateTime.now();
                final timeStr =
                    DateFormat.MMMd().add_jm().format(created.toLocal());
                final mapped = _mapLiveRow(row);
                return Material(
                  color: isRead
                      ? theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.4)
                      : theme.colorScheme.primaryContainer
                          .withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      await _liveRepo.markRead(id);
                      if (mounted) {
                        await refreshAppNotificationBadges();
                        _reload();
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.notifications_active_outlined,
                            color: isRead
                                ? theme.colorScheme.outline
                                : theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  mapped.$1,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight:
                                        isRead ? FontWeight.w500 : FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  mapped.$2,
                                  maxLines: 3,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  timeStr,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                              ],
                            ),
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

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: FutureBuilder<List<NotificationItem>>(
        future: _mockFuture,
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
          final items = snapshot.data ?? const <NotificationItem>[];
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
                    : theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (context) => NotificationDetailPage(item: item),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.notifications_outlined,
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
                                  fontWeight: unread
                                      ? FontWeight.w800
                                      : FontWeight.w500,
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
                              Text(
                                timeStr,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.outline,
                                ),
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
