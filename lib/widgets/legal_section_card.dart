import 'package:flutter/material.dart';

import '../legal/privacy_policy_page.dart';
import '../legal/terms_of_use_page.dart';
import 'delete_account_flow.dart';

/// Opens a real, informational help dialog (no fake backend form).
void showReportProblemDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Report a problem'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'App or connection issues',
              style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Check your internet connection, update to the latest version of Smeet, '
              'and try again. If something still fails, note what you were doing when it happened.',
              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
            const SizedBox(height: 16),
            Text(
              'Account access',
              style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Use Log in / Sign up on Profile if you need to access your account. '
              'Forgotten-password flows depend on how you signed up (email link, Apple, etc.).',
              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
            const SizedBox(height: 16),
            Text(
              'Account deletion',
              style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'When signed in, use “Request account deletion” on Profile to submit a formal '
              'deletion request. You’ll get a reference number after submission.',
              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
            const SizedBox(height: 16),
            Text(
              'Other help',
              style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'For product support, use the contact information listed on the App Store '
              'or your organization’s website. This in-app screen does not send a ticket automatically.',
              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
}

/// Profile: **Legal & safety** — Terms, Privacy, help, and account deletion request.
///
/// [guestMode]: hide full deletion flow; tapping deletion explains that sign-in is required.
class LegalSectionCard extends StatelessWidget {
  const LegalSectionCard({super.key, this.guestMode = false});

  final bool guestMode;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.primary.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(
              'Legal & safety',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              'Legal',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface.withValues(alpha: 0.65),
                  ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.article_outlined, color: cs.primary),
            title: const Text('Terms of Use'),
            subtitle: Text(
              'How Smeet works and user responsibilities',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.62),
                  ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const TermsOfUsePage(),
                ),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.privacy_tip_outlined, color: cs.primary),
            title: const Text('Privacy Policy'),
            subtitle: Text(
              'How we handle your data',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.62),
                  ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PrivacyPolicyPage(),
                ),
              );
            },
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'Help & account',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface.withValues(alpha: 0.65),
                  ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.help_outline, color: cs.primary),
            title: const Text('Report a problem'),
            subtitle: Text(
              'Tips for app, account, and deletion requests',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.62),
                  ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showReportProblemDialog(context),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.delete_forever_outlined, color: cs.error),
            title: Text(
              'Request account deletion',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: cs.error,
              ),
            ),
            subtitle: Text(
              guestMode
                  ? 'Sign in to submit a formal deletion request'
                  : 'Submit a formal request (processed separately)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.65),
                  ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              if (guestMode) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Sign in to request account deletion from your profile.',
                    ),
                  ),
                );
                return;
              }
              showDeleteAccountFlow(context);
            },
          ),
        ],
      ),
    );
  }
}
