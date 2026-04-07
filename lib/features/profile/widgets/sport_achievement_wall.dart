import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:smeet_app/core/constants/sports.dart';

String badgeLabel(String raw) {
  switch (raw.toLowerCase()) {
    case 'legend':
      return 'Legend';
    case 'pro':
      return 'Pro';
    case 'regular':
      return 'Regular';
    case 'active':
      return 'Active';
    case 'newcomer':
    default:
      return 'Newcomer';
  }
}

/// Next threshold games for progress bar (games played → next tier).
int? gamesToNextTier(int played) {
  if (played < 5) return 5 - played;
  if (played < 15) return 15 - played;
  if (played < 30) return 30 - played;
  if (played < 50) return 50 - played;
  return null;
}

double progressForGames(int played) {
  if (played >= 50) return 1;
  if (played >= 30) return 0.85;
  if (played >= 15) return 0.65;
  if (played >= 5) return 0.45;
  return (played / 5).clamp(0.0, 1.0);
}

class SportAchievementWall extends StatefulWidget {
  const SportAchievementWall({super.key, required this.userId, this.supabase});

  final String userId;
  final SupabaseClient? supabase;

  @override
  State<SportAchievementWall> createState() => _SportAchievementWallState();
}

class _SportAchievementWallState extends State<SportAchievementWall> {
  late final Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final client = widget.supabase ?? Supabase.instance.client;
    final data = await client
        .from('sport_achievements')
        .select('sport, games_played, total_hours, badge_level, updated_at')
        .eq('user_id', widget.userId);
    return (data as List).cast<Map<String, dynamic>>();
  }

  Map<String, Map<String, dynamic>> _bySport(List<Map<String, dynamic>> rows) {
    final m = <String, Map<String, dynamic>>{};
    for (final r in rows) {
      final s = (r['sport'] ?? '').toString();
      if (s.isNotEmpty) {
        m[s] = r;
      }
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          return const SizedBox.shrink();
        }
        if (!snap.hasData) {
          return const SizedBox(
            height: 4,
            child: LinearProgressIndicator(minHeight: 2),
          );
        }
        final bySport = _bySport(snap.data!);
        final theme = Theme.of(context);
        final cs = theme.colorScheme;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My sports',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 148,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: kSupportedSports.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final sport = kSupportedSports[i].$1;
                  final row = bySport[sport];
                  final locked = row == null;
                  final played =
                      (row?['games_played'] as num?)?.toInt() ?? 0;
                  final hours =
                      (row?['total_hours'] as num?)?.toDouble() ?? 0.0;
                  final badge =
                      (row?['badge_level'] ?? 'newcomer').toString();

                  return GestureDetector(
                    onTap: locked
                        ? null
                        : () => _showDetail(context, sport, played, hours, badge),
                    child: Container(
                      width: 110,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: locked
                            ? cs.surfaceContainerHighest.withValues(alpha: 0.5)
                            : cs.primaryContainer.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: cs.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sportEmojiForKey(sport),
                            style: const TextStyle(fontSize: 26),
                          ),
                          const Spacer(),
                          if (locked)
                            Text(
                              'Play a game to unlock',
                              maxLines: 2,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                height: 1.2,
                              ),
                            )
                          else ...[
                            Text(
                              badgeLabel(badge),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '$played games',
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progressForGames(played),
                                minHeight: 5,
                                backgroundColor:
                                    cs.surfaceContainerHighest.withValues(
                                  alpha: 0.8,
                                ),
                              ),
                            ),
                            if (gamesToNextTier(played) != null)
                              Text(
                                '${gamesToNextTier(played)} more to level up',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 10,
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _showDetail(
    BuildContext context,
    String sport,
    int played,
    double hours,
    String badge,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$sport · ${badgeLabel(badge)}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Games played: $played'),
            Text('Hours: ${hours.toStringAsFixed(1)} h'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
