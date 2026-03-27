# smeet_app

Flutter app for Smeet.

## Release / gray-box builds

- **Release** builds **must** pass Supabase credentials via `--dart-define` (see `lib/core/config/supabase_env.dart`). Builds without them fail fast on startup.
- **Debug / profile** `flutter run` can omit defines and use the dev fallbacks in `supabase_env.dart` (rotate keys if this repository is public).
- Pre-release smoke checklist and route behavior: [docs/RELEASE_CHECKLIST.md](docs/RELEASE_CHECKLIST.md).

## Getting Started

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)
- [Flutter documentation](https://docs.flutter.dev/)
