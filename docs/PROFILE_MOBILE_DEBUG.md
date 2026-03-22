# Profile tab on mobile — debug checklist

Web works but mobile looks wrong → use logs + this table to classify the issue.

## 1. Tab selection

**Logs**

- `[Nav] switch tab -> 4`
- `[Nav] Profile tab selected (index 4)`

If these **do not** appear when you tap Profile, the problem is **navigation / gesture / `NavigationBar`**, not `ProfilePage`.

## 2. Profile widget lifecycle

**Logs**

- `[ProfilePage] initState` — once per `ProfilePage` mount (session key change remounts).
- `[ProfilePage] build` — every rebuild (often many times; normal).

If **`build` never runs** after selecting tab 4, the **IndexedStack** child is not building (very rare).

## 3. Layout / constraints (most common on mobile)

**Logs**

- `[ProfilePage] layout maxW=… maxH=… finiteH=true|false`
- `[ProfilePage] layout fallback (maxH=… not usable) → height=…` — parent gave unbounded or tiny height; code uses **body-aware** fallback (screen − chrome), not `0.72 × full screen` (which could exceed `Scaffold` body and confuse layout).
- `[ProfilePage] WARNING: tiny maxHeight=…` — **IndexedStack / offstage** edge case; fallback still applies.

**Root cause class:** `Column` + `Expanded` + `TabBarView` **requires finite height**. If `maxHeight` is **∞** or **0**, mobile can assert or show a blank/wrong area.

## 4. Auth / onboarding (redirect away from Profile)

**Logs**

- `[shell_auth] no session → signedOut, reset tab to Home (was index=…)` — session disappeared; shell forces **Home**. Fix: Supabase session persistence on device, not `ProfilePage` UI.
- `[shell_auth] profile row missing → force Profile tab …` — **stays on** Profile (onboarding), does not hide it.

## 5. Plugins / permissions

| Plugin | Mobile note |
|--------|----------------|
| **image_picker** | **iOS:** `NSPhotoLibraryUsageDescription` (and camera if used) in `Info.plist`. Missing → picker fails or crashes. |
| **video_player** | Network / codec / TLS failures on init; app uses `.catchError` + placeholder. Check `[PostMedia] VideoPlayer.initialize failed` in console. |

## 6. Overflow on small screens

- Logged-in **header** name/city: `maxLines` + `ellipsis`.
- **Guest** block: `SingleChildScrollView` so long text + keyboard does not overflow.

## Concrete diagnosis buckets

| Symptom | Likely bucket |
|--------|----------------|
| No `[Nav] … 4` when tapping Profile | Tab / `NavigationBar` |
| `[Nav] 4` then immediate `[shell_auth] no session` | Auth / session |
| `finiteH=false` or fallback line + then UI OK | Layout / constraints (mitigated) |
| `finiteH=false` + blank / error | Layout + check Flutter assert in debug |
| Picker / camera errors | Plugin / **Info.plist** (iOS) |
| Video red error in Posts tab | **video_player** / URL / codec |
