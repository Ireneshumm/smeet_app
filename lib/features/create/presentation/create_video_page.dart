import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:smeet_app/features/create/data/create_post_repository.dart';
import 'package:smeet_app/features/create/data/supabase_create_post_repository.dart';
import 'package:smeet_app/features/profile/presentation/profile_page.dart';
import 'package:smeet_app/features/profile/profile_routes.dart';

/// Single video from gallery → same storage + `posts` path as main Profile video post.
class CreateVideoPage extends StatefulWidget {
  const CreateVideoPage({super.key, this.postRepository});

  final CreatePostRepository? postRepository;

  @override
  State<CreateVideoPage> createState() => _CreateVideoPageState();
}

class _CreateVideoPageState extends State<CreateVideoPage> {
  late final CreatePostRepository _repo =
      widget.postRepository ?? SupabaseCreatePostRepository();

  final _captionCtrl = TextEditingController();
  XFile? _video;
  bool _submitting = false;

  @override
  void dispose() {
    _captionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final x = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 30),
    );
    if (!mounted) return;
    if (x == null) {
      return;
    }
    setState(() => _video = x);
  }

  Future<void> _submit() async {
    final file = _video;
    if (file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a video first.')),
      );
      return;
    }
    if (_submitting) return;

    setState(() => _submitting = true);
    final result = await _repo.submitVideoPost(
      videoFile: file,
      caption: _captionCtrl.text,
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    final messenger = ScaffoldMessenger.of(context);
    if (result.success) {
      final nav = Navigator.of(context);
      nav.pop();
      await nav.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const ProfileMvpPage(
            initialTabIndex: ProfileMvpInitialTabIndex.posts,
          ),
        ),
      );
      return;
    }

    messenger.showSnackBar(
      SnackBar(content: Text(result.userMessage ?? 'Something went wrong.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Upload Video (MVP)')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'One video from gallery (max 30s, same as main Profile). '
                'Uploads to `media` then inserts a `posts` row.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _submitting ? null : _pickVideo,
                icon: const Icon(Icons.video_library_outlined),
                label: Text(_video == null ? 'Choose video' : 'Change video'),
              ),
              if (_video != null) ...[
                const SizedBox(height: 8),
                Text(
                  _video!.name,
                  style: theme.textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _captionCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Caption (optional)',
                  hintText: 'Say something about this clip…',
                  border: OutlineInputBorder(),
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.publish_outlined),
                label: Text(_submitting ? 'Posting…' : 'Post video'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
