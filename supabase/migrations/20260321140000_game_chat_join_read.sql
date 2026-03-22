-- Game group chat on join + read receipts for unread counts
-- Apply in Supabase SQL Editor or: npx supabase db push
--
-- PREREQUISITE: public.games.game_chat_id must exist (see
-- 20260321135000_ensure_games_game_chat_id.sql or section 3 of
-- 20260321120000_smeet_mvp_phases.sql). join_game reads this column; if it
-- is missing, PostgreSQL may reject this function definition or RPC will fail
-- at runtime when resolving the SELECT from games.

-- ---------------------------------------------------------------------------
-- 1) messages.created_at (for ordering + unread)
-- ---------------------------------------------------------------------------
ALTER TABLE public.messages
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now();

CREATE INDEX IF NOT EXISTS idx_messages_chat_created
  ON public.messages (chat_id, created_at);

-- ---------------------------------------------------------------------------
-- 2) chat_members.last_read_at
-- ---------------------------------------------------------------------------
ALTER TABLE public.chat_members
  ADD COLUMN IF NOT EXISTS last_read_at timestamptz;

-- Allow users to update only their own membership row (read receipts)
DROP POLICY IF EXISTS "cm_update_own_read" ON public.chat_members;
CREATE POLICY "cm_update_own_read" ON public.chat_members
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- 3) join_game: also add player to game group chat when linked
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.join_game(p_game_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid uuid := auth.uid();
  j int;
  p int;
  gc_id uuid;
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;

  SELECT joined_count, players, game_chat_id INTO j, p, gc_id
  FROM public.games
  WHERE id = p_game_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'GAME_NOT_FOUND';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.game_participants
    WHERE game_id = p_game_id AND user_id = uid AND status = 'joined'
  ) THEN
    RETURN;
  END IF;

  IF j >= p THEN
    RAISE EXCEPTION 'GAME_FULL';
  END IF;

  INSERT INTO public.game_participants (game_id, user_id, status)
  VALUES (p_game_id, uid, 'joined')
  ON CONFLICT (game_id, user_id) DO UPDATE
    SET status = 'joined', joined_at = now();

  UPDATE public.games
  SET joined_count = joined_count + 1
  WHERE id = p_game_id;

  IF gc_id IS NOT NULL THEN
    INSERT INTO public.chat_members (chat_id, user_id)
    SELECT gc_id, uid
    WHERE NOT EXISTS (
      SELECT 1 FROM public.chat_members cm
      WHERE cm.chat_id = gc_id AND cm.user_id = uid
    );
  END IF;
END;
$$;
