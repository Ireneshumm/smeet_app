import 'package:smeet_app/features/feed/models/feed_item.dart';

/// Feed source (mock or Supabase). [userLat]/[userLng] refine ordering when set.
abstract interface class FeedRepository {
  Future<List<FeedItem>> fetchFeed({
    double? userLat,
    double? userLng,
    String? sport,
  });
}
