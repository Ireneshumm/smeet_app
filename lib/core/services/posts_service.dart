import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Shared `posts` access for “my posts” read + text/media insert payloads.
///
/// Used by [ProfilePage] and Profile/Create MVP repositories — keep payloads aligned.
class PostsService {
  PostsService([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Same columns as legacy [ProfilePage]._fetchMyPosts.
  static const String myPostsSelectColumns =
      'id, caption, media_type, media_urls, created_at, author_id';

  /// Rows for `author_id == userId`, newest first. Caller handles `user == null`.
  Future<List<Map<String, dynamic>>> fetchMyPosts(String userId) async {
    final data = await _client
        .from('posts')
        .select(myPostsSelectColumns)
        .eq('author_id', userId)
        .order('created_at', ascending: false);

    return (data as List).cast<Map<String, dynamic>>();
  }

  /// Public posts for a profile (e.g. other user). Newest first.
  Future<List<Map<String, dynamic>>> fetchPostsForAuthor(
    String authorId, {
    int limit = 24,
  }) async {
    final data = await _client
        .from('posts')
        .select(myPostsSelectColumns)
        .eq('author_id', authorId)
        .order('created_at', ascending: false)
        .limit(limit);
    return (data as List).cast<Map<String, dynamic>>();
  }

  /// Deletes a post row; requires RLS allowing delete for own rows. Storage blobs are not removed here.
  Future<void> deletePost(String postId) async {
    final u = _client.auth.currentUser;
    if (u == null) {
      throw StateError('Not signed in');
    }
    await _client.from('posts').delete().eq('id', postId).eq('author_id', u.id);
  }

  /// Single row by [postId], same columns as [myPostsSelectColumns].
  /// Returns `null` when missing, RLS denies, or the request fails.
  Future<Map<String, dynamic>?> fetchPostById(String postId) async {
    try {
      final data = await _client
          .from('posts')
          .select(myPostsSelectColumns)
          .eq('id', postId)
          .maybeSingle();
      if (data == null) return null;
      return Map<String, dynamic>.from(data as Map);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[PostsService] fetchPostById failed: $e');
        debugPrint('$st');
      }
      return null;
    }
  }

  /// Text-only row (no media upload) — same shape as Create MVP / legacy text path.
  Future<void> createTextPost({
    required String userId,
    required String trimmedBody,
  }) async {
    final payload = buildTextOnlyPostPayload(
      authorId: userId,
      captionContent: trimmedBody,
    );
    await _client.from('posts').insert(payload);
  }

  /// After gallery pick + upload — same return shape as legacy `_createPost`.
  Future<Map<String, dynamic>> insertPostReturningSummary(
    Map<String, dynamic> payload,
  ) async {
    final row = await _client
        .from('posts')
        .insert(payload)
        .select('id, author_id, created_at')
        .single();
    return Map<String, dynamic>.from(row as Map);
  }

  static Map<String, dynamic> buildTextOnlyPostPayload({
    required String authorId,
    required String captionContent,
  }) {
    return {
      'author_id': authorId,
      'sport': 'tennis',
      'visibility': 'public',
      'media_urls': <String>[],
      'media_type': 'image',
      'caption': captionContent,
      'content': captionContent,
    };
  }

  static Map<String, dynamic> buildMediaPostPayload({
    required String authorId,
    required String mediaUrl,
    required String mediaType,
    required String captionTrimmed,
  }) {
    return {
      'author_id': authorId,
      'sport': 'tennis',
      'visibility': 'public',
      'media_urls': [mediaUrl],
      'media_type': mediaType,
      'caption': captionTrimmed,
      'content': captionTrimmed,
    };
  }
}
