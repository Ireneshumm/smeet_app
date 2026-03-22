# Smeet MVP — schema & product upgrade

## Current code paths (inspected)

| Area | Tables / usage |
|------|------------------|
| **Games** | `games` — stream on Home; fields: `sport`, `starts_at`, `location_text`, `location_lat`, `location_lng`, `players`, `joined_count`, `per_person`, `created_by` |
| **Join / leave** | Client updates `joined_count`; `leave_game` RPC; local `Set<String> joinedLocal` in shell |
| **Profiles** | `profiles` — `display_name`, `city`, `intro`, `avatar_url`, `sport_levels` (map), `availability` |
| **Posts** | `posts` — `author_id`, `caption`, `media_type`, `media_urls`, `created_at`, etc. |
| **Chats** | `chats`, `chat_members`, `messages` — direct 1:1 match chats |

## Proposed schema changes (apply via Supabase SQL)

1. **`game_participants`** — persistent joins (`joined` / `left`).
2. **`join_game(uuid)` / `leave_game(uuid)`** — SECURITY DEFINER RPCs: enforce capacity, maintain `joined_count`, update participant rows.
3. **`chats`** — `chat_kind` (`direct` \| `game`), optional `game_id`, `title` for list labels.
4. **`games.game_chat_id`** — FK to the group chat for that game (created with the game). **Required** for the updated `join_game` that adds `chat_members`.

See **`docs/MIGRATION_PLAN.md`** for apply order. Schema SQL: `supabase/migrations/20260321120000_smeet_mvp_phases.sql` (§3) and repair file `20260321135000_ensure_games_game_chat_id.sql`.

## RLS (you must align with your project)

The migration includes example policies. **Review and tighten** for production (e.g. restrict `game_participants` updates to own row, game creators for admin actions).

## App phases

- **Phase 1**: Client filter — hide full games; location + radius; distance label; cleaner cards.
- **Phase 2**: `join_game` RPC + load My Game from `game_participants`; roster + balance + host.
- **Phase 3**: Create game chat on game insert; add member on join; Chat list shows game vs direct.
- **Phase 4**: `OtherProfilePage` + posts/media grid; navigation from roster and chat.

After applying SQL, run: verify RPCs exist and RLS allows your roles.
