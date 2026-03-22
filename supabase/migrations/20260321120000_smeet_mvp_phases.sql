-- Smeet MVP: participants, game chats, RPC join/leave
-- Apply in Supabase Dashboard → SQL or `supabase db push`

-- ---------------------------------------------------------------------------
-- 1) game_participants
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.game_participants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id uuid NOT NULL REFERENCES public.games(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  joined_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'joined' CHECK (status IN ('joined', 'left')),
  UNIQUE (game_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_game_participants_game ON public.game_participants(game_id);
CREATE INDEX IF NOT EXISTS idx_game_participants_user ON public.game_participants(user_id) WHERE status = 'joined';

ALTER TABLE public.game_participants ENABLE ROW LEVEL SECURITY;

-- Example policies (adjust to your security model)
DROP POLICY IF EXISTS "gp_select_authenticated" ON public.game_participants;
CREATE POLICY "gp_select_authenticated" ON public.game_participants
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "gp_insert_own" ON public.game_participants;
CREATE POLICY "gp_insert_own" ON public.game_participants
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "gp_update_own" ON public.game_participants;
CREATE POLICY "gp_update_own" ON public.game_participants
  FOR UPDATE TO authenticated USING (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- 2) chats: game vs direct
-- ---------------------------------------------------------------------------
ALTER TABLE public.chats
  ADD COLUMN IF NOT EXISTS chat_kind text NOT NULL DEFAULT 'direct';

ALTER TABLE public.chats
  ADD COLUMN IF NOT EXISTS game_id uuid REFERENCES public.games(id) ON DELETE CASCADE;

ALTER TABLE public.chats
  ADD COLUMN IF NOT EXISTS title text;

-- ---------------------------------------------------------------------------
-- 3) games: link to group chat
-- ---------------------------------------------------------------------------
ALTER TABLE public.games
  ADD COLUMN IF NOT EXISTS game_chat_id uuid REFERENCES public.chats(id) ON DELETE SET NULL;

-- ---------------------------------------------------------------------------
-- 4) join_game / leave_game (replace any older definitions)
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
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;

  SELECT joined_count, players INTO j, p
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
END;
$$;

CREATE OR REPLACE FUNCTION public.leave_game(p_game_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid uuid := auth.uid();
  n int;
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;

  WITH upd AS (
    UPDATE public.game_participants
    SET status = 'left'
    WHERE game_id = p_game_id
      AND user_id = uid
      AND status = 'joined'
    RETURNING 1
  )
  SELECT COUNT(*)::int INTO n FROM upd;

  IF n = 0 THEN
    RAISE EXCEPTION 'NOT_JOINED_OR_EMPTY';
  END IF;

  UPDATE public.games
  SET joined_count = GREATEST(0, joined_count - n)
  WHERE id = p_game_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.join_game(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.leave_game(uuid) TO authenticated;
