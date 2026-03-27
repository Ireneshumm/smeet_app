import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:smeet_app/core/services/chat_conversation_list_service.dart';
import 'package:smeet_app/features/inbox/models/chat_list_item.dart';

/// Live **Game Chats** rows for Inbox MVP (subset of [ChatConversationListService]).
class SupabaseGameChatsInboxRepository {
  SupabaseGameChatsInboxRepository({
    ChatConversationListService? conversationList,
    SupabaseClient? client,
  })  : _client = client ?? Supabase.instance.client,
        _conversationList = conversationList ??
            ChatConversationListService(client ?? Supabase.instance.client);

  final SupabaseClient _client;
  final ChatConversationListService _conversationList;

  Future<List<ChatListItem>> fetchGameChatItems() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return const [];
    }

    final rows = await _conversationList.fetchEnrichedListForUser(user.id);
    final gameRows = rows
        .where(
          (c) => (c['chat_kind'] ?? 'direct').toString() == 'game',
        )
        .toList();

    return gameRows.map(_mapRow).toList();
  }

  ChatListItem _mapRow(Map<String, dynamic> row) {
    final chatId = row['chat_id'].toString();
    final title =
        (row['ui_title'] ?? row['title'] ?? 'Game chat').toString();
    final last = (row['last_message'] ?? '').toString();
    final n = (row['member_count'] as num?)?.toInt() ?? 0;
    final subtitle = last.isEmpty ? 'Group chat · $n people' : last;

    final unread = (row['unread'] as num?)?.toInt() ?? 0;
    final rawAt = row['last_message_at'] ?? row['created_at'];
    final updated = DateTime.tryParse(rawAt?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

    return ChatListItem(
      id: chatId,
      kind: InboxTabKind.gameChats,
      title: title,
      lastMessage: subtitle,
      updatedAt: updated,
      unreadCount: unread,
    );
  }
}
