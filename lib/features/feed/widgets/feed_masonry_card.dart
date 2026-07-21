import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart' show WebHtmlElementStrategy;

import 'package:smeet_app/app/smeet_app.dart';
import 'package:smeet_app/core/constants/sports.dart';
import 'package:smeet_app/core/theme/theme.dart';
import 'package:smeet_app/features/feed/models/feed_item.dart';
import 'package:smeet_app/other_profile_page.dart';
import 'package:smeet_app/widgets/circular_network_avatar.dart';

import 'web_video_thumbnail_stub.dart'
    if (dart.library.html) 'web_video_thumbnail.dart';

/// Pinterest-style masonry tile for posts/videos in the feed grid.
class FeedMasonryCard extends StatelessWidget {
  const FeedMasonryCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  final FeedItem item;
  final VoidCallback onTap;

  static double defaultAspectRatioFor(FeedItem item) {
    if (item.isVideoContent) return 4 / 3;
    return 4 / 5;
  }

  @override
  Widget build(BuildContext context) {
    final caption = item.caption.trim().isNotEmpty
        ? item.caption.trim()
        : item.title.trim();
    final mediaUrl = _firstMediaUrl(item);
    final isVideo = item.isVideoContent;
    final authorId = item.authorId?.trim() ?? '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lgAll,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppRadius.lgAll,
            boxShadow: [
              BoxShadow(
                color: SmeetApp.smeetMint.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: _MasonryMedia(
                  item: item,
                  mediaUrl: mediaUrl,
                  isVideo: isVideo,
                ),
              ),
              if (caption.isNotEmpty || authorId.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (caption.isNotEmpty)
                        Text(
                          caption,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                            color: SmeetApp.smeetInk,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      if (caption.isNotEmpty) const SizedBox(height: 8),
                      _AuthorRow(item: item),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _firstMediaUrl(FeedItem item) {
    final list = item.mediaUrls;
    if (list != null && list.isNotEmpty) {
      final s = list.first.trim();
      if (s.isNotEmpty) return s;
    }
    return item.coverImageUrl?.trim() ?? '';
  }
}

class _MasonryMedia extends StatefulWidget {
  const _MasonryMedia({
    required this.item,
    required this.mediaUrl,
    required this.isVideo,
  });

  final FeedItem item;
  final String mediaUrl;
  final bool isVideo;

  @override
  State<_MasonryMedia> createState() => _MasonryMediaState();
}

class _MasonryMediaState extends State<_MasonryMedia> {
  double? _resolvedRatio;

  @override
  void initState() {
    super.initState();
    if (!widget.isVideo && widget.mediaUrl.isNotEmpty && !kIsWeb) {
      _resolveImageRatio(widget.mediaUrl);
    }
  }

  @override
  void didUpdateWidget(covariant _MasonryMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaUrl != widget.mediaUrl) {
      _resolvedRatio = null;
      if (!widget.isVideo && widget.mediaUrl.isNotEmpty && !kIsWeb) {
        _resolveImageRatio(widget.mediaUrl);
      }
    }
  }

  void _resolveImageRatio(String url) {
    final image = NetworkImage(url);
    final stream = image.resolve(ImageConfiguration.empty);
    stream.addListener(
      ImageStreamListener(
        (info, _) {
          if (!mounted) return;
          final w = info.image.width.toDouble();
          final h = info.image.height.toDouble();
          if (h > 0) {
            setState(() => _resolvedRatio = (w / h).clamp(0.45, 2.2));
          }
        },
        onError: (_, _) {
          if (mounted) setState(() => _resolvedRatio = 4 / 5);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ratio = widget.isVideo
        ? FeedMasonryCard.defaultAspectRatioFor(widget.item)
        : (_resolvedRatio ?? FeedMasonryCard.defaultAspectRatioFor(widget.item));

    return AspectRatio(
      aspectRatio: ratio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.mediaUrl.isEmpty)
            ColoredBox(
              color: SmeetApp.smeetMintFaint,
              child: Center(
                child: Text(
                  sportEmojiForKey(widget.item.sport),
                  style: const TextStyle(
                    fontSize: 40,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            )
          else if (widget.isVideo)
            _buildVideoCover()
          else
            _buildPhoto(),
          if (widget.isVideo) _buildPlayBadge(),
        ],
      ),
    );
  }

  Widget _buildPhoto() {
    if (kIsWeb) {
      return Image.network(
        widget.mediaUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
        errorBuilder: (_, _, _) => const ColoredBox(
          color: Color(0xFFE8E8E8),
          child: Icon(Icons.broken_image_outlined),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: widget.mediaUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorWidget: (_, _, _) => const ColoredBox(
        color: Color(0xFFE8E8E8),
        child: Icon(Icons.broken_image_outlined),
      ),
    );
  }

  Widget _buildVideoCover() {
    final cover = widget.item.coverImageUrl?.trim() ?? '';
    if (cover.isNotEmpty) {
      if (kIsWeb) {
        return Image.network(
          cover,
          fit: BoxFit.cover,
          webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
        );
      }
      return CachedNetworkImage(imageUrl: cover, fit: BoxFit.cover);
    }
    if (kIsWeb && widget.mediaUrl.isNotEmpty) {
      return WebVideoThumbnail(
        videoUrl: widget.mediaUrl,
        sport: widget.item.sport,
      );
    }
    return ColoredBox(
      color: SmeetApp.smeetMintFaint,
      child: Center(
        child: Text(
          sportEmojiForKey(widget.item.sport),
          style: const TextStyle(
            fontSize: 48,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }

  Widget _buildPlayBadge() {
    return Center(
      child: Container(
        width: 56,
        height: 56,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.play_arrow_rounded,
          size: AppIconSize.lg,
          color: SmeetApp.smeetMint,
        ),
      ),
    );
  }
}

class _AuthorRow extends StatelessWidget {
  const _AuthorRow({required this.item});

  final FeedItem item;

  @override
  Widget build(BuildContext context) {
    final authorId = item.authorId?.trim() ?? '';
    final initial = item.authorName.isNotEmpty
        ? item.authorName.characters.first.toUpperCase()
        : 'P';

    void openProfile() {
      if (authorId.isEmpty) return;
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => OtherProfilePage(userId: authorId),
        ),
      );
    }

    final avatar = item.authorAvatarUrl?.trim().isNotEmpty == true
        ? CircularNetworkAvatar(
            size: 24,
            imageUrl: item.authorAvatarUrl,
            backgroundColor: SmeetApp.smeetMintLight,
            placeholder: Text(
              initial,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: SmeetApp.smeetDeep,
                decoration: TextDecoration.none,
              ),
            ),
          )
        : CircleAvatar(
            radius: 12,
            backgroundColor: SmeetApp.smeetMint,
            child: Text(
              initial,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                decoration: TextDecoration.none,
              ),
            ),
          );

    return Row(
      children: [
        GestureDetector(onTap: openProfile, child: avatar),
        const SizedBox(width: 6),
        Expanded(
          child: GestureDetector(
            onTap: openProfile,
            behavior: HitTestBehavior.opaque,
            child: Text(
              item.authorName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: SmeetApp.smeetInk,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
        Icon(
          Icons.favorite_rounded,
          size: AppIconSize.xs,
          color: SmeetApp.smeetGrey.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 2),
        Text(
          '${item.likesCount}',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: SmeetApp.smeetGrey,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }
}
