import 'package:flutter/material.dart';

import '../legal/privacy_policy_page.dart';
import '../legal/terms_of_use_page.dart';

/// Checkbox + tappable Terms / Privacy links for the sign-up flow only.
class SignupLegalAgreement extends StatelessWidget {
  const SignupLegalAgreement({
    super.key,
    required this.accepted,
    required this.loading,
    required this.onChanged,
  });

  final bool accepted;
  final bool loading;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final baseStyle = Theme.of(context).textTheme.bodySmall!.copyWith(
          height: 1.38,
          color: cs.onSurface,
        );
    final linkStyle = baseStyle.copyWith(
      color: cs.primary,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: accepted,
          onChanged: loading ? null : onChanged,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 6,
              children: [
                Text('I agree to the ', style: baseStyle),
                InkWell(
                  onTap: loading
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const TermsOfUsePage(),
                            ),
                          );
                        },
                  child: Text('Terms of Use', style: linkStyle),
                ),
                Text(' and ', style: baseStyle),
                InkWell(
                  onTap: loading
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const PrivacyPolicyPage(),
                            ),
                          );
                        },
                  child: Text('Privacy Policy', style: linkStyle),
                ),
                Text('.', style: baseStyle),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
