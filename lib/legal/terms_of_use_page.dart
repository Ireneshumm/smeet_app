import 'package:flutter/material.dart';

import 'legal_document_page.dart';
import 'placeholder_legal_copy.dart';

class TermsOfUsePage extends StatelessWidget {
  const TermsOfUsePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalDocumentPage(
      title: 'Terms of Use',
      intro: kTermsOfUseIntro,
      sections: kTermsOfUseSections,
    );
  }
}
