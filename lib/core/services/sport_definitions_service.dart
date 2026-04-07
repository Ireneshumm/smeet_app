import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:smeet_app/core/constants/sports.dart';

/// Cached sport level rows from [sport_level_definitions].
class SportDefinitionsService {
  SportDefinitionsService(this._db);

  final SupabaseClient _db;

  static final Map<String, List<SportLevelDefinition>> _cache = {};

  static void clearCache() {
    _cache.clear();
  }

  Future<List<SportLevelDefinition>> getLevelsForSport(String sport) async {
    final sportKey = canonicalSportKey(sport);
    if (_cache.containsKey(sportKey)) {
      if (kDebugMode) {
        debugPrint(
          '[SportDefs] cache hit sport=$sportKey count=${_cache[sportKey]!.length}',
        );
      }
      return _cache[sportKey]!;
    }

    final rows = await _db
        .from('sport_level_definitions')
        .select()
        .eq('sport', sportKey)
        .order('sort_order');

    var list = (rows as List)
        .map(
          (r) =>
              SportLevelDefinition.fromRow(Map<String, dynamic>.from(r as Map)),
        )
        .toList();

    if (list.isEmpty) {
      final fallback = await _db
          .from('sport_level_definitions')
          .select()
          .ilike('sport', sport.trim())
          .order('sort_order');
      list = (fallback as List)
          .map(
            (r) => SportLevelDefinition.fromRow(
              Map<String, dynamic>.from(r as Map),
            ),
          )
          .toList();
    }

    if (kDebugMode) {
      debugPrint(
        '[SportDefs] fetched sport=$sportKey rows=${list.length} '
        'labels=${list.map((l) => l.levelLabel).toList()}',
      );
    }

    final cacheKey =
        list.isEmpty ? sportKey : canonicalSportKey(list.first.sport);
    _cache[cacheKey] = list;
    if (cacheKey != sportKey) {
      _cache[sportKey] = list;
    }
    return list;
  }

  Future<Map<String, List<SportLevelDefinition>>> getAllSports() async {
    final rows =
        await _db.from('sport_level_definitions').select().order('sport').order(
              'sort_order',
            );
    final map = <String, List<SportLevelDefinition>>{};
    for (final raw in rows as List) {
      final def = SportLevelDefinition.fromRow(
        Map<String, dynamic>.from(raw as Map),
      );
      final key = canonicalSportKey(def.sport);
      map.putIfAbsent(key, () => []).add(def);
    }
    for (final k in map.keys.toList()) {
      map[k]!.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }
    if (kDebugMode) {
      debugPrint(
        '[SportDefs] getAllSports sports=${map.keys.toList()} '
        'counts=${map.map((k, v) => MapEntry(k, v.length))}',
      );
    }
    return map;
  }
}

class SportLevelDefinition {
  const SportLevelDefinition({
    required this.sport,
    required this.levelKey,
    required this.levelLabel,
    this.levelDescription,
    required this.sortOrder,
  });

  final String sport;
  final String levelKey;
  final String levelLabel;
  final String? levelDescription;
  final int sortOrder;

  factory SportLevelDefinition.fromRow(Map<String, dynamic> r) {
    return SportLevelDefinition(
      sport: r['sport']?.toString() ?? '',
      levelKey: r['level_key']?.toString() ?? '',
      levelLabel: r['level_label']?.toString() ?? '',
      levelDescription: r['level_description']?.toString(),
      sortOrder: (r['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  /// Match a stored profile value (new [levelKey], old English label, or legacy key).
  bool matchesStored(String stored) {
    final s = stored.trim();
    if (s.isEmpty) return false;
    if (levelKey.toLowerCase() == s.toLowerCase()) return true;
    if (levelLabel.toLowerCase() == s.toLowerCase()) return true;
    final canon = canonicalLegacyLevelKey(s);
    if (canon != null && levelKey.toLowerCase() == canon) return true;
    return false;
  }
}

/// Maps old generic labels (Beginner, …) to canonical [level_key] names where possible.
String? canonicalLegacyLevelKey(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'beginner':
    case '初级':
      return 'beginner';
    case 'intermediate':
    case '中级':
      return 'intermediate';
    case 'advanced':
    case '高级':
      return 'advanced';
    case 'competitive':
    case '竞技':
    case '竞技级':
      return 'competitive';
    case 'pro':
    case 'elite':
    case '专家':
    case '精英':
      return 'competitive';
    case 'casual':
    case '休闲':
      return 'casual';
    case 'gym':
      return 'beginner';
    default:
      return null;
  }
}

int? sortOrderForStored(
  List<SportLevelDefinition> defs,
  String stored,
) {
  for (final d in defs) {
    if (d.matchesStored(stored)) return d.sortOrder;
  }
  return null;
}
