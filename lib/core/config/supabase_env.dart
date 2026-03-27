import 'package:flutter/foundation.dart';

/// Compile-time Supabase credentials from `--dart-define=KEY=value`.
///
/// **Release / production:** both must be set; the app throws on startup if not.
/// **Debug / profile:** if both are empty, [resolveSupabaseConfig] falls back to
/// [_kDevFallbackUrl] / [_kDevFallbackAnonKey] so `flutter run` works without flags.
///
/// CI / store builds:
/// ```text
/// flutter build apk --release \
///   --dart-define=SUPABASE_URL=https://xxx.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=eyJ...
/// ```
abstract final class SupabaseDartDefines {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );
}

/// Development defaults only — **not** a substitute for `--dart-define` in release.
/// Rotate this anon key if the repository is public; prefer project-specific dev keys.
const String _kDevFallbackUrl = 'https://gjaljqqvtxfqddmtyxgt.supabase.co';
const String _kDevFallbackAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqYWxqcXF2dHhmcWRkbXR5eGd0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjcxODAzNTYsImV4cCI6MjA4Mjc1NjM1Nn0.xBUQad28YDmWG7uTGopg7itEruXnCMdcU-EDwkZ3308';

/// Returns `(url, anonKey)` for [Supabase.initialize].
({String url, String anonKey}) resolveSupabaseConfig() {
  final u = SupabaseDartDefines.url.trim();
  final k = SupabaseDartDefines.anonKey.trim();

  if (u.isNotEmpty && k.isNotEmpty) {
    return (url: u, anonKey: k);
  }
  if (u.isNotEmpty || k.isNotEmpty) {
    throw StateError(
      'Set both SUPABASE_URL and SUPABASE_ANON_KEY via --dart-define, or omit both '
      'to use non-release dev fallbacks. See docs/RELEASE_CHECKLIST.md.',
    );
  }

  if (kReleaseMode) {
    throw StateError(
      'Release build requires SUPABASE_URL and SUPABASE_ANON_KEY. '
      'Example:\n'
      '  flutter build apk --release '
      '--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...\n'
      'See docs/RELEASE_CHECKLIST.md.',
    );
  }

  if (kDebugMode) {
    debugPrint(
      '[supabase_env] Using dev fallbacks (no dart-define). '
      'Do not ship release builds without defines.',
    );
  }

  return (url: _kDevFallbackUrl, anonKey: _kDevFallbackAnonKey);
}
