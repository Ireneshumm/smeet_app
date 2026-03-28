import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Client-side checks for game urgency / timing; inserts via [create_game_event_notification].
class GameEventNotificationService {
  GameEventNotificationService([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Call periodically (e.g. 60s) while app is open.
  Future<void> runChecksForJoinedGames(
    Set<String> joinedGameIds,
  ) async {
    final u = _client.auth.currentUser;
    if (u == null || joinedGameIds.isEmpty) return;

    for (final gid in joinedGameIds) {
      try {
        final row = await _client
            .from('games')
            .select(
              'id, starts_at, ends_at, players, joined_count',
            )
            .eq('id', gid)
            .maybeSingle();
        if (row == null) continue;
        final players = (row['players'] as num?)?.toInt() ?? 0;
        final joined = (row['joined_count'] as num?)?.toInt() ?? 0;
        final remaining = players - joined;
        final starts =
            DateTime.tryParse(row['starts_at']?.toString() ?? '')?.toLocal();
        final ends =
            DateTime.tryParse(row['ends_at']?.toString() ?? '')?.toLocal();
        final now = DateTime.now();

        if (remaining == 1 && players > 0) {
          await _tryInsert(gid, 'game_last_spot', {});
        } else if (remaining == 2 && players > 0) {
          await _tryInsert(gid, 'game_almost_full', {});
        }

        if (starts != null && starts.isAfter(now)) {
          final until = starts.difference(now);
          if (until.inMinutes <= 30 && until.inMinutes > 0) {
            await _tryInsert(gid, 'game_starting_soon', {
              'minutes': until.inMinutes,
            });
          }
        }

        if (ends != null &&
            ends.isBefore(now) &&
            now.difference(ends) <= const Duration(hours: 24)) {
          await _tryInsert(gid, 'post_game_share_prompt', {});
        }
      } catch (e) {
        debugPrint('[GameEventNotificationService] game $gid: $e');
      }
    }
  }

  Future<void> _tryInsert(
    String gameId,
    String type,
    Map<String, dynamic> extra,
  ) async {
    try {
      await _client.rpc(
        'create_game_event_notification',
        params: {
          'p_type': type,
          'p_game_id': gameId,
          'p_payload': extra,
        },
      );
    } catch (e) {
      // Duplicate or RPC validation — ignore.
      debugPrint('[GameEventNotificationService] insert $type: $e');
    }
  }
}
