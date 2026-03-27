import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:smeet_app/core/services/game_detail_service.dart';
import 'package:smeet_app/features/profile/models/profile_tab_item.dart';

String _mvpGameSourceLabel(ProfileContentTab tab) {
  switch (tab) {
    case ProfileContentTab.joined:
      return 'Joined';
    case ProfileContentTab.hosted:
      return 'Hosting';
    case ProfileContentTab.posts:
      return '';
  }
}

DateTime? _mvpParseDt(dynamic raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  return DateTime.tryParse(raw.toString());
}

String _mvpFormatWhen(DateTime? dt) {
  if (dt == null) return '—';
  return DateFormat.yMMMd().add_jm().format(dt.toLocal());
}

double? _mvpPerPerson(dynamic raw) {
  if (raw == null) return null;
  if (raw is num) return raw.toDouble();
  if (raw is String) return double.tryParse(raw.trim());
  return null;
}

/// Read-only game detail for Profile MVP **Joined** / **Hosted** tabs.
///
/// [ProfileTabItem.id] is `games.id`. [ProfileTabItem.tab] selects the source label only.
class ProfileMvpGameDetailPage extends StatefulWidget {
  const ProfileMvpGameDetailPage({super.key, required this.item});

  final ProfileTabItem item;

  @override
  State<ProfileMvpGameDetailPage> createState() =>
      _ProfileMvpGameDetailPageState();
}

class _ProfileMvpGameDetailPageState extends State<ProfileMvpGameDetailPage> {
  late final GameDetailService _games = GameDetailService();
  late final Future<Map<String, dynamic>?> _future =
      _games.fetchGameById(widget.item.id);

  @override
  Widget build(BuildContext context) {
    final source = _mvpGameSourceLabel(widget.item.tab);
    return Scaffold(
      appBar: AppBar(
        title: Text(source.isEmpty ? 'Game' : '$source game'),
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final row = snapshot.data;
          if (row == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Game not found or unavailable.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return _GameDetailBody(
            row: row,
            sourceLabel: source,
          );
        },
      ),
    );
  }
}

class _GameDetailBody extends StatelessWidget {
  const _GameDetailBody({
    required this.row,
    required this.sourceLabel,
  });

  final Map<String, dynamic> row;
  final String sourceLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final sport = (row['sport'] ?? '').toString().trim();
    final gameLevel = (row['game_level'] ?? '').toString().trim();
    var headline = [
      if (sport.isNotEmpty) sport,
      if (gameLevel.isNotEmpty) gameLevel,
    ].join(' · ');
    if (headline.isEmpty) {
      headline = 'Game';
    }

    final starts = _mvpParseDt(row['starts_at']);
    final ends = _mvpParseDt(row['ends_at']);
    final loc = (row['location_text'] ?? '').toString().trim();

    final players = row['players'];
    final joined = row['joined_count'];
    final pStr = players is num ? players.toInt().toString() : '?';
    final jStr = joined is num ? joined.toInt().toString() : '?';

    final perPerson = _mvpPerPerson(row['per_person']);

    final createdBy = (row['created_by'] ?? '').toString().trim();
    final createdAt = _mvpParseDt(row['created_at']);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (sourceLabel.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(sourceLabel),
                ),
              ),
            ),
          Text(
            headline,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          _line(theme, 'Starts', _mvpFormatWhen(starts)),
          _line(theme, 'Ends', _mvpFormatWhen(ends)),
          const SizedBox(height: 8),
          _line(
            theme,
            'Location',
            loc.isEmpty ? '—' : loc,
          ),
          const SizedBox(height: 8),
          _line(theme, 'Players', '$jStr / $pStr joined'),
          if (perPerson != null) ...[
            const SizedBox(height: 8),
            _line(
              theme,
              'Price',
              '\$${perPerson.toStringAsFixed(2)} each',
            ),
          ],
          const SizedBox(height: 20),
          Text(
            'Details',
            style: theme.textTheme.titleSmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          if (createdBy.isNotEmpty)
            SelectableText(
              'created_by: $createdBy',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          if (createdAt != null) ...[
            if (createdBy.isNotEmpty) const SizedBox(height: 6),
            Text(
              'created_at: ${_mvpFormatWhen(createdAt)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _line(ThemeData theme, String k, String v) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(
            k,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(v, style: theme.textTheme.bodyMedium),
        ),
      ],
    );
  }
}
