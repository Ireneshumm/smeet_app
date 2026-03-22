// Placeholder legal copy for Smeet — replace with counsel-approved text before launch.
// Sections are intentionally structured for easy substitution.

/// Single block in a legal document (heading optional for short intros).
class LegalCopyBlock {
  const LegalCopyBlock({this.heading, required this.body});

  final String? heading;
  final String body;
}

const String kTermsOfUseIntro =
    'These Terms of Use (“Terms”) govern your access to and use of the Smeet mobile '
    'application and related services (“Smeet”). By creating an account or using Smeet, '
    'you agree to these Terms.\n\n'
    'Smeet helps people discover sports games and connect with other players. You are '
    'responsible for your conduct and for any content you submit.';

const List<LegalCopyBlock> kTermsOfUseSections = [
  LegalCopyBlock(
    heading: '1. Eligibility & accounts',
    body:
        'You must provide accurate registration information and safeguard your login '
        'credentials. You are responsible for activity under your account.',
  ),
  LegalCopyBlock(
    heading: '2. User conduct',
    body:
        'You agree not to harass, abuse, spam, impersonate others, or post unlawful or '
        'harmful content. We may suspend or terminate accounts that violate these Terms '
        'or threaten community safety.',
  ),
  LegalCopyBlock(
    heading: '3. Content',
    body:
        'You retain rights to content you submit, but grant Smeet a license to host, '
        'display, and distribute that content as needed to operate the service. Do not '
        'upload content you do not have the right to share.',
  ),
  LegalCopyBlock(
    heading: '4. Disclaimers',
    body:
        'Smeet is provided “as is.” We do not guarantee uninterrupted or error-free '
        'service. Organizers and participants are responsible for real-world meetups and '
        'safety.',
  ),
  LegalCopyBlock(
    heading: '5. Changes',
    body:
        'We may update these Terms. Continued use after changes constitutes acceptance of '
        'the revised Terms. Material changes will be communicated in-app where appropriate.',
  ),
  LegalCopyBlock(
    heading: '6. Contact',
    body:
        'Questions about these Terms? Contact us through the in-app support or legal '
        'contact channel provided in the app store listing.\n\n'
        '[Replace this section with your official contact details.]',
  ),
];

const String kPrivacyPolicyIntro =
    'This Privacy Policy explains how Smeet (“we,” “us”) collects, uses, and shares '
    'information when you use our app and services.\n\n'
    'By using Smeet, you agree to this policy. If you do not agree, please do not use the '
    'service.';

const List<LegalCopyBlock> kPrivacyPolicySections = [
  LegalCopyBlock(
    heading: '1. Information we collect',
    body:
        '• Account information: email address and profile details you choose to provide '
        '(e.g. display name, city, sports preferences).\n'
        '• Content: photos, posts, messages, and other materials you submit.\n'
        '• Usage & device data: approximate location if you enable location features, '
        'diagnostics, and technical logs needed to operate and secure the service.\n\n'
        '[Adjust this list to match your actual data practices.]',
  ),
  LegalCopyBlock(
    heading: '2. How we use information',
    body:
        'We use information to provide and improve Smeet, personalize your experience, '
        'facilitate games and chat, send service-related notices, enforce our policies, '
        'and comply with law.',
  ),
  LegalCopyBlock(
    heading: '3. Sharing',
    body:
        'We may share information with service providers who assist us (e.g. hosting, '
        'analytics) under strict terms, when required by law, or to protect rights and '
        'safety. We do not sell your personal information.',
  ),
  LegalCopyBlock(
    heading: '4. Retention',
    body:
        'We retain information as long as your account is active or as needed to provide '
        'the service, comply with legal obligations, resolve disputes, and enforce our '
        'agreements.',
  ),
  LegalCopyBlock(
    heading: '5. Your choices',
    body:
        'You may update profile information in the app where supported. You can request '
        'account deletion as described in the app (subject to backend processing). '
        'Location access can be controlled through your device settings.',
  ),
  LegalCopyBlock(
    heading: '6. Children',
    body:
        'Smeet is not directed at children under the age required by your region. Do not '
        'use the service if you are not old enough to consent to data processing where you '
        'live.',
  ),
  LegalCopyBlock(
    heading: '7. International users',
    body:
        'If you use Smeet from outside your home country, your information may be '
        'transferred to and processed in countries where we or our providers operate.',
  ),
  LegalCopyBlock(
    heading: '8. Contact',
    body:
        'For privacy questions or requests, contact us at the address or email provided '
        'in the app store listing.\n\n'
        '[Replace with your privacy contact.]',
  ),
];
