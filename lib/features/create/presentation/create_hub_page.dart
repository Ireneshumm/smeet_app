import 'package:flutter/material.dart';

import 'package:smeet_app/features/create/presentation/create_note_page.dart';
import 'package:smeet_app/features/create/presentation/create_video_page.dart';

/// Entry hub for create flows (MVP). Does not replace the legacy Home create form.
///
/// [onOpenLegacyCreateGame] is injected from [main.dart] so this module never
/// imports `package:smeet_app/main.dart` (avoids circular imports).
class CreateHubPage extends StatelessWidget {
  const CreateHubPage({
    super.key,
    this.onOpenLegacyCreateGame,
  });

  /// Opens the existing Create Game experience (full [HomePage] pushed as a route).
  final VoidCallback? onOpenLegacyCreateGame;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create (MVP)')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.sticky_note_2_outlined),
                title: const Text('Post Note'),
                subtitle: const Text('Text-only → saves to your posts'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (context) => const CreateNotePage(),
                    ),
                  );
                },
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.video_library_outlined),
                title: const Text('Upload Video'),
                subtitle: const Text('Single gallery video → posts'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (context) => const CreateVideoPage(),
                    ),
                  );
                },
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.sports_tennis),
                title: const Text('Create Game'),
                subtitle: const Text('Legacy flow (same as Home tab)'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  final open = onOpenLegacyCreateGame;
                  if (open != null) {
                    open();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Create Game bridge not wired for this route.'),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
