import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart'; // kIsWeb
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:smeet_app/core/config/supabase_env.dart';
import 'package:smeet_app/core/formatting/chat_row_unread_label.dart';
import 'package:smeet_app/core/notifiers/smeet_open_chat_room_notifier.dart';
import 'package:smeet_app/core/services/chat_conversation_list_service.dart';
import 'package:smeet_app/core/services/joined_games_service.dart';
import 'package:smeet_app/core/services/media_upload_service.dart';
import 'package:smeet_app/core/services/posts_service.dart';
import 'package:smeet_app/app/smeet_app.dart';
import 'package:smeet_app/game_balance.dart';
import 'package:smeet_app/geo_utils.dart';
import 'package:smeet_app/other_profile_page.dart';
import 'package:smeet_app/services/block_service.dart';
import 'package:smeet_app/widgets/app_page_states.dart';
import 'package:smeet_app/widgets/legal_section_card.dart';
import 'package:smeet_app/widgets/location_search_field.dart';
import 'package:smeet_app/widgets/post_media_display.dart';
import 'package:smeet_app/widgets/report_bottom_sheet.dart';
import 'package:smeet_app/widgets/signup_legal_agreement.dart';
import 'package:smeet_app/features/feed/feed.dart';
import 'package:smeet_app/features/inbox/inbox.dart';
import 'package:smeet_app/features/create/create.dart';
import 'package:smeet_app/features/notifications/notifications.dart';
import 'package:smeet_app/features/profile/presentation/legacy_profile_setup_section.dart';
import 'package:smeet_app/features/profile/presentation/profile_setup_demo_page.dart';
import 'package:smeet_app/features/profile/profile.dart';

part 'app/shell/smeet_shell.dart';

/// 12h time like "2:00 PM"
String formatTime12h(DateTime dt) {
  final h = dt.hour;
  final m = dt.minute;
  final ap = h >= 12 ? 'PM' : 'AM';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  final mm = m.toString().padLeft(2, '0');
  return '$h12:$mm $ap';
}

String formatGameTimeRange(DateTime? start, DateTime? end) {
  if (start == null) return '—';
  final a = formatTime12h(start);
  if (end == null) return a;
  return '$a – ${formatTime12h(end)}';
}

String sportLevelForSport(Map<String, dynamic>? profile, String sport) {
  if (profile == null) return '—';
  final sl = profile['sport_levels'];
  if (sl is! Map) return '—';
  for (final e in sl.entries) {
    if (e.key.toString().toLowerCase() == sport.toLowerCase()) {
      return e.value?.toString() ?? '—';
    }
  }
  return '—';
}

List<Map<String, dynamic>> sortedChatMessages(
  List<Map<String, dynamic>> msgs,
) {
  final copy = List<Map<String, dynamic>>.from(msgs);
  copy.sort((a, b) {
    final ca = DateTime.tryParse(a['created_at']?.toString() ?? '');
    final cb = DateTime.tryParse(b['created_at']?.toString() ?? '');
    if (ca != null && cb != null) return ca.compareTo(cb);
    return (a['id']?.toString() ?? '').compareTo(b['id']?.toString() ?? '');
  });
  return copy;
}

/// e.g. "Saturday · 03/21/2026" (weekday uses device locale)
String formatGameDateHeading(DateTime? start) {
  if (start == null) return 'Date —';
  return DateFormat('EEEE · MM/dd/yyyy').format(start);
}

String _userFacingJoinGameError(Object e) {
  debugPrint('[JoinGame] failed: $e');
  final s = e.toString().toLowerCase();
  if (s.contains('full')) {
    return 'This game is full.';
  }
  return 'Couldn’t join this game. Please try again.';
}

String _userFacingSwipeError(Object e) {
  debugPrint('[Swipe] failed: $e');
  return 'That didn’t work. Please try again.';
}

String _userFacingChatSendError(Object e) {
  debugPrint('[ChatSend] failed: $e');
  return 'Couldn’t send. Check your connection and try again.';
}

String _userFacingMembersLoadError(Object e) {
  debugPrint('[ChatRoom] members load failed: $e');
  return 'Couldn’t load the player list. Try again in a moment.';
}

String _userFacingProfileLoadError(Object e) {
  debugPrint('[Profile] load failed: $e');
  return 'Couldn’t load your profile. Please try again.';
}

String _userFacingAvatarUploadError(Object e) {
  debugPrint('[Profile] avatar upload failed: $e');
  return 'Couldn’t update your profile photo. Please try again.';
}

String _userFacingPostPublishError(Object e) {
  debugPrint('[Profile] post publish failed: $e');
  return 'Couldn’t publish your post. Please try again.';
}

Future<void> markChatRead(
  SupabaseClient supabase, {
  required String chatId,
  required String userId,
}) async {
  try {
    final now = DateTime.now().toUtc().toIso8601String();
    await supabase
        .from('chat_members')
        .update({'last_read_at': now})
        .eq('chat_id', chatId)
        .eq('user_id', userId);
    debugPrint('[Unread] markChatRead chat_id=$chatId user=$userId at=$now');
  } catch (_) {}
}

/// Shell-level Chat tab unread indicator (implementation detail).
///
/// Prefer [SmeetShell.reportChatTabUnread], [SmeetShell.clearChatTabUnreadBadge], and
/// [SmeetShell.requestChatInboxRefresh] at call sites — lightweight hooks, no messaging rewrite.
/// [SmeetShell] binds the badge via [ValueListenableBuilder] on this notifier.
final ValueNotifier<int> smeetChatTabUnreadTotal = ValueNotifier<int>(0);

/// Lightweight refresh hook: [ChatPage] listens (debounced) and refetches the chat list.
/// Used when `last_read_at` changes without a new message row (e.g. after leaving [ChatRoomPage]).
final ValueNotifier<int> smeetChatInboxRefreshSignal = ValueNotifier<int>(0);

/// Bottom nav Chat tab (larger cap).
String unreadLabelForChatTab(int n) {
  if (n <= 0) return '';
  if (n > 99) return '99+';
  return '$n';
}

Map<String, WidgetBuilder> _smeetNamedRoutesForNonRelease() {
  return {
    FeedRoutes.list: (_) => const FeedPage(),
    InboxRoutes.list: (_) => InboxPage(
          onEnsureLoggedIn: _ensureLoginAndPrompt,
          onAfterLiveChatClosed: SmeetShell.requestChatInboxRefresh,
          onAfterInboxRealtimeRefresh: SmeetShell.requestChatInboxRefresh,
          onOpenChat: (context, item) async {
            final chatKind =
                item.kind == InboxTabKind.gameChats ? 'game' : 'direct';
            await Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => ChatRoomPage(
                  chatId: item.id,
                  title: item.title,
                  chatKind: chatKind,
                  directPeerUserId: item.directPeerUserId,
                ),
              ),
            );
          },
        ),
    CreateRoutes.hub: (context) => CreateHubPage(
          onOpenLegacyCreateGame: () {
            Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (ctx) => HomePage(
                  joinedLocal: <String>{},
                  onGamesMutated: () {},
                ),
              ),
            );
          },
        ),
    NotificationsRoutes.list: (_) => const NotificationsPage(),
    ProfileRoutes.list: (context) {
      final raw = ModalRoute.of(context)?.settings.arguments;
      var tab = ProfileMvpInitialTabIndex.posts;
      if (raw is int &&
          raw >= ProfileMvpInitialTabIndex.posts &&
          raw <= ProfileMvpInitialTabIndex.joined) {
        tab = raw;
      }
      return ProfileMvpPage(initialTabIndex: tab);
    },
    ProfileRoutes.setupDemo: (_) => ProfileSetupDemoPage(
          onProfileSaved: SmeetShell.refreshAuthState,
        ),
  };
}

const List<MvpDebugLauncherItem> _kMvpDebugLauncherItems = [
  MvpDebugLauncherItem(
    label: 'Feed MVP',
    route: FeedRoutes.list,
    icon: Icons.dynamic_feed_outlined,
  ),
  MvpDebugLauncherItem(
    label: 'Inbox MVP',
    route: InboxRoutes.list,
    icon: Icons.inbox_outlined,
  ),
  MvpDebugLauncherItem(
    label: 'Create MVP',
    route: CreateRoutes.hub,
    icon: Icons.add_circle_outline,
  ),
  MvpDebugLauncherItem(
    label: 'Notifications MVP',
    route: NotificationsRoutes.list,
    icon: Icons.notifications_outlined,
  ),
  MvpDebugLauncherItem(
    label: 'Profile MVP',
    route: ProfileRoutes.list,
    icon: Icons.person_outline,
  ),
  MvpDebugLauncherItem(
    label: 'Profile Setup (debug)',
    route: ProfileRoutes.setupDemo,
    icon: Icons.manage_accounts_outlined,
  ),
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final cfg = resolveSupabaseConfig();
  // supabase package defaults to AuthFlowType.pkce; no need to pass authOptions.
  await Supabase.initialize(
    url: cfg.url,
    anonKey: cfg.anonKey,
  );

  final namedRoutes =
      kReleaseMode ? const <String, WidgetBuilder>{} : _smeetNamedRoutesForNonRelease();

  runApp(
    SmeetApp(
      home: const SmeetShell(),
      routes: namedRoutes,
      showMvpDebugLauncher: kDebugMode,
      mvpDebugLauncherItems:
          kReleaseMode ? const <MvpDebugLauncherItem>[] : _kMvpDebugLauncherItems,
    ),
  );
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // Auth + profile onboarding live in [SmeetShell] ([ShellAuthPhase]).
    // Guests browse until an action calls `_ensureLoginAndPrompt`.
    return const SmeetShell();
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

/// Friendly login errors — never show raw Supabase strings in the UI.
String _loginFailureUserMessage(Object error) {
  const fallback = 'Oops, we couldn’t log you in.\n\n'
      'New to Smeet?\n'
      'Tap “Sign up” below to create your account.\n\n'
      'Already have an account?\n'
      'Check your email and password, then try again.';

  if (error is AuthException) {
    final code = (error.code ?? '').toLowerCase();
    final msg = error.message.toLowerCase();

    if (code == 'email_not_confirmed' ||
        msg.contains('email not confirmed') ||
        msg.contains('email_not_confirmed')) {
      return 'Please verify your email before logging in. '
          'Check your inbox (and spam folder).';
    }
    if (code == 'user_not_found' || msg.contains('user not found')) {
      return 'This account doesn’t exist yet. '
          'Tap “Sign up” below to create your account.';
    }
    if (code == 'invalid_credentials' ||
        code == 'invalid_grant' ||
        msg.contains('invalid login') ||
        msg.contains('invalid credentials')) {
      return 'That email or password doesn’t look right. Please try again.';
    }
  }

  final raw = error.toString().toLowerCase();
  if (raw.contains('email not confirmed') || raw.contains('email_not_confirmed')) {
    return 'Please verify your email before logging in. '
        'Check your inbox (and spam folder).';
  }
  if (raw.contains('user not found')) {
    return 'This account doesn’t exist yet. '
        'Tap “Sign up” below to create your account.';
  }
  if (raw.contains('invalid login') || raw.contains('invalid credentials')) {
    return 'That email or password doesn’t look right. Please try again.';
  }
  return fallback;
}

String _signupFailureUserMessage(Object error) {
  if (error is AuthException) {
    final code = (error.code ?? '').toLowerCase();
    final msg = error.message.toLowerCase();
    if (code == 'user_already_exists' ||
        msg.contains('already registered') ||
        msg.contains('already been registered') ||
        (msg.contains('user') && msg.contains('already'))) {
      return 'That email is already on Smeet. Try logging in instead.';
    }
    if (msg.contains('password') &&
        (msg.contains('weak') || msg.contains('short') || msg.contains('least'))) {
      return 'Please choose a stronger password (longer is better).';
    }
    if (msg.contains('email') && msg.contains('invalid')) {
      return 'That email doesn’t look valid. Double-check and try again.';
    }
  }
  return 'We couldn’t create your account. '
      'Check your email and password, then try again.';
}

String _forgotPasswordUserMessage(Object error) {
  if (error is AuthException) {
    final msg = error.message.toLowerCase();
    if (msg.contains('rate limit') || msg.contains('too many')) {
      return 'Too many attempts. Please wait a bit and try again.';
    }
    if (msg.contains('invalid') && msg.contains('email')) {
      return 'That email doesn’t look valid. Please check and try again.';
    }
  }
  return 'We couldn’t send the email. Check your connection and try again.';
}

bool _emailLooksReasonable(String email) {
  final t = email.trim();
  return t.contains('@') && t.length > 3 && !t.startsWith('@');
}

Widget _authGuidanceLine(BuildContext context, String index, String text) {
  final cs = Theme.of(context).colorScheme;
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: cs.primary.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          index,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: cs.primary,
              ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ),
    ],
  );
}

class _ForgotPasswordDialog extends StatefulWidget {
  final TextEditingController emailController;

  const _ForgotPasswordDialog({required this.emailController});

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  bool _sending = false;
  String? _errorText;

  Future<void> _send() async {
    final email = widget.emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorText = 'Please enter your email');
      return;
    }
    if (!_emailLooksReasonable(email)) {
      setState(() => _errorText = 'Please enter a valid email address');
      return;
    }
    setState(() {
      _sending = true;
      _errorText = null;
    });
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: kIsWeb ? '${Uri.base.origin}/' : null,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('[auth] resetPasswordForEmail failed: $e');
      if (mounted) {
        setState(() {
          _sending = false;
          _errorText = _forgotPasswordUserMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reset your password'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Enter your email and we’ll send you a link to choose a new password.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: widget.emailController,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'Email',
                errorText: _errorText,
              ),
              autofocus: true,
              onSubmitted: (_) {
                if (!_sending) _send();
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _sending ? null : _send,
          child: _sending
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send reset link'),
        ),
      ],
    );
  }
}

class _AuthPageState extends State<AuthPage> {
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _isLogin = true;
  bool _loading = false;
  bool _obscurePassword = true;
  /// Required before sign-up can proceed (login unaffected).
  bool _acceptedTermsAndPrivacy = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _showForgotPassword() async {
    final ctrl = TextEditingController(text: _emailCtrl.text.trim());
    final sent = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ForgotPasswordDialog(emailController: ctrl),
    );
    ctrl.dispose();
    if (sent == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Check your email to reset your password.',
          ),
          duration: Duration(seconds: 6),
        ),
      );
    }
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final password = _pwCtrl.text;

    if (email.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email.')),
      );
      return;
    }
    if (!_emailLooksReasonable(email)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('That email doesn’t look quite right. Please check it.'),
        ),
      );
      return;
    }
    if (password.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your password.')),
      );
      return;
    }
    if (!_isLogin && !_acceptedTermsAndPrivacy) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please agree to the Terms of Use and Privacy Policy '
            'before creating your account.',
          ),
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final auth = Supabase.instance.client.auth;

      // Runtime evidence for web auth / CORS debugging (see browser / Flutter console).
      if (kIsWeb) {
        debugPrint(
          '[auth] web origin=${Uri.base.origin} path=${Uri.base.path} '
          'mode=${_isLogin ? "login" : "signup"}',
        );
      }
      // #region agent log
      debugPrint(
        '[agent_ndjson] ${jsonEncode({
          'sessionId': '2e4d4f',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'location': 'main.dart:_AuthPageState._submit',
          'message': 'auth_attempt',
          'hypothesisId': 'H1_origin',
          'data': {
            'isWeb': kIsWeb,
            if (kIsWeb) 'origin': Uri.base.origin,
            'path': Uri.base.path,
            'mode': _isLogin ? 'login' : 'signup',
          },
        })}',
      );
      // #endregion

      if (_isLogin) {
        await auth.signInWithPassword(email: email, password: password);
        // #region agent log
        debugPrint(
          '[agent_ndjson] ${jsonEncode({
            'sessionId': '2e4d4f',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'location': 'main.dart:_AuthPageState._submit',
            'message': 'auth_ok',
            'hypothesisId': 'H0_success',
            'data': {
              'isWeb': kIsWeb,
              if (kIsWeb) 'origin': Uri.base.origin,
              'mode': 'login',
            },
          })}',
        );
        // #endregion
        debugPrint(
          '[Auth] after login currentUser=${Supabase.instance.client.auth.currentUser?.id}',
        );
        debugPrint(
          '[Auth] session=${Supabase.instance.client.auth.currentSession}',
        );
        if (mounted) Navigator.of(context).pop();
        // Shell may miss auth stream timing when this route pops; ensure onboarding runs.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          SmeetShell.refreshAuthState();
        });
      } else {
        // On web, Supabase may require the redirect URL to be on the allow list
        // (URL Configuration -> Redirect URLs) for email confirmation flows.
        final res = await auth.signUp(
          email: email,
          password: password,
          emailRedirectTo: kIsWeb ? '${Uri.base.origin}/' : null,
        );
        // #region agent log
        debugPrint(
          '[agent_ndjson] ${jsonEncode({
            'sessionId': '2e4d4f',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'location': 'main.dart:_AuthPageState._submit',
            'message': 'auth_ok',
            'hypothesisId': 'H0_success',
            'data': {
              'isWeb': kIsWeb,
              if (kIsWeb) 'origin': Uri.base.origin,
              'mode': 'signup',
              'hasSession': res.session != null,
            },
          })}',
        );
        // #endregion
        if (!mounted) return;
        final hasSession = res.session != null;
        final signupTitle = 'Welcome to Smeet';
        final signupMessage = hasSession
            ? 'Account created. You can now log in.'
            : 'Account created. Please check your email and verify your '
                'account before logging in.';
        final signupHint = hasSession
            ? null
            : 'Tip: check your spam folder if you don’t see the message.';
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Text(signupTitle),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    signupMessage,
                    style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(height: 1.45),
                  ),
                  if (signupHint != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      signupHint,
                      style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                            height: 1.4,
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  if (!mounted) return;
                  if (hasSession) {
                    Navigator.of(context).pop();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      SmeetShell.refreshAuthState();
                    });
                  } else {
                    setState(() {
                      _isLogin = true;
                      _pwCtrl.clear();
                    });
                  }
                },
                child: const Text('Got it'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('[auth] failed: $e');
      final msg = e.toString();
      final isWebFetchFail =
          kIsWeb && msg.contains('Failed to fetch');
      // #region agent log
      debugPrint(
        '[agent_ndjson] ${jsonEncode({
          'sessionId': '2e4d4f',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'location': 'main.dart:_AuthPageState._submit',
          'message': 'auth_failed',
          'hypothesisId': 'H2_fetch_layer',
          'data': {
            'isWeb': kIsWeb,
            if (kIsWeb) 'origin': Uri.base.origin,
            'errorType': e.runtimeType.toString(),
            'failedToFetch': isWebFetchFail,
          },
        })}',
      );
      // #endregion
      final snackText = isWebFetchFail
          ? 'We can’t reach the sign-in service from this browser.\n\n'
              'If you’re testing on web, use a fixed port (e.g. 8080) and add '
              'that URL under Supabase → Authentication → URL Configuration. '
              'See WEB_AUTH.md for steps.\n\n'
              '(Technical: $msg)'
          : _isLogin
              ? _loginFailureUserMessage(e)
              : _signupFailureUserMessage(e);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: Duration(seconds: _isLogin ? 16 : 12),
          content: Text(snackText),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(_isLogin ? 'Log in' : 'Sign up')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isLogin) ...[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: cs.primary.withOpacity(0.2),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'New to Smeet?',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: cs.onPrimaryContainer,
                                  ),
                        ),
                        const SizedBox(height: 12),
                        _authGuidanceLine(context, '1', 'Sign up for an account'),
                        const SizedBox(height: 8),
                        _authGuidanceLine(
                          context,
                          '2',
                          '(If required) verify your email',
                        ),
                        const SizedBox(height: 8),
                        _authGuidanceLine(
                          context,
                          '3',
                          'Sign in to start matching with people near you.',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ] else ...[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: cs.outlineVariant.withOpacity(0.5),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create your account',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'You’ll use this email to log in and get match updates. '
                          'If your organizer asks for email verification, check your inbox '
                          'after signing up — then come back and use Login.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    height: 1.45,
                                    color: cs.onSurface.withOpacity(0.88),
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _pwCtrl,
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  if (!_loading) _submit();
                },
              ),
              if (!_isLogin) ...[
                const SizedBox(height: 14),
                SignupLegalAgreement(
                  accepted: _acceptedTermsAndPrivacy,
                  loading: _loading,
                  onChanged: (v) =>
                      setState(() => _acceptedTermsAndPrivacy = v ?? false),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: Text(
                    _loading
                        ? 'Please wait…'
                        : (_isLogin ? 'Log in' : 'Create account'),
                  ),
                ),
              ),
              if (_isLogin) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.center,
                  child: TextButton(
                    onPressed: _loading ? null : _showForgotPassword,
                    child: const Text('Forgot password?'),
                  ),
                ),
              ],
              const SizedBox(height: 4),
              TextButton(
                onPressed: _loading
                    ? null
                    : () => setState(() {
                          _isLogin = !_isLogin;
                          if (!_isLogin) {
                            _acceptedTermsAndPrivacy = false;
                          }
                        }),
                child: Text(
                  _isLogin
                      ? 'New here? Sign up'
                      : 'Already have an account? Log in',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ensures the user is logged in before performing an action.
/// Returns `true` if the user is logged in, otherwise `false` (e.g. user cancels login).
Future<bool> _ensureLoginAndPrompt(BuildContext context) async {
  final auth = Supabase.instance.client.auth;
  if (auth.currentUser != null) return true;

  await Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const AuthPage()),
  );

  final ok = auth.currentUser != null;
  if (ok) {
    // Auth route may pop before onAuthStateChange reaches the shell.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SmeetShell.refreshAuthState();
    });
  }
  return ok;
}

/// --- 页面 1：Home（Create Game） ---
class HomePage extends StatefulWidget {
  final Set<String> joinedLocal;
  final VoidCallback? onGamesMutated;

  const HomePage({
    super.key,
    required this.joinedLocal,
    this.onGamesMutated,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Future<bool> _ensureLogin() async {
    // Reuse the shared login gating logic.
    return _ensureLoginAndPrompt(context);
  }

  final ScrollController _scrollCtrl = ScrollController();
  final GlobalKey _upcomingKey = GlobalKey();
  final _formKey = GlobalKey<FormState>();

  /// Realtime: `joined_count` / new rows update all clients without refresh.
  /// Enable replication for table `games` in Supabase → Database → Publications.
  late Stream<List<Map<String, dynamic>>> _gamesStream;

  // Form state
  String _sport = 'Tennis';
  /// Target level for this game (not the creator’s profile level).
  String _gameLevel = 'Beginner';
  static const _gameLevels = [
    'Beginner',
    'Intermediate',
    'Advanced',
    'Competitive',
    'Pro',
  ];
  DateTime? _gameDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  int _players = 4;
  LocationResult? _selectedLocation;
  final _courtFeeCtrl = TextEditingController(text: '20');

  /// True while Create Game is awaiting network; prevents double-submit and disables the CTA.
  bool _createGameSubmitting = false;

  /// Upcoming list filter (Phase 1) — default Australia / Brisbane / 15 km.
  String _filterCountry = 'Australia';
  String _filterCity = 'Brisbane';
  double _radiusKm = 15;

  (double, double) get _searchCenter {
    final m = kPresetCityCenters[_filterCountry];
    if (m != null && m.containsKey(_filterCity)) {
      final r = m[_filterCity]!;
      return (r.$1, r.$2);
    }
    return kPresetCityCenters['Australia']!['Brisbane']!;
  }

  List<Map<String, dynamic>> _filterUpcoming(
    List<Map<String, dynamic>> games,
  ) {
    final (lat0, lng0) = _searchCenter;
    final out = <Map<String, dynamic>>[];
    for (final g in games) {
      final players = (g['players'] as num?)?.toInt() ?? 0;
      final joined = (g['joined_count'] as num?)?.toInt() ?? 0;
      if (players <= 0 || joined >= players) continue;

      final la = g['location_lat'];
      final ln = g['location_lng'];
      if (la == null || ln == null) continue;

      final d = haversineKm(
        lat0,
        lng0,
        (la as num).toDouble(),
        (ln as num).toDouble(),
      );
      if (d <= _radiusKm) {
        out.add({...g, '_distance_km': d});
      }
    }
    out.sort((a, b) {
      final ta = DateTime.tryParse(a['starts_at']?.toString() ?? '');
      final tb = DateTime.tryParse(b['starts_at']?.toString() ?? '');
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return ta.compareTo(tb);
    });
    return out;
  }

  @override
  void initState() {
    super.initState();
    _gamesStream = _fetchGamesStream();
  }

  /// Recreate the games stream after an error (lightweight retry).
  void _retryGamesStream() {
    if (!mounted) return;
    setState(() {
      _gamesStream = _fetchGamesStream();
    });
  }

  Stream<List<Map<String, dynamic>>> _fetchGamesStream() {
    return Supabase.instance.client
        .from('games')
        .stream(primaryKey: ['id'])
        .order('created_at');
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _courtFeeCtrl.dispose();
    super.dispose();
  }

  double get _courtFee {
    final raw = _courtFeeCtrl.text.trim();
    final v = double.tryParse(raw);
    return (v == null || v < 0) ? 0 : v;
  }

  double get _perPerson {
    if (_players <= 0) return 0;
    return _courtFee / _players;
  }

  Future<void> _pickGameDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _gameDate ?? now,
      firstDate: now.subtract(const Duration(days: 0)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null) return;
    setState(() => _gameDate = date);
  }

  Future<void> _pickStartTime() async {
    final now = DateTime.now();
    final time = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.fromDateTime(now),
    );
    if (time == null) return;
    setState(() => _startTime = time);
  }

  TimeOfDay _defaultEndFromStart() {
    if (_startTime == null) {
      return TimeOfDay.fromDateTime(DateTime.now());
    }
    final base = DateTime(
      2020,
      1,
      1,
      _startTime!.hour,
      _startTime!.minute,
    );
    final end = base.add(const Duration(hours: 2));
    return TimeOfDay(hour: end.hour, minute: end.minute);
  }

  Future<void> _pickEndTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _endTime ?? _defaultEndFromStart(),
    );
    if (time == null) return;
    setState(() => _endTime = time);
  }

  /// Start/end on [_gameDate], with overnight sessions rolling `endsAt` to the next day.
  ({DateTime startsAt, DateTime endsAt})? _computeGameSchedule() {
    if (_gameDate == null || _startTime == null || _endTime == null) {
      return null;
    }
    DateTime combine(DateTime d, TimeOfDay t) =>
        DateTime(d.year, d.month, d.day, t.hour, t.minute);
    final startsAt = combine(_gameDate!, _startTime!);
    var endsAt = combine(_gameDate!, _endTime!);
    if (!endsAt.isAfter(startsAt)) {
      endsAt = endsAt.add(const Duration(days: 1));
    }
    if (!endsAt.isAfter(startsAt)) {
      return null;
    }
    return (startsAt: startsAt, endsAt: endsAt);
  }

  /// Sync checks for Create Game (after [FormState.validate]). Returns a user-facing message or null.
  String? _validateCreateGameFields() {
    if (_sport.trim().isEmpty) {
      return 'Please select a sport.';
    }
    if (_gameLevel.trim().isEmpty) {
      return 'Please select a game level.';
    }
    if (_gameDate == null || _startTime == null || _endTime == null) {
      return 'Please select date, start time, and end time.';
    }
    if (_computeGameSchedule() == null) {
      return 'End time must be after start time.';
    }
    if (_players < 2 || _players > 12) {
      return 'Please choose a valid number of players.';
    }
    final feeRaw = _courtFeeCtrl.text.trim();
    final feeVal = double.tryParse(feeRaw);
    if (feeVal == null || feeVal < 0) {
      return 'Please enter a valid court fee.';
    }
    // Require a structured pick from suggestions, not only free-typed text.
    if (_selectedLocation == null) {
      return 'Please choose a location from the suggestions.';
    }
    final loc = _selectedLocation!;
    if (loc.address.trim().isEmpty ||
        !loc.lat.isFinite ||
        !loc.lng.isFinite) {
      return 'Please choose a location from the suggestions.';
    }
    return null;
  }

  String _friendlyGameInsertError(Object e) {
    debugPrint('[CreateGame] games.insert failed: $e');
    if (e is PostgrestException) {
      debugPrint(
        '[CreateGame] PostgrestException code=${e.code} message=${e.message} '
        'details=${e.details} hint=${e.hint}',
      );
    }
    return 'Couldn’t create the game. Please check your details and try again.';
  }

  Future<void> _createGame() async {
    if (_createGameSubmitting) return;
    if (!await _ensureLogin()) return;
    if (!_formKey.currentState!.validate()) return;

    final validationError = _validateCreateGameFields();
    if (validationError != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError)),
      );
      return;
    }

    final sched = _computeGameSchedule()!;
    final startsAt = sched.startsAt;
    final endsAt = sched.endsAt;

    final loc = _selectedLocation!;
    final locAddress = loc.address.trim();
    final locLat = loc.lat;
    final locLng = loc.lng;
    final fee = _courtFee;
    final each = _perPerson;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to create a game.')),
      );
      return;
    }

    setState(() => _createGameSubmitting = true);
    try {
      final supabase = Supabase.instance.client;

      final result = await supabase
          .from('games')
          .insert({
            'sport': _sport,
            'game_level': _gameLevel,
            'starts_at': startsAt.toUtc().toIso8601String(),
            'ends_at': endsAt.toUtc().toIso8601String(),
            'location_text': locAddress,
            'location_lat': locLat,
            'location_lng': locLng,
            'players': _players,
            'court_fee': fee,
            'per_person': each,
            'created_by': user.id,
          })
          .select('id')
          .single();

      final gameId = result['id'].toString();
      debugPrint('[CreateGameChat] Game inserted OK id=$gameId');

      var chatRowInserted = false;
      var gameLinkedToChat = false;

      try {
        final chatTitle = '$_sport game';
        final chatPayload = <String, dynamic>{
          'chat_kind': 'game',
          'game_id': gameId,
          'title': chatTitle,
        };
        debugPrint(
          '[CreateGameChat] BEFORE chats.insert → public.chats payload: '
          '${jsonEncode(chatPayload)}',
        );

        final chatRow = await supabase
            .from('chats')
            .insert(chatPayload)
            .select('id')
            .single();

        debugPrint(
          '[CreateGameChat] AFTER chats.insert returned row: $chatRow',
        );
        final chatId = chatRow['id']?.toString();
        if (chatId == null || chatId.isEmpty) {
          throw StateError('chats.insert returned no id (row=$chatRow)');
        }
        chatRowInserted = true;
        debugPrint('[CreateGameChat] Step A: resolved chat_id=$chatId');

        debugPrint(
          '[CreateGameChat] Step B: UPDATE games SET game_chat_id=$chatId WHERE id=$gameId ...',
        );
        final afterUpdate = await supabase
            .from('games')
            .update({'game_chat_id': chatId})
            .eq('id', gameId)
            .select('id, game_chat_id')
            .maybeSingle();

        debugPrint(
          '[CreateGameChat] Step B: games update select result = $afterUpdate',
        );

        if (afterUpdate == null) {
          debugPrint(
            '[CreateGameChat] Step B FAILED: UPDATE games returned no row — '
            'often RLS blocks UPDATE on games, or game id mismatch.',
          );
          gameLinkedToChat = false;
        } else {
          final linked = afterUpdate['game_chat_id']?.toString();
          if (linked != chatId) {
            debugPrint(
              '[CreateGameChat] Step B WARNING: DB game_chat_id=$linked expected $chatId',
            );
            gameLinkedToChat = false;
          } else {
            debugPrint(
              '[CreateGameChat] Step B OK: games.game_chat_id is set to $linked',
            );
            gameLinkedToChat = true;
          }
        }
      } catch (e, st) {
        debugPrint('[CreateGameChat] EXCEPTION during chat setup: $e');
        debugPrint('[CreateGameChat] stackTrace: $st');
        if (e is PostgrestException) {
          debugPrint(
            '[CreateGameChat] PostgrestException (chats insert / select): '
            'toString() => ${e.toString()}',
          );
          debugPrint(
            '[CreateGameChat] PostgrestException fields: '
            'code=${e.code} message=${e.message} details=${e.details} hint=${e.hint}',
          );
        }
        // Do not clear [chatRowInserted]: insert may have succeeded before a later step failed.
        gameLinkedToChat = false;
      }

      var joinOk = true;
      try {
        debugPrint(
          '[CreateGameChat] Step C: RPC join_game(p_game_id=$gameId) ...',
        );
        await supabase.rpc('join_game', params: {'p_game_id': gameId});
        debugPrint('[CreateGameChat] Step C OK: join_game finished');
      } catch (e, st) {
        joinOk = false;
        debugPrint('[CreateGameChat] Step C FAILED join_game: $e');
        debugPrint('[CreateGameChat] stackTrace: $st');
        if (e is PostgrestException) {
          debugPrint(
            '[CreateGameChat] PostgrestException: code=${e.code} message=${e.message} details=${e.details} hint=${e.hint}',
          );
        }
      }

      if (!mounted) return;

      if (!chatRowInserted || !gameLinkedToChat) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Your game is live, but the group chat isn’t ready yet. '
              'You can still see it in the list below.',
            ),
            duration: Duration(seconds: 6),
          ),
        );
      } else if (!joinOk) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your game is live.'),
            duration: Duration(seconds: 4),
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'We couldn’t add you to the player list automatically. '
              'Open My Game to join this session.',
            ),
            duration: Duration(seconds: 8),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your game is live.'),
            duration: Duration(seconds: 4),
          ),
        );
      }

      setState(() {
        _sport = 'Tennis';
        _gameLevel = 'Beginner';
        _gameDate = null;
        _startTime = null;
        _endTime = null;
        _players = 4;
        _selectedLocation = null;
        _courtFeeCtrl.text = '20';
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _upcomingKey.currentContext;
        if (ctx == null) return;
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          alignment: 0.1,
        );
      });
      widget.onGamesMutated?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyGameInsertError(e))),
      );
    } finally {
      if (mounted) {
        setState(() => _createGameSubmitting = false);
      }
    }
  }

  Future<void> _joinGame(String gameId) async {
    if (!await _ensureLogin()) return;
    try {
      final supabase = Supabase.instance.client;
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          const SnackBar(content: Text('Please sign in to join a game.')),
        );
        return;
      }

      if (widget.joinedLocal.contains(gameId)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You’re already in this game.')),
        );
        return;
      }

      // Phase 2: prefer RPC + game_participants (run supabase migration).
      try {
        await supabase.rpc('join_game', params: {'p_game_id': gameId});
      } catch (e) {
        // Legacy fallback if RPC / table not deployed yet
        final row = await supabase
            .from('games')
            .select('joined_count, players')
            .eq('id', gameId)
            .maybeSingle();
        if (row == null) {
          throw Exception('Game not found or blocked by RLS');
        }
        final joined = (row['joined_count'] as num?)?.toInt() ?? 0;
        final players = (row['players'] as num?)?.toInt() ?? 0;
        if (joined >= players) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This game is full.')),
          );
          return;
        }
        final updated = await supabase
            .from('games')
            .update({'joined_count': joined + 1})
            .eq('id', gameId)
            .select('id, joined_count')
            .maybeSingle();
        if (updated == null) {
          throw Exception('No row updated (RLS?)');
        }
      }

      // join_game RPC (updated migration) also adds this user to game_chat_id group chat.

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You’re in! Find this game under My Game.'),
        ),
      );

      setState(() {
        widget.joinedLocal.add(gameId);
      });
      widget.onGamesMutated?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_userFacingJoinGameError(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    String dateLabel;
    if (_gameDate == null) {
      dateLabel = 'Select date';
    } else {
      final dt = _gameDate!;
      final y = dt.year.toString().padLeft(4, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      dateLabel = '$y-$m-$d';
    }

    String startLabel =
        _startTime == null ? 'Select start time' : _startTime!.format(context);
    String endLabel =
        _endTime == null ? 'Select end time' : _endTime!.format(context);

    return SingleChildScrollView(
      controller: _scrollCtrl,
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // Header card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: cs.primary.withOpacity(0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create Game',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Set sport, level, time, place, headcount, and cost — '
                    'it appears below for others to join.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurface.withOpacity(0.7),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Sport
            _SectionCard(
              child: DropdownButtonFormField<String>(
                initialValue: _sport,
                decoration: const InputDecoration(
                  labelText: 'Sport',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Tennis', child: Text('Tennis')),
                  DropdownMenuItem(value: 'Golf', child: Text('Golf')),
                  DropdownMenuItem(
                    value: 'Pickleball',
                    child: Text('Pickleball'),
                  ),
                  DropdownMenuItem(
                    value: 'Badminton',
                    child: Text('Badminton'),
                  ),
                  DropdownMenuItem(value: 'Ski', child: Text('Ski')),
                  DropdownMenuItem(
                    value: 'Snowboard',
                    child: Text('Snowboard'),
                  ),
                ],
                onChanged: (v) => setState(() => _sport = v ?? 'Tennis'),
              ),
            ),

            // Game level (target level for this game)
            _SectionCard(
              child: DropdownButtonFormField<String>(
                initialValue: _gameLevel,
                decoration: const InputDecoration(
                  labelText: 'Game level (target for this game)',
                  border: OutlineInputBorder(),
                  helperText:
                      'Suitable skill level for this session — not your profile level',
                ),
                items: _gameLevels
                    .map(
                      (lv) => DropdownMenuItem(value: lv, child: Text(lv)),
                    )
                    .toList(),
                onChanged: (v) =>
                    setState(() => _gameLevel = v ?? _gameLevels.first),
              ),
            ),

            // Game date
            _SectionCard(
              child: InkWell(
                onTap: _pickGameDate,
                borderRadius: BorderRadius.circular(14),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Game date',
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined),
                      const SizedBox(width: 10),
                      Expanded(child: Text(dateLabel)),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            ),

            // Start / end time
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkWell(
                    onTap: _pickStartTime,
                    borderRadius: BorderRadius.circular(14),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Start time',
                        border: OutlineInputBorder(),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.schedule),
                          const SizedBox(width: 10),
                          Expanded(child: Text(startLabel)),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _pickEndTime,
                    borderRadius: BorderRadius.circular(14),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'End time',
                        border: OutlineInputBorder(),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.schedule_outlined),
                          const SizedBox(width: 10),
                          Expanded(child: Text(endLabel)),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Location
            _SectionCard(
              child: LocationSearchField(
                supabase: Supabase.instance.client,
                labelText: 'Location',
                hintText: 'Search a court, suburb, or full address',
                initialValue: _selectedLocation,
                onChanged: (value) {
                  setState(() => _selectedLocation = value);
                },
              ),
            ),

            // Players + fee
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Players
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Players',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        onPressed: _players <= 2
                            ? null
                            : () => setState(() => _players--),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text('$_players', style: const TextStyle(fontSize: 18)),
                      IconButton(
                        onPressed: _players >= 12
                            ? null
                            : () => setState(() => _players++),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Court fee
                  TextFormField(
                    controller: _courtFeeCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Court fee (total)',
                      prefixText: '\$ ',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      final s = (v ?? '').trim();
                      final d = double.tryParse(s);
                      if (d == null) return 'Please enter a number';
                      if (d < 0) return 'Fee can’t be negative';
                      return null;
                    },
                  ),

                  const SizedBox(height: 12),

                  // Split preview
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cs.primary.withOpacity(0.18)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calculate_outlined),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Per person: \$${_perPerson.toStringAsFixed(2)}/pp',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // CTA
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _createGameSubmitting ? null : _createGame,
                icon: _createGameSubmitting
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      )
                    : const Icon(Icons.add),
                label: Text(
                  _createGameSubmitting ? 'Creating…' : 'Create Game',
                ),
              ),
            ),

            const SizedBox(height: 10),

            Text(
              'Games you host show up in this list right away.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withOpacity(0.55),
              ),
            ),

            const SizedBox(height: 18),
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Browse near you',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _filterCountry,
                    decoration: const InputDecoration(
                      labelText: 'Country',
                      border: OutlineInputBorder(),
                    ),
                    items: kPresetCityCenters.keys
                        .map(
                          (c) => DropdownMenuItem(value: c, child: Text(c)),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _filterCountry = v;
                        final cities = kPresetCityCenters[v]?.keys.toList();
                        if (cities != null &&
                            cities.isNotEmpty &&
                            !cities.contains(_filterCity)) {
                          _filterCity = cities.first;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  Builder(
                    builder: (context) {
                      final cities = kPresetCityCenters[_filterCountry]
                              ?.keys
                              .toList() ??
                          <String>['Brisbane'];
                      final cityVal =
                          cities.contains(_filterCity) ? _filterCity : cities.first;
                      return DropdownButtonFormField<String>(
                        initialValue: cityVal,
                        decoration: const InputDecoration(
                          labelText: 'City / area',
                          border: OutlineInputBorder(),
                        ),
                        items: cities
                            .map(
                              (c) =>
                                  DropdownMenuItem(value: c, child: Text(c)),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _filterCity = v);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Radius',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [5.0, 10.0, 15.0, 25.0, 50.0].map((km) {
                      final sel = _radiusKm == km;
                      return ChoiceChip(
                        label: Text('${km.toInt()} km'),
                        selected: sel,
                        onSelected: (_) => setState(() => _radiusKm = km),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            Align(
              key: _upcomingKey,
              alignment: Alignment.centerLeft,
              child: Text(
                'Upcoming Games',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 10),

            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _gamesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const AppLoadingState(
                    message: 'Loading games…',
                  );
                }

                if (snapshot.hasError) {
                  return AppErrorState(
                    message: 'We couldn’t load games. Tap Retry.',
                    onRetry: _retryGamesStream,
                  );
                }

                final games = snapshot.data ?? [];
                final sortedGames = games.reversed.toList();
                final visible = _filterUpcoming(sortedGames);

                if (sortedGames.isEmpty) {
                  return const AppEmptyState(
                    icon: Icons.sports_tennis,
                    title: 'No games yet',
                    subtitle:
                        'Create one with the form above, or check back later.',
                  );
                }

                if (visible.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.location_searching,
                    title: 'No games in this area yet.',
                    subtitle:
                        'No joinable games within ${_radiusKm.toInt()} km of $_filterCity. '
                        'Try a larger radius or another city.',
                  );
                }

                return Column(
                  children: visible.map((g) {
                    final sport = g['sport'] ?? '';
                    final gameLevel =
                        (g['game_level'] ?? '').toString().trim();
                    final loc = g['location_text'] ?? '';
                    final players = (g['players'] as num?)?.toInt() ?? 0;
                    final joined = (g['joined_count'] as num?)?.toInt() ?? 0;
                    final remaining = (players - joined) < 0
                        ? 0
                        : (players - joined);
                    final gameId = g['id'].toString();
                    final perPerson = (g['per_person'] ?? 0.0) as num;
                    final isJoined = widget.joinedLocal.contains(gameId);
                    final distKm = (g['_distance_km'] as double?) ?? 0.0;

                    DateTime? startsAt;
                    if (g['starts_at'] != null) {
                      startsAt = DateTime.tryParse(g['starts_at'])?.toLocal();
                    }
                    DateTime? endsAt;
                    if (g['ends_at'] != null) {
                      endsAt = DateTime.tryParse(g['ends_at'])?.toLocal();
                    }

                    final dateLine = formatGameDateHeading(startsAt);
                    final timeRange = formatGameTimeRange(startsAt, endsAt);

                    final suburb = loc.split(',').first.trim();
                    final sportLevelLine = gameLevel.isEmpty
                        ? sport.toString()
                        : '$sport • $gameLevel';

                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.12),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.sports,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  sportLevelLine,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  dateLine,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  timeRange,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  suburb.isEmpty
                                      ? formatDistanceKm(distKm)
                                      : '$suburb • ${formatDistanceKm(distKm)}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$remaining spots left • \$${perPerson.toStringAsFixed(2)}/pp',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            onPressed:
                                isJoined ? null : () => _joinGame(gameId),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: Text(isJoined ? 'Joined' : 'Join'),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// 一个小卡片容器：统一间距与白底圆角
class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 6),
            color: Colors.black.withOpacity(0.04),
          ),
        ],
      ),
      child: child,
    );
  }
}

const List<String> _kSwipeMatchOpeners = [
  'Ask what they’re playing this week.',
  'Comment on a sport you have in common.',
  'Suggest a casual hit or practice session.',
];

class _SwipeMatchAvatar extends StatelessWidget {
  const _SwipeMatchAvatar({
    required this.url,
    required this.fallbackLabel,
  });

  final String? url;
  final String fallbackLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hasUrl = url != null && url!.isNotEmpty;
    final t = fallbackLabel.trim();
    final initial =
        t.isEmpty ? '?' : t.substring(0, 1).toUpperCase();
    return CircleAvatar(
      radius: 44,
      backgroundColor: cs.primaryContainer,
      backgroundImage: hasUrl ? NetworkImage(url!) : null,
      child: hasUrl
          ? null
          : Text(
              initial,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: cs.onPrimaryContainer,
              ),
            ),
    );
  }
}

/// --- 页面 2：Swipe（找搭子） ---
class SwipePage extends StatefulWidget {
  const SwipePage({super.key});

  @override
  State<SwipePage> createState() => _SwipePageState();
}

class _SwipePageState extends State<SwipePage> {
  User? get _user => Supabase.instance.client.auth.currentUser;

  bool _loading = false;
  String? _error;

  Map<String, dynamic>? _myProfile;
  List<Map<String, dynamic>> _candidates = [];
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (_user == null) {
      setState(() {
        _loading = true;
        _error = null;
      });

      try {
        _myProfile = null;
        await _loadGuestCandidates();
        _index = 0;
      } catch (e) {
        if (mounted) {
          setState(() => _error = e.toString());
        } else {
          _error = e.toString();
        }
      } finally {
        if (mounted) {
          setState(() => _loading = false);
        }
      }

      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _loadMyProfile();
      await _loadCandidates();
      _index = 0;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMyProfile() async {
    final supabase = Supabase.instance.client;
    final u = _user!;
    final row = await supabase
        .from('profiles')
        .select(
          'id, display_name, city, intro, avatar_url, sport_levels, availability',
        )
        .eq('id', u.id)
        .maybeSingle();

    if (row == null) {
      throw Exception('Your profile not found. Please fill Profile and Save.');
    }

    _myProfile = row;
  }

  /// Guest-mode candidate loader (read-only browsing).
  /// Actions (like/pass) will still require login via `_swipe`.
  Future<void> _loadGuestCandidates() async {
    final supabase = Supabase.instance.client;

    final raw = await supabase
        .from('profiles')
        .select(
          'id, display_name, city, intro, avatar_url, sport_levels, availability',
        )
        .limit(50);

    _candidates = (raw as List).cast<Map<String, dynamic>>();
  }

  // 判断：是否有共同运动
  bool _hasCommonSport(Map<String, dynamic> other) {
    final mySl = _myProfile?['sport_levels'];
    final otSl = other['sport_levels'];

    if (mySl is! Map || otSl is! Map) return false;

    final mySports = mySl.keys.map((e) => e.toString()).toSet();
    final otSports = otSl.keys.map((e) => e.toString()).toSet();

    return mySports.intersection(otSports).isNotEmpty;
  }

  Future<void> _loadCandidates() async {
    final supabase = Supabase.instance.client;
    final u = _user!;

    // 1) 取我已经 swipe 过的人（避免重复出现）
    final swiped = await supabase
        .from('swipes')
        .select('to_user')
        .eq('from_user', u.id);

    final swipedIds = (swiped as List)
        .map((e) => e['to_user']?.toString())
        .whereType<String>()
        .toSet();

    // 2) 拉一批 profiles（简单MVP：先拉 50 个，再本地过滤）
    final raw = await supabase
        .from('profiles')
        .select(
          'id, display_name, city, intro, avatar_url, sport_levels, availability',
        )
        .neq('id', u.id)
        .limit(50);

    final list = (raw as List).cast<Map<String, dynamic>>();

    // 3) 本地过滤：没 swipe 过 + 有共同运动（不限定等级或 availability）
    var filtered = list.where((p) {
      final id = p['id']?.toString();
      if (id == null) return false;
      if (swipedIds.contains(id)) return false;
      if (!_hasCommonSport(p)) return false;
      return true;
    }).toList();

    final blockSets = await BlockService.fetchMyBlockSets();
    filtered = filtered.where((p) {
      final id = p['id']?.toString();
      if (id == null) return false;
      return !blockSets.iBlocked.contains(id) &&
          !blockSets.blockedMe.contains(id);
    }).toList();

    _candidates = filtered;
  }

  Map<String, dynamic>? get _current {
    if (_index < 0 || _index >= _candidates.length) return null;
    return _candidates[_index];
  }

  /// Brief full-screen stamp; does not await network.
  void _flashDecisionStamp(String action) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    final isLike = action == 'like';
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => IgnorePointer(
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.92, end: 1.0),
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) {
              return Transform.scale(
                scale: scale,
                child: child,
              );
            },
            child: Text(
              isLike ? 'LIKE' : 'PASS',
              style: TextStyle(
                fontSize: 52,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: isLike
                    ? const Color(0xFF4ADE80).withValues(alpha: 0.92)
                    : Colors.white.withValues(alpha: 0.92),
                shadows: const [
                  Shadow(blurRadius: 16, color: Colors.black54),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Future<void>.delayed(const Duration(milliseconds: 240), () {
      entry.remove();
    });
  }

  Future<void> _showMatchCelebration({
    required String peerName,
    required String peerAvatarUrl,
    required String? selfAvatarUrl,
    required VoidCallback onSayHi,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final cs = theme.colorScheme;
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'It’s a match!',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'You and $peerName both liked each other.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.35,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _SwipeMatchAvatar(
                      url: selfAvatarUrl,
                      fallbackLabel: 'You',
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(
                        Icons.favorite_rounded,
                        color: cs.primary,
                        size: 32,
                      ),
                    ),
                    _SwipeMatchAvatar(
                      url: peerAvatarUrl.isEmpty ? null : peerAvatarUrl,
                      fallbackLabel: peerName,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Icebreakers',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ..._kSwipeMatchOpeners.map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ', style: TextStyle(color: cs.primary)),
                        Expanded(
                          child: Text(
                            line,
                            style: theme.textTheme.bodySmall?.copyWith(
                              height: 1.35,
                              color: cs.onSurface.withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      onSayHi();
                    },
                    child: const Text('Say hi'),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Keep swiping'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _swipe(String action) async {
    final cur = _current;
    if (cur == null) return;

    var u = _user;
    if (u == null) {
      // Guest users can browse, but swipe actions require login.
      final ok = await _ensureLoginAndPrompt(context);
      if (!ok) return;
      u = _user;
    }
    if (u == null) return;

    _flashDecisionStamp(action);
    setState(() => _loading = true);

    try {
      final supabase = Supabase.instance.client;
      final toUser = cur['id'].toString();

      // 1) 写入 swipes（upsert 防止重复）
      await supabase.from('swipes').upsert(
        {'from_user': u.id, 'to_user': toUser, 'action': action},
        onConflict: 'from_user,to_user', // ✅ 就是这一句
      );

      // 2) 如果 Like：检查对方是否也 Like 过我，成立则写入 matches
      if (action == 'like') {
        final back = await supabase
            .from('swipes')
            .select('id')
            .eq('from_user', toUser)
            .eq('to_user', u.id)
            .eq('action', 'like')
            .maybeSingle();

        if (back != null) {
          // 1) 规范化 pair，避免重复
          final a = u.id.compareTo(toUser) < 0 ? u.id : toUser;
          final b = u.id.compareTo(toUser) < 0 ? toUser : u.id;

          // 2) 写入 matches（你原本就有）
          await supabase.from('matches').upsert({'user_a': a, 'user_b': b});

          // 3) ✅ 创建一个 chat
          final chatRow = await supabase
              .from('chats')
              .insert({})
              .select('id')
              .single();
          final chatId = chatRow['id'];

          // 4) ✅ 把双方加入 chat_members
          await supabase.from('chat_members').insert([
            {'chat_id': chatId, 'user_id': a},
            {'chat_id': chatId, 'user_id': b},
          ]);

          if (!mounted) return;

          final otherName = (cur['display_name'] ?? 'Chat').toString();
          final peerAv = (cur['avatar_url'] ?? '').toString();
          final selfAv = _myProfile?['avatar_url']?.toString();

          await _showMatchCelebration(
            peerName: otherName,
            peerAvatarUrl: peerAv,
            selfAvatarUrl: selfAv,
            onSayHi: () {
              if (!mounted) return;
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ChatRoomPage(
                    chatId: chatId.toString(),
                    title: otherName,
                    chatKind: 'direct',
                    directPeerUserId: toUser,
                  ),
                ),
              );
            },
          );
        }
      }

      // 3) 下一张
      setState(() {
        _index += 1;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_userFacingSwipeError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Compact sport tags for the full-bleed card overlay (Tinder-style).
  List<Widget> _sportOverlayChips(Map<String, dynamic> p) {
    final sl = p['sport_levels'];
    if (sl is! Map) return const [];
    return sl.entries.take(8).map((e) {
      return Padding(
        padding: const EdgeInsets.only(right: 6, bottom: 6),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.32),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(
              '${e.key} · ${e.value}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
                height: 1.2,
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  String _overlapHint(Map<String, dynamic> other) {
    final myAv = _myProfile?['availability'];
    final otAv = other['availability'];
    if (myAv is! Map || otAv is! Map) return '';

    // 找到第一个重叠 slot 当提示
    for (final day in myAv.keys) {
      final mySlots = myAv[day];
      final otSlots = otAv[day];
      if (mySlots is List && otSlots is List) {
        final s1 = mySlots.map((e) => e.toString()).toSet();
        final s2 = otSlots.map((e) => e.toString()).toSet();
        final inter = s1.intersection(s2);
        if (inter.isNotEmpty) {
          return 'Same slot: $day ${inter.first}';
        }
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading && _candidates.isEmpty) {
      return const AppLoadingState(message: 'Finding people near you…');
    }

    if (_error != null) {
      return AppErrorState(
        message:
            'We couldn’t load people to show. Please try again.',
        onRetry: _user == null
            ? () async {
                final ok = await _ensureLoginAndPrompt(context);
                if (!ok) return;
                await _bootstrap();
              }
            : _bootstrap,
        retryLabel: _user == null ? 'Sign in / Retry' : 'Retry',
      );
    }

    final cur = _current;
    if (cur == null) {
      return AppEmptyState(
        icon: Icons.people_outline,
        title: 'No one new to show right now',
        subtitle: _user == null
            ? 'Sign in and finish your profile to see people you can connect with.'
            : 'Add a sport in Profile or pull to refresh — new people may appear later.',
        actionLabel: 'Refresh',
        onAction: _bootstrap,
      );
    }

    final name = (cur['display_name'] ?? 'Unknown').toString();
    final city = (cur['city'] ?? '').toString();
    final intro = (cur['intro'] ?? '').toString();
    final avatar = (cur['avatar_url'] ?? '').toString();
    final overlap = _overlapHint(cur);
    final sportChips = _sportOverlayChips(cur);

    final theme = Theme.of(context);
    final gradientHeight =
        (MediaQuery.sizeOf(context).height * 0.22).clamp(200.0, 320.0);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (_user == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: cs.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 20, color: cs.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Browsing as a guest — sign in to like or pass.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                        color: Colors.black.withValues(alpha: 0.10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(
                        color: cs.surfaceContainerHighest,
                      ),
                      if (avatar.isEmpty)
                        Center(
                          child: Icon(
                            Icons.person_rounded,
                            size: 96,
                            color: cs.primary.withValues(alpha: 0.35),
                          ),
                        )
                      else
                        Image.network(
                          avatar,
                          fit: BoxFit.cover,
                          width: constraints.maxWidth,
                          height: constraints.maxHeight,
                          errorBuilder: (context, error, stackTrace) => Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              size: 64,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: gradientHeight,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.78),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                height: 1.05,
                                shadows: const [
                                  Shadow(
                                    blurRadius: 12,
                                    color: Colors.black54,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  size: 18,
                                  color: Colors.white.withValues(alpha: 0.92),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    city.isEmpty ? 'City not set' : city,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.92,
                                      ),
                                      fontWeight: FontWeight.w600,
                                      shadows: const [
                                        Shadow(
                                          blurRadius: 8,
                                          color: Colors.black45,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (sportChips.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                'Sports',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.75),
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(children: sportChips),
                            ],
                            if (overlap.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                overlap,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.secondaryContainer
                                      .withValues(alpha: 0.95),
                                  fontWeight: FontWeight.w700,
                                  height: 1.35,
                                ),
                              ),
                            ],
                            if (intro.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                intro,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.88),
                                  height: 1.35,
                                  shadows: const [
                                    Shadow(
                                      blurRadius: 10,
                                      color: Colors.black45,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (_loading)
                        Positioned.fill(
                          child: ColoredBox(
                            color: Colors.black.withValues(alpha: 0.12),
                          ),
                        ),
                    ],
                  ),
                ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Material(
                color: Colors.white,
                elevation: 3,
                shadowColor: Colors.black26,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _loading ? null : () => _swipe('pass'),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: Icon(
                      Icons.close_rounded,
                      size: 36,
                      color: cs.error,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 40),
              Material(
                color: cs.primary,
                elevation: 4,
                shadowColor: Colors.black26,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _loading ? null : () => _swipe('like'),
                  child: SizedBox(
                    width: 76,
                    height: 76,
                    child: Icon(
                      Icons.favorite_rounded,
                      size: 38,
                      color: cs.onPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Showing ${_index + 1} / ${_candidates.length}',
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.55),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// --- 页面 3：My Game（我的局/我的预约） ---
class MyGamePage extends StatefulWidget {
  final Set<String> joinedLocal;
  final int listRevision;
  final VoidCallback? onGamesMutated;

  const MyGamePage({
    super.key,
    required this.joinedLocal,
    this.listRevision = 0,
    this.onGamesMutated,
  });

  @override
  State<MyGamePage> createState() => _MyGamePageState();
}

class _MyGamePageState extends State<MyGamePage> {
  late Future<List<Map<String, dynamic>>> _myGamesFuture;

  @override
  void initState() {
    super.initState();
    _myGamesFuture = _fetchMyGames();
  }

  @override
  void didUpdateWidget(MyGamePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listRevision != widget.listRevision) {
      _myGamesFuture = _fetchMyGames();
    }
  }

  Future<void> _leaveGame(String gameId) async {
    final ok = await _ensureLoginAndPrompt(context);
    if (!ok) return;

    try {
      final supabase = Supabase.instance.client;

      try {
        await supabase.rpc('leave_game', params: {'p_game_id': gameId});
      } catch (e) {
        // Legacy: decrement joined_count only
        final row = await supabase
            .from('games')
            .select('joined_count')
            .eq('id', gameId)
            .maybeSingle();
        final j = (row?['joined_count'] as num?)?.toInt() ?? 0;
        await supabase
            .from('games')
            .update({
              'joined_count': j > 0 ? j - 1 : 0,
            })
            .eq('id', gameId);
      }

      try {
        final g = await supabase
            .from('games')
            .select('game_chat_id')
            .eq('id', gameId)
            .maybeSingle();
        final cid = g?['game_chat_id']?.toString();
        final u = supabase.auth.currentUser;
        if (cid != null && u != null) {
          await supabase
              .from('chat_members')
              .delete()
              .eq('chat_id', cid)
              .eq('user_id', u.id);
        }
      } catch (_) {}

      widget.joinedLocal.remove(gameId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You’ve left this game.')),
      );

      setState(() {
        _myGamesFuture = _fetchMyGames();
      });
      widget.onGamesMutated?.call();
    } catch (e) {
      if (!mounted) return;

      final msg = e.toString().contains('NOT_JOINED_OR_EMPTY')
          ? 'You’re not in this game (or it’s already empty).'
          : 'Couldn’t leave. Please try again.';

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _attachRoster(Map<String, dynamic> g) async {
    final gid = g['id'].toString();
    final supabase = Supabase.instance.client;
    try {
      final parts = await supabase
          .from('game_participants')
          .select('user_id')
          .eq('game_id', gid)
          .eq('status', 'joined');
      final ids = (parts as List).map((e) => e['user_id'].toString()).toList();
      final host = (g['created_by'] ?? '').toString();
      if (host.isNotEmpty && !ids.contains(host)) {
        ids.add(host);
      }
      if (ids.isEmpty) {
        g['_profiles'] = <Map<String, dynamic>>[];
        return;
      }
      final profs = await supabase
          .from('profiles')
          .select('id, display_name, avatar_url, city, sport_levels')
          .inFilter('id', ids);
      final list = (profs as List).cast<Map<String, dynamic>>();
      final hostId = (g['created_by'] ?? '').toString();
      list.sort((a, b) {
        final aid = a['id']?.toString() ?? '';
        final bid = b['id']?.toString() ?? '';
        final aHost = aid.isNotEmpty && aid == hostId;
        final bHost = bid.isNotEmpty && bid == hostId;
        if (aHost != bHost) {
          return aHost ? -1 : 1;
        }
        return (a['display_name'] ?? '')
            .toString()
            .toLowerCase()
            .compareTo((b['display_name'] ?? '').toString().toLowerCase());
      });
      g['_profiles'] = list;
    } catch (_) {
      g['_profiles'] = <Map<String, dynamic>>[];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchMyGames() async {
    final supabase = Supabase.instance.client;
    final u = supabase.auth.currentUser;

    List<Map<String, dynamic>> games;

    if (u != null) {
      games =
          await JoinedGamesService(supabase).fetchJoinedGameRowsForCurrentUser();
    } else {
      games = [];
    }

    if (games.isEmpty && widget.joinedLocal.isNotEmpty) {
      final data = await supabase
          .from('games')
          .select(
            'id, sport, game_level, starts_at, ends_at, location_text, players, joined_count, per_person, created_by, created_at, game_chat_id',
          )
          .inFilter('id', widget.joinedLocal.toList())
          .order('starts_at', ascending: true);
      games = (data as List).cast<Map<String, dynamic>>();
    }

    for (final g in games) {
      await _attachRoster(g);
    }
    return games;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _myGamesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoadingState(message: 'Loading your games…');
        }
        if (snapshot.hasError) {
          return AppErrorState(
            message: 'We couldn’t load your games. Tap Retry.',
            onRetry: () {
              setState(() => _myGamesFuture = _fetchMyGames());
            },
          );
        }

        final games = snapshot.data ?? [];
        if (games.isEmpty) {
          final loggedIn = Supabase.instance.client.auth.currentUser != null;
          return AppEmptyState(
            icon: Icons.sports_outlined,
            title: loggedIn
                ? 'No joined games yet'
                : 'No games to show yet',
            subtitle: loggedIn
                ? 'Join a game from Home, or host your own.'
                : 'Sign in to see games you’ve joined. You can still browse Home as a guest.',
            actionLabel: loggedIn ? null : 'Sign in',
            onAction: loggedIn
                ? null
                : () async {
                    final ok = await _ensureLoginAndPrompt(context);
                    if (!mounted || !ok) return;
                    setState(() => _myGamesFuture = _fetchMyGames());
                  },
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: games.length,
          itemBuilder: (context, i) {
            final g = games[i];
            final sport = (g['sport'] ?? '').toString();
            final gameLevel =
                (g['game_level'] ?? '').toString().trim();
            final loc = (g['location_text'] ?? '').toString();
            final perPerson = (g['per_person'] ?? 0) as num;
            final createdBy = (g['created_by'] ?? '').toString();
            final joinedC = (g['joined_count'] as num?)?.toInt() ?? 0;
            final profiles =
                (g['_profiles'] as List?)?.cast<Map<String, dynamic>>() ??
                    const <Map<String, dynamic>>[];

            DateTime? startsAt;
            if (g['starts_at'] != null) {
              startsAt = DateTime.tryParse(g['starts_at'])?.toLocal();
            }
            DateTime? endsAt;
            if (g['ends_at'] != null) {
              endsAt = DateTime.tryParse(g['ends_at'])?.toLocal();
            }

            final dateLine = formatGameDateHeading(startsAt);
            final startLine = startsAt == null
                ? 'Start —'
                : 'Start: ${formatTime12h(startsAt)}';
            final endLine = endsAt == null
                ? 'End —'
                : 'End: ${formatTime12h(endsAt)}';
            final sportHeadline = gameLevel.isEmpty ? sport : '$sport • $gameLevel';
            final gameChatId = g['game_chat_id']?.toString();
            final chatTitle =
                (sport.isNotEmpty ? '$sport · ' : '') +
                    (loc.split(',').first.trim().isEmpty
                        ? 'Game chat'
                        : loc.split(',').first.trim());

            final balance = balanceLabelForGroup(
              sportKey: sport,
              playerProfiles: profiles.map((e) => e).toList(),
            );

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: cs.primary.withOpacity(0.12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          sportHeadline,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                      Text(
                        '\$${perPerson.toStringAsFixed(2)} each',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: cs.secondary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    dateLine,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    startLine,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    endLine,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    loc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$joinedC / ${g['players'] ?? '?'} players · $balance',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withOpacity(0.75),
                        ),
                  ),
                  const SizedBox(height: 10),
                  if (gameChatId != null && gameChatId.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ChatRoomPage(
                                chatId: gameChatId,
                                title: chatTitle,
                                chatKind: 'game',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const Text('Open group chat'),
                      ),
                    )
                  else
                    Text(
                      'Group chat isn’t available for this game yet.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    'Participants (${profiles.length})',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  ...profiles.map((p) {
                    final id = p['id']?.toString() ?? '';
                    final name =
                        (p['display_name'] ?? 'Player').toString().trim();
                    final avatar = (p['avatar_url'] ?? '').toString();
                    final city = (p['city'] ?? '').toString().trim();
                    final host = id.isNotEmpty && id == createdBy;
                    final lvl = sportLevelForSport(p, sport);
                    final subtitle = [
                      if (city.isNotEmpty) city,
                      '$sport: $lvl',
                    ].join(' · ');
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundImage:
                            avatar.isEmpty ? null : NetworkImage(avatar),
                        child: avatar.isEmpty
                            ? const Icon(Icons.person, size: 20)
                            : null,
                      ),
                      title: Text(
                        host ? '$name (host)' : name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(subtitle),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: id.isEmpty
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      OtherProfilePage(userId: id),
                                ),
                              );
                            },
                    );
                  }),
                  if (profiles.isEmpty)
                    Text(
                      'Player list will fill in as people join.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonal(
                      onPressed: () => _leaveGame(g['id'].toString()),
                      child: const Text('Leave game'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// --- 页面 4：Chat（聊天） ---
///
class ChatPage extends StatefulWidget {
  const ChatPage({super.key, this.onTotalUnreadChanged});

  /// Notifies parent (e.g. [SmeetShell]) of aggregate unread for the Chat tab badge.
  final ValueChanged<int>? onTotalUnreadChanged;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  User? get _user => Supabase.instance.client.auth.currentUser;

  late Future<List<Map<String, dynamic>>> _chatsFuture;

  StreamSubscription<List<Map<String, dynamic>>>? _messagesRealtimeSub;
  List<String> _boundChatIds = const [];
  Timer? _realtimeRefreshDebounce;
  Timer? _inboxSignalDebounce;

  int _lastPushedUnreadTotal = -1;
  String? _lastPushedOpenId;

  /// After [markChatRead] (e.g. leaving a room), refetch so row unreads + tab badge match DB.
  void _onInboxRefreshSignal() {
    _inboxSignalDebounce?.cancel();
    _inboxSignalDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => _chatsFuture = _fetchMyChats());
    });
  }

  @override
  void initState() {
    super.initState();
    _chatsFuture = _fetchMyChats();
    smeetChatInboxRefreshSignal.addListener(_onInboxRefreshSignal);
  }

  @override
  void dispose() {
    smeetChatInboxRefreshSignal.removeListener(_onInboxRefreshSignal);
    _inboxSignalDebounce?.cancel();
    _realtimeRefreshDebounce?.cancel();
    _messagesRealtimeSub?.cancel();
    super.dispose();
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

  int _sumUnreadForOpen(
    List<Map<String, dynamic>> chats,
    String? openChatId,
  ) {
    var s = 0;
    for (final c in chats) {
      final id = c['chat_id'].toString();
      final u = (c['unread'] as num?)?.toInt() ?? 0;
      if (openChatId != null && openChatId == id) continue;
      s += u;
    }
    return s;
  }

  void _pushUnreadToShell(
    List<Map<String, dynamic>> chats,
    String? openChatId,
  ) {
    final total = _sumUnreadForOpen(chats, openChatId);
    if (total == _lastPushedUnreadTotal && openChatId == _lastPushedOpenId) {
      return;
    }
    _lastPushedUnreadTotal = total;
    _lastPushedOpenId = openChatId;
    SmeetShell.reportChatTabUnread(total);
    widget.onTotalUnreadChanged?.call(total);
    debugPrint('[Unread] shell total=$total openChat=$openChatId');
    for (final c in chats) {
      final id = c['chat_id'].toString();
      final raw = (c['unread'] as num?)?.toInt() ?? 0;
      final disp = (openChatId != null && openChatId == id) ? 0 : raw;
      if (raw > 0) {
        debugPrint('[Unread] chat $id raw=$raw display_for_row=$disp');
      }
    }
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
        (_) => _scheduleChatsRefreshFromRealtime(),
        onError: (Object e) {
          debugPrint('[Unread] messages realtime stream error: $e');
        },
      );
      debugPrint(
        '[Unread] subscribed messages stream for ${chatIds.length} chat(s)',
      );
    } catch (e) {
      debugPrint('[Unread] messages realtime bind failed: $e');
    }
  }

  void _scheduleChatsRefreshFromRealtime() {
    _realtimeRefreshDebounce?.cancel();
    _realtimeRefreshDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      debugPrint('[Unread] realtime → refetch chat list');
      setState(() => _chatsFuture = _fetchMyChats());
    });
  }

  Future<List<Map<String, dynamic>>> _fetchMyChats() async {
    final u = _user;
    if (u == null) {
      _messagesRealtimeSub?.cancel();
      _messagesRealtimeSub = null;
      _boundChatIds = [];
      _lastPushedUnreadTotal = -1;
      _lastPushedOpenId = null;
      if (mounted) {
        SmeetShell.clearChatTabUnreadBadge();
        widget.onTotalUnreadChanged?.call(0);
      }
      return [];
    }

    final supabase = Supabase.instance.client;
    final filtered = await ChatConversationListService(supabase)
        .fetchEnrichedListForUser(u.id);
    if (!mounted) return filtered;

    final ids = filtered.map((e) => e['chat_id'].toString()).toList();
    _bindMessagesRealtime(ids);
    _pushUnreadToShell(filtered, smeetOpenChatRoomId.value);

    return filtered;
  }

  Widget _compactUnreadBadge(BuildContext context, int unreadShown) {
    final label = unreadLabelForChatRow(unreadShown);
    if (label.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.error.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: cs.onErrorContainer,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _chatsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoadingState(message: 'Loading chats…');
        }
        if (snapshot.hasError) {
          return AppErrorState(
            message: 'We couldn’t load your chats. Tap Retry.',
            onRetry: () {
              setState(() => _chatsFuture = _fetchMyChats());
            },
          );
        }

        final chats = snapshot.data ?? [];
        if (chats.isEmpty) {
          return AppEmptyState(
            icon: _user == null ? Icons.login : Icons.chat_bubble_outline,
            title: _user == null
                ? 'Sign in to chat'
                : 'No chats yet',
            subtitle: _user == null
                ? 'Sign in to message people you meet on Smeet.'
                : 'Match with someone on Swipe to start a conversation.',
            actionLabel: _user == null ? 'Sign in' : null,
            onAction: _user == null
                ? () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AuthPage(),
                      ),
                    );
                  }
                : null,
          );
        }

        return ValueListenableBuilder<String?>(
          valueListenable: smeetOpenChatRoomId,
          builder: (context, openChatId, _) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _pushUnreadToShell(chats, openChatId);
            });

            return RefreshIndicator(
              onRefresh: () async {
                setState(() => _chatsFuture = _fetchMyChats());
                await _chatsFuture;
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: chats.length,
                itemBuilder: (context, i) {
                  final c = chats[i];
                  final chatId = c['chat_id'].toString();
                  final last = (c['last_message'] ?? '').toString();
                  final isGame = (c['chat_kind'] ?? 'direct') == 'game';
                  final uiTitle =
                      (c['ui_title'] ?? c['title'] ?? 'Chat').toString();
                  final uiAvatar = c['ui_avatar']?.toString();
                  final rawUnread = (c['unread'] as num?)?.toInt() ?? 0;
                  final unreadShown = (openChatId != null && openChatId == chatId)
                      ? 0
                      : rawUnread;
                  final n = (c['member_count'] as num?)?.toInt() ?? 0;
                  final peerId = c['direct_peer_id']?.toString();

                  if (isGame) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: cs.primary.withOpacity(0.10),
                        ),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: cs.primary.withOpacity(0.12),
                          child: Icon(Icons.groups, color: cs.primary),
                        ),
                        title: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: cs.secondary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'GROUP',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: cs.secondary,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                uiTitle,
                                style:
                                    const TextStyle(fontWeight: FontWeight.w800),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (unreadShown > 0) ...[
                              const SizedBox(width: 8),
                              _compactUnreadBadge(context, unreadShown),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          last.isEmpty
                              ? 'Group chat · $n people'
                              : last,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () async {
                          final ok = await _ensureLoginAndPrompt(context);
                          if (!ok) return;
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChatRoomPage(
                                chatId: chatId,
                                title: uiTitle,
                                chatKind: 'game',
                              ),
                            ),
                          );
                          setState(() => _chatsFuture = _fetchMyChats());
                        },
                      ),
                    );
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: cs.primary.withOpacity(0.10)),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: cs.primary.withOpacity(0.12),
                        backgroundImage: uiAvatar != null && uiAvatar.isNotEmpty
                            ? NetworkImage(uiAvatar)
                            : null,
                        child: uiAvatar == null || uiAvatar.isEmpty
                            ? Icon(Icons.person, color: cs.primary)
                            : null,
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              uiTitle,
                              style: const TextStyle(fontWeight: FontWeight.w800),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (unreadShown > 0) ...[
                            const SizedBox(width: 8),
                            _compactUnreadBadge(context, unreadShown),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        last.isEmpty ? 'Say hi 👋' : last,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () async {
                        final ok = await _ensureLoginAndPrompt(context);
                        if (!ok) return;
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChatRoomPage(
                              chatId: chatId,
                              title: uiTitle,
                              chatKind: 'direct',
                              directPeerUserId: peerId,
                            ),
                          ),
                        );
                        setState(() => _chatsFuture = _fetchMyChats());
                      },
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class ChatRoomPage extends StatefulWidget {
  final String chatId;
  final String title;
  /// `direct` (1:1 match) or `game` (group).
  final String chatKind;
  /// When known (e.g. from a new match), avoids an extra lookup.
  final String? directPeerUserId;

  const ChatRoomPage({
    super.key,
    required this.chatId,
    required this.title,
    this.chatKind = 'direct',
    this.directPeerUserId,
  });

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  User? get _user => Supabase.instance.client.auth.currentUser;

  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _listCtrl = ScrollController();

  /// Single subscription for the lifetime of this screen — do not recreate in
  /// [build] or [StreamBuilder] will cancel/resubscribe every frame and miss
  /// or delay realtime events.
  late final Stream<List<Map<String, dynamic>>> _messagesStream;

  String _appTitle = 'Chat';
  String _gameSubtitle = '';
  String? _directPeerId;
  String? _directPeerAvatar;
  int _prevMsgLen = -1;
  /// Last count logged for [ChatMessages] debug (avoid spam).
  int _debugLastLoggedStreamLen = -1;
  Timer? _readDebounce;

  /// Rows returned from `insert().select()` until the realtime stream includes them.
  final List<Map<String, dynamic>> _pendingServerRows = [];

  /// Local-only bubbles while waiting for Postgres (removed on insert success).
  final List<Map<String, dynamic>> _optimisticMessages = [];

  bool _prunePendingPostFrameScheduled = false;

  /// Direct chat only: true if either party blocked the other (client-side).
  bool _eitherBlocked = false;
  bool _iBlockedThem = false;

  @override
  void dispose() {
    _readDebounce?.cancel();
    if (smeetOpenChatRoomId.value == widget.chatId) {
      smeetOpenChatRoomId.value = null;
      debugPrint('[Unread] closed chat room chat_id=${widget.chatId}');
    }
    final u = _user;
    if (u != null) {
      markChatRead(
        Supabase.instance.client,
        chatId: widget.chatId,
        userId: u.id,
      ).then((_) {
        SmeetShell.requestChatInboxRefresh();
      });
    }
    _ctrl.dispose();
    _listCtrl.dispose();
    super.dispose();
  }

  void _scheduleMarkRead() {
    final u = _user;
    if (u == null) return;
    _readDebounce?.cancel();
    _readDebounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      markChatRead(
        Supabase.instance.client,
        chatId: widget.chatId,
        userId: u.id,
      );
    });
  }

  void _scrollChatToBottom({bool animate = false}) {
    if (!_listCtrl.hasClients) return;
    final t = _listCtrl.position.minScrollExtent;
    if (animate) {
      _listCtrl.animateTo(
        t,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
      );
    } else {
      _listCtrl.jumpTo(t);
    }
  }

  void _schedulePrunePendingServerRows(Set<String> streamIds) {
    if (_prunePendingPostFrameScheduled) return;
    if (!_pendingServerRows.any((r) => streamIds.contains(r['id'].toString()))) {
      return;
    }
    _prunePendingPostFrameScheduled = true;
    final ids = Set<String>.from(streamIds);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prunePendingPostFrameScheduled = false;
      if (!mounted) return;
      setState(() {
        _pendingServerRows.removeWhere((r) => ids.contains(r['id'].toString()));
      });
    });
  }

  /// Stream snapshot + pending insert rows + optimistic rows, deduped by real `id`.
  List<Map<String, dynamic>> _mergeVisibleMessages(
    List<Map<String, dynamic>> streamRows,
  ) {
    final streamIds = streamRows.map((m) => m['id'].toString()).toSet();
    _schedulePrunePendingServerRows(streamIds);

    final byId = <String, Map<String, dynamic>>{};
    for (final m in streamRows) {
      byId[m['id'].toString()] = Map<String, dynamic>.from(m);
    }
    for (final r in _pendingServerRows) {
      final id = r['id'].toString();
      if (!streamIds.contains(id)) {
        byId.putIfAbsent(id, () => Map<String, dynamic>.from(r));
      }
    }
    for (final o in _optimisticMessages) {
      final cid = o['_client_id']?.toString() ?? '';
      if (cid.isEmpty) continue;
      byId['__client__$cid'] = Map<String, dynamic>.from(o);
    }
    return sortedChatMessages(byId.values.toList());
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    if (widget.chatKind == 'direct' && _eitherBlocked) return;

    var u = _user;
    if (u == null) {
      final ok = await _ensureLoginAndPrompt(context);
      if (!ok) return;
      u = _user;
    }
    if (u == null) return;

    final userId = u.id;
    final clientId = const Uuid().v4();
    final nowIso = DateTime.now().toUtc().toIso8601String();
    setState(() {
      _optimisticMessages.add({
        '_client_id': clientId,
        '_pending': true,
        'user_id': userId,
        'content': text,
        'created_at': nowIso,
        'id': '__pending__$clientId',
        'chat_id': widget.chatId,
      });
    });
    debugPrint(
      '[ChatMessages] optimistic insert client_id=$clientId chat_id=${widget.chatId} '
      'user_id=$userId len=${text.length}',
    );

    _ctrl.clear();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _scrollChatToBottom(animate: true));

    try {
      final supabase = Supabase.instance.client;
      final row = await supabase
          .from('messages')
          .insert({
            'chat_id': widget.chatId,
            'user_id': userId,
            'content': text,
          })
          .select()
          .single();
      debugPrint(
        '[ChatMessages] DB insert success id=${row['id']} chat_id=${widget.chatId} '
        'user_id=$userId — reconciling optimistic client_id=$clientId',
      );
      if (!mounted) return;
      setState(() {
        _optimisticMessages.removeWhere(
          (m) => m['_client_id']?.toString() == clientId,
        );
        _pendingServerRows.add(Map<String, dynamic>.from(row));
      });
      _scheduleMarkRead();
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _scrollChatToBottom(animate: true));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _optimisticMessages.removeWhere(
          (m) => m['_client_id']?.toString() == clientId,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_userFacingChatSendError(e))),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    smeetOpenChatRoomId.value = widget.chatId;
    debugPrint('[Unread] opened chat room chat_id=${widget.chatId}');
    _messagesStream = Supabase.instance.client
        .from('messages')
        .stream(primaryKey: const ['id'])
        .eq('chat_id', widget.chatId)
        .order('id');
    debugPrint(
      '[ChatMessages] stream created once for chat_id=${widget.chatId} '
      '(primaryKey=id, order=id)',
    );
    _appTitle = widget.title.isNotEmpty ? widget.title : 'Chat';
    if (widget.chatKind == 'direct') {
      _loadDirectHeader();
      final pid = widget.directPeerUserId;
      if (pid != null && pid.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _refreshDirectBlockStateForPeer(pid);
        });
      }
    } else {
      _loadGameHeaderMeta();
    }
  }

  Future<void> _loadGameHeaderMeta() async {
    try {
      final rows = await Supabase.instance.client
          .from('chat_members')
          .select('user_id')
          .eq('chat_id', widget.chatId);
      final n = (rows as List).length;
      if (mounted) {
        setState(() {
          _gameSubtitle = n <= 0 ? 'Group chat' : '$n people · tap for roster';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _gameSubtitle = 'Group chat · tap for roster');
      }
    }
  }

  Future<void> _loadDirectHeader() async {
    try {
      final u = _user;
      if (u == null) return;

      final supabase = Supabase.instance.client;
      var oid = widget.directPeerUserId;
      if (oid == null) {
        final other = await supabase
            .from('chat_members')
            .select('user_id')
            .eq('chat_id', widget.chatId)
            .neq('user_id', u.id)
            .limit(1)
            .maybeSingle();
        oid = other?['user_id']?.toString();
      }
      if (oid == null || !mounted) return;
      final peerId = oid;

      final p = await supabase
          .from('profiles')
          .select('display_name, avatar_url')
          .eq('id', peerId)
          .maybeSingle();

      if (!mounted) return;
      setState(() {
        _directPeerId = peerId;
        _directPeerAvatar = p?['avatar_url']?.toString();
        final name = (p?['display_name'] ?? '').toString().trim();
        if (name.isNotEmpty) {
          _appTitle = name;
        } else {
          _appTitle =
              'User ${peerId.length >= 6 ? peerId.substring(0, 6) : peerId}';
        }
      });
      await _refreshDirectBlockStateForPeer(peerId);
    } catch (_) {}
  }

  Future<void> _refreshDirectBlockStateForPeer(String peerId) async {
    if (widget.chatKind != 'direct') return;
    final u = _user;
    if (u == null) return;
    try {
      final s = await BlockService.fetchMyBlockSets();
      if (!mounted) return;
      setState(() {
        _iBlockedThem = s.iBlocked.contains(peerId);
        _eitherBlocked =
            s.iBlocked.contains(peerId) || s.blockedMe.contains(peerId);
      });
    } catch (_) {}
  }

  Future<void> _showGameMembers(BuildContext context) async {
    try {
      final supabase = Supabase.instance.client;
      final rows = await supabase
          .from('chat_members')
          .select('user_id')
          .eq('chat_id', widget.chatId);
      final ids =
          (rows as List).map((e) => e['user_id'].toString()).toList();
      if (ids.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No players in this chat yet.'),
            ),
          );
        }
        return;
      }
      final profs = await supabase
          .from('profiles')
          .select('id, display_name, avatar_url, city')
          .inFilter('id', ids);
      final list = (profs as List).cast<Map<String, dynamic>>();
      if (!context.mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (ctx) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Players in this game',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 12),
              ...list.map((p) {
                final id = p['id'].toString();
                final name =
                    (p['display_name'] ?? 'Player').toString().trim();
                final av = (p['avatar_url'] ?? '').toString();
                final city = (p['city'] ?? '').toString();
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage:
                        av.isEmpty ? null : NetworkImage(av),
                    child: av.isEmpty ? const Icon(Icons.person) : null,
                  ),
                  title: Text(name.isEmpty ? id.substring(0, 8) : name),
                  subtitle: city.isEmpty ? null : Text(city),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => OtherProfilePage(userId: id),
                      ),
                    );
                  },
                );
              }),
            ],
          );
        },
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_userFacingMembersLoadError(e))),
        );
      }
    }
  }

  /// Server-backed message id (excludes optimistic / pending placeholders).
  String? _reportableMessageId(Map<String, dynamic> m) {
    final id = m['id']?.toString() ?? '';
    if (id.isEmpty || id.startsWith('__')) return null;
    return id;
  }

  Widget _directChatBlockBanner(BuildContext context, ColorScheme cs) {
    return Material(
      color: cs.errorContainer.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.block, size: 20, color: cs.onErrorContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _iBlockedThem
                    ? 'You blocked this player. Unblock from their profile to chat.'
                    : 'You can’t message this player right now.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onErrorContainer,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onLongPressOtherUserMessage(
    BuildContext context, {
    required Map<String, dynamic> m,
    required String authorUserId,
  }) {
    final mid = _reportableMessageId(m);
    if (mid == null) return;
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.flag_outlined, color: cs.primary),
              title: const Text('Report message'),
              onTap: () {
                Navigator.of(ctx).pop();
                showReportBottomSheet(
                  context,
                  title: 'Report message',
                  subtitle:
                      'We’ll review this message and the sender. '
                      'Thank you for helping keep Smeet safe.',
                  targetUserId:
                      authorUserId.isNotEmpty ? authorUserId : null,
                  messageId: mid,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = _user;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 8,
        title: widget.chatKind == 'game'
            ? InkWell(
                onTap: () => _showGameMembers(context),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: cs.primary.withOpacity(0.15),
                        child: Icon(Icons.groups, color: cs.primary),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _appTitle,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                              ),
                            ),
                            Text(
                              _gameSubtitle,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface.withOpacity(0.65),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : InkWell(
                onTap: (widget.directPeerUserId == null && _directPeerId == null)
                    ? null
                    : () async {
                        final id =
                            widget.directPeerUserId ?? _directPeerId ?? '';
                        if (id.isEmpty) return;
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => OtherProfilePage(userId: id),
                          ),
                        );
                        if (mounted) {
                          await _refreshDirectBlockStateForPeer(id);
                        }
                      },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: cs.primary.withOpacity(0.15),
                        backgroundImage: _directPeerAvatar != null &&
                                _directPeerAvatar!.isNotEmpty
                            ? NetworkImage(_directPeerAvatar!)
                            : null,
                        child: _directPeerAvatar == null ||
                                _directPeerAvatar!.isEmpty
                            ? Icon(Icons.person, color: cs.primary)
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _appTitle,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        actions: [
          if (widget.chatKind == 'game')
            IconButton(
              tooltip: 'Participants',
              icon: const Icon(Icons.people_outline),
              onPressed: () => _showGameMembers(context),
            ),
        ],
      ),

      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                final rawLen = snapshot.hasData ? snapshot.data!.length : -1;
                debugPrint(
                  '[ChatMessages] StreamBuilder build: '
                  'connectionState=${snapshot.connectionState} '
                  'hasData=${snapshot.hasData} hasError=${snapshot.hasError} '
                  'rawCount=$rawLen',
                );
                if (snapshot.hasError) {
                  debugPrint(
                    '[ChatMessages] StreamBuilder error: ${snapshot.error}',
                  );
                }
                if (snapshot.hasData && rawLen > _debugLastLoggedStreamLen) {
                  debugPrint(
                    '[ChatMessages] stream event received: rawCount '
                    '$_debugLastLoggedStreamLen → $rawLen (chat_id=${widget.chatId})',
                  );
                  _debugLastLoggedStreamLen = rawLen;
                }

                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.cloud_off_outlined,
                              size: 48,
                              color: cs.outline,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Couldn’t load messages',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Go back and open this chat again, or check your connection.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return const Center(child: CircularProgressIndicator());
                }
                final msgs = _mergeVisibleMessages(snapshot.data!);
                if (msgs.isEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.chatKind == 'direct' && _eitherBlocked) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                          child: _directChatBlockBanner(context, cs),
                        ),
                      ],
                      Expanded(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline,
                                  size: 44,
                                  color: cs.outline,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No messages yet',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Say hi to start the conversation.',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: cs.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }

                final displayMsgs = (widget.chatKind == 'direct' &&
                        _eitherBlocked &&
                        u != null)
                    ? msgs
                        .where((m) => m['user_id']?.toString() == u.id)
                        .toList()
                    : msgs;

                if (displayMsgs.isEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.chatKind == 'direct' && _eitherBlocked) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                          child: _directChatBlockBanner(context, cs),
                        ),
                      ],
                      const Expanded(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'Messages are hidden while you and this player can’t chat.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }

                final newestFirst = displayMsgs.reversed.toList();

                final len = displayMsgs.length;
                if (len != _prevMsgLen) {
                  debugPrint(
                    '[ChatMessages] rebuild with sorted len=$len '
                    '(was $_prevMsgLen) — scheduling scroll to bottom',
                  );
                  _prevMsgLen = len;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    _scrollChatToBottom(animate: false);
                    _scheduleMarkRead();
                  });
                }

                final listView = ListView.builder(
                  reverse: true,
                  controller: _listCtrl,
                  padding: const EdgeInsets.all(12),
                  itemCount: newestFirst.length,
                  itemBuilder: (context, i) {
                    final m = newestFirst[i];
                    final isMe =
                        u != null && m['user_id']?.toString() == u.id;
                    final text = (m['content'] ?? '').toString();
                    final pending = m['_pending'] == true;
                    final uidStr = m['user_id']?.toString() ?? '';
                    final prefix = widget.chatKind == 'game' && !isMe
                        ? '${uidStr.length >= 8 ? uidStr.substring(0, 8) : uidStr} · '
                        : '';
                    final reportableId = _reportableMessageId(m);

                    Widget bubble = Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      constraints: const BoxConstraints(maxWidth: 280),
                      decoration: BoxDecoration(
                        color: isMe
                            ? cs.primary.withOpacity(0.18)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: pending
                              ? cs.outline.withOpacity(0.35)
                              : cs.primary.withOpacity(0.10),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text('$prefix$text'),
                          ),
                          if (pending) ...[
                            const SizedBox(width: 6),
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: cs.primary.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );

                    if (!isMe && reportableId != null) {
                      bubble = GestureDetector(
                        onLongPress: () => _onLongPressOtherUserMessage(
                          context,
                          m: m,
                          authorUserId: uidStr,
                        ),
                        child: bubble,
                      );
                    }

                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: bubble,
                    );
                  },
                );

                if (widget.chatKind == 'direct' && _eitherBlocked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                        child: _directChatBlockBanner(context, cs),
                      ),
                      Expanded(child: listView),
                    ],
                  );
                }
                return listView;
              },
            ),
          ),

          // 输入框
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: widget.chatKind == 'direct' && _eitherBlocked
                  ? Text(
                      _iBlockedThem
                          ? 'Messaging is off until you unblock this player from their profile.'
                          : 'You can’t send messages in this chat right now.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.78),
                            height: 1.4,
                          ),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _ctrl,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              hintText: 'Write a message…',
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                            ),
                            onSubmitted: (_) => _send(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton(
                          onPressed: _send,
                          child: const Text('Send'),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// --- 页面 5：Profile（个人信息） ---

/// Tab content height when [LayoutBuilder] gives unbounded or tiny maxHeight
/// (IndexedStack / offstage quirks on some mobile embedders). Uses screen minus
/// approximate app bar + bottom nav — avoids `0.72 * screen` exceeding [Scaffold] body.
double _profileTabSafeHeight(BoxConstraints constraints, BuildContext context) {
  final mh = constraints.maxHeight;
  if (mh.isFinite && mh > 8) {
    return mh;
  }
  final mq = MediaQuery.sizeOf(context);
  final pad = MediaQuery.paddingOf(context);
  const chrome = 56.0 + 80.0 + 24.0; // app bar + nav bar + margin
  final h = mq.height - pad.vertical - chrome;
  final out = h.clamp(240.0, 680.0);
  debugPrint(
    '[ProfilePage] layout fallback (maxH=$mh not usable) → height=$out',
  );
  return out;
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  User? get _user => Supabase.instance.client.auth.currentUser;

  final PostsService _postsService = PostsService();

  final _nameCtrl = TextEditingController();
  final _birthYearCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _introCtrl = TextEditingController();

  /// Tracks which user we last loaded into the form (guest → login needs reload).
  String? _lastLoadedProfileUserId;

  String? _avatarUrl;
  bool _loading = false;
  bool _loaded = false;

  final GlobalKey<LegacyProfileSetupSectionState> _legacySetupKey =
      GlobalKey<LegacyProfileSetupSectionState>();

  /// Snapshot for [LegacyProfileSetupSection] sport_levels / availability sync.
  Map<String, dynamic>? _setupLoadedRow;
  int _setupLoadGen = 0;

  Future<List<Map<String, dynamic>>>? _myPostsFuture;

  @override
  void initState() {
    super.initState();
    debugPrint('[ProfilePage] initState');
    final u = _user;
    if (u != null) {
      _lastLoadedProfileUserId = u.id;
      _loadProfile();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _birthYearCtrl.dispose();
    _cityCtrl.dispose();
    _introCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = _user;
    if (user == null) {
      setState(() => _loaded = true);
      return;
    }

    setState(() => _loading = true);

    try {
      final row = await fetchProfileSetupRow(
        client: Supabase.instance.client,
        userId: user.id,
      );

      if (row != null) {
        final v = ProfileSetupFieldValues.fromRow(row);
        _nameCtrl.text = v.displayName;
        _birthYearCtrl.text = v.birthYearText;
        _cityCtrl.text = v.city;
        _introCtrl.text = v.intro;
        _avatarUrl = v.avatarUrl;
      }

      if (mounted) {
        setState(() {
          _loaded = true;
          _setupLoadedRow = row;
          _setupLoadGen++;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loaded = true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(content: Text(_userFacingProfileLoadError(e))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveProfile() async {
    await _legacySetupKey.currentState?.saveProfile();
  }

  Future<String> _uploadToMediaBucketXFile(
    XFile xfile, {
    required String folder,
  }) async {
    final user = _user;
    if (user == null) throw Exception('Not logged in');

    return MediaUploadService().uploadXFileToMediaBucket(
      xfile,
      userId: user.id,
      folder: folder,
    );
  }

  Future<void> _pickAndUploadAvatar() async {
    if (_user == null) {
      final ok = await _ensureLoginAndPrompt(context);
      if (!ok) return;
    }

    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (x == null) return;

    setState(() => _loading = true);
    try {
      final url = await _uploadToMediaBucketXFile(x, folder: 'avatar');
      setState(() => _avatarUrl = url);
      await _saveProfile(); // 上传完顺便保存
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(content: Text(_userFacingAvatarUploadError(e))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchMyPosts() async {
    final user = _user;
    if (user == null) return [];

    return _postsService.fetchMyPosts(user.id);
  }

  Future<void> _createPost({required String mediaType}) async {
    var user = _user;
    if (user == null) {
      final ok = await _ensureLoginAndPrompt(context);
      if (!ok) return;
      user = _user;
      if (user == null) return;
    }

    final picker = ImagePicker();
    XFile? x;
    if (mediaType == 'image') {
      x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    } else {
      x = await picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 30),
      );
    }
    if (x == null) return;

    final caption = await _askCaption();
    if (caption == null) return;

    setState(() => _loading = true);
    try {
      final url = await _uploadToMediaBucketXFile(x, folder: 'posts');

      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          const SnackBar(content: Text('Please sign in to post.')),
        );
        return;
      }
      final payload = PostsService.buildMediaPostPayload(
        authorId: user.id,
        mediaUrl: url,
        mediaType: mediaType,
        captionTrimmed: caption.trim(),
      );
      final inserted =
          await _postsService.insertPostReturningSummary(payload);

      if (kDebugMode) {
        debugPrint('[Profile] post insert OK => $inserted');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(content: Text('Post published.')),
      );

      setState(() {
        _myPostsFuture = _fetchMyPosts();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(content: Text(_userFacingPostPublishError(e))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String?> _askCaption() async {
    final ctrl = TextEditingController();
    final cs = Theme.of(context).colorScheme;

    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add caption'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Write something about your sports session...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.primary),
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: const Text('Post'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      const SnackBar(content: Text('You’re signed out.')),
    );
    // 你现在是游客也能看主页，所以不用强制跳走
    setState(() {
      _myPostsFuture = _fetchMyPosts();
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final u = _user;

    debugPrint(
      '[Profile] build currentUser=${Supabase.instance.client.auth.currentUser?.id}',
    );

    // Logged in after starting as guest: reload profile once session exists.
    if (u != null && _lastLoadedProfileUserId != u.id) {
      final id = u.id;
      _lastLoadedProfileUserId = id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _user?.id == id) {
          _loadProfile();
        }
      });
    }
    if (u == null) {
      _lastLoadedProfileUserId = null;
    }

    // 允许游客打开 profile：提示登录（scrollable：小屏避免 Column 溢出）
    if (_user == null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.06),
            Icon(Icons.person_outline, size: 72, color: cs.primary),
            const SizedBox(height: 14),
            Text(
              'Sign in for your profile',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'Sign in to add a photo, set your sports profile, and post photos or videos.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurface.withOpacity(0.7),
                  ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const AuthPage()));
              },
              child: const Text('Sign in or create account'),
            ),
            const SizedBox(height: 24),
            const LegalSectionCard(guestMode: true),
          ],
        ),
      );
    }

    if (!_loaded && _loading) {
      return const AppLoadingState(message: 'Loading your profile…');
    }

    // No nested Scaffold. [LayoutBuilder] logs constraints; if height is unbounded
    // (some parent combinations on mobile), [SizedBox] gives TabBarView a finite height.
    return LayoutBuilder(
      builder: (context, constraints) {
        final mh = constraints.maxHeight;
        debugPrint(
          '[ProfilePage] layout maxW=${constraints.maxWidth.toStringAsFixed(0)} '
          'maxH=${mh.isFinite ? mh.toStringAsFixed(0) : "∞"} finiteH=${mh.isFinite}',
        );
        if (mh.isFinite && mh <= 8) {
          debugPrint(
            '[ProfilePage] WARNING: tiny maxHeight=$mh (IndexedStack/offstage?)',
          );
        }
        final safeH = _profileTabSafeHeight(constraints, context);

        return SizedBox(
          height: safeH,
          width: double.infinity,
          child: DefaultTabController(
            length: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              // Top header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: cs.primary.withOpacity(0.12)),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _loading ? null : _pickAndUploadAvatar,
                      child: CircleAvatar(
                        radius: 30,
                        backgroundColor: cs.primary.withOpacity(0.12),
                        backgroundImage:
                            (_avatarUrl == null || _avatarUrl!.isEmpty)
                            ? null
                            : NetworkImage(_avatarUrl!),
                        child: (_avatarUrl == null || _avatarUrl!.isEmpty)
                            ? Icon(Icons.camera_alt, color: cs.primary)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _nameCtrl.text.trim().isEmpty
                                ? 'Tap to build your profile'
                                : _nameCtrl.text.trim(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _cityCtrl.text.trim().isEmpty
                                ? 'City not set'
                                : _cityCtrl.text.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: cs.onSurface.withOpacity(0.7),
                                ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _loading ? null : _logout,
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Tabs
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: cs.primary.withOpacity(0.10)),
                ),
                child: TabBar(
                  onTap: (i) {
                    if (i == 1 && _myPostsFuture == null) {
                      setState(() {
                        _myPostsFuture = _fetchMyPosts();
                      });
                    }
                  },
                  tabs: const [
                    Tab(text: 'Profile'),
                    Tab(text: 'Posts'),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              Expanded(
                child: TabBarView(
                  children: [
                    // ========== TAB 1: Profile ==========
                    SingleChildScrollView(
                      child: Column(
                        children: [
                          LegacyProfileSetupSection(
                            key: _legacySetupKey,
                            nameCtrl: _nameCtrl,
                            birthYearCtrl: _birthYearCtrl,
                            cityCtrl: _cityCtrl,
                            introCtrl: _introCtrl,
                            currentAvatarUrl: () => _avatarUrl,
                            loadGeneration: _setupLoadGen,
                            loadedProfileRow: _setupLoadedRow,
                            onBusyChanged: (busy) {
                              if (mounted) setState(() => _loading = busy);
                            },
                            onProfileSaved: SmeetShell.refreshAuthState,
                          ),
                          const SizedBox(height: 12),
                          const LegalSectionCard(),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _loading
                                  ? null
                                  : () => _legacySetupKey.currentState
                                      ?.saveProfile(),
                              child: Text(
                                _loading ? 'Saving...' : 'Save Profile',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ========== TAB 2: Posts ==========
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _loading
                                    ? null
                                    : () => _createPost(mediaType: 'image'),
                                icon: const Icon(Icons.photo),
                                label: const Text('Post Photo'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _loading
                                    ? null
                                    : () => _createPost(mediaType: 'video'),
                                icon: const Icon(Icons.videocam),
                                label: const Text('Post Video'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        Expanded(
                          child: FutureBuilder<List<Map<String, dynamic>>>(
                            future: _myPostsFuture ??= _fetchMyPosts(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const AppLoadingState(
                                  message: 'Loading posts…',
                                );
                              }

                              if (snapshot.hasError) {
                                return AppErrorState(
                                  message: 'We couldn’t load your posts. Tap Retry.',
                                  onRetry: () {
                                    setState(() {
                                      _myPostsFuture = _fetchMyPosts();
                                    });
                                  },
                                );
                              }

                              final posts = snapshot.data ?? [];
                              if (posts.isEmpty) {
                                return const AppEmptyState(
                                  icon: Icons.photo_library_outlined,
                                  title: 'No posts yet',
                                  subtitle:
                                      'Share a photo or video from a session. It will show up here.',
                                );
                              }

                              return ListView.builder(
                                itemCount: posts.length,
                                itemBuilder: (context, i) {
                                  final p = posts[i];

                                  final caption = (p['caption'] ?? '')
                                      .toString();
                                  final type = (p['media_type'] ?? 'image')
                                      .toString()
                                      .toLowerCase();

                                  final List mediaUrls =
                                      (p['media_urls'] ?? []) as List;
                                  final String url = mediaUrls.isNotEmpty
                                      ? mediaUrls.first.toString()
                                      : '';

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary.withOpacity(0.10),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        PostProfileListMedia(type: type, url: url),

                                        const SizedBox(height: 10),
                                        Text(caption),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
              ),
            ),
          ),
        );
      },
    );
  }

}

/// Mutual likes from [matches] + [profiles]; tap opens the existing direct
/// [ChatRoomPage] when one exists (same resolution as Chat / Inbox DMs).
class MatchesPage extends StatefulWidget {
  const MatchesPage({super.key});

  @override
  State<MatchesPage> createState() => _MatchesPageState();
}

class _MatchesPageState extends State<MatchesPage> {
  User? get _user => Supabase.instance.client.auth.currentUser;

  late Future<List<Map<String, dynamic>>> _future;
  final ChatConversationListService _chatList = ChatConversationListService();
  final SupabaseMatchesInboxRepository _matchesRepo =
      SupabaseMatchesInboxRepository();

  @override
  void initState() {
    super.initState();
    _future = _fetchMatches();
  }

  Future<List<Map<String, dynamic>>> _fetchMatches() async {
    if (_user == null) return [];
    final rows = await _matchesRepo.fetchMatchRelationships();
    return rows.map((e) => e.toLegacyProfileMap()).toList();
  }

  Future<void> _onMatchRowTap(
    BuildContext context,
    Map<String, dynamic> profile,
    String displayName,
  ) async {
    final me = _user?.id;
    final peerId = profile['id']?.toString();
    if (me == null || peerId == null || peerId.isEmpty) return;

    try {
      final chatId = await _chatList.findDirectChatIdForPeer(
        myUserId: me,
        peerUserId: peerId,
      );
      if (!context.mounted) return;

      if (chatId != null && chatId.isNotEmpty) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => ChatRoomPage(
              chatId: chatId,
              title: displayName,
              chatKind: 'direct',
              directPeerUserId: peerId,
            ),
          ),
        );
        return;
      }

      final intro = (profile['intro'] ?? '').toString().trim();
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(displayName),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  intro.isEmpty ? 'No bio yet.' : intro,
                ),
                const SizedBox(height: 12),
                Text(
                  'There isn’t a chat linked to this person yet. '
                  'New mutual likes on Swipe open a chat automatically; '
                  'you can also check the Chat tab.',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        height: 1.35,
                      ),
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
    } catch (e) {
      if (!context.mounted) return;
      debugPrint('[MatchesPage] open chat failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Couldn’t open chat. Try again from the Chat tab.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Matches')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const AppLoadingState(message: 'Loading matches…');
          }
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return AppEmptyState(
              icon: Icons.favorite_border,
              title: 'No matches yet',
              subtitle:
                  'When you and someone both like each other on Swipe, they’ll show up here. '
                  'Existing chats stay in the Chat tab.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final p = items[i];
              final name = (p['display_name'] ?? 'Unknown').toString();
              final city = (p['city'] ?? '').toString();
              final avatar = (p['avatar_url'] ?? '').toString();

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: cs.primary.withOpacity(0.10)),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: cs.primary.withOpacity(0.12),
                    backgroundImage: avatar.isEmpty
                        ? null
                        : NetworkImage(avatar),
                    child: avatar.isEmpty
                        ? Icon(Icons.person, color: cs.primary)
                        : null,
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(city.isEmpty ? 'City not set' : city),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => unawaited(_onMatchRowTap(context, p, name)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
