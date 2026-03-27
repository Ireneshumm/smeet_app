import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:smeet_app/core/formatting/chat_row_unread_label.dart';
import 'package:smeet_app/core/notifiers/smeet_open_chat_room_notifier.dart';
import 'package:smeet_app/core/services/chat_conversation_list_service.dart';
import 'package:smeet_app/features/inbox/data/supabase_dms_inbox_repository.dart';
import 'package:smeet_app/features/inbox/data/supabase_game_chats_inbox_repository.dart';
import 'package:smeet_app/features/inbox/data/supabase_matches_inbox_repository.dart';
import 'package:smeet_app/features/inbox/models/chat_list_item.dart';
import 'package:smeet_app/features/inbox/models/matched_profile_row.dart';
import 'package:smeet_app/features/inbox/presentation/inbox_detail_page.dart';
import 'package:smeet_app/widgets/app_page_states.dart';

/// Opens a real chat room from a **Game Chats** or **DMs** row (implemented in app layer).
typedef InboxOpenChatCallback =
    Future<void> Function(BuildContext context, ChatListItem item);

/// Same contract as legacy [ChatPage] login gating (`_ensureLoginAndPrompt` in `main.dart`).
typedef InboxEnsureLoggedInCallback =
    Future<bool> Function(BuildContext context);

/// Inbox MVP: **Matches** = live mutual matches (relationship list); **Game Chats** + **DMs** live via Supabase.
class InboxPage extends StatefulWidget {
  const InboxPage({
    super.key,
    this.matchesRepository,
    this.gameChatsRepository,
    this.dmsRepository,
    this.onOpenChat,
    this.onEnsureLoggedIn,
    this.onAfterLiveChatClosed,
    this.onAfterInboxRealtimeRefresh,
  });

  /// When null, uses [SupabaseMatchesInboxRepository] with default Supabase client.
  final SupabaseMatchesInboxRepository? matchesRepository;

  /// When null, uses [SupabaseGameChatsInboxRepository] with default Supabase client.
  final SupabaseGameChatsInboxRepository? gameChatsRepository;

  /// When null, uses [SupabaseDmsInboxRepository] with default Supabase client.
  final SupabaseDmsInboxRepository? dmsRepository;

  /// When non-null, live tabs push a real room via this callback (e.g. [ChatRoomPage]).
  final InboxOpenChatCallback? onOpenChat;

  /// When non-null, used for signed-out live UI and before opening a live thread.
  final InboxEnsureLoggedInCallback? onEnsureLoggedIn;

  /// Optional nudge after closing a live chat (e.g. refresh legacy [ChatPage] list snapshot).
  final VoidCallback? onAfterLiveChatClosed;

  /// After Inbox **manual pull-to-refresh** ([RefreshIndicator]) succeeds only — e.g. [SmeetShell.requestChatInboxRefresh].
  /// Not invoked after realtime debounce refetch, error retry, or post-chat list refresh.
  /// Parameter name is historical (`Realtime`).
  final VoidCallback? onAfterInboxRealtimeRefresh;

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage>
    with SingleTickerProviderStateMixin {
  /// TabBar order: Matches, Game Chats, DMs.
  static const int _kTabMatches = 0;
  static const int _kTabGameChats = 1;
  static const int _kTabDms = 2;

  late final SupabaseMatchesInboxRepository _matchesRepo =
      widget.matchesRepository ?? SupabaseMatchesInboxRepository();
  late final SupabaseGameChatsInboxRepository _gameChatsRepo =
      widget.gameChatsRepository ?? SupabaseGameChatsInboxRepository();
  late final SupabaseDmsInboxRepository _dmsRepo =
      widget.dmsRepository ?? SupabaseDmsInboxRepository();

  late final TabController _tabs = TabController(length: 3, vsync: this);

  final Map<InboxTabKind, Future<List<ChatListItem>>> _futures = {};
  final ChatConversationListService _chatList = ChatConversationListService();

  late Future<List<MatchedProfileRow>> _matchesFuture;

  /// Latest `chat_id` sets for realtime (strategy A: current live tab only).
  List<String> _lastGameChatIds = const [];
  List<String> _lastDmChatIds = const [];

  StreamSubscription<List<Map<String, dynamic>>>? _messagesRealtimeSub;
  Timer? _realtimeDebounce;
  List<String> _boundChatIds = const [];

  bool get _signedIn => Supabase.instance.client.auth.currentUser != null;

  @override
  void initState() {
    super.initState();
    _tabs.addListener(_onTabIndexChanged);
    _matchesFuture = _matchesRepo.fetchMatchRelationships();
    _futures[InboxTabKind.gameChats] = _gameChatsRepo.fetchGameChatItems();
    _futures[InboxTabKind.dms] = _dmsRepo.fetchDirectMessageItems();
    unawaited(_primeChatIdCachesThenSyncRealtime());
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabIndexChanged);
    _disposeMessagesRealtime();
    _realtimeDebounce?.cancel();
    _tabs.dispose();
    super.dispose();
  }

  void _onTabIndexChanged() {
    _syncRealtimeSubscriptionForCurrentTab();
  }

  /// Loads id caches from initial futures, then binds if a live tab is visible.
  Future<void> _primeChatIdCachesThenSyncRealtime() async {
    if (!_signedIn) return;
    try {
      final games = await _futures[InboxTabKind.gameChats]!;
      final dms = await _futures[InboxTabKind.dms]!;
      if (!mounted) return;
      _lastGameChatIds = games.map((e) => e.id).toList();
      _lastDmChatIds = dms.map((e) => e.id).toList();
      _syncRealtimeSubscriptionForCurrentTab();
    } catch (_) {}
  }

  void _syncRealtimeSubscriptionForCurrentTab() {
    if (!mounted) return;
    if (!_signedIn) {
      _disposeMessagesRealtime();
      return;
    }
    switch (_tabs.index) {
      case _kTabMatches:
        _disposeMessagesRealtime();
        break;
      case _kTabGameChats:
        _bindMessagesRealtime(_lastGameChatIds);
        break;
      case _kTabDms:
        _bindMessagesRealtime(_lastDmChatIds);
        break;
      default:
        _disposeMessagesRealtime();
        break;
    }
  }

  bool _sameChatIdList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final sa = [...a]..sort();
    final sb = [...b]..sort();
    for (var i = 0; i < sa.length; i++) {
      if (sa[i] != sb[i]) return false;
    }
    return true;
  }

  void _bindMessagesRealtime(List<String> chatIds) {
    if (_sameChatIdList(chatIds, _boundChatIds) &&
        _messagesRealtimeSub != null) {
      return;
    }
    _messagesRealtimeSub?.cancel();
    _messagesRealtimeSub = null;
    _boundChatIds = List<String>.from(chatIds);
    if (chatIds.isEmpty) return;

    try {
      _messagesRealtimeSub = Supabase.instance.client
          .from('messages')
          .stream(primaryKey: const ['id'])
          .inFilter('chat_id', chatIds)
          .listen(
        (_) => _scheduleRealtimeRefresh(),
        onError: (Object e) {
          debugPrint('[Inbox MVP] messages realtime stream error: $e');
        },
      );
      debugPrint(
        '[Inbox MVP] subscribed messages stream for ${chatIds.length} chat(s) '
        '(tab=${_tabs.index})',
      );
    } catch (e) {
      debugPrint('[Inbox MVP] messages realtime bind failed: $e');
    }
  }

  void _disposeMessagesRealtime() {
    _messagesRealtimeSub?.cancel();
    _messagesRealtimeSub = null;
    _boundChatIds = const [];
  }

  void _scheduleRealtimeRefresh() {
    _realtimeDebounce?.cancel();
    _realtimeDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _applyRealtimeDebouncedRefresh();
    });
  }

  void _applyRealtimeDebouncedRefresh() {
    if (!mounted || !_signedIn) {
      _disposeMessagesRealtime();
      return;
    }
    final tab = _tabs.index;
    if (tab == _kTabGameChats) {
      setState(() {
        _futures[InboxTabKind.gameChats] =
            _gameChatsRepo.fetchGameChatItems();
      });
      unawaited(_afterGameChatsFutureForRealtime());
    } else if (tab == _kTabDms) {
      setState(() {
        _futures[InboxTabKind.dms] = _dmsRepo.fetchDirectMessageItems();
      });
      unawaited(_afterDmsFutureForRealtime());
    }
  }

  Future<void> _afterGameChatsFutureForRealtime() async {
    try {
      final list = await _futures[InboxTabKind.gameChats]!;
      if (!mounted) return;
      _lastGameChatIds = list.map((e) => e.id).toList();
      if (_tabs.index == _kTabGameChats) {
        _bindMessagesRealtime(_lastGameChatIds);
      }
    } catch (_) {}
  }

  Future<void> _afterDmsFutureForRealtime() async {
    try {
      final list = await _futures[InboxTabKind.dms]!;
      if (!mounted) return;
      _lastDmChatIds = list.map((e) => e.id).toList();
      if (_tabs.index == _kTabDms) {
        _bindMessagesRealtime(_lastDmChatIds);
      }
    } catch (_) {}
  }

  /// [afterSuccessNotifyChatInbox] — only true for [RefreshIndicator] pull-to-refresh
  /// so Chat tab snapshot stays aligned without firing on retry / post-chat refresh.
  Future<void> _refreshGameChats({bool afterSuccessNotifyChatInbox = false}) async {
    setState(() {
      _futures[InboxTabKind.gameChats] = _gameChatsRepo.fetchGameChatItems();
    });
    try {
      final list = await _futures[InboxTabKind.gameChats]!;
      if (!mounted) return;
      _lastGameChatIds = list.map((e) => e.id).toList();
      if (_tabs.index == _kTabGameChats) {
        _syncRealtimeSubscriptionForCurrentTab();
      }
      if (afterSuccessNotifyChatInbox) {
        widget.onAfterInboxRealtimeRefresh?.call();
      }
    } catch (_) {}
  }

  Future<void> _refreshDms({bool afterSuccessNotifyChatInbox = false}) async {
    setState(() {
      _futures[InboxTabKind.dms] = _dmsRepo.fetchDirectMessageItems();
    });
    try {
      final list = await _futures[InboxTabKind.dms]!;
      if (!mounted) return;
      _lastDmChatIds = list.map((e) => e.id).toList();
      if (_tabs.index == _kTabDms) {
        _syncRealtimeSubscriptionForCurrentTab();
      }
      if (afterSuccessNotifyChatInbox) {
        widget.onAfterInboxRealtimeRefresh?.call();
      }
    } catch (_) {}
  }

  Future<void> _openItem(ChatListItem item) async {
    debugPrint('[Inbox MVP] open thread id=${item.id} kind=${item.kind.name}');

    final gate = widget.onEnsureLoggedIn;
    if (gate != null) {
      final ok = await gate(context);
      if (!mounted || !ok) return;
    }

    final openChat = widget.onOpenChat;
    if (openChat != null) {
      await openChat(context, item);
      if (!mounted) return;
      if (item.kind == InboxTabKind.gameChats) {
        await _refreshGameChats();
      } else if (item.kind == InboxTabKind.dms) {
        await _refreshDms();
      }
      widget.onAfterLiveChatClosed?.call();
      return;
    }

    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => InboxDetailPage(item: item),
      ),
    );
  }

  Widget _buildConversationList(
    List<ChatListItem> items, {
    ScrollPhysics? physics,
  }) {
    return ValueListenableBuilder<String?>(
      valueListenable: smeetOpenChatRoomId,
      builder: (context, openChatId, _) {
        return ListView.separated(
          physics: physics,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          itemCount: items.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final item = items[i];
            final timeStr =
                DateFormat.MMMd().add_jm().format(item.updatedAt.toLocal());
            final rawUnread = item.unreadCount;
            final unreadShown = (openChatId != null && openChatId == item.id)
                ? 0
                : rawUnread;
            final badge = unreadLabelForChatRow(unreadShown);

            return ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              title: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  item.lastMessage,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timeStr,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                  if (badge.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badge,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onErrorContainer,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ],
                ],
              ),
              onTap: () async {
                await _openItem(item);
              },
            );
          },
        );
      },
    );
  }

  /// Aligns with [ChatPage] signed-out [AppEmptyState] (icon/title/subtitle/action).
  Widget _liveTabsSignedOutBody() {
    final gate = widget.onEnsureLoggedIn;
    return AppEmptyState(
      icon: Icons.login,
      title: 'Sign in to chat',
      subtitle: 'Log in to message people you meet on Smeet.',
      actionLabel: gate != null ? 'Log in' : null,
      onAction: gate == null
          ? null
          : () async {
              final ok = await gate(context);
              if (!mounted) return;
              if (ok) {
                setState(() {
                  _matchesFuture = _matchesRepo.fetchMatchRelationships();
                  _futures[InboxTabKind.gameChats] =
                      _gameChatsRepo.fetchGameChatItems();
                  _futures[InboxTabKind.dms] =
                      _dmsRepo.fetchDirectMessageItems();
                });
                unawaited(_primeChatIdCachesThenSyncRealtime());
              }
            },
    );
  }

  /// Aligns with [ChatPage] signed-in empty list [AppEmptyState].
  Widget _liveTabsSignedInEmptyBody() {
    return const AppEmptyState(
      icon: Icons.chat_bubble_outline,
      title: 'No chats yet.',
      subtitle: 'Match with someone from Swipe to start a conversation.',
    );
  }

  Future<void> _refreshMatches({bool afterSuccessNotifyChatInbox = false}) async {
    setState(() {
      _matchesFuture = _matchesRepo.fetchMatchRelationships();
    });
    try {
      await _matchesFuture;
      if (!mounted) return;
      if (afterSuccessNotifyChatInbox) {
        widget.onAfterInboxRealtimeRefresh?.call();
      }
    } catch (_) {}
  }

  Future<void> _onMatchRowTap(MatchedProfileRow row) async {
    final gate = widget.onEnsureLoggedIn;
    if (gate != null) {
      final ok = await gate(context);
      if (!mounted || !ok) return;
    }

    final me = Supabase.instance.client.auth.currentUser?.id;
    if (me == null) return;

    try {
      final chatId = await _chatList.findDirectChatIdForPeer(
        myUserId: me,
        peerUserId: row.peerUserId,
      );
      if (!mounted) return;

      if (chatId != null && chatId.isNotEmpty) {
        final open = widget.onOpenChat;
        if (open != null) {
          await open(
            context,
            ChatListItem(
              id: chatId,
              kind: InboxTabKind.dms,
              title: row.displayName,
              lastMessage: '',
              updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
              unreadCount: 0,
              directPeerUserId: row.peerUserId,
            ),
          );
          if (!mounted) return;
          widget.onAfterLiveChatClosed?.call();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chat opener not configured')),
          );
        }
        return;
      }

      _showMatchNoDirectChatDialog(row);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open chat: $e')),
      );
    }
  }

  void _showMatchNoDirectChatDialog(MatchedProfileRow row) {
    final intro = row.intro.trim();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(row.displayName),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(intro.isEmpty ? 'No bio yet.' : intro),
              const SizedBox(height: 12),
              Text(
                'No direct chat is linked yet. New mutual likes from Swipe '
                'open a chat automatically; otherwise check the Chat tab.',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchRelationshipList(
    List<MatchedProfileRow> items, {
    ScrollPhysics? physics,
  }) {
    final cs = Theme.of(context).colorScheme;
    return ListView.separated(
      physics: physics,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      itemCount: items.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final row = items[i];
        final cityLabel =
            row.city.trim().isEmpty ? 'City not set' : row.city.trim();
        final timeStr =
            DateFormat.MMMd().add_jm().format(row.matchedAt.toLocal());
        final avatar = row.avatarUrl.trim();
        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          leading: CircleAvatar(
            backgroundColor: cs.primary.withOpacity(0.12),
            backgroundImage:
                avatar.isEmpty ? null : NetworkImage(row.avatarUrl),
            child: avatar.isEmpty
                ? Icon(Icons.person, color: cs.primary)
                : null,
          ),
          title: Text(
            row.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              cityLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          trailing: Text(
            timeStr,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          onTap: () => unawaited(_onMatchRowTap(row)),
        );
      },
    );
  }

  Widget _listForMatchesLive() {
    if (!_signedIn) {
      return _liveTabsSignedOutBody();
    }
    return FutureBuilder<List<MatchedProfileRow>>(
      future: _matchesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const AppLoadingState(message: 'Loading matches…');
        }
        if (snapshot.hasError) {
          return AppErrorState(
            message:
                'Something went wrong while loading matches. Please try again.',
            onRetry: () {
              unawaited(_refreshMatches());
            },
          );
        }
        final items = snapshot.data ?? const [];
        if (items.isEmpty) {
          return const AppEmptyState(
            icon: Icons.favorite_border,
            title: 'No matches yet.',
            subtitle:
                'When you and someone both like each other on Swipe, they appear here.',
          );
        }
        return RefreshIndicator(
          onRefresh: () =>
              _refreshMatches(afterSuccessNotifyChatInbox: true),
          child: _buildMatchRelationshipList(
            items,
            physics: const AlwaysScrollableScrollPhysics(),
          ),
        );
      },
    );
  }

  Widget _listForGameChatsLive() {
    if (!_signedIn) {
      return _liveTabsSignedOutBody();
    }
    return FutureBuilder<List<ChatListItem>>(
      future: _futures[InboxTabKind.gameChats],
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const AppLoadingState(message: 'Loading chats…');
        }
        if (snapshot.hasError) {
          return AppErrorState(
            message:
                'Something went wrong while loading chats. Please try again.',
            onRetry: () {
              unawaited(_refreshGameChats());
            },
          );
        }
        final items = snapshot.data ?? const [];
        if (items.isEmpty) {
          return _liveTabsSignedInEmptyBody();
        }
        return RefreshIndicator(
          onRefresh: () => _refreshGameChats(afterSuccessNotifyChatInbox: true),
          child: _buildConversationList(
            items,
            physics: const AlwaysScrollableScrollPhysics(),
          ),
        );
      },
    );
  }

  Widget _listForDmsLive() {
    if (!_signedIn) {
      return _liveTabsSignedOutBody();
    }
    return FutureBuilder<List<ChatListItem>>(
      future: _futures[InboxTabKind.dms],
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const AppLoadingState(message: 'Loading chats…');
        }
        if (snapshot.hasError) {
          return AppErrorState(
            message:
                'Something went wrong while loading chats. Please try again.',
            onRetry: () {
              unawaited(_refreshDms());
            },
          );
        }
        final items = snapshot.data ?? const [];
        if (items.isEmpty) {
          return _liveTabsSignedInEmptyBody();
        }
        return RefreshIndicator(
          onRefresh: () => _refreshDms(afterSuccessNotifyChatInbox: true),
          child: _buildConversationList(
            items,
            physics: const AlwaysScrollableScrollPhysics(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inbox (MVP)'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Matches'),
            Tab(text: 'Game Chats'),
            Tab(text: 'DMs'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _listForMatchesLive(),
          _listForGameChatsLive(),
          _listForDmsLive(),
        ],
      ),
    );
  }
}
