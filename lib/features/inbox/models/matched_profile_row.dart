/// One mutual match row for Inbox **Matches** (relationship list, not a chat thread).
class MatchedProfileRow {
  const MatchedProfileRow({
    required this.peerUserId,
    required this.displayName,
    required this.city,
    required this.intro,
    required this.avatarUrl,
    required this.matchedAt,
    this.sportLevels,
    this.availability,
  });

  final String peerUserId;
  final String displayName;
  final String city;
  final String intro;
  final String avatarUrl;
  final DateTime matchedAt;
  final Map<String, dynamic>? sportLevels;
  final dynamic availability;

  /// Shape expected by [MatchesPage] list / dialog (`id`, `display_name`, …).
  Map<String, dynamic> toLegacyProfileMap() {
    return {
      'id': peerUserId,
      'display_name': displayName,
      'city': city,
      'intro': intro,
      'avatar_url': avatarUrl,
      'matched_at': matchedAt.toUtc().toIso8601String(),
      if (sportLevels != null) 'sport_levels': sportLevels,
      if (availability != null) 'availability': availability,
    };
  }
}
