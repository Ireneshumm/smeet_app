import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:smeet_app/services/block_service.dart';

/// Read-only enriched conversation list for the legacy Chat tab and Inbox MVP.
///
/// Owns the former [ChatPage] `_fetchMyChats` query, `_enrichChatRow`, and
/// unread counting. Does **not** bind realtime, shell badges, or open-room UX.
class ChatConversationListService {
  ChatConversationListService([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Same logic as the former top-level [countUnreadForChat] in `main.dart`.
  static Future<int> countUnreadForChat({
    required SupabaseClient supabase,
    required String chatId,
    required String me,
    String? lastReadIso,
  }) async {
    try {
      var q = supabase
          .from('messages')
          .select('id')
          .eq('chat_id', chatId)
          .neq('user_id', me);
      if (lastReadIso != null && lastReadIso.isNotEmpty) {
        q = q.gt('created_at', lastReadIso);
      }
      final rows =
          await q.order('created_at', ascending: false).limit(50);
      return (rows as List).length;
    } catch (_) {
      return 0;
    }
  }

  /// Fetches `chat_members` → `chats`, sorts, enriches, applies block filter.
  ///
  /// Output maps match the shape [ChatPage] previously built (e.g. `chat_id`,
  /// `ui_title`, `unread`, `direct_peer_id`, `member_count`, …).
  Future<List<Map<String, dynamic>>> fetchEnrichedListForUser(
    String userId,
  ) async {
    List<Map<String, dynamic>> list;
    try {
      final data = await _client
          .from('chat_members')
          .select(
            'chat_id, last_read_at, chats(id, last_message, last_message_at, created_at, chat_kind, game_id, title)',
          )
          .eq('user_id', userId);
      list = (data as List).cast<Map<String, dynamic>>();
    } catch (_) {
      final data = await _client
          .from('chat_members')
          .select(
            'chat_id, last_read_at, chats(id, last_message, last_message_at, created_at)',
          )
          .eq('user_id', userId);
      list = (data as List).cast<Map<String, dynamic>>();
    }

    final chats = list.map((row) {
      final chat = (row['chats'] ?? {}) as Map;
      return {
        'chat_id': row['chat_id'],
        'last_read_at': row['last_read_at'],
        'last_message': chat['last_message'],
        'last_message_at': chat['last_message_at'],
        'created_at': chat['created_at'],
        'chat_kind': (chat['chat_kind'] ?? 'direct').toString(),
        'game_id': chat['game_id'],
        'title': chat['title'],
      };
    }).toList();

    chats.sort((a, b) {
      final ta = DateTime.tryParse(
        (a['last_message_at'] ?? '')?.toString() ?? '',
      );
      final tb = DateTime.tryParse(
        (b['last_message_at'] ?? '')?.toString() ?? '',
      );
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return tb.compareTo(ta);
    });

    final enriched =
        await Future.wait(chats.map((c) => _enrichChatRow(c, userId)));

    final blockSets = await BlockService.fetchMyBlockSets();

    return enriched.where((c) {
      final kind = (c['chat_kind'] ?? 'direct').toString();
      if (kind == 'game') return true;
      final peer = c['direct_peer_id']?.toString();
      if (peer == null || peer.isEmpty) return true;
      return !blockSets.iBlocked.contains(peer) &&
          !blockSets.blockedMe.contains(peer);
    }).toList();
  }

  /// Resolves an existing **direct** (non-game) chat the current user shares
  /// with [peerUserId], using the same ordering as [fetchEnrichedListForUser]
  /// (most recent [last_message_at] first).
  ///
  /// Returns null if there is no such row, the peer is block-filtered out, or
  /// multiple 1:1 rows exist (first match wins — DB should ideally enforce one).
  Future<String?> findDirectChatIdForPeer({
    required String myUserId,
    required String peerUserId,
  }) async {
    if (peerUserId.isEmpty) return null;
    final rows = await fetchEnrichedListForUser(myUserId);
    for (final c in rows) {
      if ((c['chat_kind'] ?? 'direct').toString() == 'game') continue;
      if (c['direct_peer_id']?.toString() == peerUserId) {
        return c['chat_id']?.toString();
      }
    }
    return null;
  }

  Future<int> _gameMemberCount(String chatId) async {
    try {
      final rows = await _client
          .from('chat_members')
          .select('user_id')
          .eq('chat_id', chatId);
      return (rows as List).length;
    } catch (_) {
      return 0;
    }
  }

  Future<Map<String, dynamic>> _enrichChatRow(
    Map<String, dynamic> c,
    String myId,
  ) async {
    final chatId = c['chat_id'].toString();
    final lastRead = c['last_read_at']?.toString();
    final kind = (c['chat_kind'] ?? 'direct').toString();

    final unread = await countUnreadForChat(
      supabase: _client,
      chatId: chatId,
      me: myId,
      lastReadIso: lastRead,
    );

    if (kind == 'game') {
      final n = await _gameMemberCount(chatId);
      return {
        ...c,
        'member_count': n,
        'ui_title': (c['title'] ?? 'Game chat').toString(),
        'ui_avatar': null,
        'unread': unread,
        'direct_peer_id': null,
      };
    }

    final other = await _client
        .from('chat_members')
        .select('user_id')
        .eq('chat_id', chatId)
        .neq('user_id', myId)
        .limit(1)
        .maybeSingle();
    final oid = other?['user_id']?.toString();

    var name = 'Chat';
    String? av;
    if (oid != null) {
      final p = await _client
          .from('profiles')
          .select('display_name, avatar_url')
          .eq('id', oid)
          .maybeSingle();
      final dn = (p?['display_name'] ?? '').toString().trim();
      name = dn.isNotEmpty
          ? dn
          : 'User ${oid.length >= 6 ? oid.substring(0, 6) : oid}';
      av = p?['avatar_url']?.toString();
    }

    return {
      ...c,
      'member_count': 0,
      'ui_title': name,
      'ui_avatar': av,
      'unread': unread,
      'direct_peer_id': oid,
    };
  }
}
