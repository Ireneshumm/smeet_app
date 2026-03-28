import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// RPC [get_identity_stats] + badge labels (rules live in Dart for easy edits).
class ProfileIdentityService {
  ProfileIdentityService([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<Map<String, dynamic>?> fetchStats(String userId) async {
    try {
      final res =
          await _client.rpc('get_identity_stats', params: {'p_user_id': userId});
      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }
      if (res is Map<String, dynamic>) return res;
      return null;
    } catch (e, st) {
      debugPrint('[ProfileIdentityService] fetchStats: $e');
      debugPrint('$st');
      return null;
    }
  }
}

List<String> computeBadgeLabels(Map<String, dynamic>? stats) {
  if (stats == null) return [];
  final out = <String>[];
  final joined = (stats['total_games_joined'] as num?)?.toInt() ?? 0;
  final hosted = (stats['total_games_hosted'] as num?)?.toInt() ?? 0;
  final matches = (stats['match_count'] as num?)?.toInt() ?? 0;
  final month = (stats['this_month_sessions'] as num?)?.toInt() ?? 0;

  if (joined + hosted == 0) {
    out.add('New Player');
  }
  if (month >= 2) {
    out.add('Weekly Hitter');
  }
  if (matches >= 1) {
    out.add('Social Starter');
  }
  if (hosted >= 1) {
    out.add('Game Organizer');
  }
  if (joined >= 5) {
    out.add('Regular');
  }
  return out.toSet().toList();
}
