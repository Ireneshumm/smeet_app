import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Shared radii / border language for post images & video across Profile surfaces.
const double kPostMediaListRadius = 14;
const double kPostMediaDetailRadius = 16;
const double kPostMediaThumbRadius = 12;

Color _postMediaBackdrop(ColorScheme cs) =>
    cs.surfaceContainerHighest.withValues(alpha: 0.38);

BorderSide _postMediaBorderSide(ColorScheme cs) => BorderSide(
      color: cs.outlineVariant.withValues(alpha: 0.48),
      width: 1,
    );

/// 4:5 frame for list-style post media (Profile Posts tab, etc.).
Widget postMediaListFrame({
  required ColorScheme colorScheme,
  required Widget child,
}) {
  return AspectRatio(
    aspectRatio: 4 / 5,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(kPostMediaListRadius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _postMediaBackdrop(colorScheme),
          border: Border.fromBorderSide(_postMediaBorderSide(colorScheme)),
          borderRadius: BorderRadius.circular(kPostMediaListRadius),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(kPostMediaListRadius - 1),
          child: child,
        ),
      ),
    ),
  );
}

/// 4:5 leading thumbnail for Profile MVP post rows (image or video placeholder).
class PostMediaMvpLeading extends StatelessWidget {
  const PostMediaMvpLeading({
    super.key,
    required this.url,
    required this.isVideo,
  });

  final String url;
  final bool isVideo;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 72,
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(kPostMediaThumbRadius),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isVideo ? Colors.black : _postMediaBackdrop(cs),
              border: Border.fromBorderSide(_postMediaBorderSide(cs)),
              borderRadius: BorderRadius.circular(kPostMediaThumbRadius),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(kPostMediaThumbRadius - 1),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (!isVideo && url.isNotEmpty)
                    Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => ColoredBox(
                        color: _postMediaBackdrop(cs),
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  if (isVideo)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Profile **Posts** list (shell): 4:5 cover, optional inline video with play overlay.
class PostProfileListMedia extends StatefulWidget {
  const PostProfileListMedia({
    super.key,
    required this.type,
    required this.url,
  });

  final String type;
  final String url;

  @override
  State<PostProfileListMedia> createState() => _PostProfileListMediaState();
}

class _PostProfileListMediaState extends State<PostProfileListMedia> {
  VideoPlayerController? _vc;
  Future<void>? _initFuture;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  @override
  void didUpdateWidget(covariant PostProfileListMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url || oldWidget.type != widget.type) {
      _disposeVc();
      _setup();
    }
  }

  void _setup() {
    if (widget.type != 'video' || widget.url.isEmpty) return;
    final uri = Uri.tryParse(widget.url);
    if (uri == null || !uri.hasScheme) return;
    _vc = VideoPlayerController.networkUrl(uri);
    _initFuture = _vc!.initialize().then((_) {
      _vc!.setVolume(0);
      if (mounted) setState(() {});
    }).catchError((Object e, StackTrace st) {
      if (kDebugMode) {
        debugPrint('[PostProfileListMedia] initialize failed: $e');
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

  Widget _emptyBox(ColorScheme cs, {IconData? icon, String? label}) {
    return ColoredBox(
      color: _postMediaBackdrop(cs),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon ?? Icons.broken_image_outlined,
                size: 40, color: cs.onSurfaceVariant),
            if (label != null) ...[
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _cornerPlayBadge() {
    return Positioned(
      top: 10,
      right: 10,
      child: Icon(
        Icons.play_circle_filled_rounded,
        color: Colors.white.withValues(alpha: 0.92),
        size: 40,
        shadows: const [
          Shadow(blurRadius: 8, color: Colors.black45),
        ],
      ),
    );
  }

  Widget _centerPlayPause(bool playing) {
    return Center(
      child: Material(
        color: Colors.black.withValues(alpha: 0.42),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            setState(() {
              if (_vc!.value.isPlaying) {
                _vc!.pause();
              } else {
                _vc!.play();
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = widget.type.toLowerCase();

    if (t == 'image') {
      if (widget.url.isEmpty) {
        return postMediaListFrame(
          colorScheme: cs,
          child: _emptyBox(cs, icon: Icons.image_not_supported_outlined),
        );
      }
      return postMediaListFrame(
        colorScheme: cs,
        child: Image.network(
          widget.url,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) =>
              _emptyBox(cs, label: 'Couldn’t load image'),
        ),
      );
    }

    if (t == 'video') {
      if (widget.url.isEmpty) {
        return postMediaListFrame(
          colorScheme: cs,
          child: _emptyBox(cs, icon: Icons.videocam_off_outlined),
        );
      }
      if (_vc == null || _initFuture == null) {
        return postMediaListFrame(
          colorScheme: cs,
          child: _emptyBox(cs, icon: Icons.videocam_outlined, label: 'Video'),
        );
      }
      return postMediaListFrame(
        colorScheme: cs,
        child: FutureBuilder<void>(
          future: _initFuture,
          builder: (context, snap) {
            if (snap.hasError) {
              return _emptyBox(cs,
                  icon: Icons.error_outline, label: 'Video failed to load');
            }
            if (snap.connectionState != ConnectionState.done) {
              return ColoredBox(
                color: Colors.black,
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                  ),
                ),
              );
            }
            if (!_vc!.value.isInitialized) {
              return _emptyBox(cs,
                  icon: Icons.videocam_off_outlined, label: 'Video unavailable');
            }
            final playing = _vc!.value.isPlaying;
            return Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: Colors.black),
                FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: _vc!.value.size.width,
                    height: _vc!.value.size.height,
                    child: VideoPlayer(_vc!),
                  ),
                ),
                if (!playing) _cornerPlayBadge(),
                _centerPlayPause(playing),
              ],
            );
          },
        ),
      );
    }

    return postMediaListFrame(
      colorScheme: cs,
      child: _emptyBox(cs, icon: Icons.help_outline),
    );
  }
}

/// Detail: one or more images, 4:5 each, full width.
class PostMediaDetailImages extends StatelessWidget {
  const PostMediaDetailImages({super.key, required this.urls});

  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < urls.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(kPostMediaDetailRadius),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.fromBorderSide(_postMediaBorderSide(cs)),
                borderRadius: BorderRadius.circular(kPostMediaDetailRadius),
              ),
              child: ClipRRect(
                borderRadius:
                    BorderRadius.circular(kPostMediaDetailRadius - 1),
                child: AspectRatio(
                  aspectRatio: 4 / 5,
                  child: Image.network(
                    urls[i],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => ColoredBox(
                      color: _postMediaBackdrop(cs),
                      child: Icon(
                        Icons.broken_image_outlined,
                        size: 52,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Detail: video in 16:9 frame (full width, stable height), same border language.
class PostMediaDetailVideo extends StatefulWidget {
  const PostMediaDetailVideo({super.key, required this.url});

  final String url;

  @override
  State<PostMediaDetailVideo> createState() => _PostMediaDetailVideoState();
}

class _PostMediaDetailVideoState extends State<PostMediaDetailVideo> {
  VideoPlayerController? _vc;
  Future<void>? _initFuture;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  @override
  void didUpdateWidget(covariant PostMediaDetailVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _disposeVc();
      _setup();
    }
  }

  void _setup() {
    if (widget.url.isEmpty) return;
    final uri = Uri.tryParse(widget.url);
    if (uri == null || !uri.hasScheme) return;
    _vc = VideoPlayerController.networkUrl(uri);
    _initFuture = _vc!.initialize().then((_) {
      _vc!.setVolume(0);
      if (mounted) setState(() {});
    }).catchError((Object e, StackTrace st) {
      if (kDebugMode) {
        debugPrint('[PostMediaDetailVideo] initialize failed: $e');
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

  Widget _fallback(ColorScheme cs, IconData icon, String label) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ColoredBox(
        color: _postMediaBackdrop(cs),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: cs.onSurfaceVariant),
              const SizedBox(height: 8),
              Text(label, style: TextStyle(color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (widget.url.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(kPostMediaDetailRadius),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.fromBorderSide(_postMediaBorderSide(cs)),
            borderRadius: BorderRadius.circular(kPostMediaDetailRadius),
          ),
          child: _fallback(cs, Icons.videocam_off_outlined, 'No video'),
        ),
      );
    }
    if (_vc == null || _initFuture == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(kPostMediaDetailRadius),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.fromBorderSide(_postMediaBorderSide(cs)),
            borderRadius: BorderRadius.circular(kPostMediaDetailRadius),
          ),
          child: _fallback(cs, Icons.videocam_outlined, 'Video'),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(kPostMediaDetailRadius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.fromBorderSide(_postMediaBorderSide(cs)),
          borderRadius: BorderRadius.circular(kPostMediaDetailRadius),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(kPostMediaDetailRadius - 1),
          child: FutureBuilder<void>(
            future: _initFuture,
            builder: (context, snap) {
              if (snap.hasError) {
                return _fallback(
                    cs, Icons.error_outline, 'Video failed to load');
              }
              if (snap.connectionState != ConnectionState.done) {
                return AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ColoredBox(
                    color: Colors.black,
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(cs.primary),
                      ),
                    ),
                  ),
                );
              }
              if (!_vc!.value.isInitialized) {
                return _fallback(
                    cs, Icons.videocam_off_outlined, 'Video unavailable');
              }
              final playing = _vc!.value.isPlaying;
              return AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: Colors.black),
                    FittedBox(
                      fit: BoxFit.cover,
                      clipBehavior: Clip.hardEdge,
                      child: SizedBox(
                        width: _vc!.value.size.width,
                        height: _vc!.value.size.height,
                        child: VideoPlayer(_vc!),
                      ),
                    ),
                    if (!playing)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Icon(
                          Icons.play_circle_filled_rounded,
                          color: Colors.white.withValues(alpha: 0.92),
                          size: 44,
                          shadows: const [
                            Shadow(blurRadius: 10, color: Colors.black54),
                          ],
                        ),
                      ),
                    Center(
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.45),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () {
                            setState(() {
                              if (_vc!.value.isPlaying) {
                                _vc!.pause();
                              } else {
                                _vc!.play();
                              }
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Icon(
                              playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Read-only grid cell (e.g. other user profile): fills cell, 4:5 via parent grid ratio.
class PostMediaGridCell extends StatelessWidget {
  const PostMediaGridCell({
    super.key,
    required this.imageUrl,
    required this.isVideo,
    this.showPlayBadge = true,
  });

  final String imageUrl;
  final bool isVideo;
  final bool showPlayBadge;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(kPostMediaThumbRadius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _postMediaBackdrop(cs),
          border: Border.fromBorderSide(_postMediaBorderSide(cs)),
          borderRadius: BorderRadius.circular(kPostMediaThumbRadius),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(kPostMediaThumbRadius - 1),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (isVideo && imageUrl.isNotEmpty)
                Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => ColoredBox(
                    color: Colors.black.withValues(alpha: 0.92),
                  ),
                )
              else if (isVideo)
                ColoredBox(color: Colors.black.withValues(alpha: 0.92))
              else if (imageUrl.isNotEmpty)
                Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => ColoredBox(
                    color: _postMediaBackdrop(cs),
                    child: Icon(Icons.broken_image_outlined,
                        color: cs.onSurfaceVariant),
                  ),
                )
              else
                ColoredBox(
                  color: _postMediaBackdrop(cs),
                  child: Icon(Icons.image_not_supported_outlined,
                      color: cs.onSurfaceVariant),
                ),
              if (isVideo && showPlayBadge)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Icon(
                    Icons.play_circle_filled_rounded,
                    color: Colors.white.withValues(alpha: 0.95),
                    size: 36,
                    shadows: const [
                      Shadow(blurRadius: 8, color: Colors.black54),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
