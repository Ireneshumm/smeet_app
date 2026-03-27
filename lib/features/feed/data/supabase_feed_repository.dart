import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:smeet_app/features/feed/data/feed_repository.dart';
import 'package:smeet_app/features/feed/models/feed_item.dart';

/// Feed v1: **game-only** rows from `public.games` (same core fields as Home / My Game).
///
/// Returns an empty list when there are no rows, on RLS/network errors, or parse issues
/// (no throw — UI shows empty state).
class SupabaseFeedRepository implements FeedRepository {
  SupabaseFeedRepository([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const int _limit = 50;

  @override
  Future<List<FeedItem>> fetchFeed() async {
    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final data = await _client
          .from('games')
          .select(
            'id, sport, game_level, starts_at, ends_at, location_text, players, joined_count',
          )
          .gte('starts_at', nowIso)
          .order('starts_at', ascending: true)
          .limit(_limit);

      final rows = data as List<dynamic>?;
      if (rows == null || rows.isEmpty) {
        return const [];
      }

      final out = <FeedItem>[];
      for (final raw in rows) {
        if (raw is! Map) continue;
        final row = Map<String, dynamic>.from(raw);
        final item = _mapGameRow(row);
        if (item != null) {
          out.add(item);
        }
      }
      return out;
    } catch (e, st) {
      debugPrint('[SupabaseFeedRepository] fetchFeed failed: $e');
      debugPrint('$st');
      return const [];
    }
  }

  FeedItem? _mapGameRow(Map<String, dynamic> row) {
    try {
      final id = row['id']?.toString();
      if (id == null || id.isEmpty) return null;

      final sport = (row['sport'] ?? 'Game').toString().trim();
      final level = (row['game_level'] ?? '').toString().trim();
      final title = level.isEmpty ? sport : '$sport · $level';

      final start = DateTime.tryParse(row['starts_at']?.toString() ?? '');
      final end = DateTime.tryParse(row['ends_at']?.toString() ?? '');
      final publishedAt = start ?? DateTime.now().toUtc();

      final subtitle = _scheduleSubtitle(start, end, row);

      final loc = row['location_text']?.toString().trim();
      final gameVenue =
          (loc != null && loc.isNotEmpty) ? loc : null;

      return FeedItem(
        id: id,
        type: FeedContentType.game,
        title: title,
        subtitle: subtitle,
        coverImageUrl: null,
        publishedAt: publishedAt,
        durationLabel: null,
        gameVenue: gameVenue,
      );
    } catch (e) {
      debugPrint('[SupabaseFeedRepository] skip row: $e');
      return null;
    }
  }

  String _scheduleSubtitle(
    DateTime? start,
    DateTime? end,
    Map<String, dynamic> row,
  ) {
    final joined = (row['joined_count'] as num?)?.toInt() ?? 0;
    final players = (row['players'] as num?)?.toInt() ?? 0;
    final spots = players > 0 ? '$joined/$players joined' : '$joined joined';

    if (start == null) {
      return spots;
    }
    final dateLine = DateFormat.MMMEd().format(start.toLocal());
    final startT = DateFormat.jm().format(start.toLocal());
    if (end == null) {
      return '$dateLine · $startT · $spots';
    }
    final endT = DateFormat.jm().format(end.toLocal());
    return '$dateLine · $startT – $endT · $spots';
  }
}
