import 'package:flutter/material.dart';

/// Slot urgency from [players] capacity and [joinedCount].
Widget? buildGameUrgencyChip({
  required int players,
  required int joinedCount,
  required ColorScheme cs,
}) {
  if (players <= 0) return null;
  final remaining = players - joinedCount;
  if (remaining <= 0) return null;

  String label;
  Color bg;
  Color fg;
  if (remaining == 1) {
    label = 'Last spot';
    bg = cs.errorContainer;
    fg = cs.onErrorContainer;
  } else if (remaining == 2) {
    label = 'Almost full';
    bg = cs.tertiaryContainer;
    fg = cs.onTertiaryContainer;
  } else {
    return null;
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: fg,
      ),
    ),
  );
}
