import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Width fills the parent; height follows the image’s intrinsic aspect ratio.
class AdaptiveNetworkImage extends StatefulWidget {
  const AdaptiveNetworkImage({
    super.key,
    required this.imageUrl,
    this.borderRadius,
    this.errorBuilder,
  });

  final String imageUrl;
  final BorderRadius? borderRadius;
  final Widget Function(BuildContext context)? errorBuilder;

  @override
  State<AdaptiveNetworkImage> createState() => _AdaptiveNetworkImageState();
}

class _AdaptiveNetworkImageState extends State<AdaptiveNetworkImage> {
  double? _aspectRatio;
  ImageStream? _imageStream;
  ImageStreamListener? _listener;

  @override
  void initState() {
    super.initState();
    _resolveAspectRatio();
  }

  @override
  void didUpdateWidget(covariant AdaptiveNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _aspectRatio = null;
      _detachListener();
      _resolveAspectRatio();
    }
  }

  @override
  void dispose() {
    _detachListener();
    super.dispose();
  }

  void _detachListener() {
    if (_imageStream != null && _listener != null) {
      _imageStream!.removeListener(_listener!);
    }
    _imageStream = null;
    _listener = null;
  }

  void _resolveAspectRatio() {
    final url = widget.imageUrl.trim();
    if (url.isEmpty) {
      if (mounted) {
        setState(() => _aspectRatio = 4 / 3);
      }
      return;
    }

    _detachListener();
    final provider = NetworkImage(url);
    final stream = provider.resolve(ImageConfiguration.empty);
    _listener = ImageStreamListener(
      (ImageInfo info, bool sync) {
        if (!mounted) return;
        final w = info.image.width.toDouble();
        final h = info.image.height.toDouble();
        if (h > 0) {
          setState(() => _aspectRatio = w / h);
        }
      },
      onError: (Object? error, StackTrace? stackTrace) {
        if (mounted) setState(() => _aspectRatio = 4 / 3);
      },
    );
    _imageStream = stream;
    stream.addListener(_listener!);
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.imageUrl.trim();
    if (url.isEmpty) {
      return _errorOrEmpty(context);
    }

    final ratio = _aspectRatio;
    if (ratio == null) {
      return AspectRatio(
        aspectRatio: 4 / 3,
        child: Container(
          color: Colors.grey.shade200,
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    Widget img = CachedNetworkImage(
      imageUrl: url,
      width: double.infinity,
      fit: BoxFit.cover,
      errorWidget: (context, url, err) =>
          widget.errorBuilder?.call(context) ?? _defaultError(context),
    );

    if (widget.borderRadius != null) {
      img = ClipRRect(borderRadius: widget.borderRadius!, child: img);
    }

    return AspectRatio(
      aspectRatio: ratio,
      child: img,
    );
  }

  Widget _errorOrEmpty(BuildContext context) {
    final child = widget.errorBuilder?.call(context) ?? _defaultError(context);
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: child,
    );
  }

  Widget _defaultError(BuildContext context) {
    return ColoredBox(
      color: Colors.grey.shade300,
      child: Icon(
        Icons.broken_image_outlined,
        color: Colors.grey.shade600,
        size: 40,
      ),
    );
  }
}

/// Video poster: same width-led aspect as the cover image; play affordance on top.
class AdaptiveVideoCover extends StatefulWidget {
  const AdaptiveVideoCover({
    super.key,
    required this.coverUrl,
    this.videoUrl,
    this.onTap,
    this.borderRadius,
    this.memCacheWidth,
  });

  final String coverUrl;
  final String? videoUrl;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  /// Decodes at this width for faster first paint (e.g. 400 for feed thumbs).
  final int? memCacheWidth;

  @override
  State<AdaptiveVideoCover> createState() => _AdaptiveVideoCoverState();
}

class _AdaptiveVideoCoverState extends State<AdaptiveVideoCover> {
  double? _aspectRatio;
  ImageStream? _imageStream;
  ImageStreamListener? _listener;

  @override
  void initState() {
    super.initState();
    _resolveAspectRatio();
  }

  @override
  void didUpdateWidget(covariant AdaptiveVideoCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coverUrl != widget.coverUrl) {
      _aspectRatio = null;
      _detachListener();
      _resolveAspectRatio();
    }
  }

  @override
  void dispose() {
    _detachListener();
    super.dispose();
  }

  void _detachListener() {
    if (_imageStream != null && _listener != null) {
      _imageStream!.removeListener(_listener!);
    }
    _imageStream = null;
    _listener = null;
  }

  void _resolveAspectRatio() {
    final url = widget.coverUrl.trim();
    if (url.isEmpty) {
      if (mounted) setState(() => _aspectRatio = 16 / 9);
      return;
    }

    _detachListener();
    final provider = NetworkImage(url);
    final stream = provider.resolve(ImageConfiguration.empty);
    _listener = ImageStreamListener(
      (ImageInfo info, bool sync) {
        if (!mounted) return;
        final w = info.image.width.toDouble();
        final h = info.image.height.toDouble();
        if (h > 0) setState(() => _aspectRatio = w / h);
      },
      onError: (Object? error, StackTrace? stackTrace) {
        if (mounted) setState(() => _aspectRatio = 16 / 9);
      },
    );
    _imageStream = stream;
    stream.addListener(_listener!);
  }

  @override
  Widget build(BuildContext context) {
    final ratio = _aspectRatio ?? 16 / 9;
    final cover = widget.coverUrl.trim();

    Widget content = AspectRatio(
      aspectRatio: ratio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          cover.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: cover,
                  fit: BoxFit.cover,
                  memCacheWidth: widget.memCacheWidth,
                  placeholder: (context, _) => Container(
                    color: const Color(0xFF1A1A2E),
                    child: const Center(
                      child: Icon(
                        Icons.videocam_rounded,
                        color: Colors.white54,
                        size: 32,
                      ),
                    ),
                  ),
                  errorWidget: (context, url, err) => Container(
                    color: const Color(0xFF1A1A2E),
                    child: const Center(
                      child: Icon(
                        Icons.videocam_rounded,
                        color: Colors.white54,
                        size: 32,
                      ),
                    ),
                  ),
                )
              : Container(
                  color: const Color(0xFF1A1A2E),
                  child: const Center(
                    child: Icon(
                      Icons.videocam_rounded,
                      color: Colors.white54,
                      size: 32,
                    ),
                  ),
                ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.4),
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
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 12,
                  ),
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
            ),
          ),
        ],
      ),
    );

    if (widget.borderRadius != null) {
      content = ClipRRect(borderRadius: widget.borderRadius!, child: content);
    }

    if (widget.onTap != null) {
      content = GestureDetector(onTap: widget.onTap, behavior: HitTestBehavior.opaque, child: content);
    }

    return content;
  }
}
