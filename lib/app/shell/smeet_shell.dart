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
        unawaited(
          PushTokenService(Supabase.instance.client).registerCurrentToken(),
        );
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

  /// Build the shell tab at [i]. Indices are **0, 1, 3, 4** (2 is the center
  /// publish FAB, not a page). Only the current tab is built — avoids off-stage
  /// layout / focus races.
  Widget _pageForIndex(int i) {
    switch (i) {
      case 0:
        return FeedPage(
          onEnsureLoggedIn: _ensureLoginAndPrompt,
          onOpenLikesYou: (c) {
            Navigator.of(c).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const LikesYouPage(),
              ),
            );
          },
          onOpenMatches: (c) {
            Navigator.of(c).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const MatchesPage(),
              ),
            );
          },
          onOpenMyGame: (c) {
            Navigator.of(c).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => MyGamePage(
                  joinedLocal: _joinedLocal,
                  listRevision: _gamesListRevision,
                  onGamesMutated: _onGamesMutated,
                ),
              ),
            );
          },
          onOpenHome: (c) {
            Navigator.of(c).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => HomePage(
                  joinedLocal: _joinedLocal,
                  onGamesMutated: _onGamesMutated,
                ),
              ),
            );
          },
        );
      case 1:
        return ExplorePage(
          smeetTab: const SwipePage(),
          eventsTab: HomePage(
            joinedLocal: _joinedLocal,
            onGamesMutated: _onGamesMutated,
          ),
        );
      case 3:
        return ChatPage(
          key: ValueKey(_gamesListRevision),
        );
      case 4:
        return ProfilePage(key: ValueKey(_profileSessionKey));
      default:
        return const SizedBox.shrink();
    }
  }

  void _openCreateSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CreateActionSheet(
        onPostPhoto: () {
          Navigator.pop(ctx);
          unawaited(_handlePostPhoto(context));
        },
        onPostVideo: () {
          Navigator.pop(ctx);
          unawaited(_handlePostVideo(context));
        },
        onWriteNote: () {
          Navigator.pop(ctx);
          unawaited(_handleWriteNote(context));
        },
        onCreateGame: () {
          Navigator.pop(ctx);
          _handleCreateGame(context);
        },
      ),
    );
  }

  Future<void> _handlePostPhoto(BuildContext context) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      final ok = await _ensureLoginAndPrompt(context);
      if (!ok) return;
    }
    if (!context.mounted) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MediaSourceSheet(
        title: 'Post Photo',
        icon: Icons.photo_camera_rounded,
      ),
    );
    if (source == null || !context.mounted) return;

    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: source,
      imageQuality: 85,
    );
    if (x == null || !context.mounted) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _CreatePostPage(
          xfile: x,
          mediaType: 'image',
          userId: Supabase.instance.client.auth.currentUser!.id,
        ),
      ),
    );
  }

  Future<void> _handlePostVideo(BuildContext context) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      final ok = await _ensureLoginAndPrompt(context);
      if (!ok) return;
    }
    if (!context.mounted) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MediaSourceSheet(
        title: 'Post Video',
        icon: Icons.videocam_rounded,
      ),
    );
    if (source == null || !context.mounted) return;

    final picker = ImagePicker();
    final x = await picker.pickVideo(
      source: source,
      maxDuration: const Duration(seconds: 60),
    );
    if (x == null || !context.mounted) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _CreatePostPage(
          xfile: x,
          mediaType: 'video',
          userId: Supabase.instance.client.auth.currentUser!.id,
        ),
      ),
    );
  }

  Future<void> _handleWriteNote(BuildContext context) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      final ok = await _ensureLoginAndPrompt(context);
      if (!ok) return;
    }
    if (!context.mounted) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _WriteNotePage(
          userId: Supabase.instance.client.auth.currentUser!.id,
        ),
      ),
    );
  }

  void _handleCreateGame(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => const AuthPage()),
      );
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (ctx) => Scaffold(
          appBar: AppBar(
            title: const Text('Create Game'),
            leading: IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.pop(ctx),
            ),
          ),
          body: HomePage(
            joinedLocal: _joinedLocal,
            onGamesMutated: _onGamesMutated,
          ),
        ),
      ),
    );
  }

  Widget _buildShellBottomBar() {
    final cs = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final greyIcon = Colors.grey.shade400;
    final greyLabel = Colors.grey.shade500;

    Widget navTile({
      required int index,
      required String label,
      required IconData iconOutlined,
      required IconData iconRounded,
    }) {
      final selected = _index == index;
      final iconC = selected ? cs.primary : greyIcon;
      final labelC = selected ? cs.primary : greyLabel;
      final iconSz = selected ? 26.0 : 24.0;
      return Expanded(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              setState(() => _index = index);
              debugPrint('[Nav] switch tab -> $_index');
              if (index == _kProfileTabIndex) {
                debugPrint(
                  '[Nav] Profile tab selected (index $_kProfileTabIndex)',
                );
              }
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected ? iconRounded : iconOutlined,
                  size: iconSz,
                  color: iconC,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: labelC,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget chatTile() {
      final selected = _index == 3;
      final iconC = selected ? cs.primary : greyIcon;
      final labelC = selected ? cs.primary : greyLabel;
      final iconSz = selected ? 26.0 : 24.0;
      return Expanded(
        child: ValueListenableBuilder<int>(
          valueListenable: smeetChatTabUnreadTotal,
          builder: (context, unread, _) {
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _index = 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          selected
                              ? Icons.chat_bubble_rounded
                              : Icons.chat_bubble_outline_rounded,
                          size: iconSz,
                          color: iconC,
                        ),
                        if (unread > 0)
                          Positioned(
                            right: -10,
                            top: -8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: cs.error,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              constraints: const BoxConstraints(minWidth: 16),
                              child: Text(
                                unreadLabelForChatTab(unread),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: cs.onError,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Messages',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: labelC,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    return Material(
      color: Colors.white,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: SmeetApp.smeetNavBorder, width: 1),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SizedBox(
            height: 64,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                navTile(
                  index: 0,
                  label: 'Feed',
                  iconOutlined: Icons.home_outlined,
                  iconRounded: Icons.home_rounded,
                ),
                navTile(
                  index: 1,
                  label: 'Explore',
                  iconOutlined: Icons.explore_outlined,
                  iconRounded: Icons.explore_rounded,
                ),
                SizedBox(
                  width: 72,
                  child: Center(
                    child: GestureDetector(
                      onTap: () => _openCreateSheet(context),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: cs.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: cs.primary.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ),
                chatTile(),
                navTile(
                  index: 4,
                  label: 'Profile',
                  iconOutlined: Icons.person_outlined,
                  iconRounded: Icons.person_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
        return 'Explore';
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

    return Scaffold(
      appBar: _index == 0
          ? null
          : AppBar(
              title: Text(_title),
              centerTitle: true,
              actions: _retentionAppBarActions(context),
            ),
      // Single visible tab only (no IndexedStack): prevents off-stage subtrees from
      // participating in focus traversal / semantics before layout completes.
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth <= 0 || constraints.maxHeight <= 0) {
              return const SizedBox.shrink();
            }
            return KeyedSubtree(
              key: ValueKey<int>(_index),
              child: _pageForIndex(_index),
            );
          },
        ),
      ),
      bottomNavigationBar: _buildShellBottomBar(),
    );
  }
}

class _CreateActionSheet extends StatelessWidget {
  final VoidCallback onPostPhoto;
  final VoidCallback onPostVideo;
  final VoidCallback onWriteNote;
  final VoidCallback onCreateGame;

  const _CreateActionSheet({
    required this.onPostPhoto,
    required this.onPostVideo,
    required this.onWriteNote,
    required this.onCreateGame,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Create',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 8),
          _CreateItem(
            icon: Icons.photo_library_rounded,
            iconColor: const Color(0xFF4CAF50),
            label: 'Post Photo',
            subtitle: 'Share from gallery or take a photo',
            onTap: onPostPhoto,
          ),
          _CreateItem(
            icon: Icons.videocam_rounded,
            iconColor: const Color(0xFFE91E63),
            label: 'Post Video',
            subtitle: 'Upload or record a sports clip',
            onTap: onPostVideo,
          ),
          _CreateItem(
            icon: Icons.edit_note_rounded,
            iconColor: const Color(0xFF2196F3),
            label: 'Write Note',
            subtitle: 'Share a tip, recap or thought',
            onTap: onWriteNote,
          ),
          _CreateItem(
            icon: Icons.sports_rounded,
            iconColor: cs.primary,
            label: 'Create Game',
            subtitle: 'Set up a session for others to join',
            onTap: onCreateGame,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _CreateItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _CreateItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: iconColor, size: 24),
      ),
      title: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: Colors.grey.shade400,
        size: 20,
      ),
    );
  }
}

class _MediaSourceSheet extends StatelessWidget {
  final String title;
  final IconData icon;

  const _MediaSourceSheet({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 8),
          ListTile(
            onTap: () => Navigator.pop(context, ImageSource.camera),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: cs.primary, size: 24),
            ),
            title: const Text(
              'Take a photo / video',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              'Use your camera now',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ),
          ListTile(
            onTap: () => Navigator.pop(context, ImageSource.gallery),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.photo_library_rounded,
                color: Colors.purple,
                size: 24,
              ),
            ),
            title: const Text(
              'Choose from gallery',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              'Pick an existing file',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _CreatePostPage extends StatefulWidget {
  final XFile xfile;
  final String mediaType;
  final String userId;

  const _CreatePostPage({
    required this.xfile,
    required this.mediaType,
    required this.userId,
  });

  @override
  State<_CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<_CreatePostPage> {
  final _captionCtrl = TextEditingController();
  bool _loading = false;
  Uint8List? _previewBytes;
  XFile? _coverXFile;
  Uint8List? _coverBytes;

  @override
  void initState() {
    super.initState();
    if (widget.mediaType == 'image') {
      unawaited(_loadPreviewBytes());
    }
  }

  @override
  void dispose() {
    _captionCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPreviewBytes() async {
    try {
      final b = await widget.xfile.readAsBytes();
      if (mounted) setState(() => _previewBytes = b);
    } catch (_) {
      if (mounted) setState(() => _previewBytes = null);
    }
  }

  Future<void> _pickCover() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (x == null || !mounted) return;
    final bytes = await x.readAsBytes();
    setState(() {
      _coverXFile = x;
      _coverBytes = bytes;
    });
  }

  Future<void> _publish() async {
    setState(() => _loading = true);
    try {
      final url = await MediaUploadService().uploadXFileToMediaBucket(
        widget.xfile,
        userId: widget.userId,
        folder: 'posts',
      );

      String? coverUrl;
      if (widget.mediaType == 'video') {
        if (_coverXFile != null) {
          coverUrl = await MediaUploadService().uploadXFileToMediaBucket(
            _coverXFile!,
            userId: widget.userId,
            folder: 'posts/thumbnails',
          );
        } else if (!kIsWeb) {
          try {
            final thumbBytes = await VideoThumbnail.thumbnailData(
              video: widget.xfile.path,
              imageFormat: ImageFormat.JPEG,
              maxHeight: 400,
              quality: 75,
            );
            if (thumbBytes != null && thumbBytes.isNotEmpty) {
              final thumbPath =
                  'posts/thumbnails/${widget.userId}_'
                  '${DateTime.now().millisecondsSinceEpoch}.jpg';
              await Supabase.instance.client.storage.from('media').uploadBinary(
                    thumbPath,
                    thumbBytes,
                    fileOptions: const FileOptions(
                      contentType: 'image/jpeg',
                    ),
                  );
              coverUrl = Supabase.instance.client.storage
                  .from('media')
                  .getPublicUrl(thumbPath);
            }
          } catch (e) {
            debugPrint('[Thumbnail] failed: $e');
          }
        }
      }

      final payload = PostsService.buildMediaPostPayload(
        authorId: widget.userId,
        mediaUrl: url,
        mediaType: widget.mediaType,
        captionTrimmed: _captionCtrl.text.trim(),
        coverImageUrl: coverUrl,
      );
      await PostsService().insertPostReturningSummary(payload);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Posted!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to post. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.mediaType == 'image' ? 'New Photo' : 'New Video'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: _loading ? null : _publish,
              child: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Post'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.mediaType == 'video') ...[
              GestureDetector(
                onTap: _pickCover,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: _coverBytes != null
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.memory(
                                _coverBytes!,
                                fit: BoxFit.cover,
                              ),
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    '✏️ Change cover',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Container(
                            color: const Color(0xFF1A1A2E),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.add_photo_alternate_rounded,
                                  color: Colors.white54,
                                  size: 48,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tap to add cover image',
                                  style: TextStyle(
                                    color:
                                        Colors.white.withValues(alpha: 0.7),
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Recommended: a photo from your game',
                                  style: TextStyle(
                                    color:
                                        Colors.white.withValues(alpha: 0.4),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.videocam_rounded, size: 18, color: cs.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Video selected ✓',
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              if (_previewBytes != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(
                    _previewBytes!,
                    width: double.infinity,
                    fit: BoxFit.fitWidth,
                  ),
                )
              else
                SizedBox(
                  height: 200,
                  width: double.infinity,
                  child: ColoredBox(
                    color: cs.surfaceContainerHighest,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _captionCtrl,
              maxLines: 4,
              maxLength: 300,
              decoration: InputDecoration(
                hintText: 'Write a caption...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WriteNotePage extends StatefulWidget {
  final String userId;
  const _WriteNotePage({required this.userId});

  @override
  State<_WriteNotePage> createState() => _WriteNotePageState();
}

class _WriteNotePageState extends State<_WriteNotePage> {
  final _noteCtrl = TextEditingController();
  bool _loading = false;
  String _selectedSport = 'General';

  String get _sportKeyForPayload {
    if (_selectedSport == 'General') return 'Tennis';
    for (final e in kSupportedSports) {
      if (e.$3 == _selectedSport) return e.$1;
    }
    return 'Tennis';
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    final text = _noteCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write something first.')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final payload = PostsService.buildMediaPostPayload(
        authorId: widget.userId,
        mediaUrl: '',
        mediaType: 'note',
        captionTrimmed: text,
        sport: _sportKeyForPayload,
      );
      await PostsService().insertPostReturningSummary(payload);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note posted!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to post. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Write Note'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: _loading ? null : _publish,
              child: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Post'),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sport tag (optional)',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: ['General', ...kSupportedSports.map((s) => s.$3)]
                    .map((sport) {
                  final sel = _selectedSport == sport;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedSport = sport),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: sel ? cs.primary : cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        sport,
                        style: TextStyle(
                          color: sel ? Colors.white : cs.onSurface,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: _noteCtrl,
                maxLines: null,
                expands: true,
                maxLength: 500,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(fontSize: 16, height: 1.6),
                decoration: InputDecoration(
                  hintText:
                      "What's on your mind? Share a tip, game recap, or sports update...",
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  border: InputBorder.none,
                  counterStyle: TextStyle(color: Colors.grey.shade400),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
