// Split from `main.dart` for size only. This file is a **part** of the same library as
// `package:smeet_app/main.dart` so [HomePage], [ChatPage], notifiers, and [unreadLabelForChatTab]
// stay in scope without circular imports.

part of 'package:smeet_app/main.dart';

/// Central auth + profile row state for [SmeetShell] (guest vs needs profile vs ready).
enum ShellAuthPhase {
  /// Resolving Supabase session and `public.profiles` (avoid wrong first tab).
  authResolving,
  signedOut,
  signedInProfileMissing,
  signedInProfileReady,
}

/// Smeet 主框架：底部 5 个 Tab
class SmeetShell extends StatefulWidget {
  const SmeetShell({super.key});

  /// Re-run session + profile row resolution (after login, sign-up, profile save, etc.).
  static void refreshAuthState() {
    Future<void>.delayed(Duration.zero, () {
      _SmeetShellState.requestRefreshAuthState();
    });
  }

  // --- Chat tab unread (shell-level indicator; [ChatPage] aggregates, no messaging rewrite) ---

  /// Updates the Chat tab badge total. Called from [ChatPage] when the aggregate unread changes.
  static void reportChatTabUnread(int total) {
    smeetChatTabUnreadTotal.value = total < 0 ? 0 : total;
  }

  /// Clears the Chat tab badge (signed out, no session, etc.).
  static void clearChatTabUnreadBadge() {
    smeetChatTabUnreadTotal.value = 0;
  }

  /// Nudges [ChatPage] to refetch (debounced there) after read state is persisted without a
  /// new message — e.g. [markChatRead] when popping [ChatRoomPage].
  static void requestChatInboxRefresh() {
    smeetChatInboxRefreshSignal.value++;
  }

  @override
  State<SmeetShell> createState() => _SmeetShellState();
}

class _SmeetShellState extends State<SmeetShell> {
  static const int _kProfileTabIndex = 4;

  static _SmeetShellState? _instance;

  static void requestRefreshAuthState() {
    _instance?._scheduleAuthAndProfileResolution();
  }

  ShellAuthPhase _phase = ShellAuthPhase.authResolving;
  int _authResolveEpoch = 0;
  bool _authResolveQueued = false;
  Future<void>? _authResolveInFlight;

  int _index = 0;
  final Set<String> _joinedLocal = {};
  /// Bumps when joins / DB sync changes so My Game & related lists refetch.
  int _gamesListRevision = 0;
  /// Bumped on sign-out so [ProfilePage] resets cleanly on next login.
  int _profileSessionKey = 0;

  StreamSubscription<AuthState>? _authSub;
  /// Avoid duplicate welcome SnackBars for the same signed-in user this session.
  String? _profileWelcomeSnackUserId;

  StreamSubscription<List<Map<String, dynamic>>>? _retentionNotifSub;
  Timer? _gameEventNotifTimer;

  void _stopRetentionListeners() {
    _retentionNotifSub?.cancel();
    _retentionNotifSub = null;
    _gameEventNotifTimer?.cancel();
    _gameEventNotifTimer = null;
  }

  void _bindRetentionStreams() {
    _stopRetentionListeners();
    final u = Supabase.instance.client.auth.currentUser;
    if (u == null) {
      clearAppNotificationBadges();
      return;
    }
    final repo = UserNotificationsRepository();
    _retentionNotifSub = repo.watchMine().listen((_) {
      unawaited(refreshAppNotificationBadges());
    });
    unawaited(refreshAppNotificationBadges());
    _gameEventNotifTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (!mounted) return;
      if (Supabase.instance.client.auth.currentUser == null) return;
      unawaited(
        GameEventNotificationService().runChecksForJoinedGames(_joinedLocal),
      );
    });
    unawaited(
      GameEventNotificationService().runChecksForJoinedGames(_joinedLocal),
    );
  }

  @override
  void initState() {
    super.initState();
    _instance = this;
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      debugPrint(
        '[Shell] auth change currentUser=${Supabase.instance.client.auth.currentUser?.id}',
      );
      final ev = data.event;
      if (ev == AuthChangeEvent.signedOut) {
        _authResolveEpoch++;
        _authResolveQueued = false;
        _stopRetentionListeners();
        clearAppNotificationBadges();
        if (mounted) {
          setState(() {
            _phase = ShellAuthPhase.signedOut;
            _index = 0;
            _profileWelcomeSnackUserId = null;
            _profileSessionKey++;
            SmeetShell.clearChatTabUnreadBadge();
          });
        }
        _syncJoinedFromDb();
        return;
      }
      if (ev == AuthChangeEvent.signedIn ||
          ev == AuthChangeEvent.initialSession) {
        _scheduleAuthAndProfileResolution();
      }
      _syncJoinedFromDb();
    });
    _syncJoinedFromDb();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleAuthAndProfileResolution();
    });
  }

  @override
  void dispose() {
    if (identical(_instance, this)) {
      _instance = null;
    }
    _authSub?.cancel();
    _stopRetentionListeners();
    super.dispose();
  }

  void _scheduleAuthAndProfileResolution() {
    final u = Supabase.instance.client.auth.currentUser;
    if (u != null &&
        (_phase == ShellAuthPhase.signedOut ||
            _phase == ShellAuthPhase.authResolving)) {
      setState(() => _phase = ShellAuthPhase.authResolving);
    }
    if (_authResolveInFlight != null) {
      _authResolveQueued = true;
      return;
    }
    _authResolveInFlight = _runAuthAndProfileResolution().whenComplete(() {
      _authResolveInFlight = null;
      if (!mounted) return;
      if (_authResolveQueued) {
        _authResolveQueued = false;
        _scheduleAuthAndProfileResolution();
      }
    });
  }

  Future<void> _runAuthAndProfileResolution() async {
    final startEpoch = _authResolveEpoch;
    await Future<void>.delayed(Duration.zero);
    if (!mounted || startEpoch != _authResolveEpoch) return;

    final client = Supabase.instance.client;
    final u = client.auth.currentUser;

    if (u == null) {
      if (!mounted || startEpoch != _authResolveEpoch) return;
      debugPrint(
        '[shell_auth] no session → signedOut, reset tab to Home (was index=$_index)',
      );
      _stopRetentionListeners();
      clearAppNotificationBadges();
      setState(() {
        _phase = ShellAuthPhase.signedOut;
        _profileWelcomeSnackUserId = null;
        _index = 0;
        SmeetShell.clearChatTabUnreadBadge();
      });
      return;
    }

    Map<String, dynamic>? row;
    try {
      row = await client
          .from('profiles')
          .select('id')
          .eq('id', u.id)
          .maybeSingle();
    } catch (e, st) {
      debugPrint('[shell_auth] profiles check failed: $e');
      debugPrint('$st');
      if (!mounted || startEpoch != _authResolveEpoch) return;
      // Fail open: keep app usable if RLS/network breaks profile read.
      setState(() => _phase = ShellAuthPhase.signedInProfileReady);
      if (mounted) _bindRetentionStreams();
      return;
    }

    if (!mounted || startEpoch != _authResolveEpoch) return;

    if (row == null) {
      debugPrint(
        '[shell_auth] profile row missing → force Profile tab '
        'user=${u.id} (was index=$_index)',
      );
      setState(() {
        _phase = ShellAuthPhase.signedInProfileMissing;
        _index = _kProfileTabIndex;
      });
      final showWelcome = _profileWelcomeSnackUserId != u.id;
      if (showWelcome) {
        _profileWelcomeSnackUserId = u.id;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            const SnackBar(
              content: Text('Welcome! Please complete your profile first.'),
              duration: Duration(seconds: 5),
            ),
          );
        });
      }
    } else {
      setState(() => _phase = ShellAuthPhase.signedInProfileReady);
    }
    if (mounted) _bindRetentionStreams();
  }

  Future<void> _syncJoinedFromDb() async {
    final u = Supabase.instance.client.auth.currentUser;
    if (u == null) {
      if (mounted) {
        setState(() {
          _joinedLocal.clear();
          _gamesListRevision++;
        });
      }
      return;
    }
    try {
      final rows = await Supabase.instance.client
          .from('game_participants')
          .select('game_id')
          .eq('user_id', u.id)
          .eq('status', 'joined');
      final ids = (rows as List)
          .map((e) => e['game_id'].toString())
          .toSet();
      if (!mounted) return;
      setState(() {
        _joinedLocal
          ..clear()
          ..addAll(ids);
        _gamesListRevision++;
      });
    } catch (_) {
      if (mounted) setState(() => _gamesListRevision++);
    }
  }

  void _onGamesMutated() {
    _syncJoinedFromDb();
  }

  Widget _chatNavIcon({required bool selected, required int unread}) {
    final icon = Icon(
      selected ? Icons.chat_bubble : Icons.chat_bubble_outline,
    );
    if (unread <= 0) return icon;
    final cs = Theme.of(context).colorScheme;
    return Badge(
      backgroundColor: cs.error,
      textColor: cs.onError,
      label: Text(
        unreadLabelForChatTab(unread),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
      child: icon,
    );
  }

  List<Widget> get _pages => [
        HomePage(
          joinedLocal: _joinedLocal,
          onGamesMutated: _onGamesMutated,
        ),
        const SwipePage(),
        MyGamePage(
          key: ValueKey(_gamesListRevision),
          joinedLocal: _joinedLocal,
          listRevision: _gamesListRevision,
          onGamesMutated: _onGamesMutated,
        ),
        ChatPage(
          key: ValueKey(_gamesListRevision),
        ),
        ProfilePage(key: ValueKey(_profileSessionKey)),
      ];

  List<Widget>? _retentionAppBarActions(BuildContext context) {
    if (_phase == ShellAuthPhase.signedOut) return null;
    if (Supabase.instance.client.auth.currentUser == null) return null;
    return [
      if (_index == 1)
        ValueListenableBuilder<int>(
          valueListenable: smeetIncomingLikesCount,
          builder: (context, n, _) {
            return Badge(
              isLabelVisible: n > 0,
              label: Text(n > 99 ? '99+' : '$n'),
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const LikesYouPage(),
                    ),
                  );
                },
                child: const Text('Likes you'),
              ),
            );
          },
        ),
      ValueListenableBuilder<int>(
        valueListenable: smeetAppNotificationsUnread,
        builder: (context, n, _) {
          return IconButton(
            tooltip: 'Notifications',
            onPressed: () async {
              await Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const NotificationsPage(),
                ),
              );
              await refreshAppNotificationBadges();
            },
            icon: Badge(
              isLabelVisible: n > 0,
              label: Text(n > 99 ? '99+' : '$n'),
              child: const Icon(Icons.notifications_outlined),
            ),
          );
        },
      ),
    ];
  }

  String get _title {
    switch (_index) {
      case 0:
        return 'Smeet';
      case 1:
        return 'Swipe';
      case 2:
        return 'My Game';
      case 3:
        return 'Chat';
      case 4:
        return 'Profile';
      default:
        return 'Smeet';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == ShellAuthPhase.authResolving) {
      return const Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading…'),
              ],
            ),
          ),
        ),
      );
    }

    final pages = _pages;

    return Scaffold(
      appBar: AppBar(
        title: _index == 0
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/Smeet_logo_transparent.png',
                    height: 26,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.sports, size: 22);
                    },
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              )
            : Text(_title),
        centerTitle: true,
        actions: _retentionAppBarActions(context),
      ),
      // Use IndexedStack to keep pages alive when switching tabs.
      // Web: offstage children skip layout; isolate focus, semantics, pointers,
      // and tickers so traversal / bounds don't touch unfocused tabs.
      body: SafeArea(
        child: IndexedStack(
          index: _index,
          children: List<Widget>.generate(pages.length, (i) {
            final page = pages[i];
            if (i == _index) return page;
            return TickerMode(
              enabled: false,
              child: IgnorePointer(
                ignoring: true,
                child: ExcludeSemantics(
                  excluding: true,
                  child: ExcludeFocus(
                    excluding: true,
                    child: page,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() => _index = i);
          debugPrint('[Nav] switch tab -> $_index');
          if (i == _kProfileTabIndex) {
            debugPrint('[Nav] Profile tab selected (index $_kProfileTabIndex)');
          }
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          const NavigationDestination(icon: Icon(Icons.swipe), label: 'Swipe'),
          const NavigationDestination(
            icon: Icon(Icons.sports_tennis),
            label: 'MyGame',
          ),
          NavigationDestination(
            icon: ValueListenableBuilder<int>(
              valueListenable: smeetChatTabUnreadTotal,
              builder: (context, unread, _) {
                return _chatNavIcon(selected: false, unread: unread);
              },
            ),
            selectedIcon: ValueListenableBuilder<int>(
              valueListenable: smeetChatTabUnreadTotal,
              builder: (context, unread, _) {
                return _chatNavIcon(selected: true, unread: unread);
              },
            ),
            label: 'Chat',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
