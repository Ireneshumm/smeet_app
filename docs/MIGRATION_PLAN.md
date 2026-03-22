# Supabase migration plan (Smeet MVP)

Apply migrations **in filename order** (timestamp prefix). Use **SQL Editor** (paste each file) or `npx supabase db push` from the repo root.

## Ordered files

| Order | File | Purpose |
|------:|------|---------|
| 1 | `20260321120000_smeet_mvp_phases.sql` | `game_participants`, `chats` columns (`chat_kind`, `game_id`, `title`), **`games.game_chat_id`**, base `join_game` / `leave_game`, RLS examples |
| 2 | `20260321130000_games_level_ends_at.sql` | `games.game_level`, `games.ends_at` |
| 3 | **`20260321135000_ensure_games_game_chat_id.sql`** | **Idempotent repair:** `games.game_chat_id` if missing (same as §3 of `20000` — use when `20000` was only partially applied) |
| 4 | `20260321140000_game_chat_join_read.sql` | `messages.created_at`, `chat_members.last_read_at`, RLS for read receipts, **`join_game` replaces** to read **`games.game_chat_id`** and insert **`chat_members`** |

## `games.game_chat_id` — not forgotten

- **Already defined** in `20260321120000_smeet_mvp_phases.sql` (section 3).
- **`20260321140000` did not add it** on purpose: that file only updates `join_game` to **use** the column. If your database never ran section 3 of `20000`, you would have **no column** while the app still runs `UPDATE games SET game_chat_id = …` (Postgres would error or the client would report failure — depending on driver/Supabase behavior).

**Root cause when the column is missing:** migration `20000` was not fully applied, or a custom DB was created without that step.

**Fix:** run `20260321135000_ensure_games_game_chat_id.sql` (safe `IF NOT EXISTS`) **before** or **any time before relying on** the updated `join_game` from `40000`. On a fresh `db push`, `35000` is a no-op if `20000` already added the column.

## `join_game` and `game_chat_id`

The **current** `join_game` in `20260321140000` does:

```sql
SELECT joined_count, players, game_chat_id INTO j, p, gc_id
FROM public.games
WHERE id = p_game_id
```

So it **expects** `public.games.game_chat_id` to exist. The **`40000` file does not add that column**; it assumes prior migrations (`20000` and/or `35000`).

## App: create-game writes `game_chat_id`

In `lib/main.dart`, after inserting a `chats` row for the game, the client runs:

```dart
await supabase.from('games').update({'game_chat_id': chatId}).eq('id', gameId);
```

**Verification after migrations:**

1. Create a game in the app.
2. In SQL Editor:

```sql
SELECT id, game_chat_id, sport, created_at
FROM public.games
ORDER BY created_at DESC
LIMIT 3;
```

**Pass:** newest row has non-null `game_chat_id` and it matches a row in `public.chats` (`SELECT id, chat_kind, game_id FROM public.chats WHERE id = '<that uuid>'`).

**Fail null `game_chat_id`:** check app snackbar for setup errors, RLS on `games` UPDATE / `chats` INSERT, and that the column exists (run `35000` if needed).

## Quick column check

```sql
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'games'
  AND column_name = 'game_chat_id';
```

Should return one row (`uuid`).
