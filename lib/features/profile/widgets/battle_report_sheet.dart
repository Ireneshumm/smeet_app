import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:smeet_app/core/services/media_upload_service.dart';
import 'package:smeet_app/core/services/posts_service.dart';

/// Post-game battle report: rating + caption + optional image → posts + achievement RPC.
class BattleReportSheet extends StatefulWidget {
  const BattleReportSheet({
    super.key,
    required this.client,
    required this.game,
  });

  final SupabaseClient client;
  final Map<String, dynamic> game;

  @override
  State<BattleReportSheet> createState() => _BattleReportSheetState();
}

class _BattleReportSheetState extends State<BattleReportSheet> {
  int _rating = 0;
  final _captionCtrl = TextEditingController();
  late final PostsService _posts = PostsService(widget.client);
  bool _busy = false;
  String? _imageUrl;

  String get _sportKey => (widget.game['sport'] ?? 'Tennis').toString().trim();
  String get _gameId => (widget.game['id'] ?? '').toString();

  @override
  void dispose() {
    _captionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final u = widget.client.auth.currentUser;
    if (u == null) return;
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (x == null) return;
    setState(() => _busy = true);
    try {
      final url = await MediaUploadService(widget.client).uploadXFileToMediaBucket(
        x,
        userId: u.id,
        folder: 'posts',
      );
      if (mounted) setState(() => _imageUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Couldn’t upload image: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    final u = widget.client.auth.currentUser;
    if (u == null) return;
    if (_rating < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a rating (1–5).')),
      );
      return;
    }
    final cap = _captionCtrl.text.trim();
    final sportLower = _sportKey.toLowerCase();
    final body = [
      '🏆 Battle report · $_sportKey',
      'Rating: $_rating/5',
      if (_gameId.isNotEmpty) 'Game: $_gameId',
      if (cap.isNotEmpty) cap,
    ].join('\n');

    setState(() => _busy = true);
    try {
      if (_imageUrl != null && _imageUrl!.isNotEmpty) {
        final payload = PostsService.buildMediaPostPayload(
          authorId: u.id,
          mediaUrl: _imageUrl!,
          mediaType: 'image',
          captionTrimmed: body,
          sport: sportLower,
        );
        await _posts.insertPostReturningSummary(payload);
      } else {
        await _posts.createTextPost(
          userId: u.id,
          trimmedBody: body,
          sport: sportLower,
        );
      }

      await widget.client.rpc(
        'update_sport_achievement',
        params: {
          'p_user_id': u.id,
          'p_sport': _sportKey,
          'p_hours': 1.0,
        },
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Battle report posted.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Couldn’t post: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'How was this game?',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Rating',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(5, (i) {
              final n = i + 1;
              final on = n <= _rating;
              return IconButton(
                onPressed: _busy ? null : () => setState(() => _rating = n),
                icon: Icon(
                  Icons.sports_tennis,
                  size: 32,
                  color: on ? cs.primary : cs.outlineVariant,
                ),
              );
            }),
          ),
          TextField(
            controller: _captionCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Share how you played today…',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _pickImage,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('Add image'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
            ),
            child: _busy
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Post report'),
          ),
        ],
      ),
    );
  }
}
