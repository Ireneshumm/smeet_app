import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Single-row read from `games` for read-only detail (Profile MVP, etc.).
///
/// Column set matches [HostedGamesService] and the nested `games` embed in
/// [JoinedGamesService].
class GameDetailService {
  GameDetailService([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const String selectColumns =
      'id, sport, game_level, starts_at, ends_at, location_text, players, joined_count, per_person, created_by, created_at, game_chat_id';

  /// Returns `null` when missing, RLS denies, or the request fails.
  Future<Map<String, dynamic>?> fetchGameById(String gameId) async {
    try {
      final data = await _client
          .from('games')
          .select(selectColumns)
          .eq('id', gameId)
          .maybeSingle();
      if (data == null) return null;
      return Map<String, dynamic>.from(data as Map);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[GameDetailService] fetchGameById failed: $e');
        debugPrint('$st');
      }
      return null;
    }
  }
}
