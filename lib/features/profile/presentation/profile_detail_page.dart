import 'package:flutter/material.dart';

import 'package:smeet_app/features/profile/models/profile_tab_item.dart';
import 'package:smeet_app/core/theme/theme.dart';

class ProfileMvpDetailPage extends StatelessWidget {
  const ProfileMvpDetailPage({super.key, required this.item});

  final ProfileTabItem item;

  static String _tabLabel(ProfileContentTab t) {
    switch (t) {
      case ProfileContentTab.posts:
        return 'Posts';
      case ProfileContentTab.hosted:
        return 'Hosted';
      case ProfileContentTab.joined:
        return 'Joined';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(_tabLabel(item.tab))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              item.title,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(item.subtitle, style: theme.textTheme.bodyLarge),
            const SizedBox(height: AppSpacing.md),
            Text('id: ${item.id}', style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Placeholder — not connected to legacy Profile or Supabase.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
