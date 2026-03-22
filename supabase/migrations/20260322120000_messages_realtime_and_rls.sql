-- Realtime delivery for public.messages + RLS so chat members can SELECT/INSERT.
-- Prerequisite: public.messages and public.chat_members exist.
--
-- If you already have policies you prefer, adjust or skip the policy section
-- and only run the publication block.

-- ---------------------------------------------------------------------------
-- 1) supabase_realtime publication (enables WAL → Realtime for clients)
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime')
     AND EXISTS (
       SELECT 1 FROM information_schema.tables
       WHERE table_schema = 'public' AND table_name = 'messages'
     )
     AND NOT EXISTS (
       SELECT 1 FROM pg_publication_tables
       WHERE pubname = 'supabase_realtime'
         AND schemaname = 'public'
         AND tablename = 'messages'
     ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 2) RLS: members can read/write messages in their chats
-- ---------------------------------------------------------------------------
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "messages_select_chat_member" ON public.messages;
CREATE POLICY "messages_select_chat_member" ON public.messages
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.chat_members cm
      WHERE cm.chat_id = messages.chat_id
        AND cm.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "messages_insert_self_chat_member" ON public.messages;
CREATE POLICY "messages_insert_self_chat_member" ON public.messages
  FOR INSERT TO authenticated
  WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (
      SELECT 1 FROM public.chat_members cm
      WHERE cm.chat_id = messages.chat_id
        AND cm.user_id = auth.uid()
    )
  );
