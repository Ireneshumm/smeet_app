import 'package:flutter/material.dart';

import 'package:smeet_app/core/theme/theme.dart';

/// Compact entry point to "AI find players" (shown above the Swipe deck).
class AiFindPlayersBanner extends StatelessWidget {
  const AiFindPlayersBanner({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: AppColors.indigoLight,
      borderRadius: AppRadius.mdAll,
      child: InkWell(
        borderRadius: AppRadius.mdAll,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                color: AppColors.indigo,
                size: AppIconSize.sm,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'AI Find Players — just say who you’re looking for',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.indigo),
            ],
          ),
        ),
      ),
    );
  }
}
