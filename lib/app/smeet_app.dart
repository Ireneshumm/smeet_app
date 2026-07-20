import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:smeet_app/core/theme/theme.dart';

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

  // Brand colors — now sourced from [AppColors] (single source of truth).
  // These aliases keep existing `SmeetApp.smeetXxx` call sites working.
  static const Color smeetMint = AppColors.mint;
  static const Color smeetDeep = AppColors.deep;
  static const Color smeetInk = AppColors.ink;
  /// Warm canvas (抖音/小红书式暖白底)
  static const Color smeetCanvas = AppColors.canvas;
  static const Color smeetNavBorder = AppColors.navBorder;

  static const Color smeetMintLight = AppColors.mintLight;
  static const Color smeetMintFaint = AppColors.mintFaint;
  static const Color smeetGrey = AppColors.grey;
  static const Color smeetGreyLight = AppColors.greyLight;
  static const Color smeetCoral = AppColors.coral;
  static const Color smeetCoralLight = AppColors.coralLight;
  static const Color smeetIndigo = AppColors.indigo;
  static const Color smeetIndigoLight = AppColors.indigoLight;

  @override
  Widget build(BuildContext context) {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: smeetMint,
      brightness: Brightness.light,
    );

    final theme = ThemeData(
      useMaterial3: true,

      scaffoldBackgroundColor: smeetCanvas,

      colorScheme: baseScheme.copyWith(
        primary: smeetMint,
        secondary: smeetDeep,
        surface: Colors.white,
        onPrimary: Colors.white,
        onSurface: smeetInk,
      ),

      // Full type ramp from the design system (see core/theme/app_text_theme).
      textTheme: buildSmeetTextTheme(),

      // Default icon size — anchors ad-hoc sizes onto the token scale.
      // (Color intentionally omitted so Material components keep their own
      // contextual icon colors; onSurface already resolves to brand ink.)
      iconTheme: const IconThemeData(
        size: AppIconSize.md,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: smeetInk,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),

      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgAll,
        ),
        margin: EdgeInsets.zero,
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: const WidgetStatePropertyAll(smeetMint),
          foregroundColor: const WidgetStatePropertyAll(Colors.white),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
          shape: WidgetStatePropertyAll(
            StadiumBorder(),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
          shape: WidgetStatePropertyAll(
            StadiumBorder(),
          ),
        ),
      ),
    );

    final launcherItems = mvpDebugLauncherItems;
    final useMvpLauncher =
        showMvpDebugLauncher && launcherItems.isNotEmpty;

    return MaterialApp(
      navigatorKey: SmeetApp.navigatorKey,
      navigatorObservers: [SentryNavigatorObserver()],
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
                        padding: const EdgeInsets.fromLTRB(0, 0, 12, 104),
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
