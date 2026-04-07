// Legal copy for in-app Terms & Privacy (review with counsel before wide distribution).

/// Single block in a legal document (heading optional for short intros).
class LegalCopyBlock {
  const LegalCopyBlock({this.heading, required this.body});

  final String? heading;
  final String body;
}

/// Shown at the top of Terms and Privacy screens (fixed string; avoids rebuild drift).
const String kLegalDocumentsLastUpdated = 'March 30, 2026';

const String kTermsOfUseIntro =
    'These Terms of Use (“Terms”) govern your access to and use of the Smeet mobile '
    'application and related services (“Smeet,” “we,” “us”). By creating an account or '
    'using Smeet, you agree to these Terms.\n\n'
    'Smeet helps you discover sports games and connect with other players. You are '
    'responsible for your conduct, your safety in the real world, and any content you submit.';

const List<LegalCopyBlock> kTermsOfUseSections = [
  LegalCopyBlock(
    heading: '1. Eligibility and accounts',
    body:
        'You must meet the minimum age and eligibility requirements for your region. You '
        'agree to provide accurate registration information and to keep your login '
        'credentials secure. You are responsible for all activity that occurs under your '
        'account.',
  ),
  LegalCopyBlock(
    heading: '2. Acceptable use',
    body:
        'You agree to use Smeet only for lawful, respectful purposes. Without limitation, '
        'you must not: harass, threaten, stalk, discriminate against, or harm others; '
        'impersonate any person or entity; spam or scrape the service; upload malware or '
        'attempt to disrupt or gain unauthorized access to Smeet, other users, or our '
        'systems; post unlawful, fraudulent, obscene, hateful, or violent content; or use '
        'the service to arrange illegal activity. We may investigate violations and cooperate '
        'with law enforcement when appropriate.',
  ),
  LegalCopyBlock(
    heading: '3. Content and license',
    body:
        'You retain ownership of content you submit, but you grant Smeet a worldwide, '
        'non-exclusive license to host, store, reproduce, display, and distribute your '
        'content as needed to operate, promote, and improve the service. Do not upload '
        'content you do not have the right to share.',
  ),
  LegalCopyBlock(
    heading: '4. Account suspension and termination',
    body:
        'We may suspend or terminate your access to Smeet, with or without notice, if we '
        'reasonably believe you have violated these Terms, pose a risk to the community or '
        'our operations, or must do so for legal or security reasons. You may stop using '
        'Smeet at any time. Where the app offers account deletion, you may use that flow; '
        'some information may be retained as described in our Privacy Policy and as '
        'required by law. Provisions that should survive termination (including ownership, '
        'disclaimers, and limits of liability where allowed) will survive.',
  ),
  LegalCopyBlock(
    heading: '5. Disclaimers',
    body:
        'Smeet is provided on an “as is” and “as available” basis. We do not warrant '
        'uninterrupted or error-free service. Games and meetups are organized by users; '
        'you participate at your own risk. We are not responsible for injuries, losses, '
        'or disputes between users offline.',
  ),
  LegalCopyBlock(
    heading: '6. Dispute resolution',
    body:
        'We encourage you to contact us first to resolve concerns informally. If a dispute '
        'cannot be resolved that way, you and Smeet agree to seek resolution in accordance '
        'with applicable law. Mandatory consumer rights in your country of residence '
        'apply where they cannot lawfully be waived. Where permitted, you agree that the '
        'courts of general jurisdiction in the location of Smeet’s operating entity have '
        'exclusive jurisdiction, except that Apple is not a party to disputes between you '
        'and Smeet; your use of the app may also be subject to the Apple Media Services '
        'Terms and the Licensed Application End User License Agreement where applicable.',
  ),
  LegalCopyBlock(
    heading: '7. Changes to these Terms',
    body:
        'We may update these Terms from time to time. We will post the updated Terms in '
        'the app and may update the “last updated” date. Continued use after changes '
        'take effect constitutes acceptance of the revised Terms, except where '
        'additional consent is required by law.',
  ),
  LegalCopyBlock(
    heading: '8. Contact',
    body:
        'For questions about these Terms, contact us using the support or legal contact '
        'information shown on the Smeet product page on the App Store, or through any '
        'in-app support or feedback option we provide.',
  ),
];

const String kPrivacyPolicyIntro =
    'This Privacy Policy describes how Smeet (“we,” “us”) collects, uses, stores, and '
    'shares information when you use our mobile application and related services.\n\n'
    'By using Smeet, you acknowledge this policy. If you do not agree, please do not use '
    'the service.';

const List<LegalCopyBlock> kPrivacyPolicySections = [
  LegalCopyBlock(
    heading: '1. Information we collect',
    body:
        'We may collect the following categories of information, depending on how you use Smeet:\n\n'
        '• Account and profile: email address, display name, profile photo, city or '
        'region, sports preferences, skill levels, and similar fields you choose to provide.\n'
        '• Content you create: posts, photos, videos, messages, game listings, and other '
        'materials you upload or send.\n'
        '• Activity and device data: app usage, diagnostics, crash data, IP address, '
        'device identifiers, and approximate or precise location if you grant location '
        'permission (e.g. to show nearby games or venues).\n'
        '• Communications: support requests and feedback you send to us.\n\n'
        'We collect only what is reasonably needed to provide and improve the service, '
        'unless we tell you otherwise or the law requires more.',
  ),
  LegalCopyBlock(
    heading: '2. How we use information',
    body:
        'We use the information above to: create and manage your account; show your '
        'profile and content to other users as designed; match you with games and people; '
        'operate chat and notifications; personalize your experience; maintain security, '
        'prevent fraud and abuse; troubleshoot and improve the app; send service-related '
        'messages; comply with legal obligations; and enforce our Terms and policies.',
  ),
  LegalCopyBlock(
    heading: '3. How we share information',
    body:
        'We may share information: with other users as part of normal app features (e.g. '
        'your profile in discovery or a game roster); with service providers who host data, '
        'send push notifications, or help us operate the product, under confidentiality '
        'and security obligations; when required by law, legal process, or government '
        'requests; to protect the rights, safety, and security of users and Smeet; and in '
        'connection with a merger, acquisition, or sale of assets, subject to this policy. '
        'We do not sell your personal information for money.',
  ),
  LegalCopyBlock(
    heading: '4. Retention',
    body:
        'We keep information for as long as your account is active and as needed to '
        'provide the service, comply with law, resolve disputes, and enforce our '
        'agreements. When you delete your account where offered, we will delete or '
        'anonymize your information within a reasonable time unless we must retain '
        'specific data for legal or legitimate business reasons.',
  ),
  LegalCopyBlock(
    heading: '5. Your choices and rights',
    body:
        'You may update certain profile fields in the app. You can control location '
        'sharing through your device settings. Depending on where you live, you may have '
        'rights to access, correct, delete, or export personal data, or to object to or '
        'restrict certain processing. To exercise these rights, contact us using the '
        'details in Section 8. You may opt out of non-essential notifications in device or '
        'app settings where available.',
  ),
  LegalCopyBlock(
    heading: '6. Children',
    body:
        'Smeet is not intended for children under the age required in your jurisdiction to '
        'consent to data processing without parental permission. Do not use the service if '
        'you do not meet that age requirement.',
  ),
  LegalCopyBlock(
    heading: '7. International users',
    body:
        'If you use Smeet from outside the country where our servers or providers are '
        'located, your information may be transferred to and processed in other countries. '
        'We take steps designed to protect your information in line with this policy and '
        'applicable law.',
  ),
  LegalCopyBlock(
    heading: '8. How to contact us',
    body:
        'For privacy questions, complaints, or requests (including access or deletion '
        'where applicable), contact us using the support email or contact information '
        'listed on the Smeet page on the App Store, or through any in-app support channel '
        'we make available. We will respond in line with applicable law.',
  ),
];
