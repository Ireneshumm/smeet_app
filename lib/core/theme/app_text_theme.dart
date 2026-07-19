import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Builds the full Smeet [TextTheme] ramp.
///
/// Previously only `displaySmall / titleLarge / titleMedium / bodyLarge /
/// bodySmall` were defined; every other style (`bodyMedium`, `titleSmall`,
/// `labelSmall`, headlines…) silently fell back to Material defaults, which is
/// why type looked inconsistent across screens. This defines the whole ramp on
/// one scale and brand ink color.
///
/// The five previously-defined styles keep their exact values so existing
/// screens are visually unchanged; the rest are filled in coherently.
TextTheme buildSmeetTextTheme() {
  return Typography.blackMountainView.copyWith(
    // ---- Display (big hero numbers / splash) ----
    displayLarge: const TextStyle(
      fontSize: 34,
      fontWeight: FontWeight.w800,
      height: 1.15,
      color: AppColors.ink,
    ),
    displayMedium: const TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w800,
      height: 1.15,
      color: AppColors.ink,
    ),
    // Unchanged (was already defined).
    displaySmall: const TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w800,
      height: 1.2,
      color: AppColors.ink,
    ),

    // ---- Headline (screen / section titles) ----
    headlineLarge: const TextStyle(
      fontSize: 26,
      fontWeight: FontWeight.w800,
      height: 1.2,
      color: AppColors.ink,
    ),
    headlineMedium: const TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w800,
      height: 1.25,
      color: AppColors.ink,
    ),
    headlineSmall: const TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      height: 1.25,
      color: AppColors.ink,
    ),

    // ---- Title ----
    // Unchanged (was already defined).
    titleLarge: const TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w800,
      height: 1.25,
      color: AppColors.ink,
    ),
    // Unchanged (was already defined).
    titleMedium: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      height: 1.3,
      color: AppColors.ink,
    ),
    titleSmall: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 1.3,
      color: AppColors.ink,
    ),

    // ---- Body ----
    // Unchanged (was already defined).
    bodyLarge: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.4,
      color: AppColors.ink,
    ),
    bodyMedium: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.4,
      color: AppColors.ink,
    ),
    // Unchanged (was already defined).
    bodySmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.35,
      color: AppColors.ink.withValues(alpha: 0.55),
    ),

    // ---- Label (buttons, chips, meta) ----
    labelLarge: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 1.2,
      color: AppColors.ink,
    ),
    labelMedium: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      height: 1.2,
      color: AppColors.ink,
    ),
    // 11 is the accessibility floor for incidental meta labels.
    labelSmall: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      height: 1.2,
      color: AppColors.ink,
    ),
  );
}
