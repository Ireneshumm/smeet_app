import 'package:flutter/material.dart';

import 'package:smeet_app/widgets/post_media_display.dart';

/// Two-column grid for profile posts: image thumbnails, video with poster attempt + play icon.
class ProfilePostsGrid extends StatelessWidget {
  const ProfilePostsGrid({
    super.key,
    required this.posts,
    required this.onOpenPost,
    this.shrinkWrap = false,
    this.physics,
    this.padding = EdgeInsets.zero,
  });

  final List<Map<String, dynamic>> posts;
  final void Function(Map<String, dynamic> post) onOpenPost;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry padding;

  static String _firstUrl(Map<String, dynamic> p) {
    final raw = p['media_urls'];
    if (raw == null || raw is! List || raw.isEmpty) return '';
    return raw.first.toString();
  }

  static bool _isVideo(Map<String, dynamic> p) {
    final t = (p['media_type'] ?? 'image').toString().toLowerCase();
    return t == 'video';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return GridView.builder(
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics ??
          (shrinkWrap ? const NeverScrollableScrollPhysics() : null),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 4 / 5,
      ),
      itemCount: posts.length,
      itemBuilder: (context, i) {
        final p = posts[i];
        final url = _firstUrl(p);
        final isVideo = _isVideo(p);
        final caption = (p['caption'] ?? '').toString().trim();

        return Material(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => onOpenPost(p),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: PostMediaGridCell(
                      imageUrl: url,
                      isVideo: isVideo,
                    ),
                  ),
                  if (caption.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        height: 1.25,
                        color: cs.onSurface.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
