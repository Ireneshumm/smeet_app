import 'package:flutter/material.dart';

import 'package:smeet_app/core/services/profile_identity_service.dart';

/// Stats + badge chips from [get_identity_stats] RPC.
class ProfileIdentitySection extends StatelessWidget {
  const ProfileIdentitySection({
    super.key,
    required this.userId,
    this.heading = 'Your sports identity',
  });

  final String userId;
  final String heading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final svc = ProfileIdentityService();

    return FutureBuilder<Map<String, dynamic>?>(
      future: svc.fetchStats(userId),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(minHeight: 2),
          );
        }
        final stats = snap.data;
        if (stats == null) {
          return const SizedBox.shrink();
        }
        final badges = computeBadgeLabels(stats);
        final joined = (stats['total_games_joined'] as num?)?.toInt() ?? 0;
        final hosted = (stats['total_games_hosted'] as num?)?.toInt() ?? 0;
        final met = (stats['unique_players_met'] as num?)?.toInt() ?? 0;
        final matches = (stats['match_count'] as num?)?.toInt() ?? 0;
        final month = (stats['this_month_sessions'] as num?)?.toInt() ?? 0;

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                heading,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  _statChip(theme, 'Joined', '$joined'),
                  _statChip(theme, 'Hosted', '$hosted'),
                  _statChip(theme, 'Players met', '$met'),
                  _statChip(theme, 'Matches', '$matches'),
                  _statChip(theme, 'This month', '$month'),
                ],
              ),
              if (badges.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Badges',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: badges
                      .map(
                        (b) => Chip(
                          label: Text(b),
                          visualDensity: VisualDensity.compact,
                          backgroundColor:
                              cs.primaryContainer.withValues(alpha: 0.6),
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  static Widget _statChip(ThemeData theme, String k, String v) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            k,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            v,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
