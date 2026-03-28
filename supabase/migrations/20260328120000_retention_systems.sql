-- Retention: in-app notifications, identity stats RPC, entitlements, host typing.
-- Apply with `supabase db push` or SQL Editor.

-- ---------------------------------------------------------------------------
-- 1) user_notifications
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  actor_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  type text NOT NULL,
  entity_type text,
  entity_id uuid,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  is_read boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_notifications_user_created
  ON public.user_notifications (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_user_notifications_user_unread
  ON public.user_notifications (user_id)
  WHERE is_read = false;

CREATE UNIQUE INDEX IF NOT EXISTS uq_user_notifications_incoming_like
  ON public.user_notifications (user_id, actor_user_id)
  WHERE type = 'incoming_like';

CREATE UNIQUE INDEX IF NOT EXISTS uq_user_notifications_mutual_match
  ON public.user_notifications (user_id, entity_id)
  WHERE type = 'mutual_match' AND entity_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_user_notifications_game_event
  ON public.user_notifications (user_id, type, entity_id)
  WHERE type IN ('game_almost_full', 'game_last_spot', 'game_starting_soon', 'post_game_share_prompt')
    AND entity_id IS NOT NULL;

ALTER TABLE public.user_notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "un_select_own" ON public.user_notifications;
CREATE POLICY "un_select_own" ON public.user_notifications
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "un_update_own" ON public.user_notifications;
CREATE POLICY "un_update_own" ON public.user_notifications
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Inserts from clients go through SECURITY DEFINER RPCs or triggers only.
DROP POLICY IF EXISTS "un_insert_none" ON public.user_notifications;
CREATE POLICY "un_insert_none" ON public.user_notifications
  FOR INSERT TO authenticated
  WITH CHECK (false);

-- ---------------------------------------------------------------------------
-- 2) Triggers: swipe like → incoming_like; match → mutual_match + clear incoming
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_notify_swipe_like()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.action <> 'like' THEN
    RETURN NEW;
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.swipes s
    WHERE s.from_user = NEW.to_user
      AND s.to_user = NEW.from_user
      AND s.action = 'like'
  ) THEN
    RETURN NEW;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.user_notifications un
    WHERE un.user_id = NEW.to_user
      AND un.actor_user_id = NEW.from_user
      AND un.type = 'incoming_like'
  ) THEN
    INSERT INTO public.user_notifications (
      user_id, actor_user_id, type, entity_type, entity_id, payload
    )
    VALUES (
      NEW.to_user,
      NEW.from_user,
      'incoming_like',
      'profile',
      NEW.from_user,
      jsonb_build_object('from_user', NEW.from_user::text)
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_swipes_like_notify ON public.swipes;
CREATE TRIGGER trg_swipes_like_notify
  AFTER INSERT OR UPDATE OF action ON public.swipes
  FOR EACH ROW
  WHEN (NEW.action = 'like')
  EXECUTE FUNCTION public.trg_notify_swipe_like();

CREATE OR REPLACE FUNCTION public.trg_notify_match()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.user_notifications
    WHERE user_id = NEW.user_a AND type = 'mutual_match' AND entity_id = NEW.id
  ) THEN
    INSERT INTO public.user_notifications (
      user_id, actor_user_id, type, entity_type, entity_id, payload
    )
    VALUES
      (
        NEW.user_a,
        NEW.user_b,
        'mutual_match',
        'match',
        NEW.id,
        jsonb_build_object('peer_user_id', NEW.user_b::text, 'match_id', NEW.id::text)
      ),
      (
        NEW.user_b,
        NEW.user_a,
        'mutual_match',
        'match',
        NEW.id,
        jsonb_build_object('peer_user_id', NEW.user_a::text, 'match_id', NEW.id::text)
      );
  END IF;

  UPDATE public.user_notifications un
  SET is_read = true
  WHERE un.type = 'incoming_like'
    AND (
      (un.user_id = NEW.user_a AND un.actor_user_id = NEW.user_b)
      OR (un.user_id = NEW.user_b AND un.actor_user_id = NEW.user_a)
    );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_matches_notify ON public.matches;
CREATE TRIGGER trg_matches_notify
  AFTER INSERT ON public.matches
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_notify_match();

-- ---------------------------------------------------------------------------
-- 3) profiles.account_type + games host fields
-- ---------------------------------------------------------------------------
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS account_type text NOT NULL DEFAULT 'player';

ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_account_type_check;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_account_type_check
  CHECK (account_type IN ('player', 'coach', 'club', 'venue', 'organizer', 'brand'));

ALTER TABLE public.games
  ADD COLUMN IF NOT EXISTS host_type text NOT NULL DEFAULT 'player';

ALTER TABLE public.games
  ADD COLUMN IF NOT EXISTS host_org_id uuid;

ALTER TABLE public.games
  DROP CONSTRAINT IF EXISTS games_host_type_check;

ALTER TABLE public.games
  ADD CONSTRAINT games_host_type_check
  CHECK (host_type IN ('player', 'club', 'venue', 'organizer', 'brand'));

-- ---------------------------------------------------------------------------
-- 4) user_entitlements (future gating; empty = app defaults all on in client)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_entitlements (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  entitlement_key text NOT NULL,
  value jsonb NOT NULL DEFAULT 'true'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, entitlement_key)
);

CREATE INDEX IF NOT EXISTS idx_user_entitlements_user ON public.user_entitlements (user_id);

ALTER TABLE public.user_entitlements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "ue_select_own" ON public.user_entitlements;
CREATE POLICY "ue_select_own" ON public.user_entitlements
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "ue_modify_none" ON public.user_entitlements;
CREATE POLICY "ue_modify_none" ON public.user_entitlements
  FOR ALL TO authenticated
  USING (false);

-- ---------------------------------------------------------------------------
-- 5) Identity stats RPC (badges computed client-side from JSON)
-- ---------------------------------------------------------------------------
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
         AND joined_at >= date_trunc('month', timezone('utc', now()))),
    'streak_weeks_active',
      0
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_identity_stats(uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- 6) Client-safe notification insert (self only; game participation checked)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_game_event_notification(
  p_type text,
  p_game_id uuid,
  p_payload jsonb DEFAULT '{}'::jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  me uuid := auth.uid();
  allowed boolean;
  new_id uuid;
BEGIN
  IF me IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;

  IF p_type NOT IN (
    'game_almost_full',
    'game_last_spot',
    'game_starting_soon',
    'post_game_share_prompt'
  ) THEN
    RAISE EXCEPTION 'INVALID_TYPE';
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.game_participants
    WHERE game_id = p_game_id AND user_id = me AND status = 'joined'
  ) INTO allowed;

  IF NOT allowed THEN
    RAISE EXCEPTION 'NOT_PARTICIPANT';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.user_notifications
    WHERE user_id = me AND type = p_type AND entity_id = p_game_id
  ) THEN
    RETURN (SELECT id FROM public.user_notifications
            WHERE user_id = me AND type = p_type AND entity_id = p_game_id
            LIMIT 1);
  END IF;

  INSERT INTO public.user_notifications (
    user_id, actor_user_id, type, entity_type, entity_id, payload
  )
  VALUES (
    me,
    NULL,
    p_type,
    'game',
    p_game_id,
    p_payload || jsonb_build_object('game_id', p_game_id::text)
  )
  RETURNING id INTO new_id;

  RETURN new_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_game_event_notification(text, uuid, jsonb) TO authenticated;

-- ---------------------------------------------------------------------------
-- 7) Realtime (Supabase)
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.user_notifications;
EXCEPTION
  WHEN OTHERS THEN
    NULL;
END $$;
