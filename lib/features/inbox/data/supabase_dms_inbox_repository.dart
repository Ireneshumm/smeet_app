import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:smeet_app/core/services/chat_conversation_list_service.dart';
import 'package:smeet_app/features/inbox/models/chat_list_item.dart';

/// Live **DMs** (non-game chats) for Inbox MVP — same filter as legacy [ChatPage] direct rows.
class SupabaseDmsInboxRepository {
  SupabaseDmsInboxRepository({
    ChatConversationListService? conversationList,
    SupabaseClient? client,
  })  : _client = client ?? Supabase.instance.client,
        _conversationList = conversationList ??
            ChatConversationListService(client ?? Supabase.instance.client);

  final SupabaseClient _client;
  final ChatConversationListService _conversationList;

  /// Rows where `chat_kind != 'game'` (typically `direct`), after block filtering from the service.
  Future<List<ChatListItem>> fetchDirectMessageItems() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return const [];
    }

    final rows = await _conversationList.fetchEnrichedListForUser(user.id);
    final dmRows = rows
        .where(
          (c) => (c['chat_kind'] ?? 'direct').toString() != 'game',
        )
        .toList();

    return dmRows.map(_mapRow).toList();
  }

  /// Aligns with [ChatPage] direct [ListTile]: title, subtitle, time, unread.
  ChatListItem _mapRow(Map<String, dynamic> row) {
    final chatId = row['chat_id'].toString();
    final title =
        (row['ui_title'] ?? row['title'] ?? 'Chat').toString();
    final last = (row['last_message'] ?? '').toString();
    final subtitle = last.isEmpty ? 'Say hi 👋' : last;

    final unread = (row['unread'] as num?)?.toInt() ?? 0;
    final rawAt = row['last_message_at'] ?? row['created_at'];
    final updated = DateTime.tryParse(rawAt?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

    return ChatListItem(
      id: chatId,
      kind: InboxTabKind.dms,
      title: title,
      lastMessage: subtitle,
      updatedAt: updated,
      unreadCount: unread,
      directPeerUserId: row['direct_peer_id']?.toString(),
      avatarUrl: row['ui_avatar']?.toString(),
    );
  }
}
