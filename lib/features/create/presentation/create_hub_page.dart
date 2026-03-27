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
      appBar: AppBar(title: const Text('Create')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
              child: Text(
                'Add something new to your profile, or start the same game flow as Home.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.sticky_note_2_outlined),
                title: const Text('Text note'),
                subtitle: const Text('A short written update on your profile'),
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
                title: const Text('Video'),
                subtitle: const Text('One gallery clip on your profile (up to 30s)'),
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
                title: const Text('Create game'),
                subtitle: const Text('Same flow as creating a game from Home'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  final open = onOpenLegacyCreateGame;
                  if (open != null) {
                    open();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Game creation isn’t available from this screen in this build.',
                        ),
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
