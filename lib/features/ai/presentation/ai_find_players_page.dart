import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:smeet_app/core/constants/sports.dart';
import 'package:smeet_app/core/services/ai_assistant_service.dart';
import 'package:smeet_app/core/theme/theme.dart';
import 'package:smeet_app/other_profile_page.dart';
import 'package:smeet_app/widgets/app_page_states.dart';
import 'package:smeet_app/widgets/location_search_field.dart';

/// "AI find players": describe who you want to play with, optionally pick a
/// place, and get a short list of matching players with a reason for each.
class AiFindPlayersPage extends StatefulWidget {
  const AiFindPlayersPage({super.key});

  @override
  State<AiFindPlayersPage> createState() => _AiFindPlayersPageState();
}

class _AiFindPlayersPageState extends State<AiFindPlayersPage> {
  static const _examples = [
    'Tennis partner near me for weekend mornings',
    'Beginner-friendly golf buddy',
    'Ski crew for a Niseko trip',
    'Dive buddy with Advanced Open Water',
  ];

  final TextEditingController _queryCtrl = TextEditingController();
  LocationResult? _near;
  bool _loading = false;
  String? _error;
  String? _summary;
  List<AiPlayerMatch>? _results;

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _queryCtrl.text.trim();
    if (query.isEmpty || _loading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final near = _near;
      final out = await AiAssistantService.findPlayers(
        query,
        near: near == null
            ? null
            : (lat: near.lat, lng: near.lng, label: near.address),
      );
      if (!mounted) return;
      setState(() {
        _summary = out.summary;
        _results = out.results;
      });
    } on AiAssistantException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('AI Find Players')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
          children: [
            Text(
              'Tell AI who you’d like to play with — sport, level, place or '
              'time — and we’ll look for matching players.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _queryCtrl,
              minLines: 2,
              maxLines: 4,
              maxLength: 400,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'e.g. Intermediate tennis player in Sydney for '
                    'Saturday mornings',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final e in _examples)
                  ActionChip(
                    label: Text(e),
                    onPressed: () => setState(() => _queryCtrl.text = e),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            LocationSearchField(
              supabase: Supabase.instance.client,
              labelText: 'Search near (optional)',
              hintText: 'Pick a suburb, city or venue',
              initialValue: _near,
              onChanged: (v) => setState(() => _near = v),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: _loading || _queryCtrl.text.trim().isEmpty
                  ? null
                  : _search,
              icon: _loading
                  ? const SizedBox(
                      width: AppIconSize.xs,
                      height: AppIconSize.xs,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome, size: AppIconSize.sm),
              label: Text(_loading ? 'Searching…' : 'Find players'),
            ),
            const SizedBox(height: AppSpacing.lg),
            ..._buildResults(theme),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildResults(ThemeData theme) {
    if (_error != null) {
      return [
        AppEmptyState(
          icon: Icons.cloud_off_outlined,
          title: _error!,
          actionLabel: 'Try again',
          onAction: _search,
        ),
      ];
    }
    final results = _results;
    if (results == null) return const [];
    if (results.isEmpty) {
      return [
        const AppEmptyState(
          icon: Icons.person_search_outlined,
          title: 'No matching players yet',
          subtitle: 'Try a wider area, another sport, or fewer details.',
        ),
      ];
    }
    return [
      if ((_summary ?? '').isNotEmpty) ...[
        Text(
          _summary!,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
      for (final p in results) ...[
        _AiMatchTile(match: p),
        const SizedBox(height: AppSpacing.xs),
      ],
      const SizedBox(height: AppSpacing.xs),
      Text(
        'Suggestions are generated by AI from public profiles.',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    ];
  }
}

class _AiMatchTile extends StatelessWidget {
  const _AiMatchTile({required this.match});

  final AiPlayerMatch match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final avatar = (match.avatarUrl ?? '').trim();
    final emojis = match.sportLevels.keys
        .where(isFeaturedSport)
        .map((k) => sportEmojiForKey(canonicalSportKey(k)))
        .join(' ');
    final meta = [
      if ((match.city ?? '').trim().isNotEmpty) match.city!.trim(),
      if (match.distanceKm != null)
        '${match.distanceKm!.toStringAsFixed(match.distanceKm! < 10 ? 1 : 0)} km',
      if (emojis.isNotEmpty) emojis,
    ].join(' · ');

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.lgAll,
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: InkWell(
        borderRadius: AppRadius.lgAll,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => OtherProfilePage(userId: match.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundImage: avatar.isEmpty ? null : NetworkImage(avatar),
                child: avatar.isEmpty ? const Icon(Icons.person) : null,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      match.displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (meta.isNotEmpty)
                      Text(
                        meta,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    if (match.reason.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(match.reason, style: theme.textTheme.bodyMedium),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
