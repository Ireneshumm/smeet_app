import 'package:flutter/foundation.dart';

/// Compile-time Supabase credentials from `--dart-define=KEY=value`.
///
/// **Release / production:** both must be set; the app throws on startup if not,
/// or if values look like documentation placeholders (see [_releaseUrlLooksLikePlaceholder]).
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

/// Release-only: reject doc-style placeholders so bad `--dart-define` fails fast.
bool _releaseUrlLooksLikePlaceholder(String u) {
  final s = u.toLowerCase();
  if (!s.startsWith('https://')) return true;
  const fragments = <String>[
    'your_project',
    'your_ref',
    'your-anon',
    'example.com',
    'placeholder',
    'changeme',
    'localhost',
  ];
  for (final f in fragments) {
    if (s.contains(f)) return true;
  }
  return false;
}

bool _releaseAnonKeyLooksLikePlaceholder(String k) {
  if (k.length < 80) return true;
  if (!k.startsWith('eyJ')) return true;
  final lower = k.toLowerCase();
  if (lower.contains('your_anon') ||
      lower.contains('placeholder') ||
      lower.contains('changeme')) {
    return true;
  }
  return false;
}

/// Returns `(url, anonKey)` for [Supabase.initialize].
({String url, String anonKey}) resolveSupabaseConfig() {
  final u = SupabaseDartDefines.url.trim();
  final k = SupabaseDartDefines.anonKey.trim();

  if (u.isNotEmpty && k.isNotEmpty) {
    if (kReleaseMode &&
        (_releaseUrlLooksLikePlaceholder(u) ||
            _releaseAnonKeyLooksLikePlaceholder(k))) {
      throw StateError(
        'Release Supabase config looks like a placeholder or invalid value. '
        'Paste the real Project URL and anon public key from Supabase Dashboard '
        '(Settings → API). See docs/RELEASE_CHECKLIST.md.',
      );
    }
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
