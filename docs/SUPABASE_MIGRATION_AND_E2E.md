# Apply migration + E2E test (Create game → Upcoming → My Game → Chat → Profile)

## 1) Apply migration (pick one)

### Option A — Supabase Dashboard (fastest)

1. Open [Supabase Dashboard](https://supabase.com/dashboard) → your project (`gjaljqqvtxfqddmtyxgt`).
2. **SQL Editor** → **New query**.
3. Paste and run:

```sql
-- Game target level + end time (Phase 1 MVP)
ALTER TABLE public.games
  ADD COLUMN IF NOT EXISTS game_level text;

ALTER TABLE public.games
  ADD COLUMN IF NOT EXISTS ends_at timestamptz;

COMMENT ON COLUMN public.games.game_level IS 'Target/suitable level for this game (not creator profile level).';
COMMENT ON COLUMN public.games.ends_at IS 'Game end time (UTC).';
```

4. Confirm: **Database** → **Tables** → `games` → columns include `game_level` and `ends_at`.

5. **Game group chat on join + unread counts:** run the SQL in  
   `supabase/migrations/20260321140000_game_chat_join_read.sql`  
   (adds `messages.created_at`, `chat_members.last_read_at`, updates `join_game` to add members to the game’s group chat, and RLS to update `last_read_at`).

### Option B — Supabase CLI (from this repo)

Requires [Supabase CLI](https://supabase.com/docs/guides/cli) and your **database password** (Dashboard → **Project Settings** → **Database**).

```powershell
cd c:\Users\shumn\Downloads\smeet_app
npx supabase link --project-ref gjaljqqvtxfqddmtyxgt
npx supabase db push
```

`db push` applies everything under `supabase/migrations/` that isn’t on the remote DB yet.

**Migration order & `game_chat_id`:** see **`docs/MIGRATION_PLAN.md`**. If `games.game_chat_id` is missing, run `20260321135000_ensure_games_game_chat_id.sql` (or re-run §3 of `20260321120000`). The `20260321140000` file updates `join_game` to use this column but does not create it.

---

## 2) Preconditions

- [ ] You can **sign in** in the app (same Supabase project as above).
- [ ] **Profile** saved with at least **one sport + level** and optional **availability** (helps Swipe / social proof; not required for create game).
- [ ] **Realtime** (optional but nice for Home “Upcoming” without refresh): Dashboard → **Database** → **Publications** → ensure `games` is in the `supabase_realtime` publication (or enable replication for `games` per your project docs).

---

## 3) E2E checklist (do in order)

### Step A — Create game (Home)

1. Open **Home**.
2. Fill **Sport**, **Game level**, **Game date**, **Start time**, **End time** (end after start, or next-day end is OK).
3. Pick **Location** from suggestions.
4. Set **players** + **court fee**; confirm **per person** preview.
5. **Create Game** → expect success snackbar.

**Verify:** Row appears under **Upcoming Games** (may need a moment if Realtime is on, or hot-restart / re-open tab).

### Step B — Upcoming game card (Home)

On the new card, confirm:

- `Sport • Game level`
- `Start – End` in 12h form (e.g. `2:00 PM – 4:00 PM`)
- Suburb + distance line
- Spots left + `$/pp`

**Join** the game → expect “Joined” / success.

### Step C — My Game

1. Open **My Game** tab.
2. Open the joined game card.

**Verify:**

- Same sport / level / time range as created.
- **Participants** list: avatar, name, city, **that sport’s level**; **host** label if applicable.
3. Tap a participant → **Player profile** opens (`OtherProfilePage`).

**Verify on profile:** name, city, intro, sports & levels, availability, posts/media grid.

### Step D — Chat (game group)

1. From **Chat**, open the **game** chat (group icon / title).
2. Send a message → it should appear at the **bottom**; list should open showing **latest at bottom**.

**Optional:** Use **participants** icon in app bar → tap someone → profile.

### Step E — Chat (direct) + profile from header

1. Use **Swipe** → **Like** someone who already liked you (or create a second test user) until you get a **match** and land in **direct** chat.
2. Or open an existing **direct** chat from **Chat** list.

**Verify:**

- Messages stay **newest at bottom**; **Send** scrolls to bottom.
- Tap **avatar + name** in the app bar → **Player profile** with levels, availability, posts.

---

## 4) If something fails

| Symptom | Likely cause |
|--------|----------------|
| Create game error about unknown column | Migration not applied — run SQL in §1. |
| Upcoming shows old layout / no end time | Old rows: `ends_at` null until you create new games after migration. |
| My Game roster empty | `game_participants` + `join_game` RPC migration not applied, or RLS blocking reads. |
| Chat not updating live | Realtime not enabled on `messages` / network. |
| Direct header not tappable | Only **direct** chats use tappable header; **game** chats use the people icon. |

---

## 5) Quick local run

```powershell
cd c:\Users\shumn\Downloads\smeet_app
flutter pub get
flutter run -d chrome
```

Use two browsers (or incognito + normal) with two accounts to test match → direct chat → profile header.
