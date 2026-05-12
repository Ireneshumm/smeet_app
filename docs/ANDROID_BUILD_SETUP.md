# Android Build Setup

CI builds a signed **App Bundle (.aab)** on GitHub Actions (Ubuntu) and uploads it as an artifact. No keystore or passwords are committed to the repo.

## 1. Generate keystore (first-time, run locally)

```bash
bash scripts/generate_android_keystore.sh
```

This creates `~/smeet-android-keystore.jks` and prints which secrets to add. **Back up** that file in more than one safe place (password manager + cloud). If you lose it, you cannot ship updates with the same Play signing identity.

## 2. Add GitHub Actions secrets

Open: `https://github.com/Ireneshumm/smeet_app/settings/secrets/actions`

Create these **repository secrets**:

| Secret | Value |
|--------|--------|
| `ANDROID_KEYSTORE_BASE64` | Base64 of the `.jks` file (see below) |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_PASSWORD` | Key password (often same as keystore) |
| `ANDROID_KEY_ALIAS` | `smeet` (must match the alias in the script) |

**Base64 the keystore:**

- **macOS:** `base64 -i ~/smeet-android-keystore.jks | pbcopy`
- **Linux:** `base64 -w0 ~/smeet-android-keystore.jks` then copy the line (no newlines in the secret).

## 3. Trigger a build

- **Automatic:** push to `main` that touches `lib/**`, `android/**`, `pubspec.yaml`, or this workflow file.
- **Manual:** GitHub → **Actions** → **Android Build** → **Run workflow**.

If any secret is missing or wrong, the job will fail at decode or Gradle signing.

## 4. Download the .aab

Actions → latest successful run → **Artifacts** → `smeet-release-aab` → download `app-release.aab`.

Upload that bundle in [Google Play Console](https://play.google.com/console).

There is also a `smeet-release-apk` artifact for sideload / QA.

## 5. Local release builds (optional)

Copy `key.properties` into `android/` (never commit it) and place the keystore file where `storeFile` points (e.g. `android/app/smeet-keystore.jks`). See `android/app/build.gradle.kts` — without `key.properties`, release still builds using the **debug** keystore (same as before).

## 6. Version bumps (Play Store)

`pubspec.yaml` uses `version: x.y.z+build` where **build** is `versionCode` and must increase for every Play upload.

---

**iOS:** This repo change does **not** set up Apple / TestFlight builds (separate Apple Developer program and workflows).
