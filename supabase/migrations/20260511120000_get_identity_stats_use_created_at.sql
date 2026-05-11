-- get_identity_stats: use created_at for monthly session count.
-- Production may lack joined_at; repo MVP has joined_at but not created_at — add + backfill first.

ALTER TABLE public.game_participants
  ADD COLUMN IF NOT EXISTS created_at timestamptz;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'game_participants'
      AND column_name = 'joined_at'
  ) THEN
    EXECUTE $backfill$
      UPDATE public.game_participants gp
      SET created_at = COALESCE(gp.created_at, gp.joined_at)
      WHERE gp.created_at IS NULL
    $backfill$;
  END IF;
END $$;

UPDATE public.game_participants
SET created_at = timezone('utc', now())
WHERE created_at IS NULL;

ALTER TABLE public.game_participants
  ALTER COLUMN created_at SET DEFAULT timezone('utc', now());

ALTER TABLE public.game_participants
  ALTER COLUMN created_at SET NOT NULL;

CREATE OR REPLACE FUNCTION public.get_identity_stats(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  me uuid := auth.uid();
BEGIN
  IF me IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;

  RETURN jsonb_build_object(
    'total_games_joined',
      (SELECT COUNT(*)::int FROM public.game_participants
       WHERE user_id = p_user_id AND status = 'joined'),
    'total_games_hosted',
      (SELECT COUNT(*)::int FROM public.games WHERE created_by = p_user_id),
    'match_count',
      (SELECT COUNT(*)::int FROM public.matches
       WHERE user_a = p_user_id OR user_b = p_user_id),
    'unique_players_met',
      COALESCE((
        SELECT COUNT(DISTINCT gp2.user_id)::int
        FROM public.game_participants gp1
        JOIN public.game_participants gp2
          ON gp1.game_id = gp2.game_id
         AND gp2.user_id <> p_user_id
         AND gp2.status = 'joined'
        WHERE gp1.user_id = p_user_id
          AND gp1.status = 'joined'
      ), 0),
    'this_month_sessions',
      (SELECT COUNT(*)::int FROM public.game_participants
       WHERE user_id = p_user_id
         AND status = 'joined'
         AND created_at >= date_trunc('month', timezone('utc', now()))),
    'streak_weeks_active',
      0
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_identity_stats(uuid) TO authenticated;
