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
  static const String webClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '',
  );

  static const String iosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue: '',
  );
}
