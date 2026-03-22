# iOS App Store — lightweight review checklist (Smeet)

Use before archiving / uploading a build.

## Info.plist & permissions

- [ ] **`NSPhotoLibraryUsageDescription`** present (photo/video picks from library for avatar & posts).
- [ ] **No unused permission strings** added “just in case” (camera/mic/location only when code uses them).
- [ ] **Bundle display name / version** acceptable in Xcode / `Info.plist` / Flutter build.

## Legal & trust

- [ ] **Terms of Use** and **Privacy Policy** reachable in-app (Profile / guest flow).
- [ ] Account deletion / data request flow available per product requirements.

## Safety features (smoke test)

- [ ] **Report** flow reachable where implemented.
- [ ] **Block** user flow works at a basic level.
- [ ] No obvious **placeholder** or dead primary buttons on main tabs.

## Build

- [ ] `flutter build ipa` (or Xcode Archive) succeeds for the intended scheme/configuration.
- [ ] **App Review notes** filled in App Store Connect (copy from `docs/APP_REVIEW_NOTES.md`).

## If you add features later

| Capability | Add to Info.plist when… |
|------------|-------------------------|
| Device GPS | App uses Core Location / `geolocator` etc. → `NSLocationWhenInUseUsageDescription` (and usage as required). |
| Camera capture | `ImageSource.camera` or native camera → `NSCameraUsageDescription`. |
| Mic (e.g. record video) | Recording with audio → `NSMicrophoneUsageDescription`. |
| Save images to library | Saving to Photos → `NSPhotoLibraryAddUsageDescription`. |
| Push notifications | User-facing notifications → enable capability + usage as required by Apple. |

---

*Task 9: conservative permissions; gallery-only media picking today.*
