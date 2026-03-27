/// In-app notification categories for the Notifications MVP (mock only).
enum NotificationKind {
  like,
  match,
  comment,
  joinRequest,
  gameReminder,
  message,
  follow,
  nearbyGame,
}

class NotificationItem {
  NotificationItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
  });

  final String id;
  final NotificationKind kind;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;
}
