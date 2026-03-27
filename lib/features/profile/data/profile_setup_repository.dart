import 'package:supabase_flutter/supabase_flutter.dart';

/// `profiles` columns loaded for legacy profile setup + [LegacyProfileSetupSection].
const kProfileSetupSelectColumns =
    'display_name,birth_year,city,intro,avatar_url,sport_levels,availability';

/// Fetches the current user’s profile row for setup (or null if missing).
Future<Map<String, dynamic>?> fetchProfileSetupRow({
  required SupabaseClient client,
  required String userId,
}) async {
  final row = await client
      .from('profiles')
      .select(kProfileSetupSelectColumns)
      .eq('id', userId)
      .maybeSingle();
  if (row == null) return null;
  return Map<String, dynamic>.from(row);
}

/// Values mapped from a `profiles` row into host-held text fields + avatar URL.
class ProfileSetupFieldValues {
  const ProfileSetupFieldValues({
    required this.displayName,
    required this.birthYearText,
    required this.city,
    required this.intro,
    this.avatarUrl,
  });

  final String displayName;
  final String birthYearText;
  final String city;
  final String intro;
  final String? avatarUrl;

  factory ProfileSetupFieldValues.fromRow(Map<String, dynamic> row) {
    return ProfileSetupFieldValues(
      displayName: (row['display_name'] ?? '') as String,
      birthYearText: row['birth_year'] == null
          ? ''
          : row['birth_year'].toString(),
      city: (row['city'] ?? '') as String,
      intro: (row['intro'] ?? '') as String,
      avatarUrl: row['avatar_url'] as String?,
    );
  }
}

/// Same `profiles` upsert payload as `LegacyProfileSetupSection.saveProfile`.
Future<void> upsertProfileSetup({
  required SupabaseClient client,
  required String userId,
  required String displayName,
  required String birthYearText,
  required String city,
  required String intro,
  required String? avatarUrl,
  required Map<String, String> sportLevels,
  required Map<String, Set<String>> availability,
}) async {
  final birthYear = int.tryParse(birthYearText.trim());

  final availabilityJson = <String, dynamic>{};
  availability.forEach((day, slots) {
    availabilityJson[day] = slots.toList()..sort();
  });

  await client.from('profiles').upsert({
    'id': userId,
    'display_name': displayName.trim(),
    'birth_year': birthYear,
    'city': city.trim(),
    'intro': intro.trim(),
    'avatar_url': avatarUrl,
    'sport_levels': sportLevels,
    'availability': availabilityJson,
  });
}
