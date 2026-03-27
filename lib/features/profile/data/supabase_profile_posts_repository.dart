import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:smeet_app/core/services/posts_service.dart';
import 'package:smeet_app/features/profile/models/profile_tab_item.dart';

/// My posts for Profile MVP **Posts** tab — same query shape as [ProfilePage]._fetchMyPosts
/// (`posts` by `author_id`, order `created_at` desc).
///
/// Returns `[]` when not signed in, on error, or when there are no rows (caller shows empty state).
class SupabaseProfilePostsRepository {
  SupabaseProfilePostsRepository([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client,
        _posts = PostsService(client ?? Supabase.instance.client);

  final SupabaseClient _client;
  final PostsService _posts;

  Future<List<ProfileTabItem>> fetchMyPostsTabItems() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return const [];
    }

    try {
      final rows = await _posts.fetchMyPosts(user.id);
      if (rows.isEmpty) {
        return const [];
      }

      final out = <ProfileTabItem>[];
      for (final row in rows) {
        final item = _mapRow(row);
        if (item != null) {
          out.add(item);
        }
      }
      return out;
    } catch (e, st) {
      debugPrint('[SupabaseProfilePostsRepository] fetchMyPostsTabItems failed: $e');
      debugPrint('$st');
      return const [];
    }
  }

  ProfileTabItem? _mapRow(Map<String, dynamic> row) {
    try {
      final id = row['id']?.toString();
      if (id == null || id.isEmpty) return null;

      final caption = (row['caption'] as String?)?.trim() ?? '';
      final mediaType = (row['media_type'] ?? '').toString().trim();

      final title = caption.isNotEmpty
          ? (caption.length > 100 ? '${caption.substring(0, 97)}…' : caption)
          : _defaultTitleForMediaType(mediaType);

      final created = DateTime.tryParse(row['created_at']?.toString() ?? '');
      final when = created != null
          ? DateFormat.yMMMd().add_jm().format(created.toLocal())
          : '—';

      final typeLabel = mediaType.isEmpty ? 'post' : mediaType;
      final subtitle = '$when · $typeLabel';

      final rawUrls = row['media_urls'];
      String? firstUrl;
      if (rawUrls is List && rawUrls.isNotEmpty) {
        final s = rawUrls.first?.toString().trim() ?? '';
        firstUrl = s.isEmpty ? null : s;
      }

      return ProfileTabItem(
        id: id,
        tab: ProfileContentTab.posts,
        title: title,
        subtitle: subtitle,
        previewMediaUrl: firstUrl,
        previewMediaType:
            mediaType.isEmpty ? null : mediaType.toLowerCase().trim(),
      );
    } catch (e) {
      debugPrint('[SupabaseProfilePostsRepository] skip row: $e');
      return null;
    }
  }

  static String _defaultTitleForMediaType(String mediaType) {
    switch (mediaType.toLowerCase()) {
      case 'video':
        return 'Video post';
      case 'image':
        return 'Photo post';
      default:
        return 'Post';
    }
  }
}
