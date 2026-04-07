import 'package:flutter/material.dart';

/// Shared loading UI for tab pages (Material 3 friendly, minimal).
class AppLoadingState extends StatelessWidget {
  const AppLoadingState({
    super.key,
    required this.message,
    this.padding = const EdgeInsets.all(24),
  });

  final String message;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty list / no data — icon, title, optional subtitle and action.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: cs.primary.withValues(alpha: 0.65)),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      color: cs.onSurface.withValues(alpha: 0.55),
                    ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Recoverable failure — no raw exception strings in [message] (reviewer-safe).
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.message,
    this.detail,
    this.onRetry,
    this.retryLabel = 'Retry',
  });

  final String message;
  final String? detail;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 52,
              color: cs.error.withValues(alpha: 0.88),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            if (detail != null && detail!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.65),
                    ),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 18),
              FilledButton.tonal(
                onPressed: onRetry,
                child: Text(retryLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
