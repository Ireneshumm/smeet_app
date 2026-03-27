import 'package:smeet_app/features/notifications/models/notification_item.dart';

class MockNotificationsRepository {
  MockNotificationsRepository();

  Future<List<NotificationItem>> fetchNotifications({
    Duration delay = const Duration(milliseconds: 220),
  }) async {
    await Future<void>.delayed(delay);
    return List<NotificationItem>.unmodifiable(_mock);
  }

  static final List<NotificationItem> _mock = <NotificationItem>[
    NotificationItem(
      id: 'n-like-1',
      kind: NotificationKind.like,
      title: 'Alex liked your post',
      body: '“Weekend ladder is open”',
      createdAt: DateTime.utc(2026, 3, 25, 20, 10),
      isRead: false,
    ),
    NotificationItem(
      id: 'n-match-1',
      kind: NotificationKind.match,
      title: 'New match',
      body: 'You and Jordan both want to play Tennis this week.',
      createdAt: DateTime.utc(2026, 3, 25, 18, 0),
      isRead: false,
    ),
    NotificationItem(
      id: 'n-comment-1',
      kind: NotificationKind.comment,
      title: 'New comment',
      body: 'Taylor: “I’m in for Saturday!”',
      createdAt: DateTime.utc(2026, 3, 24, 12, 30),
      isRead: true,
    ),
    NotificationItem(
      id: 'n-join-1',
      kind: NotificationKind.joinRequest,
      title: 'Join request',
      body: 'Sam wants to join your Open play game.',
      createdAt: DateTime.utc(2026, 3, 24, 9, 15),
      isRead: false,
    ),
    NotificationItem(
      id: 'n-remind-1',
      kind: NotificationKind.gameReminder,
      title: 'Game tomorrow',
      body: 'Doubles mixer · Sun 6:00 PM at Union Gym.',
      createdAt: DateTime.utc(2026, 3, 23, 8, 0),
      isRead: true,
    ),
    NotificationItem(
      id: 'n-msg-1',
      kind: NotificationKind.message,
      title: 'New message',
      body: 'Coach Rivera: Footwork video (mock).',
      createdAt: DateTime.utc(2026, 3, 22, 19, 45),
      isRead: false,
    ),
    NotificationItem(
      id: 'n-follow-1',
      kind: NotificationKind.follow,
      title: 'New follower',
      body: 'Riley started following you.',
      createdAt: DateTime.utc(2026, 3, 21, 14, 20),
      isRead: true,
    ),
    NotificationItem(
      id: 'n-nearby-1',
      kind: NotificationKind.nearbyGame,
      title: 'Game near you',
      body: 'Pickleball · 2 km away · starts in 45 min.',
      createdAt: DateTime.utc(2026, 3, 20, 11, 5),
      isRead: false,
    ),
  ];
}
