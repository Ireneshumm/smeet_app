import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:smeet_app/core/constants/sports.dart';
import 'package:smeet_app/features/feed/models/feed_item.dart';
import 'package:smeet_app/widgets/circular_network_avatar.dart';
import 'package:smeet_app/other_profile_page.dart';

import 'web_video_thumbnail_stub.dart'
    if (dart.library.html) 'web_video_thumbnail.dart';

String _feedFirstMediaUrl(FeedItem item) {
  final list = item.mediaUrls;
  if (list != null && list.isNotEmpty) {
    final s = list.first.trim();
    if (s.isNotEmpty) return s;
  }
  return item.coverImageUrl?.trim() ?? '';
}

/// Playable video URL for Web [&lt;video&gt;] / fallbacks (not the poster image).
String _feedVideoPlayableUrl(FeedItem item) {
  final v = item.videoUrl?.trim() ?? '';
  if (v.isNotEmpty) return v;
  final list = item.mediaUrls;
  if (list == null) return '';
  for (final u in list) {
    final s = u.toString().trim();
    if (s.isNotEmpty) return s;
  }
  return '';
}

Widget _feedVideoLabel() {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(6),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.play_arrow_rounded, color: Colors.white, size: 12),
        SizedBox(width: 3),
        Text(
          'Video',
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

/// Gradient + emoji only — play icon / label come from [_buildVideoSection] overlay.
Widget _feedVideoGradientOnly(String sport) {
  final emoji = sportEmojiForKey(sport);
  return SizedBox.expand(
    child: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F2027),
            Color(0xFF203A43),
            Color(0xFF2C5364),
          ],
        ),
      ),
      child: Center(
        child: Opacity(
          opacity: 0.2,
          child: Text(
            emoji.isEmpty ? '🎯' : emoji,
            style: const TextStyle(fontSize: 72),
          ),
        ),
      ),
    ),
  );
}

/// Image post — aspect ratio from decoded dimensions.
class _PostImage extends StatefulWidget {
  const _PostImage({required this.imageUrl});

  final String imageUrl;

  @override
  State<_PostImage> createState() => _PostImageState();
}

class _PostImageState extends State<_PostImage> {
  double? _ratio;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void initState() {
    super.initState();
    _resolveRatio();
  }

  @override
  void dispose() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    super.dispose();
  }

  void _resolveRatio() {
    final image = NetworkImage(widget.imageUrl);
    final stream = image.resolve(ImageConfiguration.empty);
    _stream = stream;
    _listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        if (!mounted) return;
        final w = info.image.width.toDouble();
        final h = info.image.height.toDouble();
        if (h > 0) setState(() => _ratio = w / h);
      },
      onError: (Object error, StackTrace? stackTrace) {
        if (mounted) setState(() => _ratio = 4 / 3);
      },
    );
    stream.addListener(_listener!);
  }

  @override
  Widget build(BuildContext context) {
    final ratio = _ratio ?? 4 / 3;
    return AspectRatio(
      aspectRatio: ratio,
      child: CachedNetworkImage(
        imageUrl: widget.imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      ),
    );
  }
}

/// Feed tile — media on top, caption + author + like (Reels-style).
class FeedPostCard extends StatelessWidget {
  const FeedPostCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  final FeedItem item;
  final VoidCallback onTap;

  static const BorderRadius _mediaClipTop = BorderRadius.vertical(
    top: Radius.circular(16),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaUrl = _feedFirstMediaUrl(item);
    final hasCover = mediaUrl.isNotEmpty;
    final isVideo = item.isVideoContent;

    final cs = Theme.of(context).colorScheme;
    final authorId = item.authorId?.trim() ?? '';

    void openAuthorProfile() {
      if (authorId.isEmpty) return;
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => OtherProfilePage(userId: authorId),
        ),
      );
    }

    final caption = item.caption.trim().isNotEmpty
        ? item.caption.trim()
        : item.title.trim();

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              offset: const Offset(0, 2),
              blurRadius: 12,
              color: Colors.black.withValues(alpha: 0.08),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: _mediaClipTop,
                child: isVideo
                    ? _buildVideoSection(theme)
                    : _buildImageSection(mediaUrl, hasCover),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (caption.isNotEmpty) ...[
                      Text(
                        caption,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                    ],
                    Row(
                      children: [
                        GestureDetector(
                          onTap: openAuthorProfile,
                          child: CircularNetworkAvatar(
                            size: 26,
                            imageUrl: item.authorAvatarUrl,
                            backgroundColor:
                                cs.primary.withValues(alpha: 0.15),
                            placeholder: Icon(
                              Icons.person_rounded,
                              size: 12,
                              color: cs.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: GestureDetector(
                            onTap: openAuthorProfile,
                            behavior: HitTestBehavior.opaque,
                            child: Text(
                              item.authorName,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        if (item.type != FeedContentType.game)
                          _FeedLikeButton(item: item),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection(String mediaUrl, bool hasCover) {
    if (hasCover) {
      return _PostImage(imageUrl: mediaUrl);
    }
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: const ColoredBox(
        color: Color(0xFFE8E8E8),
        child: Center(
          child: Icon(Icons.image_not_supported_outlined, size: 40),
        ),
      ),
    );
  }

  Widget _buildVideoSection(ThemeData theme) {
    final coverUrl = item.coverImageUrl?.trim() ?? '';
    final videoUrl = _feedVideoPlayableUrl(item);

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.hardEdge,
        children: [
          if (coverUrl.isNotEmpty)
            CachedNetworkImage(
              imageUrl: coverUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) =>
                  _feedVideoGradientOnly(item.sport),
              errorWidget: (context, url, error) =>
                  _feedVideoGradientOnly(item.sport),
            )
          else if (kIsWeb && videoUrl.isNotEmpty)
            WebVideoThumbnail(
              videoUrl: videoUrl,
              sport: item.sport,
            )
          else
            _feedVideoGradientOnly(item.sport),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.35),
                  ],
                ),
              ),
            ),
          ),
          const Center(
            child: Icon(
              Icons.play_circle_filled_rounded,
              color: Colors.white,
              size: 52,
            ),
          ),
          Positioned(
            top: 10,
            left: 10,
            child: _feedVideoLabel(),
          ),
          if (item.durationLabel?.trim().isNotEmpty ?? false)
            Positioned(
              top: 8,
              right: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Text(
                    item.durationLabel!.trim(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FeedLikeButton extends StatefulWidget {
  const _FeedLikeButton({required this.item});

  final FeedItem item;

  @override
  State<_FeedLikeButton> createState() => _FeedLikeButtonState();
}

class _FeedLikeButtonState extends State<_FeedLikeButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  bool _liked = false;
  late int _count;

  @override
  void initState() {
    super.initState();
    _count = widget.item.likesCount;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scale = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
    _hydrateLiked();
  }

  Future<void> _hydrateLiked() async {
    final u = Supabase.instance.client.auth.currentUser;
    if (u == null) return;
    try {
      final row = await Supabase.instance.client
          .from('post_likes')
          .select('post_id')
          .eq('post_id', widget.item.id)
          .eq('user_id', u.id)
          .maybeSingle();
      if (!mounted) return;
      if (row != null) setState(() => _liked = true);
    } catch (_) {}
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _toggleLike() async {
    final u = Supabase.instance.client.auth.currentUser;
    if (u == null) return;

    setState(() {
      _liked = !_liked;
      _count += _liked ? 1 : -1;
      if (_count < 0) _count = 0;
    });
    await _ctrl.forward();
    await _ctrl.reverse();

    try {
      if (_liked) {
        await Supabase.instance.client.from('post_likes').upsert(
          {
            'post_id': widget.item.id,
            'user_id': u.id,
          },
          onConflict: 'post_id,user_id',
        );
      } else {
        await Supabase.instance.client
            .from('post_likes')
            .delete()
            .eq('post_id', widget.item.id)
            .eq('user_id', u.id);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleLike,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: _scale,
            child: Icon(
              _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              size: 18,
              color: _liked ? Colors.red.shade400 : Colors.grey.shade400,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            '$_count',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
