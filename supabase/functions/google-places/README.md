# Edge Function: `google-places`

Proxies **Google Places Autocomplete** and **Place Details** so your API key stays in Supabase secrets (Flutter Web/Mobile calls `supabase.functions.invoke` only).

## Request (POST JSON)

| `action`        | Fields |
|-----------------|--------|
| `autocomplete`  | `input`, optional `sessionToken` |
| `details`       | `placeId`, optional `sessionToken` |

## Secrets

| Name | Purpose |
|------|---------|
| `GOOGLE_MAPS_API_KEY` | Preferred. Your Google Maps / Places API key. |
| `Maps_API_KEY` | Alternative name (function checks this if `GOOGLE_MAPS_API_KEY` is unset). |
| `PLACES_ALLOWED_ORIGINS` | Optional. Comma-separated origins for CORS in production (e.g. `https://app.example.com,http://localhost:8080`). If unset, `Access-Control-Allow-Origin: *`. |

---

## Supabase CLI — copy/paste

Run from your **project root** (where `supabase/` lives).

### 1) Install & login (once)

```bash
npm i -g supabase
supabase login
```

### 2) Link this repo to your Supabase project (once)

```bash
supabase link --project-ref YOUR_PROJECT_REF
```

`YOUR_PROJECT_REF` is in the Supabase Dashboard → **Project Settings → General → Reference ID**.

### 3) Create the function locally (only if the folder is empty)

If `supabase/functions/google-places/index.ts` **already exists** (this repo), you **do not** need `functions new` — skip to step 4.

Otherwise:

```bash
supabase functions new google-places
# then paste the contents of index.ts into supabase/functions/google-places/index.ts
```

### 4) Set the Maps / Google API key secret (remote project)

Use **one** of these (same key value):

```bash
supabase secrets set GOOGLE_MAPS_API_KEY=YOUR_ACTUAL_GOOGLE_KEY
```

or:

```bash
supabase secrets set Maps_API_KEY=YOUR_ACTUAL_GOOGLE_KEY
```

Production CORS (comma-separated, no spaces after commas unless trimmed):

```bash
npx supabase secrets set PLACES_ALLOWED_ORIGINS=https://smeet.com.au,https://www.smeet.com.au,http://localhost
```

Redeploy after changing secrets:

```bash
npx supabase functions deploy google-places
```

`http://localhost` matches any port (e.g. `http://localhost:8080`). Add `http://127.0.0.1` if you use that.

### 5) Deploy the function

```bash
supabase functions deploy google-places
```

### 6) Local testing (optional)

```bash
supabase start
supabase secrets set GOOGLE_MAPS_API_KEY=YOUR_KEY   # for linked local stack, or use Dashboard for remote
supabase functions serve google-places --no-verify-jwt
```

Invoke URL (local): `http://127.0.0.1:54321/functions/v1/google-places` (with `Authorization: Bearer <anon_key>` when testing with curl).

---

`verify_jwt` for this function is set to **false** in `supabase/config.toml` so unauthenticated guests can use location search if your app allows it. To require login, set `verify_jwt = true` and redeploy.
