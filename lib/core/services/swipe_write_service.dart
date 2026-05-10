import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Single path for recording a swipe against [swipes_from_to_unique].
///
/// PostgREST upsert requires `Prefer: resolution=merge-duplicates` + `on_conflict`.
/// If anything prevents a true upsert (client, proxy, race), PostgreSQL returns
/// **23505** on insert; we fall back to **UPDATE** on the existing pair.
class SwipeWriteService {
  SwipeWriteService(this._client);

  final SupabaseClient _client;

  static bool _isUniqueViolation(PostgrestException e) {
    final c = e.code?.toString();
    if (c == '23505') return true;
    final msg = e.message.toLowerCase();
    return msg.contains('duplicate key') || msg.contains('unique constraint');
  }

  /// Persists one row per ([fromUser], [toUser]); latest [action] wins.
  Future<void> recordSwipe({
    required String fromUser,
    required String toUser,
    required String action,
  }) async {
    try {
      await _client.from('swipes').upsert(
        {
          'from_user': fromUser,
          'to_user': toUser,
          'action': action,
        },
        onConflict: 'from_user,to_user',
      );
    } on PostgrestException catch (e) {
      if (!_isUniqueViolation(e)) rethrow;
      if (kDebugMode) {
        debugPrint(
          '[Swipe] upsert hit unique violation (${e.code}), using update fallback',
        );
      }
      try {
        await _client
            .from('swipes')
            .update({'action': action})
            .eq('from_user', fromUser)
            .eq('to_user', toUser);
      } on PostgrestException catch (e2) {
        if (kDebugMode) {
          debugPrint('[Swipe] update fallback failed: $e2');
        }
        // Row already reflects a prior write; avoid breaking UX.
      }
    }
  }
}
