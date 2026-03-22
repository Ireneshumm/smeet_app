# Account deletion — request workflow (current)

Smeet implements an **account deletion request** flow, not an immediate wipe from the mobile app. This matches App Store expectations (user can initiate deletion in-app) while keeping **service role** keys off the client.

## User journey (app)

1. **Profile → Legal → Request account deletion**
2. If a **pending** or **processing** request already exists → dialog shows **status** and **reference** (short + full UUID); user exits without re-submitting.
3. Otherwise → **Request account deletion** explains that this is a **formal request** for server-side processing.
4. User must type **`DELETE`** to confirm intent.
5. App **inserts or updates** `public.account_deletion_requests` and returns the row **`id`** as the request reference.
6. **Request received** dialog shows reference → user taps **Sign out** → session ends.

No Auth user deletion or bulk data delete runs in Flutter.

## Database (`account_deletion_requests`)

| Column     | Purpose |
|-----------|---------|
| `id`      | **Request reference** (UUID) — show to user and support |
| `user_id` | `auth.uid()` — unique per user |
| `status`  | `pending` → `processing` → `completed` / `cancelled` |
| `created_at` | First recorded time |

RLS: users can only read/write their own row. Delete own row allowed only when `pending` (withdraw request).

## Re-request after completion

If `status` is `completed` or `cancelled`, the app sets `status` back to `pending` (same row) so a new processing cycle can run.

---

## Future: full deletion (Edge Function)

See **[EDGE_FUNCTION_FULL_ACCOUNT_DELETION.md](./EDGE_FUNCTION_FULL_ACCOUNT_DELETION.md)** for the recommended server-side design (service role, table order, idempotency, security).
