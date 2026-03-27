/// Header row for Profile MVP (mock or `profiles` row).
class ProfileSummary {
  ProfileSummary({
    required this.displayName,
    required this.city,
    required this.sportsSummary,
    this.avatarUrl,
    this.isGuest = false,
  });

  final String displayName;
  final String city;

  /// One line: sports + levels, intro, or hint copy.
  final String sportsSummary;

  final String? avatarUrl;

  /// Signed-out / no session — show guest styling and hints.
  final bool isGuest;
}
