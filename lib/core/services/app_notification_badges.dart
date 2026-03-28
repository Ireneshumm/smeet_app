import 'package:flutter/foundation.dart';

import 'package:smeet_app/core/services/user_notifications_repository.dart';

/// Shell-level badges: unread incoming likes (Swipe) and all in-app notifications.
final ValueNotifier<int> smeetIncomingLikesCount = ValueNotifier<int>(0);
final ValueNotifier<int> smeetAppNotificationsUnread = ValueNotifier<int>(0);

Future<void> refreshAppNotificationBadges() async {
  final repo = UserNotificationsRepository();
  smeetIncomingLikesCount.value = await repo.countUnreadIncomingLikes();
  smeetAppNotificationsUnread.value = await repo.countAllUnread();
}

void clearAppNotificationBadges() {
  smeetIncomingLikesCount.value = 0;
  smeetAppNotificationsUnread.value = 0;
}
