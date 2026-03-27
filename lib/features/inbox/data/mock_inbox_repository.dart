import 'package:smeet_app/features/inbox/models/chat_list_item.dart';

/// Mock inbox threads per tab; replace with real queries later.
class MockInboxRepository {
  MockInboxRepository();

  Future<List<ChatListItem>> fetchForTab(
    InboxTabKind kind, {
    Duration delay = const Duration(milliseconds: 240),
  }) async {
    await Future<void>.delayed(delay);
    switch (kind) {
      case InboxTabKind.matches:
        return List<ChatListItem>.unmodifiable(_matches);
      case InboxTabKind.gameChats:
        return List<ChatListItem>.unmodifiable(_gameChats);
      case InboxTabKind.dms:
        return List<ChatListItem>.unmodifiable(_dms);
    }
  }

  static final List<ChatListItem> _matches = <ChatListItem>[
    ChatListItem(
      id: 'mock-match-1',
      kind: InboxTabKind.matches,
      title: 'Alex · You both liked Pickleball',
      lastMessage: 'Want to hit courts Saturday morning?',
      updatedAt: DateTime.utc(2026, 3, 25, 18, 5),
      unreadCount: 2,
    ),
    ChatListItem(
      id: 'mock-match-2',
      kind: InboxTabKind.matches,
      title: 'Jordan · Tennis match',
      lastMessage: 'I can do 6pm at Riverside.',
      updatedAt: DateTime.utc(2026, 3, 24, 22, 40),
      unreadCount: 0,
    ),
    ChatListItem(
      id: 'mock-match-3',
      kind: InboxTabKind.matches,
      title: 'Sam · New connection',
      lastMessage: 'Hey! Saw you in the ladder chat.',
      updatedAt: DateTime.utc(2026, 3, 23, 9, 12),
      unreadCount: 1,
    ),
  ];

  static final List<ChatListItem> _gameChats = <ChatListItem>[
    ChatListItem(
      id: 'mock-gc-1',
      kind: InboxTabKind.gameChats,
      title: 'Open play · Sat 10am (Group)',
      lastMessage: 'Organizer: Court 3 is reserved.',
      updatedAt: DateTime.utc(2026, 3, 25, 15, 30),
      unreadCount: 5,
    ),
    ChatListItem(
      id: 'mock-gc-2',
      kind: InboxTabKind.gameChats,
      title: 'Doubles mixer · Sun 6pm',
      lastMessage: 'You: I’ll bring balls 👍',
      updatedAt: DateTime.utc(2026, 3, 25, 12, 0),
      unreadCount: 0,
    ),
    ChatListItem(
      id: 'mock-gc-3',
      kind: InboxTabKind.gameChats,
      title: 'Ladder Week 4',
      lastMessage: 'Bracket updated — check match #7.',
      updatedAt: DateTime.utc(2026, 3, 22, 8, 15),
      unreadCount: 3,
    ),
  ];

  static final List<ChatListItem> _dms = <ChatListItem>[
    ChatListItem(
      id: 'mock-dm-1',
      kind: InboxTabKind.dms,
      title: 'Coach Rivera',
      lastMessage: 'Footwork video attached (mock).',
      updatedAt: DateTime.utc(2026, 3, 25, 19, 45),
      unreadCount: 1,
    ),
    ChatListItem(
      id: 'mock-dm-2',
      kind: InboxTabKind.dms,
      title: 'Facility desk',
      lastMessage: 'Your court booking is confirmed.',
      updatedAt: DateTime.utc(2026, 3, 21, 14, 20),
      unreadCount: 0,
    ),
    ChatListItem(
      id: 'mock-dm-3',
      kind: InboxTabKind.dms,
      title: 'Taylor',
      lastMessage: 'Rain check on Tuesday?',
      updatedAt: DateTime.utc(2026, 3, 20, 21, 3),
      unreadCount: 12,
    ),
  ];
}
