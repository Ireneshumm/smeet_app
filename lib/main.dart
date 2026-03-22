import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart'; // kIsWeb
import 'package:video_player/video_player.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:postgrest/postgrest.dart' show PostgrestException;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:smeet_app/game_balance.dart';
import 'package:smeet_app/geo_utils.dart';
import 'package:smeet_app/other_profile_page.dart';
import 'package:smeet_app/widgets/location_search_field.dart';

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

Future<int> countUnreadForChat({
  required SupabaseClient supabase,
  required String chatId,
  required String me,
  String? lastReadIso,
}) async {
  try {
    var q = supabase
        .from('messages')
        .select('id')
        .eq('chat_id', chatId)
        .neq('user_id', me);
    if (lastReadIso != null && lastReadIso.isNotEmpty) {
      q = q.gt('created_at', lastReadIso);
    }
    final rows =
        await q.order('created_at', ascending: false).limit(50);
    return (rows as List).length;
  } catch (_) {
    return 0;
  }
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
  } catch (_) {}
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // supabase package defaults to AuthFlowType.pkce; no need to pass authOptions.
  await Supabase.initialize(
    url: 'https://gjaljqqvtxfqddmtyxgt.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqYWxqcXF2dHhmcWRkbXR5eGd0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjcxODAzNTYsImV4cCI6MjA4Mjc1NjM1Nn0.xBUQad28YDmWG7uTGopg7itEruXnCMdcU-EDwkZ3308',
  );

  runApp(const SmeetApp());
}

class SmeetApp extends StatelessWidget {
  const SmeetApp({super.key});

  // Brand colors (from your logo)
  static const Color smeetMint = Color(0xFF56CDBE);
  static const Color smeetDeep = Color(0xFF0B8F85);
  static const Color smeetInk = Color(0xFF0F2D2A);
  static const Color smeetBg = Color(0xFFF7FBFA);

  @override
  Widget build(BuildContext context) {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: smeetMint,
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'Smeet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,

        scaffoldBackgroundColor: smeetBg,

        colorScheme: baseScheme.copyWith(
          primary: smeetMint,
          secondary: smeetDeep,
          surface: Colors.white,
          onPrimary: Colors.white,
          onSurface: smeetInk,
        ),

        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: smeetInk,
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),

        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: smeetMint.withOpacity(0.18),
          labelTextStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 12)),
        ),

        filledButtonTheme: FilledButtonThemeData(
          style: ButtonStyle(
            backgroundColor: const WidgetStatePropertyAll(smeetMint),
            foregroundColor: const WidgetStatePropertyAll(Colors.white),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ),
      home: const SmeetShell(),
    );
  }
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
                          'Log in to start matching 🎾',
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

  @override
  void initState() {
    super.initState();
    _instance = this;
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final ev = data.event;
      if (ev == AuthChangeEvent.signedOut) {
        _authResolveEpoch++;
        _authResolveQueued = false;
        if (mounted) {
          setState(() {
            _phase = ShellAuthPhase.signedOut;
            _index = 0;
            _profileWelcomeSnackUserId = null;
            _profileSessionKey++;
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
      setState(() {
        _phase = ShellAuthPhase.signedOut;
        _profileWelcomeSnackUserId = null;
        _index = 0;
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
      return;
    }

    if (!mounted || startEpoch != _authResolveEpoch) return;

    if (row == null) {
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
        ChatPage(key: ValueKey(_gamesListRevision)),
        ProfilePage(key: ValueKey(_profileSessionKey)),
      ];

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
      ),
      // Use IndexedStack to keep pages alive when switching tabs
      body: SafeArea(
        child: IndexedStack(
          index: _index,
          children: _pages,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.swipe), label: 'Swipe'),
          NavigationDestination(
            icon: Icon(Icons.sports_tennis),
            label: 'MyGame',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
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

  Future<void> _createGame() async {
    if (!await _ensureLogin()) return;
    if (!_formKey.currentState!.validate()) return;
    if (_gameDate == null || _startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select game date, start time, and end time'),
        ),
      );
      return;
    }

    DateTime combine(DateTime d, TimeOfDay t) =>
        DateTime(d.year, d.month, d.day, t.hour, t.minute);

    var startsAt = combine(_gameDate!, _startTime!);
    var endsAt = combine(_gameDate!, _endTime!);
    if (!endsAt.isAfter(startsAt)) {
      endsAt = endsAt.add(const Duration(days: 1));
    }

    if (_selectedLocation == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please pick a location from suggestions'),
        ),
      );
      return;
    }

    final loc = _selectedLocation!.address;
    final locLat = _selectedLocation!.lat;
    final locLng = _selectedLocation!.lng;
    final fee = _courtFee;
    final each = _perPerson;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please login first')));
      return;
    }

    try {
      final supabase = Supabase.instance.client;

      final result = await supabase
          .from('games')
          .insert({
            'sport': _sport,
            'game_level': _gameLevel,
            'starts_at': startsAt.toUtc().toIso8601String(),
            'ends_at': endsAt.toUtc().toIso8601String(),
            'location_text': loc,
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

      // Group chat: insert chats → update games.game_chat_id → join_game (RPC).
      String? setupNote;
      String? joinGameError;
      var chatSetupErrorShown = false;

      try {
        // Match working manual inserts: only chat_kind, game_id, title.
        // DB defaults fill id, created_at, last_message, last_message_at.
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

        // Prefer returning only id — broad .select() can fail under RLS even when INSERT succeeded.
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

        debugPrint('[CreateGameChat] Step B: games update select result = $afterUpdate');

        if (afterUpdate == null) {
          const msg =
              'UPDATE games returned no row — often RLS blocks UPDATE on games, or game id mismatch.';
          debugPrint('[CreateGameChat] Step B FAILED: $msg');
          setupNote = msg;
          if (mounted) {
            chatSetupErrorShown = true;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
                content: Text(
                  'Game created, but linking chat failed:\n$msg',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
                duration: const Duration(seconds: 8),
              ),
            );
          }
        } else {
          final linked = afterUpdate['game_chat_id']?.toString();
          if (linked != chatId) {
            debugPrint(
              '[CreateGameChat] Step B WARNING: DB game_chat_id=$linked expected $chatId',
            );
            setupNote = 'game_chat_id mismatch after update (got $linked)';
          } else {
            debugPrint(
              '[CreateGameChat] Step B OK: games.game_chat_id is set to $linked',
            );
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
        setupNote = 'Group chat setup failed: $e';
        if (mounted) {
          chatSetupErrorShown = true;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Theme.of(context).colorScheme.error,
              content: Text(
                'Chat creation failed (game still saved):\n$e',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onError,
                ),
              ),
              duration: const Duration(seconds: 10),
            ),
          );
        }
      }

      try {
        debugPrint('[CreateGameChat] Step C: RPC join_game(p_game_id=$gameId) ...');
        await supabase.rpc('join_game', params: {'p_game_id': gameId});
        debugPrint('[CreateGameChat] Step C OK: join_game finished');
      } catch (e, st) {
        debugPrint('[CreateGameChat] Step C FAILED join_game: $e');
        debugPrint('[CreateGameChat] stackTrace: $st');
        if (e is PostgrestException) {
          debugPrint(
            '[CreateGameChat] PostgrestException: code=${e.code} message=${e.message} details=${e.details} hint=${e.hint}',
          );
        }
        joinGameError = '$e';
      }

      if (!mounted) return;
      if (!chatSetupErrorShown) {
        if (joinGameError == null && setupNote == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Game & group chat ready!')),
          );
        } else if (joinGameError == null && setupNote != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ Game saved. Note: $setupNote')),
          );
        } else if (joinGameError != null && setupNote == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 8),
              content: Text(
                '✅ Game & chat linked. join_game failed:\n$joinGameError',
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 8),
              content: Text(
                '✅ Game saved. $setupNote · join_game: $joinGameError',
              ),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 6),
            content: Text(
              '✅ Game was saved. Chat linking failed — see previous message and console [CreateGameChat].',
            ),
          ),
        );
        if (joinGameError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 8),
              content: Text('join_game also failed:\n$joinGameError'),
            ),
          );
        }
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
        // List updates via realtime stream (no manual refresh).
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Save failed: $e')));
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
        ).showSnackBar(const SnackBar(content: Text('Please login first')));
        return;
      }

      if (widget.joinedLocal.contains(gameId)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Already joined')),
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
            const SnackBar(content: Text('❌ Full already')),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ Joined!')));

      setState(() {
        widget.joinedLocal.add(gameId);
      });
      widget.onGamesMutated?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Join failed: $e')));
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
                    'Sport • game level • start/end • location • players • cost split',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurface.withOpacity(0.7),
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
                onPressed: _createGame,
                icon: const Icon(Icons.add),
                label: const Text('Create Game'),
              ),
            ),

            const SizedBox(height: 10),

            Text(
              'Next step: Save to Supabase + share link + join/pay flow',

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
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return Text('Load failed: ${snapshot.error}');
                }

                final games = snapshot.data ?? [];
                final sortedGames = games.reversed.toList();
                final visible = _filterUpcoming(sortedGames);

                if (sortedGames.isEmpty) {
                  return Text(
                    'No games yet. Create your first one!',
                    style: Theme.of(context).textTheme.bodyMedium,
                  );
                }

                if (visible.isEmpty) {
                  return Text(
                    'No joinable games within ${_radiusKm.toInt()} km of $_filterCity. Try a larger radius or another city.',
                    style: Theme.of(context).textTheme.bodyMedium,
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
    final filtered = list.where((p) {
      final id = p['id']?.toString();
      if (id == null) return false;
      if (swipedIds.contains(id)) return false;
      if (!_hasCommonSport(p)) return false;
      return true;
    }).toList();

    _candidates = filtered;
  }

  Map<String, dynamic>? get _current {
    if (_index < 0 || _index >= _candidates.length) return null;
    return _candidates[_index];
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

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('🎉 Matched! Chat created')),
          );

          // ✅ 直接进入聊天室
          final otherName = (cur['display_name'] ?? 'Chat').toString();

          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChatRoomPage(
                chatId: chatId.toString(),
                title: otherName,
                chatKind: 'direct',
                directPeerUserId: toUser,
              ),
            ),
          );
        }
      }

      // 3) 下一张
      setState(() {
        _index += 1;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Swipe failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _sportsText(Map<String, dynamic> p) {
    final sl = p['sport_levels'];
    if (sl is! Map) return '-';
    final items = sl.entries
        .map((e) => '${e.key}: ${e.value}')
        .take(4)
        .toList();
    return items.isEmpty ? '-' : items.join('  •  ');
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
          return 'Overlap: $day ${inter.first}';
        }
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading && _candidates.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('❌ $_error', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              if (_user == null)
                FilledButton(
                  onPressed: () async {
                    final ok = await _ensureLoginAndPrompt(context);
                    if (!ok) return;
                    await _bootstrap();
                  },
                  child: const Text('Login / Retry'),
                )
              else
                FilledButton(onPressed: _bootstrap, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final cur = _current;
    if (cur == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_outline, size: 64, color: cs.primary),
              const SizedBox(height: 12),
              const Text('No more matches right now.'),
              const SizedBox(height: 6),
              Text(
                'Tip: add more sports in Profile so others can find you.',
                style: TextStyle(color: cs.onSurface.withOpacity(0.7)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              FilledButton(onPressed: _bootstrap, child: const Text('Refresh')),
            ],
          ),
        ),
      );
    }

    final name = (cur['display_name'] ?? 'Unknown').toString();
    final city = (cur['city'] ?? '').toString();
    final intro = (cur['intro'] ?? '').toString();
    final avatar = (cur['avatar_url'] ?? '').toString();
    final overlap = _overlapHint(cur);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 卡片
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: cs.primary.withOpacity(0.12)),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                    color: Colors.black.withOpacity(0.05),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 头像/封面
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(22),
                    ),
                    child: Container(
                      height: 260,
                      width: double.infinity,
                      color: cs.primary.withOpacity(0.08),
                      child: avatar.isEmpty
                          ? Center(
                              child: Icon(
                                Icons.person,
                                size: 72,
                                color: cs.primary,
                              ),
                            )
                          : Image.network(avatar, fit: BoxFit.cover),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          city.isEmpty ? 'City not set' : city,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: cs.onSurface.withOpacity(0.7)),
                        ),
                        const SizedBox(height: 10),

                        // sports & levels (all levels shown — swipe is not level-gated)
                        Text(
                          'Sports & levels',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: cs.onSurface.withOpacity(0.75),
                              ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: cs.primary.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: cs.primary.withOpacity(0.12),
                            ),
                          ),
                          child: Text(
                            _sportsText(cur),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),

                        if (overlap.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            overlap,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: cs.secondary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],

                        if (intro.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(intro),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // 操作按钮
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _loading ? null : () => _swipe('pass'),
                  icon: const Icon(Icons.close),
                  label: const Text('Pass'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _loading ? null : () => _swipe('like'),
                  icon: const Icon(Icons.favorite),
                  label: const Text('Like'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Text(
            'Showing ${_index + 1} / ${_candidates.length}',
            style: TextStyle(color: cs.onSurface.withOpacity(0.6)),
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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ Left game')));

      setState(() {
        _myGamesFuture = _fetchMyGames();
      });
      widget.onGamesMutated?.call();
    } catch (e) {
      if (!mounted) return;

      final msg = e.toString().contains('NOT_JOINED_OR_EMPTY')
          ? '❌ Cannot leave'
          : '❌ Leave failed: $e';

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
      try {
        final rows = await supabase
            .from('game_participants')
            .select(
              'game_id, games(id, sport, game_level, starts_at, ends_at, location_text, players, joined_count, per_person, created_by, game_chat_id)',
            )
            .eq('user_id', u.id)
            .eq('status', 'joined');

        games = [];
        for (final r in rows as List) {
          final nested = r['games'];
          if (nested is Map) {
            games.add(
              Map<String, dynamic>.from(Map<Object?, Object?>.from(nested)),
            );
          }
        }
        games.sort((a, b) {
          final ta = DateTime.tryParse(a['starts_at']?.toString() ?? '');
          final tb = DateTime.tryParse(b['starts_at']?.toString() ?? '');
          if (ta == null && tb == null) return 0;
          if (ta == null) return 1;
          if (tb == null) return -1;
          return ta.compareTo(tb);
        });
      } catch (_) {
        games = [];
      }
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
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Load failed: ${snapshot.error}'));
        }

        final games = snapshot.data ?? [];
        if (games.isEmpty) {
          return const Center(child: Text('No joined games yet.'));
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
                      'Group chat unavailable for this game (run latest DB migration / check game_chat_id).',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.error,
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
                      'Roster loads after migration (game_participants).',
                      style: Theme.of(context).textTheme.bodySmall,
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
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  User? get _user => Supabase.instance.client.auth.currentUser;

  late Future<List<Map<String, dynamic>>> _chatsFuture;

  @override
  void initState() {
    super.initState();
    _chatsFuture = _fetchMyChats();
  }

  Future<List<Map<String, dynamic>>> _fetchMyChats() async {
    final u = _user;
    if (u == null) return [];

    final supabase = Supabase.instance.client;

    List<Map<String, dynamic>> list;
    try {
      final data = await supabase
          .from('chat_members')
          .select(
            'chat_id, last_read_at, chats(id, last_message, last_message_at, created_at, chat_kind, game_id, title)',
          )
          .eq('user_id', u.id);
      list = (data as List).cast<Map<String, dynamic>>();
    } catch (_) {
      final data = await supabase
          .from('chat_members')
          .select(
            'chat_id, last_read_at, chats(id, last_message, last_message_at, created_at)',
          )
          .eq('user_id', u.id);
      list = (data as List).cast<Map<String, dynamic>>();
    }

    final chats = list.map((row) {
      final chat = (row['chats'] ?? {}) as Map;
      return {
        'chat_id': row['chat_id'],
        'last_read_at': row['last_read_at'],
        'last_message': chat['last_message'],
        'last_message_at': chat['last_message_at'],
        'created_at': chat['created_at'],
        'chat_kind': (chat['chat_kind'] ?? 'direct').toString(),
        'game_id': chat['game_id'],
        'title': chat['title'],
      };
    }).toList();

    chats.sort((a, b) {
      final ta = DateTime.tryParse(
        (a['last_message_at'] ?? '')?.toString() ?? '',
      );
      final tb = DateTime.tryParse(
        (b['last_message_at'] ?? '')?.toString() ?? '',
      );
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return tb.compareTo(ta);
    });

    final enriched =
        await Future.wait(chats.map((c) => _enrichChatRow(c, u.id)));
    return enriched;
  }

  Future<int> _gameMemberCount(String chatId) async {
    try {
      final rows = await Supabase.instance.client
          .from('chat_members')
          .select('user_id')
          .eq('chat_id', chatId);
      return (rows as List).length;
    } catch (_) {
      return 0;
    }
  }

  Future<Map<String, dynamic>> _enrichChatRow(
    Map<String, dynamic> c,
    String myId,
  ) async {
    final supabase = Supabase.instance.client;
    final chatId = c['chat_id'].toString();
    final lastRead = c['last_read_at']?.toString();
    final kind = (c['chat_kind'] ?? 'direct').toString();

    final unread = await countUnreadForChat(
      supabase: supabase,
      chatId: chatId,
      me: myId,
      lastReadIso: lastRead,
    );

    if (kind == 'game') {
      final n = await _gameMemberCount(chatId);
      return {
        ...c,
        'member_count': n,
        'ui_title': (c['title'] ?? 'Game chat').toString(),
        'ui_avatar': null,
        'unread': unread,
        'direct_peer_id': null,
      };
    }

    final other = await supabase
        .from('chat_members')
        .select('user_id')
        .eq('chat_id', chatId)
        .neq('user_id', myId)
        .limit(1)
        .maybeSingle();
    final oid = other?['user_id']?.toString();

    var name = 'Chat';
    String? av;
    if (oid != null) {
      final p = await supabase
          .from('profiles')
          .select('display_name, avatar_url')
          .eq('id', oid)
          .maybeSingle();
      final dn = (p?['display_name'] ?? '').toString().trim();
      name = dn.isNotEmpty
          ? dn
          : 'User ${oid.length >= 6 ? oid.substring(0, 6) : oid}';
      av = p?['avatar_url']?.toString();
    }

    return {
      ...c,
      'member_count': 0,
      'ui_title': name,
      'ui_avatar': av,
      'unread': unread,
      'direct_peer_id': oid,
    };
  }

  Widget _unreadTrailing(int n) {
    if (n <= 0) return const SizedBox.shrink();
    final label = n >= 50 ? '50+' : '$n';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 12,
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
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Load chats failed: ${snapshot.error}'));
        }

        final chats = snapshot.data ?? [];
        if (chats.isEmpty) {
          return Center(
            child: Text(
              _user == null
                  ? 'Login to start chatting.'
                  : 'No chats yet. Match someone first 🙂',
            ),
          );
        }

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
              final uiTitle = (c['ui_title'] ?? c['title'] ?? 'Chat').toString();
              final uiAvatar = c['ui_avatar']?.toString();
              final unread = (c['unread'] as num?)?.toInt() ?? 0;
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
                            style: const TextStyle(fontWeight: FontWeight.w800),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      last.isEmpty
                          ? 'Group chat · $n people'
                          : last,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: _unreadTrailing(unread),
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
                  title: Text(
                    uiTitle,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    last.isEmpty ? 'Say hi 👋' : last,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: _unreadTrailing(unread),
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

  @override
  void dispose() {
    _readDebounce?.cancel();
    final u = _user;
    if (u != null) {
      markChatRead(
        Supabase.instance.client,
        chatId: widget.chatId,
        userId: u.id,
      );
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Send failed: $e')));
    }
  }

  @override
  void initState() {
    super.initState();
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
            const SnackBar(content: Text('No members found')),
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
          SnackBar(content: Text('Could not load members: $e')),
        );
      }
    }
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
                onTap: _directPeerId == null
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                OtherProfilePage(userId: _directPeerId!),
                          ),
                        );
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
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Messages stream error:\n${snapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  return const Center(child: CircularProgressIndicator());
                }
                final msgs = _mergeVisibleMessages(snapshot.data!);
                if (msgs.isEmpty) {
                  return const Center(child: Text('Say hi 👋'));
                }

                final newestFirst = msgs.reversed.toList();

                final len = msgs.length;
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

                return ListView.builder(
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

                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
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
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // 输入框
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      decoration: const InputDecoration(
                        hintText: 'Message...',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(onPressed: _send, child: const Text('Send')),
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

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  User? get _user => Supabase.instance.client.auth.currentUser;

  final _nameCtrl = TextEditingController();
  final _birthYearCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _introCtrl = TextEditingController();

  /// Tracks which user we last loaded into the form (guest → login needs reload).
  String? _lastLoadedProfileUserId;

  String? _avatarUrl;
  bool _loading = false;
  bool _loaded = false;

  // dynamic: 先选运动，再选 level
  final Map<String, String> _sportLevels = {};
  String? _sportToAdd;

  static const _sports = [
    'Tennis',
    'Golf',
    'Pickleball',
    'Badminton',
    'Ski',
    'Snowboard',
    'Running',
    'Gym',
  ];

  static const _levels = [
    'Beginner',
    'Intermediate',
    'Advanced',
    'Competitive',
    'Pro',
  ];

  final Map<String, Set<String>> _availability = {
    'Mon': <String>{},
    'Tue': <String>{},
    'Wed': <String>{},
    'Thu': <String>{},
    'Fri': <String>{},
    'Sat': <String>{},
    'Sun': <String>{},
  };

  Future<List<Map<String, dynamic>>>? _myPostsFuture;

  @override
  void initState() {
    super.initState();
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
      final supabase = Supabase.instance.client;
      final row = await supabase
          .from('profiles')
          .select(
            'display_name,birth_year,city,intro,avatar_url,sport_levels,availability',
          )
          .eq('id', user.id)
          .maybeSingle();

      if (row != null) {
        _nameCtrl.text = (row['display_name'] ?? '') as String;
        _birthYearCtrl.text = row['birth_year'] == null
            ? ''
            : row['birth_year'].toString();
        _cityCtrl.text = (row['city'] ?? '') as String;
        _introCtrl.text = (row['intro'] ?? '') as String;
        _avatarUrl = row['avatar_url'] as String?;

        final sl = row['sport_levels'];
        if (sl is Map) {
          _sportLevels
            ..clear()
            ..addAll(sl.map((k, v) => MapEntry(k.toString(), v.toString())));
        }
        // ✅ 防止已存在的 sport 还留在 dropdown 里
        if (_sportToAdd != null && _sportLevels.containsKey(_sportToAdd)) {
          _sportToAdd = null;
        }

        final avail = row['availability'];
        if (avail is Map) {
          for (final day in _availability.keys) {
            final v = avail[day];
            if (v is List) {
              _availability[day] = v.map((e) => e.toString()).toSet();
            }
          }
        }
      }

      if (mounted) setState(() => _loaded = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loaded = true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Load profile failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveProfile() async {
    final user = _user;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please login first')));
      return;
    }

    final birthYear = int.tryParse(_birthYearCtrl.text.trim());

    final availabilityJson = <String, dynamic>{};
    _availability.forEach((day, slots) {
      availabilityJson[day] = slots.toList()..sort();
    });

    setState(() => _loading = true);

    try {
      final supabase = Supabase.instance.client;
      await supabase.from('profiles').upsert({
        'id': user.id,
        'display_name': _nameCtrl.text.trim(),
        'birth_year': birthYear,
        'city': _cityCtrl.text.trim(),
        'intro': _introCtrl.text.trim(),
        'avatar_url': _avatarUrl,
        'sport_levels': _sportLevels,
        'availability': availabilityJson,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ Profile saved')));
      SmeetShell.refreshAuthState();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Save failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String> _uploadToMediaBucketXFile(
    XFile xfile, {
    required String folder,
  }) async {
    final user = _user;
    if (user == null) throw Exception('Not logged in');

    final supabase = Supabase.instance.client;
    final uuid = const Uuid().v4();

    final ext = (xfile.name.split('.').last).toLowerCase();
    final path = '${user.id}/$folder/$uuid.$ext';

    final Uint8List bytes = await xfile.readAsBytes();

    String contentType = 'application/octet-stream';
    if (ext == 'png') contentType = 'image/png';
    if (ext == 'jpg' || ext == 'jpeg') contentType = 'image/jpeg';
    if (ext == 'mp4') contentType = 'video/mp4';
    if (ext == 'mov') contentType = 'video/quicktime';

    await supabase.storage
        .from('media')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );

    return supabase.storage.from('media').getPublicUrl(path);
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
      ).showSnackBar(SnackBar(content: Text('❌ Avatar upload failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchMyPosts() async {
    final user = _user;
    if (user == null) return [];

    final supabase = Supabase.instance.client;
    final data = await supabase
        .from('posts')
        .select('id, caption, media_type, media_urls, created_at, author_id')
        .eq('author_id', user.id)
        .order('created_at', ascending: false);

    return (data as List).cast<Map<String, dynamic>>();
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

      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please login to post')));
        return;
      }
      final inserted = await supabase
          .from('posts')
          .insert({
            'author_id': user.id,
            'sport': 'tennis',
            'visibility': 'public',
            'media_urls': [url],
            'media_type': mediaType,
            'caption': caption.trim(),
            'content': caption.trim(),
          })
          .select('id, author_id, created_at')
          .single();

      debugPrint('✅ INSERT OK => $inserted');

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ Posted')));

      setState(() {
        _myPostsFuture = _fetchMyPosts();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Post failed: $e')));
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
    ).showSnackBar(const SnackBar(content: Text('Signed out')));
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

    // 允许游客打开 profile：提示登录
    if (_user == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_outline, size: 72, color: cs.primary),
              const SizedBox(height: 14),
              Text(
                'Guest mode',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                'Login to upload avatar, set your sports profile, and post photos/videos.',
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
                child: const Text('Login / Sign up'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_loaded && _loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final slots = const ['Morning', 'Afternoon', 'Night'];

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
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
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _cityCtrl.text.trim().isEmpty
                                ? 'City not set'
                                : _cityCtrl.text.trim(),
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

              SizedBox(
                height: 900, // 简单处理：给 TabBarView 一个高度
                child: TabBarView(
                  children: [
                    // ========== TAB 1: Profile ==========
                    SingleChildScrollView(
                      child: Column(
                        children: [
                          _card(
                            context,
                            child: Column(
                              children: [
                                TextField(
                                  controller: _nameCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Display name',
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _birthYearCtrl,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          labelText: 'Birth year',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextField(
                                        controller: _cityCtrl,
                                        decoration: const InputDecoration(
                                          labelText: 'City',
                                          border: OutlineInputBorder(),
                                        ),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _introCtrl,
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                    labelText: 'Sports-only bio',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Sports & Level
                          _card(
                            context,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sports & Level',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 10),
                                // ✅ 防止 Dropdown value 不在 items 里导致红屏
                                Builder(
                                  builder: (context) {
                                    final availableSports = _sports
                                        .where(
                                          (s) => !_sportLevels.containsKey(s),
                                        )
                                        .toList();
                                    final safeValue =
                                        availableSports.contains(_sportToAdd)
                                        ? _sportToAdd
                                        : null;

                                    return DropdownButtonFormField<String>(
                                      initialValue: safeValue,
                                      decoration: const InputDecoration(
                                        labelText: 'Choose a sport',
                                        border: OutlineInputBorder(),
                                      ),
                                      items: availableSports
                                          .map(
                                            (s) => DropdownMenuItem(
                                              value: s,
                                              child: Text(s),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (v) =>
                                          setState(() => _sportToAdd = v),
                                    );
                                  },
                                ),

                                const SizedBox(height: 10),
                                if (_sportToAdd != null)
                                  DropdownButtonFormField<String>(
                                    initialValue:
                                        _sportLevels[_sportToAdd!] ??
                                        _levels.first,
                                    decoration: InputDecoration(
                                      labelText: '${_sportToAdd!} level',
                                      border: const OutlineInputBorder(),
                                    ),
                                    items: _levels
                                        .map(
                                          (l) => DropdownMenuItem(
                                            value: l,
                                            child: Text(l),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) {
                                      if (v == null) return;
                                      setState(() {
                                        _sportLevels[_sportToAdd!] = v;
                                      });
                                    },
                                  ),
                                const SizedBox(height: 12),
                                if (_sportLevels.isEmpty)
                                  Text(
                                    'No sports added yet.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: cs.onSurface.withOpacity(0.7),
                                        ),
                                  )
                                else
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _sportLevels.entries.map((e) {
                                      return InputChip(
                                        label: Text('${e.key}: ${e.value}'),
                                        onDeleted: () {
                                          setState(() {
                                            _sportLevels.remove(e.key);
                                            if (_sportToAdd == e.key) {
                                              _sportToAdd = null;
                                            }
                                          });
                                        },
                                      );
                                    }).toList(),
                                  ),
                              ],
                            ),
                          ),

                          // Availability
                          _card(
                            context,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Availability',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 10),
                                ..._availability.keys.map((day) {
                                  final selected = _availability[day]!;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          day,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: slots.map((s) {
                                            final isOn = selected.contains(s);
                                            return ChoiceChip(
                                              label: Text(s),
                                              selected: isOn,
                                              onSelected: (on) {
                                                setState(() {
                                                  if (on) {
                                                    selected.add(s);
                                                  } else {
                                                    selected.remove(s);
                                                  }
                                                });
                                              },
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),

                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _loading ? null : _saveProfile,
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
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              if (snapshot.hasError) {
                                return Center(
                                  child: Text(
                                    'Load posts failed: ${snapshot.error}',
                                  ),
                                );
                              }

                              final posts = snapshot.data ?? [];
                              if (posts.isEmpty) {
                                return const Center(
                                  child: Text('No posts yet.'),
                                );
                              }

                              return ListView.builder(
                                itemCount: posts.length,
                                itemBuilder: (context, i) {
                                  final p = posts[i];

                                  // 1) 读字段
                                  final caption = (p['caption'] ?? '')
                                      .toString();
                                  final type = (p['media_type'] ?? 'image')
                                      .toString()
                                      .toLowerCase();

                                  // ✅ 正确：从 media_urls 数组里取
                                  final List mediaUrls =
                                      (p['media_urls'] ?? []) as List;
                                  final String url = mediaUrls.isNotEmpty
                                      ? mediaUrls.first.toString()
                                      : '';

                                  // 2) ✅ Debug：看类型和URL到底是什么
                                  debugPrint('POST[$i] type=$type url=$url');

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
                                        // 3) ✅ 用 _PostMedia 统一渲染 image / video（视频可直接点播）
                                        _PostMedia(type: type, url: url),

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
  }

  Widget _card(BuildContext context, {required Widget child}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.primary.withOpacity(0.10)),
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

/// 一个统一的占位页（后面再替换成真实页面）
class _PostMedia extends StatefulWidget {
  final String type; // 'image' | 'video'
  final String url;

  const _PostMedia({required this.type, required this.url});

  @override
  State<_PostMedia> createState() => _PostMediaState();
}

class _PostMediaState extends State<_PostMedia> {
  VideoPlayerController? _vc;
  Future<void>? _initFuture;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  @override
  void didUpdateWidget(covariant _PostMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 如果类型或URL变了，重新初始化 controller
    if (oldWidget.url != widget.url || oldWidget.type != widget.type) {
      _disposeVc();
      _setup();
    }
  }

  void _setup() {
    if (widget.type != 'video' || widget.url.isEmpty) return;

    final uri = Uri.parse(widget.url);
    _vc = VideoPlayerController.networkUrl(uri);
    _initFuture = _vc!.initialize().then((_) {
      // 可选：默认静音，避免刷屏有声音
      _vc!.setVolume(0);
      if (mounted) setState(() {});
    });
  }

  void _disposeVc() {
    _vc?.dispose();
    _vc = null;
    _initFuture = null;
  }

  @override
  void dispose() {
    _disposeVc();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // IMAGE
    if (widget.type == 'image') {
      if (widget.url.isEmpty) {
        return _emptyBox(context, icon: Icons.image_not_supported);
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: Image.network(
            widget.url,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _emptyBox(context, label: 'Image failed');
            },
          ),
        ),
      );
    }

    // VIDEO
    if (widget.type == 'video') {
      if (widget.url.isEmpty) {
        return _emptyBox(context, icon: Icons.play_disabled, label: 'No video');
      }

      if (_vc == null || _initFuture == null) {
        return _emptyBox(
          context,
          icon: Icons.play_circle_outline,
          label: 'Init',
        );
      }

      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          color: Colors.black,
          child: FutureBuilder<void>(
            future: _initFuture,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(cs.primary),
                    ),
                  ),
                );
              }

              final ar =
                  (_vc!.value.isInitialized && _vc!.value.aspectRatio > 0)
                  ? _vc!.value.aspectRatio
                  : (4 / 3);

              return Stack(
                alignment: Alignment.center,
                children: [
                  AspectRatio(aspectRatio: ar, child: VideoPlayer(_vc!)),
                  // 播放/暂停按钮
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        if (_vc!.value.isPlaying) {
                          _vc!.pause();
                        } else {
                          _vc!.play();
                        }
                      });
                    },
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.35),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _vc!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                        size: 36,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    }

    // unknown type fallback
    return _emptyBox(context, icon: Icons.help_outline);
  }

  Widget _emptyBox(BuildContext context, {IconData? icon, String? label}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 220,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: cs.primary.withOpacity(0.08),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon ?? Icons.broken_image, size: 56),
          if (label != null) ...[const SizedBox(height: 6), Text(label)],
        ],
      ),
    );
  }
}

class MatchesPage extends StatefulWidget {
  const MatchesPage({super.key});

  @override
  State<MatchesPage> createState() => _MatchesPageState();
}

class _MatchesPageState extends State<MatchesPage> {
  User? get _user => Supabase.instance.client.auth.currentUser;

  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchMatches();
  }

  Future<List<Map<String, dynamic>>> _fetchMatches() async {
    final u = _user;
    if (u == null) return [];

    final supabase = Supabase.instance.client;

    // matches: user_a, user_b
    final rows = await supabase
        .from('matches')
        .select('user_a,user_b,created_at')
        .or('user_a.eq.${u.id},user_b.eq.${u.id}')
        .order('created_at', ascending: false);

    final list = (rows as List).cast<Map<String, dynamic>>();

    // 取出 other ids
    final otherIds = list
        .map((m) {
          final a = m['user_a'].toString();
          final b = m['user_b'].toString();
          return a == u.id ? b : a;
        })
        .toSet()
        .toList();

    if (otherIds.isEmpty) return [];

    final prof = await supabase
        .from('profiles')
        .select(
          'id,display_name,city,intro,avatar_url,sport_levels,availability',
        )
        .inFilter('id', otherIds);

    final profiles = (prof as List).cast<Map<String, dynamic>>();

    // 按 otherIds 顺序排一下
    final map = {for (final p in profiles) p['id'].toString(): p};
    return otherIds.map((id) => map[id] ?? {'id': id}).toList();
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
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return const Center(child: Text('No matches yet.'));
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
                  onTap: () {
                    // MVP：先弹出简介（你后面可以做完整 ProfileViewPage）
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text(name),
                        content: Text(
                          (p['intro'] ?? '').toString().isEmpty
                              ? 'No bio yet.'
                              : (p['intro'] ?? '').toString(),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
