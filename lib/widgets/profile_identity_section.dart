import 'package:flutter/material.dart';

import 'package:smeet_app/app/smeet_app.dart';
import 'package:smeet_app/core/services/profile_identity_service.dart';

/// Shared white section card for profile tab sections.
class ProfileSectionCard extends StatelessWidget {
  const ProfileSectionCard({
    super.key,
    this.title,
    required this.child,
  });

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SmeetApp.smeetGreyLight),
        boxShadow: [
          BoxShadow(
            color: SmeetApp.smeetMint.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: SmeetApp.smeetInk,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

/// Stats + badge chips from [get_identity_stats] RPC (collapsible by default).
class ProfileIdentitySection extends StatefulWidget {
  const ProfileIdentitySection({
    super.key,
    required this.userId,
    this.heading = 'Your sports identity',
  });

  final String userId;
  final String heading;

  @override
  State<ProfileIdentitySection> createState() => _ProfileIdentitySectionState();
}

class _ProfileIdentitySectionState extends State<ProfileIdentitySection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final svc = ProfileIdentityService();

    return FutureBuilder<Map<String, dynamic>?>(
      future: svc.fetchStats(widget.userId),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const ProfileSectionCard(
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

        return ProfileSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.heading,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: SmeetApp.smeetInk,
                                decoration: TextDecoration.none,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _CollapsedStatsRow(
                              joined: joined,
                              hosted: hosted,
                              matches: matches,
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: SmeetApp.smeetMint,
                        size: 28,
                      ),
                    ],
                  ),
                ),
              ),
              if (_expanded)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _statBox(
                              '$joined',
                              'Joined',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _statBox(
                              '$hosted',
                              'Hosted',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _statBox(
                              '$met',
                              'Players met',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _statBox(
                              '$matches',
                              'Matches',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: SmeetApp.smeetMintFaint,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.trending_up_rounded,
                              size: 16,
                              color: SmeetApp.smeetMint,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'This month: ',
                              style: TextStyle(
                                fontSize: 13,
                                color: SmeetApp.smeetGrey,
                                fontWeight: FontWeight.w500,
                                decoration: TextDecoration.none,
                              ),
                            ),
                            Text(
                              '$month',
                              style: const TextStyle(
                                fontSize: 13,
                                color: SmeetApp.smeetInk,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (badges.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Badges',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: SmeetApp.smeetInk,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: badges.map(_badgeChip).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  static Widget _statBox(String value, String label) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SmeetApp.smeetMintFaint,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: SmeetApp.smeetInk,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: SmeetApp.smeetGrey,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _badgeChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: SmeetApp.smeetMintLight,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: SmeetApp.smeetDeep,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

class _CollapsedStatsRow extends StatelessWidget {
  const _CollapsedStatsRow({
    required this.joined,
    required this.hosted,
    required this.matches,
  });

  final int joined;
  final int hosted;
  final int matches;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _miniStat('$joined', 'Joined')),
        Container(
          width: 1,
          height: 28,
          color: SmeetApp.smeetGreyLight,
        ),
        Expanded(child: _miniStat('$hosted', 'Hosted')),
        Container(
          width: 1,
          height: 28,
          color: SmeetApp.smeetGreyLight,
        ),
        Expanded(child: _miniStat('$matches', 'Matches')),
      ],
    );
  }

  static Widget _miniStat(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: SmeetApp.smeetInk,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            color: SmeetApp.smeetGrey,
            fontWeight: FontWeight.w500,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }
}
