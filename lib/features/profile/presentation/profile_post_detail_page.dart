import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

import 'package:smeet_app/core/services/posts_service.dart';
import 'package:smeet_app/features/profile/models/profile_tab_item.dart';

/// Minimal real post detail for Profile MVP **Posts** tab (by [ProfileTabItem.id]).
class ProfileMvpPostDetailPage extends StatefulWidget {
  const ProfileMvpPostDetailPage({super.key, required this.item});

  final ProfileTabItem item;

  @override
  State<ProfileMvpPostDetailPage> createState() =>
      _ProfileMvpPostDetailPageState();
}

class _ProfileMvpPostDetailPageState extends State<ProfileMvpPostDetailPage> {
  late final PostsService _posts = PostsService();
  late final Future<Map<String, dynamic>?> _future =
      _posts.fetchPostById(widget.item.id);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final row = snapshot.data;
          if (row == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Post not found or unavailable.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return _PostDetailBody(row: row);
        },
      ),
    );
  }
}

class _PostDetailBody extends StatelessWidget {
  const _PostDetailBody({required this.row});

  final Map<String, dynamic> row;

  static List<String> _urls(dynamic raw) {
    if (raw == null) return const [];
    if (raw is! List) return const [];
    return raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
  }

  static String? _mediaType(dynamic raw) {
    final s = raw?.toString().trim() ?? '';
    return s.isEmpty ? null : s;
  }

  static DateTime? _createdAt(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    return DateTime.tryParse(raw.toString());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final caption = (row['caption'] as String?)?.trim() ?? '';
    final mediaType = _mediaType(row['media_type']) ?? '—';
    final urls = _urls(row['media_urls']);
    final created = _createdAt(row['created_at']);
    final when = created != null
        ? DateFormat.yMMMd().add_jm().format(created.toLocal())
        : '—';

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            when,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'media_type: $mediaType',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          if (caption.isEmpty)
            Text(
              '(No caption)',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            Text(caption, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 20),
          _MediaBlock(
            mediaType: mediaType == '—' ? '' : mediaType,
            urls: urls,
          ),
        ],
      ),
    );
  }
}

class _MediaBlock extends StatefulWidget {
  const _MediaBlock({required this.mediaType, required this.urls});

  final String mediaType;
  final List<String> urls;

  @override
  State<_MediaBlock> createState() => _MediaBlockState();
}

class _MediaBlockState extends State<_MediaBlock> {
  VideoPlayerController? _vc;
  Future<void>? _initFuture;

  @override
  void initState() {
    super.initState();
    _setupVideoIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _MediaBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaType != widget.mediaType ||
        oldWidget.urls.length != widget.urls.length ||
        (widget.urls.isNotEmpty &&
            oldWidget.urls.isNotEmpty &&
            oldWidget.urls.first != widget.urls.first)) {
      _disposeVc();
      _setupVideoIfNeeded();
    }
  }

  void _setupVideoIfNeeded() {
    if (widget.mediaType.toLowerCase() != 'video') return;
    final url = widget.urls.isNotEmpty ? widget.urls.first : '';
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return;

    _vc = VideoPlayerController.networkUrl(uri);
    _initFuture = _vc!.initialize().then((_) {
      _vc!.setVolume(0);
      if (mounted) setState(() {});
    }).catchError((Object e, StackTrace st) {
      if (kDebugMode) {
        debugPrint('[ProfileMvpPostDetail] video init failed: $e');
        debugPrint('$st');
      }
      if (mounted) setState(() {});
    });
  }

  void _disposeVc() {
    _vc?.dispose();
    _vc = null;
    _initFuture = null;
  }

  @override
  void dispose() {
    _disposeVc();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final t = widget.mediaType.toLowerCase();

    if (widget.urls.isEmpty) {
      return Text(
        'No media URLs',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: cs.onSurfaceVariant,
        ),
      );
    }

    if (t == 'video') {
      final url = widget.urls.first;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              color: Colors.black,
              child: _buildVideoArea(context, url),
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            url,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    // image or unknown: show images from URLs
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final url in widget.urls) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return ColoredBox(
                    color: cs.surfaceContainerHighest,
                    child: Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: cs.onSurfaceVariant,
                        size: 48,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildVideoArea(BuildContext context, String url) {
    final cs = Theme.of(context).colorScheme;

    if (_vc == null || _initFuture == null) {
      return AspectRatio(
        aspectRatio: 4 / 3,
        child: _videoFallback(
          context,
          icon: Icons.videocam_outlined,
          label: 'Video',
        ),
      );
    }

    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snap) {
        if (snap.hasError) {
          return AspectRatio(
            aspectRatio: 4 / 3,
            child: _videoFallback(
              context,
              icon: Icons.error_outline,
              label: 'Video failed to load',
            ),
          );
        }
        if (snap.connectionState != ConnectionState.done) {
          return AspectRatio(
            aspectRatio: 4 / 3,
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
              ),
            ),
          );
        }
        if (!_vc!.value.isInitialized) {
          return AspectRatio(
            aspectRatio: 4 / 3,
            child: _videoFallback(
              context,
              icon: Icons.videocam_off_outlined,
              label: 'Video unavailable',
            ),
          );
        }

        final ar = _vc!.value.aspectRatio > 0 ? _vc!.value.aspectRatio : 4 / 3;
        return Stack(
          alignment: Alignment.center,
          children: [
            AspectRatio(aspectRatio: ar, child: VideoPlayer(_vc!)),
            GestureDetector(
              onTap: () {
                setState(() {
                  if (_vc!.value.isPlaying) {
                    _vc!.pause();
                  } else {
                    _vc!.play();
                  }
                });
              },
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _vc!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _videoFallback(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    final cs = Theme.of(context).colorScheme;
    return ColoredBox(
      color: cs.surfaceContainerHighest,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: cs.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}
