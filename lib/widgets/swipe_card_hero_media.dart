import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Swipe card hero: muted looping video when [resolvedVideoUrl] works, else [avatarUrl].
///
/// Only one candidate is on-screen at a time in [SwipePage]; [candidateKey] changes on swipe
/// so this state is disposed and the player is released.
class SwipeCardHeroMedia extends StatefulWidget {
  const SwipeCardHeroMedia({
    super.key,
    required this.candidateKey,
    required this.resolvedVideoUrl,
    required this.avatarUrl,
  });

  final String candidateKey;
  final String? resolvedVideoUrl;
  final String avatarUrl;

  @override
  State<SwipeCardHeroMedia> createState() => _SwipeCardHeroMediaState();
}

class _SwipeCardHeroMediaState extends State<SwipeCardHeroMedia> {
  VideoPlayerController? _controller;
  bool _videoReady = false;
  bool _videoFailed = false;

  @override
  void initState() {
    super.initState();
    _tryInitVideo();
  }

  @override
  void didUpdateWidget(covariant SwipeCardHeroMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resolvedVideoUrl != widget.resolvedVideoUrl ||
        oldWidget.candidateKey != widget.candidateKey) {
      _disposeVideo();
      _videoFailed = false;
      _videoReady = false;
      _tryInitVideo();
    }
  }

  void _tryInitVideo() {
    final raw = widget.resolvedVideoUrl?.trim() ?? '';
    if (raw.isEmpty) return;

    Uri uri;
    try {
      uri = Uri.parse(raw);
      if (!uri.hasScheme || (!uri.scheme.startsWith('http'))) {
        setState(() => _videoFailed = true);
        return;
      }
    } catch (_) {
      setState(() => _videoFailed = true);
      return;
    }

    final c = VideoPlayerController.networkUrl(uri);
    _controller = c;
    c.initialize().then((_) async {
      if (!mounted || _controller != c) {
        await c.dispose();
        return;
      }
      await c.setLooping(true);
      await c.setVolume(0);
      await c.play();
      if (mounted) {
        setState(() => _videoReady = true);
      }
    }).catchError((Object e) {
      debugPrint('[SwipeCardHeroMedia] init failed: $e');
      c.dispose();
      if (!mounted) return;
      _controller = null;
      setState(() {
        _videoFailed = true;
        _videoReady = false;
      });
    });
  }

  void _disposeVideo() {
    final c = _controller;
    _controller = null;
    _videoReady = false;
    c?.dispose();
  }

  @override
  void dispose() {
    _disposeVideo();
    super.dispose();
  }

  Widget _avatar(ColorScheme cs, BoxConstraints constraints) {
    final url = widget.avatarUrl.trim();
    if (url.isEmpty) {
      return Center(
        child: Icon(
          Icons.person_rounded,
          size: 96,
          color: cs.primary.withValues(alpha: 0.35),
        ),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: constraints.maxWidth,
      height: constraints.maxHeight,
      errorBuilder: (context, error, stackTrace) => Center(
        child: Icon(
          Icons.broken_image_outlined,
          size: 64,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_videoFailed ||
        widget.resolvedVideoUrl == null ||
        widget.resolvedVideoUrl!.trim().isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => _avatar(cs, constraints),
      );
    }

    final c = _controller;
    if (!_videoReady || c == null || !c.value.isInitialized) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            fit: StackFit.expand,
            children: [
              _avatar(cs, constraints),
              const Center(
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ],
          );
        },
      );
    }

    final size = c.value.size;
    if (size.width <= 0 || size.height <= 0) {
      return LayoutBuilder(
        builder: (context, constraints) => _avatar(cs, constraints),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return FittedBox(
          fit: BoxFit.cover,
          alignment: Alignment.center,
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: VideoPlayer(c),
          ),
        );
      },
    );
  }
}
