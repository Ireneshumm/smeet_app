import 'package:image_picker/image_picker.dart';

/// Result of a create-post attempt (Create MVP).
class CreatePostSubmitResult {
  const CreatePostSubmitResult({
    required this.success,
    this.userMessage,
  });

  final bool success;

  /// Short message for SnackBar / inline error (null on success).
  final String? userMessage;
}

/// Text note + single-video post from Create MVP.
abstract interface class CreatePostRepository {
  Future<CreatePostSubmitResult> submitTextNote(String body);

  /// One gallery video → `media` bucket → `posts` row (`media_type`: video).
  Future<CreatePostSubmitResult> submitVideoPost({
    required XFile videoFile,
    required String caption,
  });
}