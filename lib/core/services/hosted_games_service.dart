import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:smeet_app/core/services/game_detail_service.dart';

/// Shared query for games the current user created (`games.created_by`).
///
/// Same field set as [MyGamePage]’s `games` fallback select; ordered by
/// `starts_at` ascending.
class HostedGamesService {
  HostedGamesService([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Single-table `games` where `created_by` is the signed-in user.
  ///
  /// Returns `[]` when not signed in, on error, or when there are no rows.
  Future<List<Map<String, dynamic>>> fetchHostedGameRowsForCurrentUser() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return const [];
    }

    try {
      final data = await _client
          .from('games')
          .select(GameDetailService.selectColumns)
          .eq('created_by', user.id)
          .order('starts_at', ascending: true);

      return (data as List).cast<Map<String, dynamic>>();
    } catch (e, st) {
      debugPrint(
        '[HostedGamesService] fetchHostedGameRowsForCurrentUser failed: $e',
      );
      debugPrint('$st');
      return const [];
    }
  }
}
