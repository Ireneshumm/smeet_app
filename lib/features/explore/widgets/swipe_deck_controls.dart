import 'package:flutter/material.dart';
import 'package:smeet_app/app/smeet_app.dart';

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

  static const double _buttonSize = 64;
  static const double _buttonGap = 48;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SwipeCircleButton(
              tooltip: 'Skip',
              enabled: !loading,
              borderColor: SmeetApp.smeetGreyLight,
              pressedBorderColor: SmeetApp.smeetMint,
              pressedBackgroundColor: SmeetApp.smeetMintLight,
              pressScale: 0.92,
              glowOnPress: false,
              onPressed: onSkip,
              child: const Icon(
                Icons.close_rounded,
                size: 28,
                color: SmeetApp.smeetGrey,
              ),
            ),
            const SizedBox(width: _buttonGap),
            _SwipeCircleButton(
              tooltip: 'Play',
              enabled: !loading,
              borderColor: SmeetApp.smeetMint,
              pressedBorderColor: SmeetApp.smeetMint,
              pressedBackgroundColor: Colors.white,
              pressScale: 1.08,
              glowOnPress: true,
              onPressed: onPlay,
              child: const Icon(
                Icons.sports_tennis_rounded,
                size: 28,
                color: SmeetApp.smeetMint,
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            'Showing ${currentIndex + 1} / $totalCount',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: SmeetApp.smeetGrey,
            ),
          ),
        ),
      ],
    );
  }
}

class _SwipeCircleButton extends StatefulWidget {
  const _SwipeCircleButton({
    required this.tooltip,
    required this.enabled,
    required this.borderColor,
    required this.pressedBorderColor,
    required this.pressedBackgroundColor,
    required this.pressScale,
    required this.glowOnPress,
    required this.onPressed,
    required this.child,
  });

  final String tooltip;
  final bool enabled;
  final Color borderColor;
  final Color pressedBorderColor;
  final Color pressedBackgroundColor;
  final double pressScale;
  final bool glowOnPress;
  final VoidCallback onPressed;
  final Widget child;

  @override
  State<_SwipeCircleButton> createState() => _SwipeCircleButtonState();
}

class _SwipeCircleButtonState extends State<_SwipeCircleButton> {
  bool _pressed = false;

  static const _duration = Duration(milliseconds: 100);

  void _setPressed(bool value) {
    if (!widget.enabled) return;
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final border = _pressed ? widget.pressedBorderColor : widget.borderColor;
    final bg = _pressed ? widget.pressedBackgroundColor : Colors.white;
    final scale = _pressed ? widget.pressScale : 1.0;

    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) {
          _setPressed(false);
          if (widget.enabled) widget.onPressed();
        },
        onTapCancel: () => _setPressed(false),
        child: AnimatedScale(
          scale: scale,
          duration: _duration,
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: _duration,
            curve: Curves.easeOut,
            width: SwipeDeckControls._buttonSize,
            height: SwipeDeckControls._buttonSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bg,
              border: Border.all(color: border, width: 2),
              boxShadow: [
                if (_pressed && widget.glowOnPress)
                  BoxShadow(
                    color: SmeetApp.smeetMint.withValues(alpha: 0.35),
                    blurRadius: 16,
                    spreadRadius: 2,
                  )
                else
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
              ],
            ),
            child: Center(child: widget.child),
          ),
        ),
      ),
    );
  }
}
