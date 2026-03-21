# Supabase

## Realtime: Home “Upcoming Games” list

`HomePage` uses `.from('games').stream(primaryKey: ['id'])` so `joined_count` updates live when anyone joins.

1. In **Dashboard → Database → Publications**, ensure the `supabase_realtime` publication includes table **`games`** (or enable **Realtime** for `games` under **Database → Replication** depending on UI version).
2. RLS policies must still allow `SELECT` on rows clients should see; updates are pushed over Realtime after commits.

---

## Edge Functions — Google Places proxy (`google-places`)

Flutter Web does **not** call Google directly. The app invokes this Edge Function; the function reads the API key from Supabase secrets and calls Google.

### 1. Set secrets

```bash
supabase secrets set GOOGLE_MAPS_API_KEY=your_server_key_here
```

Optional — **production CORS** (comma-separated origins; required for browser calls from your domain):

```bash
supabase secrets set PLACES_ALLOWED_ORIGINS=https://www.smeet.com.au,https://smeet.com.au,http://localhost:8080
```

If unset, `Access-Control-Allow-Origin: *` is used (fine for local dev; lock down in production).

### 2. Deploy

```bash
supabase functions deploy google-places
```

`verify_jwt` is **false** in `config.toml` so guests can use Home; the Google key never ships to the client.

### 3. Local testing

```bash
supabase start
supabase secrets set GOOGLE_MAPS_API_KEY=... --env-file ./supabase/.env.local   # if you use a local env file
supabase functions serve google-places --no-verify-jwt
```

Point Flutter at local Supabase URL only when developing against local stack.

### Google Cloud

Enable **Places API** (and billing) for the key. Restrict the key by IP for Edge Functions, or use HTTP referrer + server key patterns per Google’s docs.
