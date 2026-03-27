import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:smeet_app/features/profile/data/profile_setup_repository.dart';

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

class LegacyProfileSetupSectionState extends State<LegacyProfileSetupSection> {
  static const _sports = [
    'Tennis',
    'Golf',
    'Pickleball',
    'Badminton',
    'Ski',
    'Snowboard',
    'Running',
    'Gym',
  ];

  static const _levels = [
    'Beginner',
    'Intermediate',
    'Advanced',
    'Competitive',
    'Pro',
  ];

  final Map<String, String> _sportLevels = {};
  String? _sportToAdd;

  final Map<String, Set<String>> _availability = {
    'Mon': <String>{},
    'Tue': <String>{},
    'Wed': <String>{},
    'Thu': <String>{},
    'Fri': <String>{},
    'Sat': <String>{},
    'Sun': <String>{},
  };

  int _appliedGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.loadGeneration > 0 &&
          widget.loadGeneration != _appliedGeneration) {
        _applyLoadedRow(widget.loadedProfileRow);
      }
    });
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
        _sportToAdd = null;
        for (final d in _availability.keys) {
          _availability[d] = {};
        }
        return;
      }

      final sl = row['sport_levels'];
      if (sl is Map) {
        _sportLevels
          ..clear()
          ..addAll(sl.map((k, v) => MapEntry(k.toString(), v.toString())));
      } else {
        _sportLevels.clear();
      }
      if (_sportToAdd != null && _sportLevels.containsKey(_sportToAdd)) {
        _sportToAdd = null;
      }

      final avail = row['availability'];
      if (avail is Map) {
        for (final day in _availability.keys) {
          final v = avail[day];
          if (v is List) {
            _availability[day] = v.map((e) => e.toString()).toSet();
          } else {
            _availability[day] = {};
          }
        }
      } else {
        for (final d in _availability.keys) {
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
        const SnackBar(content: Text('Please login first')),
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
        const SnackBar(content: Text('✅ Profile saved')),
      );
      widget.onProfileSaved();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Save failed: $e')),
      );
    } finally {
      if (mounted) {
        widget.onBusyChanged(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const slots = ['Morning', 'Afternoon', 'Night'];

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
              Builder(
                builder: (context) {
                  final availableSports = _sports
                      .where((s) => !_sportLevels.containsKey(s))
                      .toList();
                  final safeValue =
                      availableSports.contains(_sportToAdd) ? _sportToAdd : null;

                  return DropdownButtonFormField<String>(
                    initialValue: safeValue,
                    decoration: const InputDecoration(
                      labelText: 'Choose a sport',
                      border: OutlineInputBorder(),
                    ),
                    items: availableSports
                        .map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child: Text(s),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _sportToAdd = v),
                  );
                },
              ),
              const SizedBox(height: 10),
              if (_sportToAdd != null)
                DropdownButtonFormField<String>(
                  initialValue:
                      _sportLevels[_sportToAdd!] ?? _levels.first,
                  decoration: InputDecoration(
                    labelText: '${_sportToAdd!} level',
                    border: const OutlineInputBorder(),
                  ),
                  items: _levels
                      .map(
                        (l) => DropdownMenuItem(
                          value: l,
                          child: Text(l),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _sportLevels[_sportToAdd!] = v;
                    });
                  },
                ),
              const SizedBox(height: 12),
              if (_sportLevels.isEmpty)
                Text(
                  'No sports added yet.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurface.withOpacity(0.7),
                      ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _sportLevels.entries.map((e) {
                    return InputChip(
                      label: Text('${e.key}: ${e.value}'),
                      onDeleted: () {
                        setState(() {
                          _sportLevels.remove(e.key);
                          if (_sportToAdd == e.key) {
                            _sportToAdd = null;
                          }
                        });
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
              ..._availability.keys.map((day) {
                final selected = _availability[day]!;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        day,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: slots.map((s) {
                          final isOn = selected.contains(s);
                          return ChoiceChip(
                            label: Text(s),
                            selected: isOn,
                            onSelected: (on) {
                              setState(() {
                                if (on) {
                                  selected.add(s);
                                } else {
                                  selected.remove(s);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                );
              }),
            ],
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
        border: Border.all(color: cs.primary.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 6),
            color: Colors.black.withOpacity(0.04),
          ),
        ],
      ),
      child: child,
    );
  }
}
