import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OtherProfilePage extends StatelessWidget {
  final String userId;

  const OtherProfilePage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: Supabase.instance.client
            .from('profiles')
            .select(
              'display_name, city, intro, avatar_url, sport_levels, availability',
            )
            .eq('id', userId)
            .maybeSingle(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final p = snap.data;
          if (p == null) {
            return const Center(child: Text('Profile not found'));
          }

          final name = (p['display_name'] ?? '').toString();
          final city = (p['city'] ?? '').toString();
          final intro = (p['intro'] ?? '').toString();
          final avatar = (p['avatar_url'] ?? '').toString();
          final sportLevels = p['sport_levels'] as Map? ?? {};

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: cs.primary.withOpacity(0.15),
                  backgroundImage:
                      avatar.isEmpty ? null : NetworkImage(avatar),
                  child: avatar.isEmpty
                      ? Icon(Icons.person, size: 40, color: cs.primary)
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  name.isEmpty ? 'Unnamed' : name,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                if (city.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(city),
                ],
                if (intro.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(intro),
                ],
                const SizedBox(height: 16),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Sports',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 8),
                if (sportLevels.isEmpty)
                  const Text('No sports info')
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: sportLevels.entries.map<Widget>((e) {
                      return Chip(
                        label: Text('${e.key}: ${e.value}'),
                      );
                    }).toList(),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
