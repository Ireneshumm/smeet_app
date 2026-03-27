import 'package:intl/intl.dart';

import 'package:smeet_app/core/services/hosted_games_service.dart';
import 'package:smeet_app/features/profile/models/profile_tab_item.dart';

/// Profile MVP **Hosted** tab — maps [HostedGamesService] rows to [ProfileTabItem].
///
/// No roster / profiles / chat; list-only. Mapping aligns with
/// [SupabaseProfileJoinedRepository].
class SupabaseProfileHostedRepository {
  SupabaseProfileHostedRepository([HostedGamesService? hostedGames])
      : _hostedGames = hostedGames ?? HostedGamesService();

  final HostedGamesService _hostedGames;

  Future<List<ProfileTabItem>> fetchHostedTabItems() async {
    final rows = await _hostedGames.fetchHostedGameRowsForCurrentUser();
    if (rows.isEmpty) {
      return const [];
    }

    final out = <ProfileTabItem>[];
    for (final row in rows) {
      final item = _mapRow(row);
      if (item != null) {
        out.add(item);
      }
    }
    return out;
  }

  ProfileTabItem? _mapRow(Map<String, dynamic> row) {
    try {
      final id = row['id']?.toString();
      if (id == null || id.isEmpty) return null;

      final sport = (row['sport'] ?? '').toString().trim();
      final gameLevel = (row['game_level'] ?? '').toString().trim();
      var title = [
        if (sport.isNotEmpty) sport,
        if (gameLevel.isNotEmpty) gameLevel,
      ].join(' · ');
      if (title.isEmpty) {
        title = 'Game';
      }

      final starts = DateTime.tryParse(row['starts_at']?.toString() ?? '');
      final when = starts != null
          ? DateFormat.yMMMd().add_jm().format(starts.toLocal())
          : '—';

      final players = row['players'];
      final joined = row['joined_count'];
      final pStr = players is num ? players.toInt().toString() : '?';
      final jStr = joined is num ? joined.toInt().toString() : '?';

      final loc = (row['location_text'] ?? '').toString().trim();
      final locShort = loc.isEmpty
          ? ''
          : (loc.length > 42 ? '${loc.substring(0, 39)}…' : loc);

      final subtitle = [
        'Hosting',
        when,
        '$jStr/$pStr players',
        if (locShort.isNotEmpty) locShort,
      ].join(' · ');

      return ProfileTabItem(
        id: id,
        tab: ProfileContentTab.hosted,
        title: title,
        subtitle: subtitle,
      );
    } catch (_) {
      return null;
    }
  }
}
