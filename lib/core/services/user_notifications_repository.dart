import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// In-app [user_notifications] rows (RLS: own rows only).
class UserNotificationsRepository {
  UserNotificationsRepository([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<int> countUnreadIncomingLikes() async {
    final u = _client.auth.currentUser;
    if (u == null) return 0;
    try {
      final rows = await _client
          .from('user_notifications')
          .select('id')
          .eq('user_id', u.id)
          .eq('type', 'incoming_like')
          .eq('is_read', false);
      return (rows as List).length;
    } catch (e, st) {
      debugPrint('[UserNotificationsRepository] countUnreadIncomingLikes: $e');
      debugPrint('$st');
      return 0;
    }
  }

  Future<int> countAllUnread() async {
    final u = _client.auth.currentUser;
    if (u == null) return 0;
    try {
      final rows = await _client
          .from('user_notifications')
          .select('id')
          .eq('user_id', u.id)
          .eq('is_read', false);
      return (rows as List).length;
    } catch (e) {
      debugPrint('[UserNotificationsRepository] countAllUnread: $e');
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> fetchRecent({int limit = 50}) async {
    final u = _client.auth.currentUser;
    if (u == null) return [];
    final rows = await _client
        .from('user_notifications')
        .select()
        .eq('user_id', u.id)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> markRead(String id) async {
    await _client
        .from('user_notifications')
        .update({'is_read': true}).eq('id', id);
  }

  Future<void> markIncomingLikesFromUserRead(String actorUserId) async {
    final u = _client.auth.currentUser;
    if (u == null) return;
    await _client
        .from('user_notifications')
        .update({'is_read': true})
        .eq('user_id', u.id)
        .eq('type', 'incoming_like')
        .eq('actor_user_id', actorUserId);
  }

  /// Supabase realtime: primary key stream.
  Stream<List<Map<String, dynamic>>> watchMine() {
    final u = _client.auth.currentUser;
    if (u == null) {
      return const Stream.empty();
    }
    return _client
        .from('user_notifications')
        .stream(primaryKey: ['id']).eq('user_id', u.id);
  }
}
