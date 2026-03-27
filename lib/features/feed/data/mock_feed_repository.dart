import 'package:smeet_app/features/feed/data/feed_repository.dart';
import 'package:smeet_app/features/feed/models/feed_item.dart';

/// Local mock feed source (mixed card kinds for UI demos).
class MockFeedRepository implements FeedRepository {
  MockFeedRepository();

  /// Simulated network delay so loading state is visible briefly.
  @override
  Future<List<FeedItem>> fetchFeed({Duration delay = const Duration(milliseconds: 280)}) async {
    await Future<void>.delayed(delay);
    return List<FeedItem>.unmodifiable(_mockItems);
  }

  static final List<FeedItem> _mockItems = <FeedItem>[
    FeedItem(
      id: 'mock-post-1',
      type: FeedContentType.post,
      title: 'Weekend ladder is open — sign up by Friday',
      subtitle: 'Community · Pickleball',
      publishedAt: DateTime.utc(2026, 3, 20, 14, 30),
      coverImageUrl: null,
    ),
    FeedItem(
      id: 'mock-video-1',
      type: FeedContentType.video,
      title: 'Drill: third-shot drop fundamentals',
      subtitle: 'Coach Alex · Technique',
      publishedAt: DateTime.utc(2026, 3, 21, 9, 15),
      durationLabel: '4:12',
      coverImageUrl: null,
    ),
    FeedItem(
      id: 'mock-game-1',
      type: FeedContentType.game,
      title: 'Open play · Intermediate',
      subtitle: 'Sat 10:00 AM – 12:00 PM',
      publishedAt: DateTime.utc(2026, 3, 22, 12, 0),
      gameVenue: 'Riverside Courts',
      coverImageUrl: null,
    ),
    FeedItem(
      id: 'mock-post-2',
      type: FeedContentType.post,
      title: 'New lights installed at North Park',
      subtitle: 'Facility update',
      publishedAt: DateTime.utc(2026, 3, 18, 16, 45),
    ),
    FeedItem(
      id: 'mock-video-2',
      type: FeedContentType.video,
      title: 'Match highlights: doubles finals',
      subtitle: 'Tournament reel',
      publishedAt: DateTime.utc(2026, 3, 19, 20, 0),
      durationLabel: '1:05',
    ),
    FeedItem(
      id: 'mock-game-2',
      type: FeedContentType.game,
      title: 'Doubles mixer — all levels welcome',
      subtitle: 'Sun 6:00 PM – 8:00 PM',
      publishedAt: DateTime.utc(2026, 3, 23, 23, 0),
      gameVenue: 'Union Gym',
    ),
  ];
}
