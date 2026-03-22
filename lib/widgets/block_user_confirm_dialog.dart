import 'package:flutter/material.dart';

/// Confirms blocking another user before calling [BlockService.blockUser].
Future<bool> showBlockUserConfirmDialog(
  BuildContext context, {
  required String displayName,
}) async {
  final name = displayName.trim().isEmpty ? 'this player' : displayName.trim();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Block player?'),
      content: Text(
        '$name won’t be able to interact with you on Smeet the same way, '
        'and you won’t see them in swipe or your chat list while the block is active. '
        'You can unblock later from their profile.',
        style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(height: 1.45),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Block'),
        ),
      ],
    ),
  );
  return ok == true;
}
