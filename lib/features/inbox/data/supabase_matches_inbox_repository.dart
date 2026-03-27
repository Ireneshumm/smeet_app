import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:smeet_app/features/inbox/models/matched_profile_row.dart';

/// Live mutual matches: `matches` + `profiles`, same source as legacy [MatchesPage].
class SupabaseMatchesInboxRepository {
  SupabaseMatchesInboxRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Ordered by most recent match first; one row per peer.
  Future<List<MatchedProfileRow>> fetchMatchRelationships() async {
    final u = _client.auth.currentUser;
    if (u == null) return const [];

    final rows = await _client
        .from('matches')
        .select('user_a,user_b,created_at')
        .or('user_a.eq.${u.id},user_b.eq.${u.id}')
        .order('created_at', ascending: false);

    final list = (rows as List).cast<Map<String, dynamic>>();
    if (list.isEmpty) return const [];

    final peerOrder = <String>[];
    final seenPeers = <String>{};
    final peerLatestMatchAt = <String, DateTime>{};
    for (final m in list) {
      final a = m['user_a'].toString();
      final b = m['user_b'].toString();
      final other = a == u.id ? b : a;
      final rawAt = m['created_at'];
      final at = DateTime.tryParse(rawAt?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      final prev = peerLatestMatchAt[other];
      if (prev == null || at.isAfter(prev)) {
        peerLatestMatchAt[other] = at;
      }
      if (seenPeers.add(other)) {
        peerOrder.add(other);
      }
    }

    if (peerOrder.isEmpty) return const [];

    final prof = await _client
        .from('profiles')
        .select(
          'id,display_name,city,intro,avatar_url,sport_levels,availability',
        )
        .inFilter('id', peerOrder);

    final profiles = (prof as List).cast<Map<String, dynamic>>();
    final map = {for (final p in profiles) p['id'].toString(): p};

    return peerOrder.map((id) {
      final p = map[id];
      final matchedAt = peerLatestMatchAt[id] ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      if (p == null) {
        return MatchedProfileRow(
          peerUserId: id,
          displayName: 'Unknown',
          city: '',
          intro: '',
          avatarUrl: '',
          matchedAt: matchedAt,
        );
      }
      return MatchedProfileRow(
        peerUserId: id,
        displayName: (p['display_name'] ?? 'Unknown').toString(),
        city: (p['city'] ?? '').toString(),
        intro: (p['intro'] ?? '').toString(),
        avatarUrl: (p['avatar_url'] ?? '').toString(),
        matchedAt: matchedAt,
        sportLevels: p['sport_levels'] is Map<String, dynamic>
            ? p['sport_levels'] as Map<String, dynamic>
            : null,
        availability: p['availability'],
      );
    }).toList();
  }
}
