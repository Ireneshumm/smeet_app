/// Icon size scale (logical pixels).
///
/// The app previously used ~25 distinct icon sizes. Collapse new usage onto
/// this small ramp so icons read as one system. [md] (24) is the default icon
/// size wired into the app [ThemeData].
abstract final class AppIconSize {
  /// Inline / dense affordances (badges, tiny meta rows).
  static const double xs = 16;

  /// Secondary actions, list trailing icons.
  static const double sm = 20;

  /// Default — nav, app bar actions, most buttons.
  static const double md = 24;

  /// Prominent actions / section headers.
  static const double lg = 32;

  /// Feature icons, empty-state glyphs.
  static const double xl = 40;

  /// Hero / large empty states.
  static const double xxl = 48;
}
