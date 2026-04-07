import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

/// Inline autoplay for feed detail — aspect ratio follows the file; optional immersive fullscreen.
class FeedDetailVideo extends StatefulWidget {
  const FeedDetailVideo({super.key, required this.url});

  final String url;

  @override
  State<FeedDetailVideo> createState() => _FeedDetailVideoState();
}

class _FeedDetailVideoState extends State<FeedDetailVideo> {
  VideoPlayerController? _controller;
  bool _failed = false;

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    if (widget.url.trim().isEmpty) {
      _failed = true;
      return;
    }
    final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller = c;
    c.addListener(_onControllerUpdate);
    c.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      c.play();
    }).catchError((_) {
      if (!mounted) return;
      setState(() => _failed = true);
    });
  }

  @override
  void dispose() {
    final c = _controller;
    if (c != null) {
      c.removeListener(_onControllerUpdate);
      c.dispose();
    }
    super.dispose();
  }

  double get _aspectRatio {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return 16 / 9;
    final ar = c.value.aspectRatio;
    return ar == 0 ? 16 / 9 : ar;
  }

  Future<void> _toggleFullscreen(BuildContext context) async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _FullscreenVideoPage(controller: c),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_failed || _controller == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Could not load video'),
        ),
      );
    }

    final c = _controller!;
    if (!c.value.isInitialized) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(
          color: Colors.black,
          child: Center(
            child: CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      );
    }

    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () {
        if (c.value.isPlaying) {
          c.pause();
        } else {
          c.play();
        }
      },
      child: AspectRatio(
        aspectRatio: _aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Colors.black),
            VideoPlayer(c),
            if (!c.value.isPlaying)
              const Center(
                child: Icon(
                  Icons.play_circle_filled_rounded,
                  color: Colors.white,
                  size: 64,
                ),
              ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: VideoProgressIndicator(
                c,
                allowScrubbing: true,
                colors: VideoProgressColors(
                  playedColor: cs.primary,
                  bufferedColor: Colors.white30,
                  backgroundColor: Colors.white10,
                ),
              ),
            ),
            Positioned(
              bottom: 24,
              right: 8,
              child: GestureDetector(
                onTap: () => _toggleFullscreen(context),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.fullscreen_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullscreenVideoPage extends StatefulWidget {
  const _FullscreenVideoPage({required this.controller});

  final VideoPlayerController controller;

  @override
  State<_FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<_FullscreenVideoPage> {
  late final VoidCallback _listener;

  @override
  void initState() {
    super.initState();
    _listener = () {
      if (mounted) setState(() {});
    };
    widget.controller.addListener(_listener);

    if (!kIsWeb) {
      final size = widget.controller.value.size;
      final isLandscape = size.width > size.height;
      if (isLandscape) {
        SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } else {
        SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.portraitUp,
        ]);
      }
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_listener);
    if (!kIsWeb) {
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  void _exit() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final ar = c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio;
    final cs = Theme.of(context).colorScheme;
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: () {
              if (c.value.isPlaying) {
                c.pause();
              } else {
                c.play();
              }
            },
            child: Center(
              child: AspectRatio(
                aspectRatio: ar,
                child: VideoPlayer(c),
              ),
            ),
          ),
          if (!c.value.isPlaying)
            const Center(
              child: Icon(
                Icons.play_circle_filled_rounded,
                color: Colors.white,
                size: 64,
              ),
            ),
          Positioned(
            top: topInset + 4,
            left: 4,
            child: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: _exit,
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: VideoProgressIndicator(
              c,
              allowScrubbing: true,
              colors: VideoProgressColors(
                playedColor: cs.primary,
                bufferedColor: Colors.white30,
                backgroundColor: Colors.white10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
