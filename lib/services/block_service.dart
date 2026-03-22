import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// UI-safe error for block/unblock failures.
class BlockActionException implements Exception {
  BlockActionException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Reads/writes [public.blocked_users] (RLS: only own rows as [user_id]).
class BlockService {
  BlockService._();

  static final SupabaseClient _client = Supabase.instance.client;

  /// Users you blocked (their ids) and users who blocked you (their ids).
  static Future<({Set<String> iBlocked, Set<String> blockedMe})>
      fetchMyBlockSets() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      return (iBlocked: <String>{}, blockedMe: <String>{});
    }

    try {
      final outRows = await _client
          .from('blocked_users')
          .select('blocked_user_id')
          .eq('user_id', uid);
      final iBlocked = (outRows as List)
          .map((e) => e['blocked_user_id']?.toString())
          .whereType<String>()
          .toSet();

      final inRows = await _client
          .from('blocked_users')
          .select('user_id')
          .eq('blocked_user_id', uid);
      final blockedMe = (inRows as List)
          .map((e) => e['user_id']?.toString())
          .whereType<String>()
          .toSet();

      return (iBlocked: iBlocked, blockedMe: blockedMe);
    } catch (e, st) {
      debugPrint('[Block] fetchMyBlockSets failed: $e\n$st');
      return (iBlocked: <String>{}, blockedMe: <String>{});
    }
  }

  static Future<bool> iBlocked(String otherUserId) async {
    final s = await fetchMyBlockSets();
    return s.iBlocked.contains(otherUserId);
  }

  static Future<bool> blockedMe(String otherUserId) async {
    final s = await fetchMyBlockSets();
    return s.blockedMe.contains(otherUserId);
  }

  static Future<bool> isEitherBlocked(String otherUserId) async {
    final s = await fetchMyBlockSets();
    return s.iBlocked.contains(otherUserId) || s.blockedMe.contains(otherUserId);
  }

  static Future<void> blockUser(String blockedUserId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw BlockActionException('Please sign in to block someone.');
    }
    if (blockedUserId == uid) {
      throw BlockActionException('You can’t block yourself.');
    }
    try {
      await _client.from('blocked_users').insert({
        'user_id': uid,
        'blocked_user_id': blockedUserId,
      });
    } catch (e, st) {
      debugPrint('[Block] blockUser failed: $e\n$st');
      throw BlockActionException(_friendly(e));
    }
  }

  static Future<void> unblockUser(String blockedUserId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw BlockActionException('Please sign in to unblock.');
    }
    try {
      await _client
          .from('blocked_users')
          .delete()
          .eq('user_id', uid)
          .eq('blocked_user_id', blockedUserId);
    } catch (e, st) {
      debugPrint('[Block] unblockUser failed: $e\n$st');
      throw BlockActionException(_friendly(e));
    }
  }

  static String _friendly(Object e) {
    final raw = e.toString().toLowerCase();
    if (raw.contains('duplicate') || raw.contains('unique')) {
      return 'This player is already blocked.';
    }
    if (raw.contains('row-level security') || raw.contains('permission')) {
      return 'You don’t have permission to change this.';
    }
    return 'Something went wrong. Please try again.';
  }
}
