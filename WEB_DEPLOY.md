# Flutter Web — ensure production matches your current code

## Source check (this repo)

- `lib/widgets/location_search_field.dart` uses **only** `supabase.functions.invoke('google-places', ...)` — **no** `http` package, **no** `maps.googleapis.com`, **no** `你的APIKEY`.
- A full-text search of the project for `你的APIKEY` returns **nothing**.

If production still behaves like the old app, the problem is almost always **deployment or browser cache**, not this file missing from git.

---

## 1. Confirm what you pushed

```bash
git status
git log -1 --oneline
git grep -n "你的APIKEY" || echo "OK: no placeholder in repo"
git grep -n "maps.googleapis" -- "*.dart" || echo "OK: no direct Google URLs in Dart"
```

Your **production branch** (e.g. `main`) on GitHub/GitLab must contain the commit that has the Edge Function client code.

---

## 2. Clean build before deploy

Stale `build/web` or CI cache can ship an old `main.dart.js`.

```bash
flutter clean
flutter pub get
flutter build web --release
```

Then deploy the **`build/web`** folder (or let Vercel run the same commands in CI).

**Vercel:** Redeploy with **“Clear cache and redeploy”** if the UI still looks old.

---

## 3. Browser / Service Worker cache

Flutter Web registers a service worker that can keep **old JavaScript** until a new build is fetched.

After deploy:

- Hard refresh: **Ctrl+Shift+R** (Windows) or **Cmd+Shift+R** (Mac), or  
- DevTools → **Application** → **Clear site data** for `smeet.com.au`, then reload.

---

## 4. Verify the deployed bundle (optional)

Download `https://www.smeet.com.au/main.dart.js` (or the hashed main file from Network tab) and search for:

- `你的APIKEY` — should **not** appear if the new build is live.
- `google-places` — **should** appear (Edge Function name in the compiled output).

---

## 5. Hosting must build from this repo

If production is **not** built from the same machine/repo (e.g. old manual upload, wrong branch, second copy of the project), fix the pipeline so **only** the linked repo + branch runs `flutter build web --release`.
