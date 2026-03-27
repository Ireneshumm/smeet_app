import 'package:smeet_app/features/feed/models/feed_item.dart';

/// Minimal feed source for the Feed feature (mock or Supabase).
abstract interface class FeedRepository {
  Future<List<FeedItem>> fetchFeed();
}
