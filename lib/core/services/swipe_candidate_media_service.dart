import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Resolves [profiles.swipe_intro_video_url], else latest video [posts] URL per candidate.
class SwipeCandidateMediaService {
  SwipeCandidateMediaService([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Mutates each map with `_swipe_resolved_video_url` (String?) for UI.
  Future<void> mergeResolvedVideoUrls(
    List<Map<String, dynamic>> candidates,
  ) async {
    for (final p in candidates) {
      p.remove('_swipe_resolved_video_url');
      final intro = (p['swipe_intro_video_url'] ?? '').toString().trim();
      if (intro.isNotEmpty) {
        p['_swipe_resolved_video_url'] = intro;
      }
    }

    final needPost = <String>[];
    for (final p in candidates) {
      final id = p['id']?.toString();
      if (id == null) continue;
      if (p['_swipe_resolved_video_url'] != null) continue;
      needPost.add(id);
    }
    if (needPost.isEmpty) return;

    try {
      final data = await _client
          .from('posts')
          .select('author_id, media_urls, media_type, created_at')
          .inFilter('author_id', needPost)
          .eq('media_type', 'video')
          .order('created_at', ascending: false);

      final rows = (data as List).cast<Map<String, dynamic>>();
      final firstByAuthor = <String, String>{};
      for (final r in rows) {
        final aid = r['author_id']?.toString();
        if (aid == null || firstByAuthor.containsKey(aid)) continue;
        final u = firstUrlFromMediaUrls(r['media_urls']);
        if (u != null && u.isNotEmpty) {
          firstByAuthor[aid] = u;
        }
      }
      for (final p in candidates) {
        final id = p['id']?.toString();
        if (id == null) continue;
        if (p['_swipe_resolved_video_url'] != null) continue;
        final u = firstByAuthor[id];
        if (u != null && u.isNotEmpty) {
          p['_swipe_resolved_video_url'] = u;
        }
      }
    } catch (e, st) {
      debugPrint('[SwipeCandidateMediaService] posts merge: $e');
      debugPrint('$st');
    }
  }

  /// First non-empty string from [media_urls] (list or json).
  static String? firstUrlFromMediaUrls(dynamic raw) {
    if (raw == null) return null;
    if (raw is List && raw.isNotEmpty) {
      for (final e in raw) {
        final s = e?.toString().trim() ?? '';
        if (s.isNotEmpty) return s;
      }
      return null;
    }
    if (raw is String) {
      final s = raw.trim();
      return s.isEmpty ? null : s;
    }
    return null;
  }
}
