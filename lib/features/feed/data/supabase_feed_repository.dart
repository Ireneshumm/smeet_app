import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:smeet_app/core/constants/sports.dart';
import 'package:smeet_app/features/feed/data/feed_repository.dart';
import 'package:smeet_app/features/feed/models/feed_item.dart';
import 'package:smeet_app/geo_utils.dart';

/// Upcoming games + recent public posts. Videos first, then by distance (when coords given).
class SupabaseFeedRepository implements FeedRepository {
  SupabaseFeedRepository([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const int _gameLimit = 50;
  static const int _postLimit = 40;

  @override
  Future<List<FeedItem>> fetchFeed({
    double? userLat,
    double? userLng,
    String? sport,
  }) async {
    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final sportNorm = sport?.trim();

      final gameRows = await _client
          .from('games')
          .select(
            'id, sport, game_level, starts_at, ends_at, location_text, players, joined_count, location_lat, location_lng, per_person',
          )
          .gte('starts_at', nowIso)
          .order('starts_at', ascending: true)
          .limit(_gameLimit);

      List<dynamic> postRows = const [];
      try {
        final pr = await _client
            .from('posts')
            .select(
              'id, caption, media_type, media_urls, created_at, sport, author_id, likes_count, cover_image_url, profiles(display_name, avatar_url)',
            )
            .eq('visibility', 'public')
            .order('created_at', ascending: false)
            .limit(_postLimit);
        postRows = pr as List<dynamic>? ?? const [];
      } catch (e) {
        debugPrint('[SupabaseFeedRepository] posts with profiles failed, retry: $e');
        try {
          final pr = await _client
              .from('posts')
              .select(
                'id, caption, media_type, media_urls, created_at, sport, author_id, likes_count, cover_image_url',
              )
              .eq('visibility', 'public')
              .order('created_at', ascending: false)
              .limit(_postLimit);
          postRows = pr as List<dynamic>? ?? const [];
        } catch (e2) {
          debugPrint('[SupabaseFeedRepository] posts fetch skipped: $e2');
        }
      }

      final out = <FeedItem>[];

      final games = gameRows as List<dynamic>? ?? const [];
      for (final raw in games) {
        if (raw is! Map) continue;
        final row = Map<String, dynamic>.from(raw);
        final item = _mapGameRow(
          row,
          userLat: userLat,
          userLng: userLng,
          sportFilter: sportNorm,
        );
        if (item != null) out.add(item);
      }

      final posts = postRows as List<dynamic>? ?? const [];
      for (final raw in posts) {
        if (raw is! Map) continue;
        final row = Map<String, dynamic>.from(raw);
        final item = _mapPostRow(row, sportFilter: sportNorm);
        if (item != null) out.add(item);
      }

      out.sort((a, b) => _compareFeedItems(a, b));
      return out;
    } catch (e, st) {
      debugPrint('[SupabaseFeedRepository] fetchFeed failed: $e');
      debugPrint('$st');
      return const [];
    }
  }

  int _compareFeedItems(FeedItem a, FeedItem b) {
    final va = a.isVideoContent ? 0 : 1;
    final vb = b.isVideoContent ? 0 : 1;
    if (va != vb) return va.compareTo(vb);

    final da = a.distanceKm;
    final db = b.distanceKm;
    if (da != null && db != null && da != db) {
      return da.compareTo(db);
    }
    if (da != null && db == null) return -1;
    if (da == null && db != null) return 1;

    return b.publishedAt.compareTo(a.publishedAt);
  }

  FeedItem? _mapPostRow(
    Map<String, dynamic> row, {
    String? sportFilter,
  }) {
    try {
      final id = row['id']?.toString();
      if (id == null || id.isEmpty) return null;

      final rowSport = (row['sport'] ?? '').toString().trim();
      final sportKey = rowSport.isEmpty ? '' : canonicalSportKey(rowSport);
      if (sportFilter != null && sportFilter.isNotEmpty) {
        if (sportKey.toLowerCase() != sportFilter.toLowerCase()) {
          return null;
        }
      }

      final caption = (row['caption'] ?? '').toString().trim();
      final title = caption.isEmpty ? 'Post' : caption;

      final mediaUrlsRaw = row['media_urls'];
      List<String>? mediaUrlList;
      if (mediaUrlsRaw is List && mediaUrlsRaw.isNotEmpty) {
        mediaUrlList = mediaUrlsRaw
            .map((e) => e.toString().trim())
            .where((s) => s.isNotEmpty)
            .toList();
        if (mediaUrlList.isEmpty) mediaUrlList = null;
      }
      String? firstUrl;
      if (mediaUrlList != null && mediaUrlList.isNotEmpty) {
        firstUrl = mediaUrlList.first;
      }

      final mt = (row['media_type'] ?? 'image').toString().toLowerCase();
      final isVideo = mt == 'video';
      final created = DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.now().toUtc();

      String? authorName;
      String? avatarUrl;
      final prof = row['profiles'];
      if (prof is Map) {
        authorName = prof['display_name']?.toString().trim();
        if (authorName != null && authorName.isEmpty) authorName = null;
        final av = prof['avatar_url']?.toString().trim();
        avatarUrl = (av != null && av.isNotEmpty) ? av : null;
      }

      final authorId = row['author_id']?.toString().trim();
      final authorIdNorm =
          (authorId != null && authorId.isNotEmpty) ? authorId : null;

      var subtitle = rowSport.isEmpty ? 'Post' : 'Post · $rowSport';
      if (authorName != null && authorName.isNotEmpty) {
        subtitle = rowSport.isEmpty ? authorName : '$authorName · $rowSport';
      }

      final likesRaw = row['likes_count'];
      final likesCount = likesRaw is num ? likesRaw.toInt() : 0;

      final dbCover = row['cover_image_url']?.toString().trim();
      final String? coverForFeed;
      if (dbCover != null && dbCover.isNotEmpty) {
        coverForFeed = dbCover;
      } else if (!isVideo && firstUrl != null && firstUrl.isNotEmpty) {
        coverForFeed = firstUrl;
      } else {
        coverForFeed = null;
      }

      return FeedItem(
        id: id,
        type: isVideo ? FeedContentType.video : FeedContentType.post,
        title: title,
        subtitle: subtitle,
        coverImageUrl: coverForFeed,
        publishedAt: created,
        durationLabel: null,
        gameVenue: null,
        videoUrl: isVideo ? firstUrl : null,
        distanceKm: null,
        authorDisplayName: authorName,
        authorId: authorIdNorm,
        authorAvatarUrl: avatarUrl,
        mediaUrls: mediaUrlList,
        sport: sportKey,
        caption: caption,
        likesCount: likesCount,
      );
    } catch (e) {
      debugPrint('[SupabaseFeedRepository] skip post row: $e');
      return null;
    }
  }

  /// [FeedItem.id] for games is `games.id` (UUID), not `posts.id`.
  FeedItem? _mapGameRow(
    Map<String, dynamic> row, {
    double? userLat,
    double? userLng,
    String? sportFilter,
  }) {
    try {
      final id = row['id']?.toString() ?? '';
      if (id.isEmpty) return null;

      final sportRaw = (row['sport'] ?? 'Game').toString().trim();
      final sportKey = canonicalSportKey(sportRaw);
      if (sportFilter != null && sportFilter.isNotEmpty) {
        if (sportKey.toLowerCase() != sportFilter.toLowerCase()) {
          return null;
        }
      }

      final level = (row['game_level'] ?? '').toString().trim();
      final title = level.isEmpty ? sportKey : '$sportKey · $level';

      final start = DateTime.tryParse(row['starts_at']?.toString() ?? '');
      final end = DateTime.tryParse(row['ends_at']?.toString() ?? '');
      final publishedAt = start ?? DateTime.now().toUtc();

      final subtitle = _gameJoinSummary(row);

      final loc = row['location_text']?.toString().trim();
      final gameVenue =
          (loc != null && loc.isNotEmpty) ? loc : null;

      final players = (row['players'] as num?)?.toInt();
      final joined = (row['joined_count'] as num?)?.toInt();

      double? ppVal;
      final pp = row['per_person'];
      if (pp is num) ppVal = pp.toDouble();

      double? dist;
      final la = row['location_lat'];
      final ln = row['location_lng'];
      if (userLat != null &&
          userLng != null &&
          la != null &&
          ln != null) {
        dist = haversineKm(
          userLat,
          userLng,
          (la as num).toDouble(),
          (ln as num).toDouble(),
        );
      }

      return FeedItem(
        id: id,
        type: FeedContentType.game,
        title: title,
        subtitle: subtitle,
        coverImageUrl: null,
        publishedAt: publishedAt,
        durationLabel: null,
        gameVenue: gameVenue,
        videoUrl: null,
        distanceKm: dist,
        gamePlayers: players,
        gameJoined: joined,
        gamePerPerson: ppVal,
        gameEndsAt: end,
        sport: sportKey,
        caption: '',
        likesCount: 0,
      );
    } catch (e) {
      debugPrint('[SupabaseFeedRepository] skip game row: $e');
      return null;
    }
  }

  /// Join counts + optional per-person price (no date — card shows schedule separately).
  String _gameJoinSummary(Map<String, dynamic> row) {
    final joined = (row['joined_count'] as num?)?.toInt() ?? 0;
    final players = (row['players'] as num?)?.toInt() ?? 0;
    final spots = players > 0 ? '$joined/$players joined' : '$joined joined';
    final pp = row['per_person'];
    if (pp != null) {
      final n = (pp as num).toDouble();
      if (n > 0) {
        return '$spots · \$${n.toStringAsFixed(2)}/pp';
      }
    }
    return spots;
  }
}
