-- Sport achievements + RPC (Smeet engagement). user_notifications already exists — not recreated here.

-- ---------------------------------------------------------------------------
-- sport_achievements
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.sport_achievements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  sport text NOT NULL,
  games_played int NOT NULL DEFAULT 0,
  total_hours numeric NOT NULL DEFAULT 0,
  badge_level text NOT NULL DEFAULT 'newcomer',
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, sport)
);

CREATE INDEX IF NOT EXISTS idx_sport_achievements_user
  ON public.sport_achievements (user_id);

ALTER TABLE public.sport_achievements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "sport_achievements_select_all" ON public.sport_achievements;
CREATE POLICY "sport_achievements_select_all"
  ON public.sport_achievements
  FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "sport_achievements_insert_own" ON public.sport_achievements;
CREATE POLICY "sport_achievements_insert_own"
  ON public.sport_achievements
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "sport_achievements_update_own" ON public.sport_achievements;
CREATE POLICY "sport_achievements_update_own"
  ON public.sport_achievements
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "sport_achievements_delete_own" ON public.sport_achievements;
CREATE POLICY "sport_achievements_delete_own"
  ON public.sport_achievements
  FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- RPC: bump games_played / hours / badge (caller must be same user)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.update_sport_achievement(
  p_user_id uuid,
  p_sport text,
  p_hours numeric DEFAULT 1.0
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_games int;
  v_badge text;
BEGIN
  IF auth.uid() IS NULL OR auth.uid() IS DISTINCT FROM p_user_id THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  IF p_sport IS NULL OR btrim(p_sport) = '' THEN
    RAISE EXCEPTION 'sport required';
  END IF;

  INSERT INTO public.sport_achievements (user_id, sport, games_played, total_hours)
  VALUES (p_user_id, btrim(p_sport), 1, COALESCE(p_hours, 1.0))
  ON CONFLICT (user_id, sport) DO UPDATE
    SET games_played = public.sport_achievements.games_played + 1,
        total_hours = public.sport_achievements.total_hours + COALESCE(p_hours, 1.0),
        updated_at = now();

  SELECT games_played INTO v_games
  FROM public.sport_achievements
  WHERE user_id = p_user_id AND sport = btrim(p_sport);

  v_badge := CASE
    WHEN v_games >= 50 THEN 'legend'
    WHEN v_games >= 30 THEN 'pro'
    WHEN v_games >= 15 THEN 'regular'
    WHEN v_games >= 5 THEN 'active'
    ELSE 'newcomer'
  END;

  UPDATE public.sport_achievements
  SET badge_level = v_badge
  WHERE user_id = p_user_id AND sport = btrim(p_sport);
END;
$$;

REVOKE ALL ON FUNCTION public.update_sport_achievement(uuid, text, numeric) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_sport_achievement(uuid, text, numeric) TO authenticated;
