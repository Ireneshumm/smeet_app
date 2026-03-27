import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Uploads binary to Supabase Storage `media` bucket — same rules as legacy [ProfilePage]._uploadToMediaBucketXFile.
class MediaUploadService {
  MediaUploadService([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Returns public URL for the uploaded object.
  Future<String> uploadXFileToMediaBucket(
    XFile xfile, {
    required String userId,
    required String folder,
  }) async {
    final uuid = const Uuid().v4();
    final ext = (xfile.name.split('.').last).toLowerCase();
    final path = '$userId/$folder/$uuid.$ext';

    final Uint8List bytes = await xfile.readAsBytes();

    var contentType = 'application/octet-stream';
    if (ext == 'png') contentType = 'image/png';
    if (ext == 'jpg' || ext == 'jpeg') contentType = 'image/jpeg';
    if (ext == 'mp4') contentType = 'video/mp4';
    if (ext == 'mov') contentType = 'video/quicktime';

    await _client.storage.from('media').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );

    return _client.storage.from('media').getPublicUrl(path);
  }
}
