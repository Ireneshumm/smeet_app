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

/// Profile **My sports** — achievement wall for every supported sport.
///
/// Loads `sport_achievements` per user: cells with data are tappable (badge +
/// games/hours); cells without data appear locked (not an add-sport flow).
class SportAchievementWall extends StatefulWidget {
  const SportAchievementWall({super.key, required this.userId, this.supabase});

  final String userId;
  final SupabaseClient? supabase;

  @override
  State<SportAchievementWall> createState() => _SportAchievementWallState();
}

class _SportAchievementWallState extends State<SportAchievementWall> {
  static const double _maxSectionWidth = 600;
  static const double _cellHeight = 92;

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

  static int _crossAxisCountForWidth(double width) {
    if (width >= 280) return 3;
    return 2;
  }

  Widget _sectionShell({required Widget child}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth.clamp(0.0, _maxSectionWidth);
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxSectionWidth),
            child: SizedBox(width: w, child: child),
          ),
        );
      },
    );
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
          return _sectionShell(
            child: const ProfileSectionCard(
              child: LinearProgressIndicator(minHeight: 2),
            ),
          );
        }
        final bySport = _bySport(snap.data!);

        return _sectionShell(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final gridW = constraints.maxWidth;
              final crossAxisCount = _crossAxisCountForWidth(gridW);

              return ProfileSectionCard(
                title: 'My sports',
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: _cellHeight,
                  ),
                  itemCount: kSupportedSports.length,
                  itemBuilder: (context, i) {
                    final sport = kSupportedSports[i].$1;
                    final label = kSupportedSports[i].$3;
                    final row = bySport[sport];
                    final locked = row == null;
                    final played = (row?['games_played'] as num?)?.toInt() ?? 0;
                    final hours = (row?['total_hours'] as num?)?.toDouble() ?? 0.0;
                    final badge = (row?['badge_level'] ?? 'newcomer').toString();

                    return _SportAchievementCell(
                      sportKey: sport,
                      label: label,
                      locked: locked,
                      played: played,
                      badge: badge,
                      onTap: locked
                          ? null
                          : () => _showDetail(
                                context,
                                sport,
                                played,
                                hours,
                                badge,
                              ),
                    );
                  },
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

class _SportAchievementCell extends StatelessWidget {
  const _SportAchievementCell({
    required this.sportKey,
    required this.label,
    required this.locked,
    required this.played,
    required this.badge,
    this.onTap,
  });

  final String sportKey;
  final String label;
  final bool locked;
  final int played;
  final String badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: locked
                ? SmeetApp.smeetGreyLight.withValues(alpha: 0.35)
                : SmeetApp.smeetMintFaint,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: locked
                  ? SmeetApp.smeetGreyLight
                  : SmeetApp.smeetMint.withValues(alpha: 0.25),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                sportEmojiForKey(sportKey),
                style: TextStyle(
                  fontSize: 24,
                  decoration: TextDecoration.none,
                  color: locked
                      ? SmeetApp.smeetGrey.withValues(alpha: 0.55)
                      : null,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: locked ? SmeetApp.smeetGrey : SmeetApp.smeetInk,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 4),
              if (locked)
                Text(
                  'No games yet',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: SmeetApp.smeetGrey.withValues(alpha: 0.85),
                    decoration: TextDecoration.none,
                  ),
                )
              else ...[
                Text(
                  badgeLabel(badge),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: SmeetApp.smeetDeep,
                    decoration: TextDecoration.none,
                  ),
                ),
                Text(
                  '$played games',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: SmeetApp.smeetGrey,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
