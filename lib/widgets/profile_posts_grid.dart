import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import 'package:smeet_app/widgets/adaptive_media.dart';

/// Two-column masonry grid for profile posts: intrinsic image/video aspect per cell.
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

    return MasonryGridView.count(
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics ??
          (shrinkWrap ? const NeverScrollableScrollPhysics() : null),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isVideo)
                    AdaptiveVideoCover(
                      coverUrl: url,
                      borderRadius: BorderRadius.circular(12),
                    )
                  else if (url.isNotEmpty)
                    AdaptiveNetworkImage(
                      imageUrl: url,
                      borderRadius: BorderRadius.circular(12),
                    )
                  else
                    AspectRatio(
                      aspectRatio: 4 / 3,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(
                            alpha: 0.5,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: cs.onSurfaceVariant,
                        ),
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
