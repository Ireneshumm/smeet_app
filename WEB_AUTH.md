# Web auth / “Failed to fetch” (Supabase)

If signup/login shows `ClientException: Failed to fetch` and **no HTTP status**, the browser never completed the request to Supabase.

## 1. Stable localhost URL (Flutter)

`flutter run -d chrome` can pick a **random port** each time. Supabase **Redirect URLs** must match your app origin exactly.

**Use a fixed port:**

```bash
flutter run -d chrome --web-port=8080
```

Or in VS Code / Cursor: run **“Smeet: Chrome (web port 8080)”** from `.vscode/launch.json`.

Then whitelist (step 2) for `http://localhost:8080`.

## 2. Supabase Dashboard

**Authentication → URL Configuration**

- **Site URL:** `http://localhost:8080/` (match your real origin + port)
- **Redirect URLs:** add  
  - `http://localhost:8080/**`  
  - If you use `127.0.0.1`, add those variants too.

Save, then hard-refresh the app and try again.

## 3. Debug logs (Flutter console)

On auth, the app prints lines starting with **`[agent_ndjson]`** (one JSON object per line, no email/password).  
Copy those lines into `debug-2e4d4f.log` in the project root if you need to share evidence; they include `origin` and `failedToFetch`.

## 4. Still failing?

- Chrome **DevTools → Network**: find `signup` / `token` — note **blocked**, **CORS**, or **(failed)**.
- Try another network / disable VPN or extensions that block third-party requests.
- Confirm the project URL in `lib/main.dart` matches your Supabase project.
