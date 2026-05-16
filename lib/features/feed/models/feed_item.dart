/// High-level feed card kinds for the Feed MVP (mock-friendly; Supabase fills extra fields).
enum FeedContentType {
  post,
  video,
  game,
}

/// One row in the feed list.
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
    this.videoUrl,
    this.distanceKm,
    this.gamePlayers,
    this.gameJoined,
    this.gamePerPerson,
    this.authorDisplayName,
    this.authorId,
    this.authorAvatarUrl,
    this.gameEndsAt,
    this.mediaUrls,
    this.sport = '',
    this.caption = '',
    this.likesCount = 0,
  });

  final String id;
  final FeedContentType type;
  final String title;
  final String subtitle;

  /// Hero / thumbnail (image or video poster URL).
  final String? coverImageUrl;

  /// Raw `media_urls` from `posts` (first URL often matches [coverImageUrl]).
  final List<String>? mediaUrls;
  final DateTime publishedAt;

  /// For [FeedContentType.video] mock display, e.g. "3:42".
  final String? durationLabel;

  /// For [FeedContentType.game] display.
  final String? gameVenue;

  /// When [type] is [FeedContentType.video], first playable URL.
  final String? videoUrl;

  /// Great-circle distance to the user when known (games; posts may omit).
  final double? distanceKm;

  /// Game capacity / joined (games only) — for urgency UI.
  final int? gamePlayers;
  final int? gameJoined;

  /// Court fee per person when known (games).
  final double? gamePerPerson;

  /// Post author display name when joined from `profiles`.
  final String? authorDisplayName;

  /// Post `author_id` (Supabase) for profile navigation.
  final String? authorId;

  /// Post author avatar URL when joined from `profiles`.
  final String? authorAvatarUrl;

  /// Game end time; for games [publishedAt] is [starts_at].
  final DateTime? gameEndsAt;

  /// Canonical sport key from `posts.sport` / `games.sport` (may be empty).
  final String sport;

  /// Post caption for UI (same as [title] for text posts when from DB).
  final String caption;

  /// Denormalized like count from `posts.likes_count` when present.
  final int likesCount;

  bool get isGameContent => type == FeedContentType.game;

  bool get isVideoContent =>
      type == FeedContentType.video ||
      (videoUrl != null && videoUrl!.trim().isNotEmpty);

  /// Few spots left (games).
  bool get gameIsUrgent {
    final p = gamePlayers;
    final j = gameJoined;
    if (p == null || j == null || p <= 0) return false;
    if (j >= p) return false;
    return (p - j) <= 2;
  }

  /// Alias for game card layout.
  int? get gameSpotsFilled => gameJoined;

  /// Alias for game card layout.
  int? get gameTotalSpots => gamePlayers;

  String get authorName {
    final n = authorDisplayName?.trim();
    if (n != null && n.isNotEmpty) return n;
    return 'Player';
  }
}
