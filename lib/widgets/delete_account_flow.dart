import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:smeet_app/services/account_deletion_service.dart';

const String _kDeleteConfirmWord = 'DELETE';

/// **Account deletion request** workflow (not immediate deletion):
/// 1. Block if an active request already exists (show reference).
/// 2. Explain the request → user types DELETE.
/// 3. Record row in `account_deletion_requests` → show confirmation with **request reference** → sign out.
Future<void> showDeleteAccountFlow(BuildContext context) async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sign in to manage your account.')),
    );
    return;
  }

  final active = await AccountDeletionService.fetchActiveDeletionRequest();
  if (!context.mounted) return;

  if (active != null) {
    final ref = AccountDeletionService.formatRequestReference(active.requestId);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Deletion request in progress'),
        content: SingleChildScrollView(
          child: Text(
            'You already have an active account deletion request.\n\n'
            'Reference: $ref\n'
            'Status: ${active.status}\n\n'
            'Our team will process it — you don’t need to submit again. '
            'If this wasn’t you, contact support with your reference.',
            style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return;
  }

  final goAhead = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Request account deletion'),
      content: SingleChildScrollView(
        child: Text(
          'You are about to submit a formal request to delete your Smeet account '
          'and associated data, as described in our Privacy Policy.\n\n'
          '• Your account is not removed instantly — this records your request for processing.\n'
          '• After we save your request, you will be signed out.\n'
          '• You will receive a reference number to keep for your records.\n\n'
          'Do you want to continue?',
          style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(height: 1.45),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(ctx).colorScheme.error,
            foregroundColor: Theme.of(ctx).colorScheme.onError,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Continue'),
        ),
      ],
    ),
  );

  if (goAhead != true || !context.mounted) return;

  final typed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const _TypeDeleteDialog(),
  );

  if (typed != true || !context.mounted) return;

  final messenger = ScaffoldMessenger.maybeOf(context);
  final nav = Navigator.of(context, rootNavigator: true);

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const _DeletingDialog(),
  );

  try {
    final submission = await AccountDeletionService.submitDeletionRequest();

    if (submission.isAlreadyActive) {
      if (nav.canPop()) {
        nav.pop();
      }
      final ref = AccountDeletionService.formatRequestReference(
        submission.requestId,
      );
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            'A deletion request is already on file (ref. $ref).',
          ),
        ),
      );
      return;
    }

    final ref = AccountDeletionService.formatRequestReference(
      submission.requestId,
    );

    if (nav.canPop()) {
      nav.pop();
    }

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Request received'),
        content: SingleChildScrollView(
          child: Text(
            'Your account deletion request has been recorded.\n\n'
            'Reference: $ref\n'
            '(Full ID: ${submission.requestId ?? '—'})\n\n'
            'Keep this reference if you contact support. '
            'Processing happens on our servers — you will be signed out now.',
            style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 200));
    await Supabase.instance.client.auth.signOut();
  } on AccountDeletionException catch (e) {
    if (nav.canPop()) {
      nav.pop();
    }
    messenger?.showSnackBar(SnackBar(content: Text(e.userMessage)));
  } catch (e) {
    if (nav.canPop()) {
      nav.pop();
    }
    debugPrint('[DeleteAccount] $e');
    messenger?.showSnackBar(
      const SnackBar(
        content: Text('Something went wrong. Please try again.'),
      ),
    );
  }
}


class _TypeDeleteDialog extends StatefulWidget {
  const _TypeDeleteDialog();

  @override
  State<_TypeDeleteDialog> createState() => _TypeDeleteDialogState();
}

class _TypeDeleteDialogState extends State<_TypeDeleteDialog> {
  final _ctrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_ctrl.text.trim() == _kDeleteConfirmWord) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _error = 'Type the word $_kDeleteConfirmWord exactly to confirm.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Confirm your request'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'To submit your deletion request, type $_kDeleteConfirmWord in capital letters.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _ctrl,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Confirmation',
                errorText: _error,
                border: const OutlineInputBorder(),
                hintText: _kDeleteConfirmWord,
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: cs.error,
            foregroundColor: cs.onError,
          ),
          onPressed: _submit,
          child: const Text('Submit request'),
        ),
      ],
    );
  }
}

class _DeletingDialog extends StatelessWidget {
  const _DeletingDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Row(
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Text(
              'Recording your deletion request…',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}
