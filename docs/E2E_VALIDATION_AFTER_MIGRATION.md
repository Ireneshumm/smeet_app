# E2E validation (no new features) — after migrations

Use this to **safely** confirm the flow after applying migrations — see **`docs/MIGRATION_PLAN.md`** for the full ordered list.

**Critical:** `public.games.game_chat_id` must exist before the updated `join_game` from `20260321140000` is useful. It is added in `20260321120000` (§3) and **repaired** by `20260321135000_ensure_games_game_chat_id.sql` if your DB skipped that step.

- `20260321120000_smeet_mvp_phases.sql` — `game_participants`, `chats` columns, **`games.game_chat_id`**, base `join_game` / `leave_game`
- `20260321130000_games_level_ends_at.sql` — optional UI fields
- **`20260321135000_ensure_games_game_chat_id.sql`** — idempotent if `game_chat_id` missing
- **`20260321140000_game_chat_join_read.sql`** — unread + **`join_game` reads `game_chat_id`** and adds `chat_members` (does **not** add the column)

---

## Pre-flight (Supabase Dashboard → SQL Editor)

Run as needed (read-only checks):

```sql
-- 1) games.game_chat_id exists
SELECT column_name
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'games' AND column_name = 'game_chat_id';

-- 2) messages.created_at exists (unread + ordering)
SELECT column_name
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'messages' AND column_name = 'created_at';

-- 3) chat_members.last_read_at exists
SELECT column_name
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'chat_members' AND column_name = 'last_read_at';

-- 4) join_game body should mention game_chat_id + chat_members (updated RPC)
SELECT pg_get_functiondef(p.oid) AS definition
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public' AND p.proname = 'join_game';
```

**Pass:** rows/columns exist; function definition includes `game_chat_id` and `INSERT` into `chat_members` (or `chat_members` in the body).  
**If (4) has no `chat_members`:** **outdated `join_game` RPC** — re-run `20260321140000_game_chat_join_read.sql`.

---

## Scenario 1 — Create game sets `game_chat_id`

**App**

1. Log in → **Home** → create a game (location, times, etc.) → submit.
2. Expect snackbar like **“Game & group chat ready!”** (or a note if chat/RPC failed).

**DB (replace `:game_id` after you copy id from app or table)**

```sql
SELECT id, game_chat_id, sport, starts_at
FROM public.games
ORDER BY created_at DESC
LIMIT 5;
```

**Pass:** latest row has **`game_chat_id` NOT NULL**.  
**Fail `game_chat_id` NULL:**

| Likely cause | What to check |
|--------------|----------------|
| **Missing migration** | `chats.chat_kind` / `game_id` / `title` columns; `games.game_chat_id` column |
| **RLS / insert blocked** | App can insert into `chats` and update `games` (Dashboard logs / try insert as user) |
| **UI / binding** | Snackbar shows “Setup note” — read message; create path still saved the **game** row |

---

## Scenario 2 — `join_game` adds `game_participants` + `chat_members`

**App**

1. Second account (or incognito) → **Home** → **Join** on that game.

**DB**

```sql
-- :gid = game uuid
SELECT user_id, status FROM public.game_participants WHERE game_id = :gid AND status = 'joined';

SELECT c.id AS chat_id, cm.user_id
FROM public.games g
JOIN public.chats c ON c.id = g.game_chat_id
JOIN public.chat_members cm ON cm.chat_id = c.id
WHERE g.id = :gid
ORDER BY cm.user_id;
```

**Pass:** joiner appears in **`game_participants`** and in **`chat_members`** for the game’s `game_chat_id`.  
**Fail participant row only (no `chat_members`):**

| Likely cause |
|--------------|
| **Outdated `join_game` RPC** (no chat branch) |
| **`game_chat_id` NULL** on that game (Scenario 1 failed) |

**Fail neither row (legacy path in app):**

| Likely cause |
|--------------|
| **RPC error** — app fell back to old “increment `joined_count` only” path; fix RPC + `game_participants` |

---

## Scenario 3 — My Game shows date / time / participants

**App**

1. **My Game** as creator and as joiner.

**Pass**

- Date line + **Start** / **End** times match what you created (timezone = local display).
- **Participants** lists people; **host** first when roster loads.
- Count in **“Participants (N)”** is plausible (includes host merged from `created_by`).

**Fail wrong or empty roster**

| Likely cause | What to check |
|--------------|----------------|
| **Missing / failing `game_participants`** | Table empty; RLS blocking `SELECT` |
| **UI binding** | `created_by` missing on `games` row; network error (loading forever) |
| **Only host, no joiners** | Scenario 2 never ran or failed |

---

## Scenario 4 — Group chat opens from My Game

**App**

1. **My Game** → **Open group chat** on a game with `game_chat_id`.

**Pass:** `ChatRoomPage` opens; you can send a message; other member sees it (second device/account).

**Fail button missing / “Group chat unavailable”**

| Likely cause |
|--------------|
| **`game_chat_id` NULL** (Scenario 1) |
| **UI** — app didn’t load `game_chat_id` in My Game query (should be in nested `games(...)` select) |

**Fail opens but “Send failed” / empty forever**

| Likely cause |
|--------------|
| **`chat_members`** — user not in room (Scenario 2) |
| **RLS** on `messages` / `chat_members` |

---

## Scenario 5 — Unread count updates

** Preconditions:** `messages.created_at` exists; `chat_members.last_read_at` exists; **`cm_update_own_read`** policy applied.

**App**

1. User A and B in same **group** chat.
2. A stays on **Chat** list; B sends a message in the group.
3. A should see a **badge** (or `50+` cap) on that chat row.
4. A opens the chat → badge should **clear** after a moment (debounced `last_read_at` update).
5. Repeat with **direct** chat if you use unread there too.

**Fail badge always 0**

| Likely cause |
|--------------|
| **Missing `messages.created_at`** — app can’t filter; `countUnreadForChat` catches errors → 0 |
| **`last_read_at` never null issue** — less common; if always “now”, unread stays 0 |
| **UI** — list not refreshed after return from chat (`setState` / `Future` not re-run) |

**Fail badge never clears**

| Likely cause |
|--------------|
| **RLS** — `UPDATE chat_members` blocked (no policy or wrong `USING`) |
| **Unread logic** — `last_read_at` not updated (mark read fails silently in app) |

**Quick DB check (as the user, hard to do in SQL Editor; use app Network tab or logs)**

- After opening chat, `chat_members.last_read_at` for that `(chat_id, user_id)` should become **non-null / recent**.

---

## Scenario 6 — Header & participant rows → `OtherProfilePage`

**App**

1. **Group:** app bar title (group header) tap → participant sheet; tap a row → **Player profile**.
2. **Group:** people icon → same sheet → profile.
3. **Direct:** app bar (avatar + name) tap → **Other Profile**.
4. **My Game:** tap a participant row → **Other Profile**.

**Fail tap does nothing / wrong user**

| Likely cause |
|--------------|
| **UI** — `_directPeerId` null (direct); sheet row `id` empty |
| **Not a migration issue** unless profiles `SELECT` blocked by RLS |

---

## Short decision tree (when something fails)

1. **`game_chat_id` NULL** → fix **game + chat creation** (migration columns, RLS, or app snackbar “Setup note”).
2. **Participant row OK, no `chat_members` for joiner** → **outdated `join_game`** or **`game_chat_id` NULL**.
3. **My Game UI wrong but DB correct** → **UI binding / query** (missing `game_chat_id`, `ends_at`, etc.).
4. **Unread always 0 or stuck** → **`created_at` / `last_read_at` / UPDATE policy**, then **mark-read + list refresh** logic.
5. **Profile navigation broken but DB has users** → **UI** (null ids, wrong `Navigator`).

---

## Safe testing tips

- Use **two test accounts** and two browsers (or normal + incognito).
- After changing SQL, **reload the app** so chat streams reconnect.
- Prefer verifying **Scenario 1 → 2** in the DB before spending time on unread UI.
