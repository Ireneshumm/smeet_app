import 'package:flutter/material.dart';

/// Single source of truth for Smeet brand colors.
///
/// These were previously declared as `SmeetApp.smeetXxx` static constants in
/// `app/smeet_app.dart`. That class keeps those names as aliases onto these
/// tokens, so existing call sites (`SmeetApp.smeetMint`, …) keep working while
/// new code can reference [AppColors] directly.
abstract final class AppColors {
  // Core brand palette (derived from the logo).
  static const Color mint = Color(0xFF56CDBE);
  static const Color deep = Color(0xFF0B8F85);
  static const Color ink = Color(0xFF0F2D2A);

  /// Warm off-white app canvas (抖音/小红书式暖白底).
  static const Color canvas = Color(0xFFF8F7F4);
  static const Color navBorder = Color(0xFFF0EEE8);

  static const Color mintLight = Color(0xFFDCFFF1);
  static const Color mintFaint = Color(0xFFFAFCFB);
  static const Color grey = Color(0xFF6E7874);
  static const Color greyLight = Color(0xFFE5F4EE);
  static const Color coral = Color(0xFFE07A5F);
  static const Color coralLight = Color(0xFFFFE5DC);
  static const Color indigo = Color(0xFF5B6CFF);
  static const Color indigoLight = Color(0xFFE8E9FF);
}
