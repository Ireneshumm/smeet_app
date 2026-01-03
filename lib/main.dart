import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
    final auth = Supabase.instance.client.auth;

    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = auth.currentSession;
        if (session != null) return const SmeetShell();
        return const AuthPage();
      },
    );
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

      if (_isLogin) {
        await auth.signInWithPassword(email: email, password: password);
      } else {
        await auth.signUp(email: email, password: password);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Auth failed: $e')));
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
                  // Put your logo here:
                  // 1) Save image to: assets/images/Smeet_logo_transparent.png
                  // 2) Add in pubspec.yaml:
                  //    flutter:
                  //      assets:
                  //        - assets/images/Smeet_logo_transparent.png
                  Image.asset(
                    'assets/images/Smeet_logo_transparent.png',

                    height: 26,
                    errorBuilder: (context, error, stackTrace) {
                      // If asset not added yet, show fallback icon
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
      body: SafeArea(child: _pages[_index]),
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
  User? get _user => Supabase.instance.client.auth.currentUser;

  Future<bool> _ensureLogin() async {
    if (_user != null) return true;

    // 跳登录页
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AuthPage()));

    // 回来后再检查是否登录成功
    return _user != null;
  }

  final ScrollController _scrollCtrl = ScrollController();
  final GlobalKey _upcomingKey = GlobalKey();
  final _formKey = GlobalKey<FormState>();
  late Future<List<Map<String, dynamic>>> _gamesFuture;

  // Form state
  String _sport = 'Tennis';
  DateTime? _dateTime;
  int _players = 4;

  final _locationCtrl = TextEditingController();
  final _courtFeeCtrl = TextEditingController(text: '20'); // default

  @override
  void initState() {
    super.initState();
    _gamesFuture = _fetchGames();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _locationCtrl.dispose();
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
    final loc = _locationCtrl.text.trim();
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
        _locationCtrl.clear();
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

      // 1) 读当前 joined_count / players
      final row = await supabase
          .from('games')
          .select('joined_count, players')
          .eq('id', gameId)
          .maybeSingle();

      if (row == null) {
        throw Exception('Game not found or blocked by RLS');
      }

      final joined = (row['joined_count'] ?? 0) as int;
      final players = (row['players'] ?? 0) as int;

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

      // 3) ✅ 刷新 future，让 UI 重新 fetch 最新 joined_count
      setState(() {
        widget.joinedLocal.add(gameId); // ✅ 记住已加入
        _gamesFuture = _fetchGames(); // ✅ 刷新列表
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Join failed: $e')));
    }
  }

  Future<List<Map<String, dynamic>>> _fetchGames() async {
    final supabase = Supabase.instance.client;

    final data = await supabase
        .from('games')
        .select(
          'id, sport, starts_at, location_text, players, joined_count, per_person, created_at',
        )
        .order('created_at', ascending: false)
        .limit(20);

    return (data as List).cast<Map<String, dynamic>>();
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
                value: _sport,
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
              child: TextFormField(
                controller: _locationCtrl,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  hintText: 'e.g. Kalinga Tennis Park',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final s = (v ?? '').trim();
                  if (s.isEmpty) return 'Please enter a location';
                  return null;
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

            FutureBuilder<List<Map<String, dynamic>>>(
              future: _gamesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return Text('Load failed: ${snapshot.error}');
                }

                final games = snapshot.data ?? [];
                if (games.isEmpty) {
                  return Text(
                    'No games yet. Create your first one!',
                    style: Theme.of(context).textTheme.bodyMedium,
                  );
                }

                return Column(
                  children: games.map((g) {
                    final sport = g['sport'] ?? '';
                    final loc = g['location_text'] ?? '';
                    final players = (g['players'] ?? 0) as int;
                    final joined = (g['joined_count'] ?? 0) as int;
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
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.12),
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

                          /// 左侧：文字信息
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$sport • $players players • \$${perPerson.toStringAsFixed(2)}/pp',
                                  style: Theme.of(context).textTheme.titleSmall
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
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 12),

                          /// 右侧：Join 按钮
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
      setState(() => _error = 'Please login to use Swipe');
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
        .select('id, display_name, city, intro, avatar_url, sport_levels, availability')
        .eq('id', u.id)
        .maybeSingle();

    if (row == null) {
      throw Exception('Your profile not found. Please fill Profile and Save.');
    }

    _myProfile = row;
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
        .select('id, display_name, city, intro, avatar_url, sport_levels, availability')
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
    final u = _user;
    final cur = _current;
    if (u == null || cur == null) return;

    setState(() => _loading = true);

    try {
      final supabase = Supabase.instance.client;
      final toUser = cur['id'].toString();

      // 1) 写入 swipes（upsert 防止重复）
      await supabase.from('swipes').upsert({
        'from_user': u.id,
        'to_user': toUser,
        'action': action,
      });

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
          // 规范化 pair，避免 (a,b) / (b,a) 重复
          final a = u.id.compareTo(toUser) < 0 ? u.id : toUser;
          final b = u.id.compareTo(toUser) < 0 ? toUser : u.id;

          await supabase.from('matches').upsert({
            'user_a': a,
            'user_b': b,
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('🎉 Matched!')),
            );
          }
        }
      }

      // 3) 下一张
      setState(() {
        _index += 1;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Swipe failed: $e')),
        );
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

    if (_user == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.swipe, size: 72, color: cs.primary),
              const SizedBox(height: 12),
              const Text('Login to use Swipe'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AuthPage()),
                  );
                },
                child: const Text('Login / Sign up'),
              ),
            ],
          ),
        ),
      );
    }

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
              FilledButton(
                onPressed: _bootstrap,
                child: const Text('Retry'),
              ),
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
              FilledButton(
                onPressed: _bootstrap,
                child: const Text('Refresh'),
              ),
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
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                    child: Container(
                      height: 260,
                      width: double.infinity,
                      color: cs.primary.withOpacity(0.08),
                      child: avatar.isEmpty
                          ? Center(
                              child: Icon(Icons.person, size: 72, color: cs.primary),
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
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          city.isEmpty ? 'City not set' : city,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: cs.onSurface.withOpacity(0.7),
                              ),
                        ),
                        const SizedBox(height: 10),

                        // sports
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: cs.primary.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: cs.primary.withOpacity(0.12)),
                          ),
                          child: Text(
                            _sportsText(cur),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),

                        if (overlap.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            overlap,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
      final ta = DateTime.tryParse((a['last_message_at'] ?? '')?.toString() ?? '');
      final tb = DateTime.tryParse((b['last_message_at'] ?? '')?.toString() ?? '');
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

    if (_user == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.chat_bubble_outline, size: 72, color: cs.primary),
              const SizedBox(height: 12),
              const Text('Login to use Chat'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AuthPage()),
                  );
                },
                child: const Text('Login / Sign up'),
              ),
            ],
          ),
        ),
      );
    }

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
          return const Center(
            child: Text('No chats yet. Match someone first 🙂'),
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
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChatRoomPage(chatId: chatId),
                          ),
                        );
                        // 返回后刷新一下列表（更新 last message）
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
  const ChatRoomPage({super.key, required this.chatId});

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  User? get _user => Supabase.instance.client.auth.currentUser;
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final u = _user;
    final text = _ctrl.text.trim();
    if (u == null || text.isEmpty) return;

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Send failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = _user;
    final cs = Theme.of(context).colorScheme;

    if (u == null) {
      return const Scaffold(
        body: Center(child: Text('Please login')),
      );
    }

    // ✅ 实时流：messages 表按 chat_id 过滤
    final stream = Supabase.instance.client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('chat_id', widget.chatId)
        .order('id');

    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
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

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: msgs.length,
                  itemBuilder: (context, i) {
                    final m = msgs[i];
                    final isMe = m['user_id']?.toString() == u.id;
                    final text = (m['content'] ?? '').toString();

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        constraints: const BoxConstraints(maxWidth: 280),
                        decoration: BoxDecoration(
                          color: isMe ? cs.primary.withOpacity(0.18) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cs.primary.withOpacity(0.10)),
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
        'updated_at': DateTime.now().toUtc().toIso8601String(),
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

  /// 统一上传到 Storage(media bucket)，返回 public url
  Future<String> _uploadToMediaBucket(
    File file, {
    required String folder,
  }) async {
    final user = _user;
    if (user == null) throw Exception('Not logged in');

    final supabase = Supabase.instance.client;
    final uuid = const Uuid().v4();

    final ext = file.path.split('.').last.toLowerCase();
    final path = '${user.id}/$folder/$uuid.$ext';

    await supabase.storage.from('media').upload(path, file);

    final url = supabase.storage.from('media').getPublicUrl(path);
    return url;
  }

  Future<void> _pickAndUploadAvatar() async {
    if (_user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to upload avatar')),
      );
      return;
    }

    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (x == null) return;

    setState(() => _loading = true);
    try {
      final url = await _uploadToMediaBucket(File(x.path), folder: 'avatar');
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
        .select('id,caption,media_type,media_url,created_at')
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<void> _createPost({required String mediaType}) async {
    final user = _user;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please login to post')));
      return;
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
      final url = await _uploadToMediaBucket(File(x.path), folder: 'posts');

      final supabase = Supabase.instance.client;
      await supabase.from('posts').insert({
        'user_id': user.id,
        'caption': caption.trim(),
        'media_type': mediaType,
        'media_url': url,
      });

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
                                DropdownButtonFormField<String>(
                                  value: _sportToAdd,
                                  decoration: const InputDecoration(
                                    labelText: 'Choose a sport',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: _sports
                                      .where(
                                        (s) => !_sportLevels.containsKey(s),
                                      )
                                      .map(
                                        (s) => DropdownMenuItem(
                                          value: s,
                                          child: Text(s),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _sportToAdd = v),
                                ),
                                const SizedBox(height: 10),
                                if (_sportToAdd != null)
                                  DropdownButtonFormField<String>(
                                    value:
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
                                            if (_sportToAdd == e.key)
                                              _sportToAdd = null;
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
                                  final caption =
                                      (p['caption'] ?? '') as String;
                                  final type =
                                      (p['media_type'] ?? 'image') as String;
                                  final url = (p['media_url'] ?? '') as String;

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
                                        if (type == 'image')
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            child: AspectRatio(
                                              aspectRatio: 4 / 3,
                                              child: Image.network(
                                                url,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          )
                                        else
                                          Container(
                                            height: 220,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withOpacity(0.08),
                                            ),
                                            child: const Icon(
                                              Icons.play_circle_outline,
                                              size: 56,
                                            ),
                                          ),
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
