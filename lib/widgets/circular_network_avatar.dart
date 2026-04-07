import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Round avatar with [BoxFit.cover] — avoids [CircleAvatar] + [NetworkImage] distortion.
class CircularNetworkAvatar extends StatelessWidget {
  const CircularNetworkAvatar({
    super.key,
    required this.size,
    required this.imageUrl,
    required this.placeholder,
    this.backgroundColor,
  });

  final double size;
  final String? imageUrl;
  final Widget placeholder;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final trimmed = imageUrl?.trim();
    final bg = backgroundColor ??
        Theme.of(context).colorScheme.primary.withValues(alpha: 0.12);

    Widget empty() => Container(
          width: size,
          height: size,
          color: bg,
          alignment: Alignment.center,
          child: placeholder,
        );

    final Widget core;
    if (trimmed == null || trimmed.isEmpty) {
      core = ClipOval(child: empty());
    } else {
      core = ClipOval(
        child: CachedNetworkImage(
          imageUrl: trimmed,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (context, url) => empty(),
          errorWidget: (context, url, err) => empty(),
        ),
      );
    }

    // Tight square so stretched parents (e.g. Column crossAxisAlignment: stretch)
    // never turn ClipOval into an ellipse.
    return SizedBox(
      width: size,
      height: size,
      child: core,
    );
  }
}
