import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:smeet_app/core/services/media_upload_service.dart';
import 'package:smeet_app/core/services/posts_service.dart';
import 'package:smeet_app/features/create/data/create_post_repository.dart';

/// Inserts into `posts` via [PostsService.createTextPost] (aligned with legacy field set).
class SupabaseCreatePostRepository implements CreatePostRepository {
  SupabaseCreatePostRepository([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client,
        _posts = PostsService(client ?? Supabase.instance.client);

  final SupabaseClient _client;
  final PostsService _posts;

  @override
  Future<CreatePostSubmitResult> submitTextNote(String body) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return const CreatePostSubmitResult(
        success: false,
        userMessage: 'Please sign in to post.',
      );
    }

    final text = body.trim();
    if (text.isEmpty) {
      return const CreatePostSubmitResult(
        success: false,
        userMessage: 'Write something before posting.',
      );
    }

    try {
      await _posts.createTextPost(userId: user.id, trimmedBody: text);

      debugPrint('[SupabaseCreatePostRepository] text note inserted author=${user.id}');
      return const CreatePostSubmitResult(success: true);
    } catch (e, st) {
      debugPrint('[SupabaseCreatePostRepository] insert failed: $e');
      debugPrint('$st');
      return CreatePostSubmitResult(
        success: false,
        userMessage: 'Couldn’t post. Please try again.',
      );
    }
  }

  @override
  Future<CreatePostSubmitResult> submitVideoPost({
    required XFile videoFile,
    required String caption,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return const CreatePostSubmitResult(
        success: false,
        userMessage: 'Please sign in to post.',
      );
    }

    try {
      final upload = MediaUploadService(_client);
      final url = await upload.uploadXFileToMediaBucket(
        videoFile,
        userId: user.id,
        folder: 'posts',
      );

      final trimmed = caption.trim();
      final payload = PostsService.buildMediaPostPayload(
        authorId: user.id,
        mediaUrl: url,
        mediaType: 'video',
        captionTrimmed: trimmed,
      );

      await _posts.insertPostReturningSummary(payload);

      debugPrint(
        '[SupabaseCreatePostRepository] video post inserted author=${user.id}',
      );
      return const CreatePostSubmitResult(success: true);
    } catch (e, st) {
      debugPrint('[SupabaseCreatePostRepository] video post failed: $e');
      debugPrint('$st');
      return CreatePostSubmitResult(
        success: false,
        userMessage:
            'Couldn’t upload or post the video. Check connection and try again.',
      );
    }
  }
}
