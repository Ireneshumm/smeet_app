/// Google Sign-In client IDs from `--dart-define` (never commit real secrets).
///
/// ```text
/// flutter run --dart-define=GOOGLE_WEB_CLIENT_ID=xxx.apps.googleusercontent.com \
///   --dart-define=GOOGLE_IOS_CLIENT_ID=yyy.apps.googleusercontent.com
/// ```
///
/// - **Web client ID**: Firebase Console → Project settings → Your apps → Web → OAuth client.
/// - **iOS client ID**: `GoogleService-Info.plist` → `CLIENT_ID`.
abstract final class GoogleOAuthDartDefines {
  // OAuth client IDs are not secrets (the iOS one already ships in the bundled
  // GoogleService-Info.plist). Defaulting them here means every build — CI
  // included — has Google sign-in configured; a --dart-define still overrides.
  static const String webClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '717679610351-rp3rcotlsfabp4bmiv7a40bdsjjdtt13.apps.googleusercontent.com',
  );

  static const String iosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue:
        '717679610351-74u12bfpscpcm7n9sohinck93tbtjb9t.apps.googleusercontent.com',
  );
}
