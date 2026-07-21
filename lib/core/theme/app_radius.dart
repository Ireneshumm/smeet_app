import 'package:flutter/widgets.dart';

/// Corner-radius scale (logical pixels).
///
/// Keeps cards, sheets, chips and buttons on a consistent rounding system.
abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;

  /// Default card radius (matches the app [CardTheme]).
  static const double lg = 18;

  /// Sheets, hero media, large surfaces.
  static const double xl = 24;

  /// Fully rounded (pills, avatars, stadium buttons).
  static const double pill = 999;

  static BorderRadius get smAll => BorderRadius.circular(sm);
  static BorderRadius get mdAll => BorderRadius.circular(md);
  static BorderRadius get lgAll => BorderRadius.circular(lg);
  static BorderRadius get xlAll => BorderRadius.circular(xl);
}
