# Retention systems (Smeet)

工程说明：数据库对象、客户端服务与扩展点。发布边界与商店口径见 [`RELEASE_AND_GREY_SCOPE.md`](./RELEASE_AND_GREY_SCOPE.md)。

**相关文档**

| 文档 | 用途 |
|------|------|
| [`SUPABASE_RETENTION_HANDTEST.md`](./SUPABASE_RETENTION_HANDTEST.md) | 目标环境 migration 核对 SQL、五项手测记录表 |
| [`RETENTION_HANDTEST_SCRIPT.md`](./RETENTION_HANDTEST_SCRIPT.md) | 五项逐步手测脚本 |
| [`RETENTION_HANDTEST_RECORD_TEMPLATE.md`](./RETENTION_HANDTEST_RECORD_TEMPLATE.md) | 测试员执行记录模板 |
| [`RELEASE_CHECKLIST.md`](./RELEASE_CHECKLIST.md) | Release `--dart-define`、占位符校验（`supabase_env.dart`） |

---

## Database (migration `20260328120000_retention_systems.sql`)

### Tables

| Table | Purpose |
|-------|---------|
| `user_notifications` | In-app notification rows per user (`type`, `actor_user_id`, `entity_id`, `payload`, `is_read`). Inserts via triggers/RPC only (RLS blocks direct client insert). |
| `user_entitlements` | Future feature gating: `(user_id, entitlement_key)` with `value` jsonb. RLS: select own rows; no client writes. Empty table ⇒ app treats entitlements as “all on”. |

### Columns added

- `profiles.account_type` — `player` (default), `coach`, `club`, `venue`, `organizer`, `brand`.
- `profiles.swipe_intro_video_url` — optional HTTPS URL for Swipe card video (see `20260329103000_profiles_swipe_intro_video_url.sql`); else latest video post, else avatar.
- `games.host_type` — default `player`; `games.host_org_id` nullable for future org-hosted games.

### Notification types

| `type` | Meaning |
|--------|---------|
| `incoming_like` | Someone liked you (not mutual yet). Unique per `(user_id, actor_user_id)`. |
| `mutual_match` | Match created; `entity_id` = match id. |
| `game_almost_full` | Two spots left (client-driven checks). |
| `game_last_spot` | One spot left. |
| `game_starting_soon` | Start within ~30 minutes (client checks). |
| `post_game_share_prompt` | End + within 24h (client checks). |

### RPCs

- `get_identity_stats(p_user_id uuid)` → jsonb counts for profile stats.
- `create_game_event_notification(p_type, p_game_id, p_payload)` — participant-only game alerts (deduped in SQL).

### Triggers

- `swipes` (like) → `incoming_like` for recipient if not yet mutual and not duplicate.
- `matches` (insert) → `mutual_match` for both users; marks related `incoming_like` rows read.

---

## Flutter services

- `lib/core/services/app_notification_badges.dart` — shell badge notifiers + `refreshAppNotificationBadges` / `clearAppNotificationBadges`.
- `lib/core/services/user_notifications_repository.dart` — queries, mark read, `watchMine()` realtime stream.
- `lib/core/services/game_event_notification_service.dart` — periodic RPC calls for joined games.
- `lib/core/services/profile_identity_service.dart` — `get_identity_stats` + `computeBadgeLabels` (Dart rules).
- `lib/core/services/entitlements_service.dart` — read map for future gating.

---

## Badge rules (Dart)

Defined in `computeBadgeLabels` in `profile_identity_service.dart`: e.g. New Player (no games), Weekly Hitter (≥2 sessions this month), Social Starter (≥1 match), Game Organizer (≥1 hosted), Regular (≥5 joined). Adjust thresholds there.

---

## Merchant / membership hooks

- **Account/host typing:** `profiles.account_type`, `games.host_type` / `host_org_id` for future dashboards and listings.
- **Entitlements:** add rows to `user_entitlements` when billing exists; gate features in Dart via `EntitlementsService` (default: allow all if no row).

---

## Manual Supabase setup

1. Apply migration: `supabase db push` or run the SQL file in the SQL Editor.
2. Confirm objects with [`SUPABASE_RETENTION_HANDTEST.md`](./SUPABASE_RETENTION_HANDTEST.md) (migration 核对步骤).
3. Enable **Realtime** for `user_notifications` if the publication step did not apply (Dashboard → Database → Replication).

---

## Release client config

Release builds must pass real `SUPABASE_URL` and `SUPABASE_ANON_KEY` via `--dart-define`; placeholder-like values are rejected at startup (`lib/core/config/supabase_env.dart`). See [`RELEASE_CHECKLIST.md`](./RELEASE_CHECKLIST.md) §1.1.

---

## Follow-ups

- Server-side cron or Edge Functions for game timing notifications if the app should notify when closed.
- Push (FCM/APNs) can subscribe to the same `user_notifications` feed or mirror to a push outbox.
