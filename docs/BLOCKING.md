# Blocking (Smeet)

## What the app enforces today (client + `blocked_users` RLS)

- **Data**: Rows in `public.blocked_users` with `user_id = auth.uid()` for people you block.
- **Other profile**: Block / Unblock, confirmation before block; restricted UI if they blocked you or you blocked them.
- **Direct 1:1 chat**: If either party has blocked the other (you blocked them **or** they blocked you), the thread shows a banner, **incoming messages from the peer are hidden**, and **send is disabled**.
- **Chat list**: Direct threads with a blocked peer are **hidden** (not shown).
- **Swipe**: Candidates you blocked or who blocked you are **filtered out** after load.

## Not enforced in this pass (future hardening)

- **Group / game chat**: No per-member message hiding; members can still see group messages. Prefer opening profiles only when needed; full group moderation is TBD.
- **Server-side messaging**: Messages are not blocked at the API layer; a determined client could still POST. **Next step**: Supabase RLS policy on `messages` or Edge Function to reject sends when a block exists between participants in direct chats.
- **Profile discovery**: Other surfaces that list users may still show blocked people until each is wired to `BlockService.fetchMyBlockSets()`.
