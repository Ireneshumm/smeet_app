import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:smeet_app/app/smeet_app.dart';
import 'package:smeet_app/core/constants/sports.dart';
import 'package:smeet_app/widgets/profile_identity_section.dart';

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
          return const ProfileSectionCard(
            child: LinearProgressIndicator(minHeight: 2),
          );
        }
        final bySport = _bySport(snap.data!);

        return ProfileSectionCard(
          title: 'My sports',
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemCount: kSupportedSports.length,
            itemBuilder: (context, i) {
              final sport = kSupportedSports[i].$1;
              final row = bySport[sport];
              final locked = row == null;
              final played = (row?['games_played'] as num?)?.toInt() ?? 0;
              final hours = (row?['total_hours'] as num?)?.toDouble() ?? 0.0;
              final badge = (row?['badge_level'] ?? 'newcomer').toString();

              return GestureDetector(
                onTap: locked
                    ? null
                    : () => _showDetail(context, sport, played, hours, badge),
                child: Container(
                  decoration: BoxDecoration(
                    color: locked
                        ? SmeetApp.smeetGreyLight.withValues(alpha: 0.35)
                        : SmeetApp.smeetMintFaint,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    sportEmojiForKey(sport),
                    style: TextStyle(
                      fontSize: 48,
                      decoration: TextDecoration.none,
                      color: locked
                          ? SmeetApp.smeetGrey.withValues(alpha: 0.5)
                          : null,
                    ),
                  ),
                ),
              );
            },
          ),
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
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$sport · ${badgeLabel(badge)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$played games · ${hours.toStringAsFixed(1)} h',
              style: const TextStyle(
                color: SmeetApp.smeetGrey,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
