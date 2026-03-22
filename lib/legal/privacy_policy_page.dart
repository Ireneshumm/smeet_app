import 'package:flutter/material.dart';

import 'legal_document_page.dart';
import 'placeholder_legal_copy.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalDocumentPage(
      title: 'Privacy Policy',
      intro: kPrivacyPolicyIntro,
      sections: kPrivacyPolicySections,
    );
  }
}
