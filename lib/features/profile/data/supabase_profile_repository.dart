import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:smeet_app/features/profile/data/profile_repository.dart';
import 'package:smeet_app/features/profile/models/profile_summary.dart';

/// Current user row from `public.profiles` — same fields as legacy [ProfilePage]._loadProfile.
///
/// Never throws: returns a [ProfileSummary] with [ProfileSummary.isGuest] or placeholder text.
class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<ProfileSummary> fetchSummary() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return ProfileSummary(
        displayName: 'Guest',
        city: 'Sign in to load your profile',
        sportsSummary: 'Open the Profile tab after signing in to complete your details.',
        avatarUrl: null,
        isGuest: true,
      );
    }

    try {
      final row = await _client
          .from('profiles')
          .select(
            'display_name,city,intro,avatar_url,sport_levels',
          )
          .eq('id', user.id)
          .maybeSingle();

      if (row == null) {
        final hint = (user.email ?? '').split('@').first;
        return ProfileSummary(
          displayName: hint.isNotEmpty ? hint : 'You',
          city: 'Not set yet',
          sportsSummary:
              'No profile row yet — finish setup in the main Profile tab.',
          avatarUrl: null,
          isGuest: false,
        );
      }

      final displayName = (row['display_name'] as String?)?.trim();
      final city = (row['city'] as String?)?.trim();
      final intro = (row['intro'] as String?)?.trim();
      final avatarUrl = row['avatar_url'] as String?;

      final name = (displayName != null && displayName.isNotEmpty)
          ? displayName
          : ((user.email ?? '').split('@').first.isNotEmpty
              ? (user.email ?? '').split('@').first
              : 'You');

      final cityLine =
          (city != null && city.isNotEmpty) ? city : 'Location not set';

      final sportsLine = _sportsSummaryLine(row['sport_levels'], intro);

      return ProfileSummary(
        displayName: name,
        city: cityLine,
        sportsSummary: sportsLine,
        avatarUrl: avatarUrl,
        isGuest: false,
      );
    } catch (e, st) {
      debugPrint('[SupabaseProfileRepository] fetchSummary failed: $e');
      debugPrint('$st');
      return ProfileSummary(
        displayName: 'You',
        city: '—',
        sportsSummary: 'Could not load profile. Check connection and try again.',
        avatarUrl: null,
        isGuest: false,
      );
    }
  }

  static String _sportsSummaryLine(dynamic sportLevels, String? intro) {
    if (sportLevels is Map && sportLevels.isNotEmpty) {
      final parts = <String>[];
      for (final e in sportLevels.entries) {
        final k = e.key?.toString() ?? '';
        final v = e.value?.toString() ?? '';
        if (k.isEmpty) continue;
        parts.add(v.isEmpty ? k : '$k · $v');
      }
      if (parts.isNotEmpty) {
        return parts.join(' · ');
      }
    }
    if (intro != null && intro.isNotEmpty) {
      return intro.length > 160 ? '${intro.substring(0, 157)}…' : intro;
    }
    return 'Add sports and a short intro in the main Profile tab.';
  }
}
