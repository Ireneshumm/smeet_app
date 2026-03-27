import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:smeet_app/features/inbox/models/chat_list_item.dart';

class InboxDetailPage extends StatelessWidget {
  const InboxDetailPage({super.key, required this.item});

  final ChatListItem item;

  static String _kindLabel(InboxTabKind k) {
    switch (k) {
      case InboxTabKind.matches:
        return 'Matches';
      case InboxTabKind.gameChats:
        return 'Game Chats';
      case InboxTabKind.dms:
        return 'DMs';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final when = DateFormat.yMMMd().add_jm().format(item.updatedAt.toLocal());

    return Scaffold(
      appBar: AppBar(
        title: Text(_kindLabel(item.kind)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              item.title,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text('Last: ${item.lastMessage}', style: theme.textTheme.bodyLarge),
            const SizedBox(height: 8),
            Text('Updated: $when', style: theme.textTheme.bodySmall),
            Text('Unread (mock): ${item.unreadCount}', style: theme.textTheme.bodySmall),
            Text('id: ${item.id}', style: theme.textTheme.bodySmall),
            const SizedBox(height: 28),
            Text(
              'Placeholder — not connected to Chat tab or Supabase.',
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
