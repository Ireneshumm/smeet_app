import 'dart:convert';

import 'package:flutter/foundation.dart'; // kIsWeb
import 'package:video_player/video_player.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:smeet_app/widgets/location_search_field.dart';

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
    // Guest mode: never block app access behind login.
    // Individual pages/actions will call `_ensureLoginAndPrompt` when needed.
    return const SmeetShell();
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _isLogin = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    final email = _emailCtrl.text.trim();
    final password = _pwCtrl.text;

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
      } else {
        // On web, Supabase may require the redirect URL to be on the allow list
        // (URL Configuration -> Redirect URLs) for email confirmation flows.
        await auth.signUp(
          email: email,
          password: password,
          emailRedirectTo: kIsWeb ? '${Uri.base.origin}/' : null,
        );
      }
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
            'mode': _isLogin ? 'login' : 'signup',
          },
        })}',
      );
      // #endregion
      if (mounted) Navigator.of(context).pop();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 12),
          content: Text(
            isWebFetchFail
                ? '❌ Browser could not reach Supabase (no HTTP status). '
                    'Use a fixed port: run "Smeet: Chrome (web port 8080)" or '
                    'flutter run -d chrome --web-port=8080, then in Supabase → '
                    'Authentication → URL Configuration set Site URL + Redirect URLs '
                    'for http://localhost:8080 (see WEB_AUTH.md). DevTools → Network '
                    'for details. Raw: $msg'
                : '❌ Auth failed: $msg',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isLogin ? 'Login' : 'Sign Up')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _emailCtrl,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _pwCtrl,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _submit,
                child: Text(
                  _loading ? '...' : (_isLogin ? 'Login' : 'Create account'),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => setState(() => _isLogin = !_isLogin),
              child: Text(
                _isLogin ? 'No account? Sign up' : 'Have an account? Login',
              ),
            ),
          ],
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

  return auth.currentUser != null;
}

/// Smeet 主框架：底部 5 个 Tab
class SmeetShell extends StatefulWidget {
  const SmeetShell({super.key});

  @override
  State<SmeetShell> createState() => _SmeetShellState();
}

class _SmeetShellState extends State<SmeetShell> {
  int _index = 0;
  final Set<String> _joinedLocal = {};

  late final List<Widget> _pages = [
    HomePage(joinedLocal: _joinedLocal), // 👈 这里传进去
    const SwipePage(),
    MyGamePage(joinedLocal: _joinedLocal), // 👈 这里也传
    const ChatPage(),
    const ProfilePage(),
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

  const HomePage({super.key, required this.joinedLocal});

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
  DateTime? _dateTime;
  int _players = 4;
  LocationResult? _selectedLocation;
  final _courtFeeCtrl = TextEditingController(text: '20');

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

  Future<void> _pickDateTime() async {
    final now = DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: _dateTime ?? now,
      firstDate: now.subtract(const Duration(days: 0)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime ?? now),
    );
    if (time == null) return;

    setState(() {
      _dateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _createGame() async {
    if (!await _ensureLogin()) return;
    if (!_formKey.currentState!.validate()) return;
    if (_dateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select date & time')),
      );
      return;
    }

    final dt = _dateTime!;
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
            'starts_at': dt.toUtc().toIso8601String(),
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

      final gameId = result['id'];

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Saved to Supabase! ID: $gameId')),
      );
      setState(() {
        _sport = 'Tennis';
        _dateTime = null;
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
      debugPrint('USER = ${user?.id}');
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

      // 1) 读当前 joined_count / players
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('❌ Full already')));
        return;
      }

      // 2) ✅ update 后立刻 select 返回新值（关键！）
      final updated = await supabase
          .from('games')
          .update({'joined_count': joined + 1})
          .eq('id', gameId)
          .select('id, joined_count')
          .maybeSingle();

      if (updated == null) {
        throw Exception(
          'No row updated (blocked by RLS/permission or id not found)',
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ Joined!')));

      // Realtime stream updates joined_count for everyone; we only track local Joined UI.
      setState(() {
        widget.joinedLocal.add(gameId);
      });
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

    String dateTimeLabel;
    if (_dateTime == null) {
      dateTimeLabel = 'Select date & time';
    } else {
      final dt = _dateTime!;
      final y = dt.year.toString().padLeft(4, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      dateTimeLabel = '$y-$m-$d  $hh:$mm';
    }

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
                    'Pick sport • time • location • players • split costs',
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

            // Date time
            _SectionCard(
              child: InkWell(
                onTap: _pickDateTime,
                borderRadius: BorderRadius.circular(14),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date & Time',
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined),
                      const SizedBox(width: 10),
                      Expanded(child: Text(dateTimeLabel)),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
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
                onLocationSelected: (address, lat, lng) {
                  setState(() {
                    _selectedLocation = LocationResult(
                      address: address,
                      lat: lat,
                      lng: lng,
                    );
                  });
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
                            'Each pays: \$${_perPerson.toStringAsFixed(2)}',
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
                // Reverse the list since stream ordering might differ
                final sortedGames = games.reversed.toList();

                if (sortedGames.isEmpty) {
                  return Text(
                    'No games yet. Create your first one!',
                    style: Theme.of(context).textTheme.bodyMedium,
                  );
                }

                return Column(
                  children: sortedGames.map((g) {
                    final sport = g['sport'] ?? '';
                    final loc = g['location_text'] ?? '';
                    final players = (g['players'] as num?)?.toInt() ?? 0;
                    final joined = (g['joined_count'] as num?)?.toInt() ?? 0;
                    final remaining = (players - joined) < 0
                        ? 0
                        : (players - joined);
                    final isFull = remaining == 0;
                    final gameId = g['id'].toString();
                    final perPerson = (g['per_person'] ?? 0.0) as num;
                    final isJoined = widget.joinedLocal.contains(gameId);

                    DateTime? startsAt;
                    if (g['starts_at'] != null) {
                      startsAt = DateTime.tryParse(g['starts_at'])?.toLocal();
                    }

                    final when = startsAt == null
                        ? '-'
                        : '${startsAt.year}-${startsAt.month.toString().padLeft(2, '0')}-${startsAt.day.toString().padLeft(2, '0')} '
                              '${startsAt.hour.toString().padLeft(2, '0')}:${startsAt.minute.toString().padLeft(2, '0')}';

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
                                  '$sport • $players players • \$${perPerson.toStringAsFixed(2)}/pp',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  loc,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  when,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Remaining: $remaining',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: isFull
                                            ? Colors.red
                                            : Theme.of(context)
                                                .colorScheme
                                                .secondary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            onPressed: (isFull || isJoined)
                                ? null
                                : () => _joinGame(gameId),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: Text(
                              isFull
                                  ? 'Full'
                                  : isJoined
                                      ? 'Joined'
                                      : 'Join',
                            ),
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

  // 判断：是否有可约时间重叠（同一天同slot）
  bool _hasAvailabilityOverlap(Map<String, dynamic> other) {
    final myAv = _myProfile?['availability'];
    final otAv = other['availability'];

    if (myAv is! Map || otAv is! Map) return false;

    for (final day in myAv.keys) {
      final mySlots = myAv[day];
      final otSlots = otAv[day];
      if (mySlots is List && otSlots is List) {
        final s1 = mySlots.map((e) => e.toString()).toSet();
        final s2 = otSlots.map((e) => e.toString()).toSet();
        if (s1.intersection(s2).isNotEmpty) return true;
      }
    }
    return false;
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

    // 3) 本地过滤：没 swipe 过 + 有共同运动 + 可约时间有重叠
    final filtered = list.where((p) {
      final id = p['id']?.toString();
      if (id == null) return false;
      if (swipedIds.contains(id)) return false;
      if (!_hasCommonSport(p)) return false;
      if (!_hasAvailabilityOverlap(p)) return false;
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
              builder: (_) =>
                  ChatRoomPage(chatId: chatId.toString(), title: otherName),
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
                'Tip: add more Sports & Availability in Profile.',
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

                        // sports
                        Container(
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
                                ?.copyWith(fontWeight: FontWeight.w700),
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
  const MyGamePage({super.key, required this.joinedLocal});

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

  Future<void> _leaveGame(String gameId) async {
    final ok = await _ensureLoginAndPrompt(context);
    if (!ok) return;

    try {
      final supabase = Supabase.instance.client;

      // 1) 调用 RPC 扣 joined_count
      await supabase.rpc('leave_game', params: {'p_game_id': gameId});

      // 2) 本地移除已加入记录
      widget.joinedLocal.remove(gameId);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ Left game')));

      // 3) 刷新 MyGame 列表
      setState(() {
        _myGamesFuture = _fetchMyGames();
      });
    } catch (e) {
      if (!mounted) return;

      final msg = e.toString().contains('NOT_JOINED_OR_EMPTY')
          ? '❌ Cannot leave'
          : '❌ Leave failed: $e';

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<List<Map<String, dynamic>>> _fetchMyGames() async {
    final supabase = Supabase.instance.client;

    if (widget.joinedLocal.isEmpty) return [];

    final data = await supabase
        .from('games')
        .select(
          'id, sport, starts_at, location_text, players, joined_count, per_person, created_at',
        )
        .inFilter('id', widget.joinedLocal.toList())
        .order('starts_at', ascending: true);

    return (data as List).cast<Map<String, dynamic>>();
  }

  @override
  Widget build(BuildContext context) {
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
            final sport = g['sport'] ?? '';
            final loc = g['location_text'] ?? '';
            final perPerson = (g['per_person'] ?? 0) as num;

            DateTime? startsAt;
            if (g['starts_at'] != null) {
              startsAt = DateTime.tryParse(g['starts_at'])?.toLocal();
            }

            final when = startsAt == null
                ? '-'
                : '${startsAt.year}-${startsAt.month.toString().padLeft(2, '0')}-${startsAt.day.toString().padLeft(2, '0')} '
                      '${startsAt.hour.toString().padLeft(2, '0')}:${startsAt.minute.toString().padLeft(2, '0')}';

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withOpacity(0.12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$sport • \$${perPerson.toStringAsFixed(2)}/pp',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(loc, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(when, style: Theme.of(context).textTheme.bodySmall),

                  const SizedBox(height: 10),

                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonal(
                      onPressed: () => _leaveGame(g['id'].toString()),
                      child: const Text('Leave'),
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

    // 通过 membership 查我的聊天室，并把 chats 信息一起带出来
    final data = await supabase
        .from('chat_members')
        .select('chat_id, chats(id, last_message, last_message_at, created_at)')
        .eq('user_id', u.id);

    final list = (data as List).cast<Map<String, dynamic>>();

    // 展平成 [{chat_id, last_message, last_message_at...}]
    final chats = list.map((row) {
      final chat = (row['chats'] ?? {}) as Map;
      return {
        'chat_id': row['chat_id'],
        'last_message': chat['last_message'],
        'last_message_at': chat['last_message_at'],
        'created_at': chat['created_at'],
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

    return chats;
  }

  Future<String> _otherUserLabel(String chatId) async {
    final u = _user!;
    final supabase = Supabase.instance.client;

    // 找到另一个成员
    final other = await supabase
        .from('chat_members')
        .select('user_id')
        .eq('chat_id', chatId)
        .neq('user_id', u.id)
        .limit(1)
        .maybeSingle();
    final otherId = other?['user_id']?.toString();
    if (otherId == null) return 'Chat';

    // 从 profiles 拿名字（没有就显示短ID）
    final p = await supabase
        .from('profiles')
        .select('display_name')
        .eq('id', otherId)
        .maybeSingle();

    final name = (p?['display_name'] ?? '').toString().trim();
    if (name.isNotEmpty) return name;

    return 'User ${otherId.substring(0, 6)}';
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

              return FutureBuilder<String>(
                future: _otherUserLabel(chatId),
                builder: (context, nameSnap) {
                  final title = nameSnap.data ?? 'Chat';

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
                        child: Icon(Icons.person, color: cs.primary),
                      ),
                      title: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        last.isEmpty ? 'Say hi 👋' : last,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () async {
                        final ok = await _ensureLoginAndPrompt(context);
                        if (!ok) return;
                        final title = nameSnap.data ?? 'Chat';
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                ChatRoomPage(chatId: chatId, title: title),
                          ),
                        );
                        setState(() => _chatsFuture = _fetchMyChats());
                      },
                    ),
                  );
                },
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
  final String title; // ✅ 新增这一行

  const ChatRoomPage({super.key, required this.chatId, required this.title});

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  User? get _user => Supabase.instance.client.auth.currentUser;

  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _listCtrl = ScrollController();

  String _appTitle = 'Chat';
  int _lastMsgCount = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    _listCtrl.dispose();
    super.dispose();
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

    try {
      final supabase = Supabase.instance.client;
      await supabase.from('messages').insert({
        'chat_id': widget.chatId,
        'user_id': u.id,
        'content': text,
      });
      _ctrl.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Send failed: $e')));
    }
  }

  @override
  void initState() {
    super.initState();
    _appTitle = widget.title.isNotEmpty ? widget.title : 'Chat';
    _loadOtherName().then((name) {
      if (mounted) {
        setState(() => _appTitle = name);
      }
    });
  }

  Future<String> _loadOtherName() async {
    try {
      final u = _user;
      if (u == null) return 'Unknown';

      final supabase = Supabase.instance.client;

      final other = await supabase
          .from('chat_members')
          .select('user_id')
          .eq('chat_id', widget.chatId)
          .neq('user_id', u.id)
          .limit(1)
          .maybeSingle();

      final otherId = other?['user_id']?.toString();
      if (otherId == null) return 'Unknown';

      final p = await supabase
          .from('profiles')
          .select('display_name')
          .eq('id', otherId)
          .maybeSingle();

      final name = (p?['display_name'] ?? '').toString().trim();
      if (name.isNotEmpty) {
        return name;
      }

      return 'User ${otherId.substring(0, 6)}';
    } catch (_) {
      return 'Chat';
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = _user;
    final cs = Theme.of(context).colorScheme;

    // ✅ 实时流：messages 表按 chat_id 过滤
    final stream = Supabase.instance.client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('chat_id', widget.chatId)
        .order('id');

    return Scaffold(
      appBar: AppBar(title: Text(_appTitle)),

      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: stream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final msgs = snapshot.data!;
                if (msgs.isEmpty) {
                  return const Center(child: Text('Say hi 👋'));
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final newCount = msgs.length;
                  final hasNewMessage = newCount > _lastMsgCount;

                  _lastMsgCount = newCount;

                  if (hasNewMessage && _listCtrl.hasClients) {
                    _listCtrl.jumpTo(_listCtrl.position.maxScrollExtent);
                  }
                });

                return ListView.builder(
                  controller: _listCtrl,
                  padding: const EdgeInsets.all(12),
                  itemCount: msgs.length,
                  itemBuilder: (context, i) {
                    final m = msgs[i];
                    final isMe =
                        u != null && m['user_id']?.toString() == u.id;
                    final text = (m['content'] ?? '').toString();

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
                            color: cs.primary.withOpacity(0.10),
                          ),
                        ),
                        child: Text(text),
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
    _loadProfile();
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
class _PlaceholderPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _PlaceholderPage({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 72, color: cs.primary),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurface.withOpacity(0.75),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Next: we will build this page.'),
                  ),
                );
              },
              child: const Text('Start building'),
            ),
          ],
        ),
      ),
    );
  }
}

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
