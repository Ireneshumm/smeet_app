import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:smeet_app/core/services/game_detail_service.dart';

/// Shared query for games the current user has joined via [game_participants].
///
/// Same embed + sort as [MyGamePage]’s logged-in primary path (before guest
/// [joinedLocal] fallback and roster attachment).
class JoinedGamesService {
  JoinedGamesService([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// `game_participants` → nested `games`, `user_id` + `status = joined`,
  /// sorted by `starts_at` ascending.
  ///
  /// Returns `[]` when not signed in, on error, or when there are no rows.
  Future<List<Map<String, dynamic>>> fetchJoinedGameRowsForCurrentUser() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return const [];
    }

    try {
      final rows = await _client
          .from('game_participants')
          .select(
            'game_id, games(${GameDetailService.selectColumns})',
          )
          .eq('user_id', user.id)
          .eq('status', 'joined');

      final games = <Map<String, dynamic>>[];
      for (final r in rows as List) {
        final nested = r['games'];
        if (nested is Map) {
          games.add(
            Map<String, dynamic>.from(Map<Object?, Object?>.from(nested)),
          );
        }
      }
      games.sort((a, b) {
        final ta = DateTime.tryParse(a['starts_at']?.toString() ?? '');
        final tb = DateTime.tryParse(b['starts_at']?.toString() ?? '');
        if (ta == null && tb == null) return 0;
        if (ta == null) return 1;
        if (tb == null) return -1;
        return ta.compareTo(tb);
      });
      return games;
    } catch (e, st) {
      debugPrint(
        '[JoinedGamesService] fetchJoinedGameRowsForCurrentUser failed: $e',
      );
      debugPrint('$st');
      return const [];
    }
  }
}
