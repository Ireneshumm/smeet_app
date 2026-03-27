/// Which Inbox MVP tab owns this row (mock segmentation).
enum InboxTabKind {
  matches,
  gameChats,
  dms,
}

/// One conversation-style row in the inbox (mock or live).
class ChatListItem {
  ChatListItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.lastMessage,
    required this.updatedAt,
    required this.unreadCount,
    this.directPeerUserId,
    this.avatarUrl,
  });

  /// Chat id (`chats.id` / `chat_members.chat_id`).
  final String id;
  final InboxTabKind kind;
  final String title;
  final String lastMessage;
  final DateTime updatedAt;

  /// Row unread (live rows mirror [ChatConversationListService] counts).
  final int unreadCount;

  /// Other user in a direct chat; null for game chats and mock rows.
  final String? directPeerUserId;

  /// Direct chat peer avatar URL from [ChatConversationListService] (`ui_avatar`).
  final String? avatarUrl;
}
