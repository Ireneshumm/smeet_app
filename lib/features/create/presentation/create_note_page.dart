import 'package:flutter/material.dart';

import 'package:smeet_app/features/create/data/create_post_repository.dart';
import 'package:smeet_app/features/create/data/supabase_create_post_repository.dart';
import 'package:smeet_app/features/profile/presentation/profile_page.dart';
import 'package:smeet_app/features/profile/profile_routes.dart';

/// Minimal text post — reuses `posts` insert shape from the main Profile flow.
class CreateNotePage extends StatefulWidget {
  const CreateNotePage({super.key, this.postRepository});

  final CreatePostRepository? postRepository;

  @override
  State<CreateNotePage> createState() => _CreateNotePageState();
}

class _CreateNotePageState extends State<CreateNotePage> {
  late final CreatePostRepository _repo =
      widget.postRepository ?? SupabaseCreatePostRepository();
  final _bodyCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final result = await _repo.submitTextNote(_bodyCtrl.text);
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
            snackMessageOnOpen: 'Your note is on your profile.',
          ),
        ),
      );
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result.userMessage ?? 'That didn’t work. Please try again.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New note')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Write a short text update. It appears on your profile with your other posts.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TextField(
                  controller: _bodyCtrl,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    alignLabelWithHint: true,
                    labelText: 'What’s on your mind?',
                    hintText: 'Share an update…',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
                label: Text(_submitting ? 'Posting…' : 'Post'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
