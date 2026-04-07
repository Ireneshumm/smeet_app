// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Web-only: HTML `<video>` first frame — fills parent (e.g. 16:9 [AspectRatio]).
class WebVideoThumbnail extends StatefulWidget {
  const WebVideoThumbnail({
    super.key,
    required this.videoUrl,
    required this.sport,
  });

  final String videoUrl;
  final String sport;

  @override
  State<WebVideoThumbnail> createState() => _WebVideoThumbnailState();
}

class _WebVideoThumbnailState extends State<WebVideoThumbnail> {
  late final String _viewId;
  bool _registered = false;

  @override
  void initState() {
    super.initState();
    _viewId =
        'video_thumb_${widget.videoUrl.hashCode}_${DateTime.now().microsecondsSinceEpoch}';
    _register();
  }

  void _register() {
    if (!kIsWeb || _registered) return;
    _registered = true;

    ui_web.platformViewRegistry.registerViewFactory(
      _viewId,
      (int viewId) {
        final video = html.VideoElement()
          ..src = widget.videoUrl
          ..autoplay = false
          ..controls = false
          ..muted = true
          ..preload = 'metadata'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.objectFit = 'cover';

        video.onLoadedMetadata.listen((_) {
          video.currentTime = 0.1;
        });

        return video;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: HtmlElementView(viewType: _viewId),
    );
  }
}
