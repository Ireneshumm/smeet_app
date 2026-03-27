/// High-level feed card kinds for the Feed MVP (mock-backed).
enum FeedContentType {
  post,
  video,
  game,
}

/// One row in the feed list (all fields mock-friendly; no backend yet).
class FeedItem {
  FeedItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    this.coverImageUrl,
    required this.publishedAt,
    this.durationLabel,
    this.gameVenue,
  });

  final String id;
  final FeedContentType type;
  final String title;
  final String subtitle;

  /// Optional hero / thumbnail (may be null; UI falls back to type icon).
  final String? coverImageUrl;
  final DateTime publishedAt;

  /// For [FeedContentType.video] mock display, e.g. "3:42".
  final String? durationLabel;

  /// For [FeedContentType.game] mock display.
  final String? gameVenue;
}
