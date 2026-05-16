import 'package:flutter/material.dart';

/// Skip / Play controls below the swipe card (Explore → Smeet).
class SwipeDeckControls extends StatelessWidget {
  const SwipeDeckControls({
    super.key,
    required this.loading,
    required this.onSkip,
    required this.onPlay,
    required this.currentIndex,
    required this.totalCount,
  });

  final bool loading;
  final VoidCallback onSkip;
  final VoidCallback onPlay;

  /// Zero-based index into the candidate list.
  final int currentIndex;
  final int totalCount;

  static const Color _skipBorder = Color(0xFFD6D6D6);
  static const Color _skipIcon = Color(0xFFE53935);
  static const Color _playTeal = Color(0xFF14B8A6);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget circleButton({
      required double diameter,
      required String tooltip,
      required Widget child,
      required Color borderColor,
      required VoidCallback? onTap,
    }) {
      return Tooltip(
        message: tooltip,
        child: Container(
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(
                width: diameter,
                height: diameter,
                child: Center(child: child),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '← Skip     Play →',
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.35),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            circleButton(
              diameter: 48,
              tooltip: 'Skip',
              onTap: loading ? null : onSkip,
              borderColor: _skipBorder,
              child: const Icon(
                Icons.close_rounded,
                size: 22,
                color: _skipIcon,
              ),
            ),
            const SizedBox(width: 28),
            circleButton(
              diameter: 52,
              tooltip: 'Play',
              onTap: loading ? null : onPlay,
              borderColor: _playTeal.withValues(alpha: 0.42),
              child: const Text(
                '🎾',
                style: TextStyle(fontSize: 21, height: 1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Showing ${currentIndex + 1} / $totalCount',
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.36),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
