import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:smeet_app/core/constants/sports.dart';
import 'package:smeet_app/core/services/sport_definitions_service.dart';
import 'package:smeet_app/features/profile/data/profile_setup_repository.dart';
import 'package:smeet_app/features/profile/widgets/availability_picker.dart';

/// Extracted **profile setup** UI + `profiles` upsert.
///
/// Used by legacy `ProfilePage` and [ProfileSetupDemoPage] (debug).
/// [loadedProfileRow] + [loadGeneration] sync sport_levels / availability after fetch.
/// [onProfileSaved] runs after successful upsert (e.g. shell refresh from `main.dart`).
class LegacyProfileSetupSection extends StatefulWidget {
  const LegacyProfileSetupSection({
    super.key,
    required this.nameCtrl,
    required this.birthYearCtrl,
    required this.cityCtrl,
    required this.introCtrl,
    required this.currentAvatarUrl,
    required this.loadGeneration,
    required this.loadedProfileRow,
    required this.onBusyChanged,
    required this.onProfileSaved,
  });

  final TextEditingController nameCtrl;
  final TextEditingController birthYearCtrl;
  final TextEditingController cityCtrl;
  final TextEditingController introCtrl;

  /// Latest avatar URL from parent (header upload updates parent state).
  final String? Function() currentAvatarUrl;

  /// Increment when `_loadProfile` finishes so sport/availability can re-sync.
  final int loadGeneration;

  /// Last `profiles` row from server (or null); only `sport_levels` / `availability` read.
  final Map<String, dynamic>? loadedProfileRow;

  final ValueChanged<bool> onBusyChanged;
  final VoidCallback onProfileSaved;

  @override
  State<LegacyProfileSetupSection> createState() =>
      LegacyProfileSetupSectionState();
}

/// Resolves stored level for [sport] when map keys may differ by case / legacy spelling.
String? _storedLevelForSport(Map<String, String> levels, String sport) {
  final c = canonicalSportKey(sport);
  if (levels.containsKey(sport)) return levels[sport];
  if (levels.containsKey(c)) return levels[c];
  for (final e in levels.entries) {
    if (canonicalSportKey(e.key) == c) return e.value;
  }
  return null;
}

class LegacyProfileSetupSectionState extends State<LegacyProfileSetupSection> {
  final Map<String, String> _sportLevels = {};

  final Map<String, Set<String>> _availability = {
    for (final d in kAvailabilityDays) d: <String>{},
  };

  int _appliedGeneration = 0;

  Map<String, List<SportLevelDefinition>>? _defsBySport;
  bool _defsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDefinitions();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.loadGeneration > 0 &&
          widget.loadGeneration != _appliedGeneration) {
        _applyLoadedRow(widget.loadedProfileRow);
      }
    });
  }

  Future<void> _loadDefinitions() async {
    try {
      final map =
          await SportDefinitionsService(Supabase.instance.client).getAllSports();
      if (!mounted) return;
      setState(() {
        _defsBySport = map;
        _defsLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ProfileSetup] sport definitions: $e');
      }
      if (!mounted) return;
      setState(() => _defsLoading = false);
    }
  }

  String _levelDisplayLabel(String sport, String stored) {
    final defs = _defsForSport(sport);
    if (defs == null) return stored;
    for (final d in defs) {
      if (d.matchesStored(stored)) return d.levelLabel;
    }
    return stored;
  }

  List<SportLevelDefinition>? _defsForSport(String sport) {
    final c = canonicalSportKey(sport);
    return _defsBySport?[c] ?? _defsBySport?[sport];
  }

  @override
  void didUpdateWidget(covariant LegacyProfileSetupSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.loadGeneration != oldWidget.loadGeneration) {
      _applyLoadedRow(widget.loadedProfileRow);
    }
  }

  void _applyLoadedRow(Map<String, dynamic>? row) {
    if (!mounted) return;
    if (widget.loadGeneration == _appliedGeneration) return;
    _appliedGeneration = widget.loadGeneration;

    setState(() {
      if (row == null) {
        _sportLevels.clear();
        for (final d in kAvailabilityDays) {
          _availability[d] = {};
        }
        return;
      }

      final sl = row['sport_levels'];
      if (sl is Map) {
        _sportLevels
          ..clear()
          ..addAll(
            sl.map(
              (k, v) => MapEntry(
                canonicalSportKey(k.toString()),
                v.toString(),
              ),
            ),
          );
      } else {
        _sportLevels.clear();
      }

      final avail = row['availability'];
      if (avail is Map) {
        final norm = normalizeAvailabilityMap(avail);
        for (final day in kAvailabilityDays) {
          _availability[day] = norm[day]?.toSet() ?? {};
        }
      } else {
        for (final d in kAvailabilityDays) {
          _availability[d] = {};
        }
      }
    });
  }

  /// Persists current form + sport_levels + availability + [currentAvatarUrl]).
  Future<void> saveProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in first.')),
      );
      return;
    }

    widget.onBusyChanged(true);

    try {
      await upsertProfileSetup(
        client: Supabase.instance.client,
        userId: user.id,
        displayName: widget.nameCtrl.text,
        birthYearText: widget.birthYearCtrl.text,
        city: widget.cityCtrl.text,
        intro: widget.introCtrl.text,
        avatarUrl: widget.currentAvatarUrl(),
        sportLevels: _sportLevels,
        availability: _availability,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved.')),
      );
      widget.onProfileSaved();
    } catch (e) {
      if (!mounted) return;
      if (kDebugMode) {
        debugPrint('[ProfileSetup] save failed: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Couldn’t save your profile. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        widget.onBusyChanged(false);
      }
    }
  }

  List<String> get _orderedSportKeys {
    final fromDb = _defsBySport?.keys.toList() ?? <String>[];
    fromDb.sort();
    final extra = <String>[];
    for (final e in kSupportedSports) {
      if (!fromDb.contains(e.$1)) extra.add(e.$1);
    }
    return [...fromDb, ...extra];
  }

  Future<void> _openSportPickerSheet() async {
    final defs = _defsBySport;
    if (defs == null || defs.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not load sport levels. Check your connection.'),
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (context, scrollCtrl) {
            return _SportLevelBottomSheet(
              defsBySport: defs,
              sportLevels: _sportLevels,
              orderedSportKeys: _orderedSportKeys,
              scrollController: scrollCtrl,
              onCommit: (sport, levelKey) {
                setState(() => _sportLevels[sport] = levelKey);
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProfileSetupCard(
          child: Column(
            children: [
              TextField(
                controller: widget.nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: widget.birthYearCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Birth year',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: widget.cityCtrl,
                      decoration: const InputDecoration(
                        labelText: 'City',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: widget.introCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Sports-only bio',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        _ProfileSetupCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sports & Level',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 10),
              if (_defsLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                OutlinedButton.icon(
                  onPressed: _openSportPickerSheet,
                  icon: const Icon(Icons.sports_outlined),
                  label: const Text('Add or edit sports'),
                ),
                const SizedBox(height: 12),
              ],
              if (_sportLevels.isEmpty)
                Text(
                  'No sports added yet.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.7),
                      ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _sportLevels.entries.map((e) {
                    final sk = canonicalSportKey(e.key);
                    final emoji = sportEmojiForKey(sk);
                    final label = _levelDisplayLabel(sk, e.value);
                    return InputChip(
                      label: Text('$emoji ${sportLabelForKey(sk)}: $label'),
                      onDeleted: () {
                        setState(() => _sportLevels.remove(e.key));
                      },
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
        _ProfileSetupCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Availability',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 10),
              AvailabilityPickerWidget(
                key: ValueKey<int>(widget.loadGeneration),
                initialValue: {
                  for (final d in kAvailabilityDays)
                    d: _availability[d]?.toList() ?? [],
                },
                onChanged: (m) {
                  setState(() {
                    for (final day in kAvailabilityDays) {
                      _availability[day] = m[day]?.toSet() ?? {};
                    }
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SportLevelBottomSheet extends StatefulWidget {
  const _SportLevelBottomSheet({
    required this.defsBySport,
    required this.sportLevels,
    required this.orderedSportKeys,
    required this.scrollController,
    required this.onCommit,
  });

  final Map<String, List<SportLevelDefinition>> defsBySport;
  final Map<String, String> sportLevels;
  final List<String> orderedSportKeys;
  final ScrollController scrollController;
  final void Function(String sport, String levelKey) onCommit;

  @override
  State<_SportLevelBottomSheet> createState() => _SportLevelBottomSheetState();
}

class _SportLevelBottomSheetState extends State<_SportLevelBottomSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final q = _query.trim().toLowerCase();
    final sports = widget.orderedSportKeys.where((sk) {
      if (q.isEmpty) return true;
      final label = sportLabelForKey(sk).toLowerCase();
      return sk.toLowerCase().contains(q) || label.contains(q);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Text(
            'Sports & levels',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search sports',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            controller: widget.scrollController,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            itemCount: sports.length,
            itemBuilder: (context, i) {
              final sport = sports[i];
              final defs = widget.defsBySport[sport];
              final emoji = sportEmojiForKey(sport);
              final label = sportLabelForKey(sport);
              final current =
                  _storedLevelForSport(widget.sportLevels, sport);
              final summary = current != null
                  ? (defs == null
                      ? current
                      : defs
                          .firstWhere(
                            (d) => d.matchesStored(current),
                            orElse: () => defs.first,
                          )
                          .levelLabel)
                  : null;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                child: ExpansionTile(
                  key: ValueKey(sport),
                  title: Row(
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          label,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (summary != null)
                        Text(
                          summary,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: cs.primary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                    ],
                  ),
                  children: [
                    if (defs == null || defs.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No levels defined for this sport yet.'),
                      )
                    else
                      Builder(
                        builder: (context) {
                          String? selectedKey;
                          if (current != null) {
                            for (final d in defs) {
                              if (d.matchesStored(current)) {
                                selectedKey = d.levelKey;
                                break;
                              }
                            }
                          }
                          return Column(
                            children: defs.map((d) {
                              return RadioListTile<String>(
                                value: d.levelKey,
                                groupValue: selectedKey,
                                title: Text(
                                  d.levelLabel,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: d.levelDescription != null &&
                                        d.levelDescription!.trim().isNotEmpty
                                    ? Text(
                                        d.levelDescription!,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      )
                                    : null,
                                onChanged: (v) {
                                  if (v == null) return;
                                  widget.onCommit(sport, v);
                                  setState(() {});
                                },
                              );
                            }).toList(),
                          );
                        },
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ProfileSetupCard extends StatelessWidget {
  const _ProfileSetupCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.primary.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 6),
            color: Colors.black.withValues(alpha: 0.04),
          ),
        ],
      ),
      child: child,
    );
  }
}
