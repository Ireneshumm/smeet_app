import 'package:flutter/material.dart';

/// Stub when not compiling for Web — never used when [kIsWeb] guards the widget.
class WebVideoThumbnail extends StatelessWidget {
  const WebVideoThumbnail({
    super.key,
    required this.videoUrl,
    required this.sport,
  });

  final String videoUrl;
  final String sport;

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
