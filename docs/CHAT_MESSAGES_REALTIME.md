# Chat messages: realtime + RLS checklist

Use this when **messages don’t show immediately** or the stream never updates after `INSERT`.

The app uses **optimistic UI** for sends (message appears instantly) and **`insert().select()`** so the real row is merged immediately; the **realtime stream** still drives other users’ messages and eventual consistency. See `[ChatMessages]` logs below.

## Verify in SQL (Dashboard → SQL Editor)

```sql
-- 1) Realtime publication includes messages
SELECT pubname, schemaname, tablename
FROM pg_publication_tables
WHERE tablename = 'messages';

-- 2) RLS policies on messages (expect SELECT + INSERT for members)
SELECT polname, polcmd, polroles::regrole[]
FROM pg_policy
WHERE polrelid = 'public.messages'::regclass
ORDER BY polname;
```

If `messages` is missing from `pg_publication_tables`, run migration `20260322120000_messages_realtime_and_rls.sql` or:

```sql
ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
```

## 1) Realtime enabled for `public.messages`

Supabase Realtime only pushes changes for tables in the **`supabase_realtime` publication**.

1. Dashboard → **Database** → **Publications** → `supabase_realtime`.
2. Ensure **`messages`** is included (checkbox), or run SQL:

```sql
ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
```

3. **Replication** must be on for the table (often automatic when added to publication).

**Symptom if missing:** `INSERT` succeeds (and row exists in Table Editor) but **`[ChatMessages] stream event: count …`** never fires after your own send; polling would be the only way to see data.

---

## 2) RLS `SELECT` on `messages` for chat members

The client stream runs as **`authenticated`** and must be allowed to **read** rows for that `chat_id`.

Typical pattern:

- `SELECT` allowed when `EXISTS (SELECT 1 FROM chat_members cm WHERE cm.chat_id = messages.chat_id AND cm.user_id = auth.uid())`.

**Symptom if blocked:** Stream may **error** or return **no rows**; `[ChatMessages] StreamBuilder error:` may appear; Table Editor still shows rows.

---

## 3) RLS `INSERT` on `messages`

Send must be allowed for members of the chat (same membership check on `INSERT`).

**Symptom if blocked:** Snackbar “Send failed” and **no** `[ChatMessages] DB insert success` line.

---

## 4) App: stable stream subscription

The messages **`Stream` must be created once** (e.g. in `initState`), **not** inside `build()`. Recreating it every rebuild makes `StreamBuilder` cancel and resubscribe repeatedly, which can **drop or delay** realtime updates.

The app uses **`[ChatMessages]`** `debugPrint` lines to trace:

| Log | Meaning |
|-----|--------|
| `stream created once for chat_id=…` | Subscription started (once per screen). |
| `optimistic insert client_id=…` | Local bubble added before network returns. |
| `DB insert success id=…` | `insert().select()` returned the row; optimistic row removed and merged. |
| `StreamBuilder build: … rawCount=N` | Every rebuild; watch `rawCount` after send. |
| `stream event received: rawCount A → B` | Realtime snapshot grew (new rows visible to `SELECT`). |
| `rebuild with sorted len=…` | UI list length changed after merge/sort. |

**Interpretation:**

- **DB insert success** but **no** `stream event received` / `rawCount` unchanged → **realtime publication** or **SELECT RLS** (other clients may not see updates; your own message still shows via optimistic + `select()`).
- **`stream event received`** and **`rebuild with sorted len`** increase → realtime path is fine for multi-device.

---

## 5) Scroll vs visibility

With `ListView(reverse: true)` and newest-first items, **`jumpTo(minScrollExtent)`** moves to the **visual bottom** (newest). It does not hide widgets; if counts increase in logs but UI is wrong, capture a screenshot and check overflow/parent constraints.
