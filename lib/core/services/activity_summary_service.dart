import 'package:supabase_flutter/supabase_flutter.dart';

class ActivitySummary {
  final int incomingLikes; // 未读的 incoming_like 通知数
  final int todayGames; // 今天附近还有名额的球局数
  final int newMatches; // 过去 24h 新匹配数
  final Map<String, dynamic>? nextGame; // 我加入的下一场未开始的球局

  const ActivitySummary({
    required this.incomingLikes,
    required this.todayGames,
    required this.newMatches,
    this.nextGame,
  });

  bool get hasAnything =>
      incomingLikes > 0 ||
      todayGames > 0 ||
      newMatches > 0 ||
      nextGame != null;
}

class ActivitySummaryService {
  ActivitySummaryService(this._db);

  final SupabaseClient _db;

  Future<ActivitySummary> fetch(String userId) async {
    final results = await Future.wait<Object?>([
      _countIncomingLikes(userId).catchError((_) => 0),
      _countTodayGames().catchError((_) => 0),
      _countNewMatches(userId).catchError((_) => 0),
      _fetchNextGame(userId).catchError((_) => null),
    ]);

    return ActivitySummary(
      incomingLikes: results[0]! as int,
      todayGames: results[1]! as int,
      newMatches: results[2]! as int,
      nextGame: results[3] as Map<String, dynamic>?,
    );
  }

  Future<int> _countIncomingLikes(String userId) async {
    final rows = await _db
        .from('user_notifications')
        .select('id')
        .eq('user_id', userId)
        .eq('type', 'incoming_like')
        .eq('is_read', false);
    return (rows as List).length;
  }

  Future<int> _countTodayGames() async {
    final now = DateTime.now().toUtc();
    final todayStart = DateTime.utc(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final rows = await _db
        .from('games')
        .select('id, players, joined_count')
        .gte('starts_at', todayStart.toIso8601String())
        .lt('starts_at', todayEnd.toIso8601String());
    return (rows as List).where((g) {
      final p = (g['players'] as num?)?.toInt() ?? 0;
      final j = (g['joined_count'] as num?)?.toInt() ?? 0;
      return p > 0 && j < p;
    }).length;
  }

  Future<int> _countNewMatches(String userId) async {
    final since = DateTime.now()
        .toUtc()
        .subtract(const Duration(hours: 24))
        .toIso8601String();
    final rows = await _db
        .from('matches')
        .select('id')
        .or('user_a.eq.$userId,user_b.eq.$userId')
        .gte('created_at', since);
    return (rows as List).length;
  }

  Future<Map<String, dynamic>?> _fetchNextGame(String userId) async {
    final parts = await _db
        .from('game_participants')
        .select('game_id')
        .eq('user_id', userId)
        .eq('status', 'joined');
    final ids = (parts as List)
        .map((e) => e['game_id']?.toString())
        .whereType<String>()
        .where((e) => e.isNotEmpty)
        .toList();
    if (ids.isEmpty) return null;

    final now = DateTime.now().toUtc().toIso8601String();
    final rows = await _db
        .from('games')
        .select('id, sport, starts_at, ends_at, location_text')
        .inFilter('id', ids)
        .gt('starts_at', now)
        .order('starts_at', ascending: true)
        .limit(1);
    final list = rows as List;
    if (list.isEmpty) return null;
    return (list.first as Map).cast<String, dynamic>();
  }
}
