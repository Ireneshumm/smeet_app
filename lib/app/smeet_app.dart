import 'package:flutter/material.dart';

/// One entry in the unified MVP debug launcher ([SmeetApp] — no feature imports).
class MvpDebugLauncherItem {
  const MvpDebugLauncherItem({
    required this.label,
    required this.route,
    required this.icon,
  });

  final String label;
  final String route;
  final IconData icon;
}

void _openMvpDebugLauncher(
  BuildContext context,
  List<MvpDebugLauncherItem> items,
) {
  if (items.isEmpty) return;
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'MVP debug',
                style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            for (final e in items)
              ListTile(
                leading: Icon(e.icon),
                title: Text(e.label),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.of(context).pushNamed(e.route);
                },
              ),
          ],
        ),
      );
    },
  );
}

/// Root [MaterialApp] for Smeet — theme and shell [home] are wired from here.
///
/// [home] is injected from [main.dart] so this library does not import `main.dart`
/// (avoids circular imports while [SmeetShell] still lives there).
class SmeetApp extends StatelessWidget {
  const SmeetApp({
    super.key,
    required this.home,
    this.routes = const {},
    this.showMvpDebugLauncher = false,
    this.mvpDebugLauncherItems = const [],
  });

  /// [MaterialApp.builder] sits above [Navigator]; use this for modal route ops.
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// First screen after launch (currently [SmeetShell] from `main.dart`).
  final Widget home;

  /// Optional named routes (e.g. Feed MVP) without changing [home].
  final Map<String, WidgetBuilder> routes;

  /// When true, shows one FAB that opens a bottom sheet with [mvpDebugLauncherItems].
  final bool showMvpDebugLauncher;

  /// Targets for the MVP debug menu — labels, [Navigator.pushNamed] routes, icons.
  final List<MvpDebugLauncherItem> mvpDebugLauncherItems;

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

    final theme = ThemeData(
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
    );

    final launcherItems = mvpDebugLauncherItems;
    final useMvpLauncher =
        showMvpDebugLauncher && launcherItems.isNotEmpty;

    return MaterialApp(
      navigatorKey: SmeetApp.navigatorKey,
      title: 'Smeet',
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: home,
      routes: routes,
      builder: useMvpLauncher
          ? (context, child) {
              final stackChild = child ?? const SizedBox.shrink();
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  stackChild,
                  SafeArea(
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(0, 0, 12, 88),
                        child: FloatingActionButton.small(
                          heroTag: 'smeet_mvp_debug_launcher',
                          // Omit tooltip: FAB Tooltip needs Overlay; builder Stack is not under it.
                          onPressed: () {
                            final navCtx = SmeetApp.navigatorKey.currentContext;
                            if (navCtx != null) {
                              _openMvpDebugLauncher(navCtx, launcherItems);
                            }
                          },
                          child: const Icon(Icons.bug_report_outlined),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }
          : null,
    );
  }
}
