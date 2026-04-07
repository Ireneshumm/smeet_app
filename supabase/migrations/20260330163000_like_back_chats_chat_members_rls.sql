-- Like back / DM flow: allow creating direct chats + membership rows from the client.
-- Also fixes PostgREST insert(...).select('id') on chats before chat_members exist:
-- SELECT must allow rows with zero members briefly, OR member chats.

ALTER TABLE public.chats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_members ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- chats
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "users can create chats" ON public.chats;
CREATE POLICY "users can create chats" ON public.chats
  FOR INSERT TO authenticated
  WITH CHECK (true);

DROP POLICY IF EXISTS "users can read chats" ON public.chats;
CREATE POLICY "users can read chats" ON public.chats
  FOR SELECT TO authenticated
  USING (
    id IN (
      SELECT cm.chat_id FROM public.chat_members cm
      WHERE cm.user_id = auth.uid()
    )
    OR NOT EXISTS (
      SELECT 1 FROM public.chat_members cm WHERE cm.chat_id = chats.id
    )
  );

-- ---------------------------------------------------------------------------
-- chat_members
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "users can join chats" ON public.chat_members;
CREATE POLICY "users can join chats" ON public.chat_members
  FOR INSERT TO authenticated
  WITH CHECK (true);

DROP POLICY IF EXISTS "users can read chat members" ON public.chat_members;
CREATE POLICY "users can read chat members" ON public.chat_members
  FOR SELECT TO authenticated
  USING (
    chat_id IN (
      SELECT cm.chat_id FROM public.chat_members cm
      WHERE cm.user_id = auth.uid()
    )
  );
