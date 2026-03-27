import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:smeet_app/features/profile/data/profile_setup_repository.dart';
import 'package:smeet_app/features/profile/presentation/legacy_profile_setup_section.dart';

/// **Debug-only** standalone host for [LegacyProfileSetupSection] (MVP launcher).
///
/// Not part of Shell or `signedInProfileMissing`. [onProfileSaved] is injected
/// from `main.dart` (e.g. [SmeetShell.refreshAuthState]) to avoid importing
/// `main.dart` here.
class ProfileSetupDemoPage extends StatefulWidget {
  const ProfileSetupDemoPage({
    super.key,
    this.onProfileSaved,
  });

  /// Called after a successful `profiles` upsert; may be null in tests.
  final VoidCallback? onProfileSaved;

  @override
  State<ProfileSetupDemoPage> createState() => _ProfileSetupDemoPageState();
}

class _ProfileSetupDemoPageState extends State<ProfileSetupDemoPage> {
  final _nameCtrl = TextEditingController();
  final _birthYearCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _introCtrl = TextEditingController();

  final GlobalKey<LegacyProfileSetupSectionState> _setupKey =
      GlobalKey<LegacyProfileSetupSectionState>();

  String? _avatarUrl;
  bool _loading = false;
  bool _loaded = false;

  Map<String, dynamic>? _setupLoadedRow;
  int _setupLoadGen = 0;

  @override
  void initState() {
    super.initState();
    if (Supabase.instance.client.auth.currentUser != null) {
      _loadProfile();
    } else {
      _loaded = true;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _birthYearCtrl.dispose();
    _cityCtrl.dispose();
    _introCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loaded = true);
      return;
    }

    setState(() => _loading = true);

    try {
      final row = await fetchProfileSetupRow(
        client: Supabase.instance.client,
        userId: user.id,
      );

      if (row != null) {
        final v = ProfileSetupFieldValues.fromRow(row);
        _nameCtrl.text = v.displayName;
        _birthYearCtrl.text = v.birthYearText;
        _cityCtrl.text = v.city;
        _introCtrl.text = v.intro;
        _avatarUrl = v.avatarUrl;
      }

      if (mounted) {
        setState(() {
          _loaded = true;
          _setupLoadedRow = row;
          _setupLoadGen++;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loaded = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Load failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    await _setupKey.currentState?.saveProfile();
  }

  @override
  Widget build(BuildContext context) {
    final u = Supabase.instance.client.auth.currentUser;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Setup (debug)'),
      ),
      body: u == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.engineering_outlined,
                        size: 48, color: theme.colorScheme.outline),
                    const SizedBox(height: 16),
                    Text(
                      'Sign in to try this demo.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Debug-only — not used for onboarding.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : !_loaded && _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Standalone [LegacyProfileSetupSection] — save uses the same upsert as Profile tab.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    LegacyProfileSetupSection(
                      key: _setupKey,
                      nameCtrl: _nameCtrl,
                      birthYearCtrl: _birthYearCtrl,
                      cityCtrl: _cityCtrl,
                      introCtrl: _introCtrl,
                      currentAvatarUrl: () => _avatarUrl,
                      loadGeneration: _setupLoadGen,
                      loadedProfileRow: _setupLoadedRow,
                      onBusyChanged: (busy) {
                        if (mounted) setState(() => _loading = busy);
                      },
                      onProfileSaved: () => widget.onProfileSaved?.call(),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _loading ? null : _save,
                      child: Text(_loading ? 'Saving…' : 'Save profile'),
                    ),
                  ],
                ),
    );
  }
}
