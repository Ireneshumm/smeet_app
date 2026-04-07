-- Swipes: play/skip actions, multiple rows per (from_user, to_user), created_at ordering.
-- Prerequisite: public.swipes exists (MVP schema).

UPDATE public.swipes SET action = 'play' WHERE action = 'like';
UPDATE public.swipes SET action = 'skip' WHERE action = 'pass';

ALTER TABLE public.swipes
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now();

-- Drop unique(pair) so the same users can record multiple swipes over time.
ALTER TABLE public.swipes DROP CONSTRAINT IF EXISTS swipes_from_user_to_user_key;

-- Surrogate PK: drop composite PK if present, then ensure id + PRIMARY KEY(id).
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'swipes' AND column_name = 'id'
  ) THEN
    ALTER TABLE public.swipes ADD COLUMN id uuid NOT NULL DEFAULT gen_random_uuid();
  END IF;
END $$;

UPDATE public.swipes SET id = gen_random_uuid() WHERE id IS NULL;

ALTER TABLE public.swipes ALTER COLUMN id SET NOT NULL;
ALTER TABLE public.swipes ALTER COLUMN id SET DEFAULT gen_random_uuid();

ALTER TABLE public.swipes DROP CONSTRAINT IF EXISTS swipes_pkey;
ALTER TABLE public.swipes ADD CONSTRAINT swipes_pkey PRIMARY KEY (id);

CREATE INDEX IF NOT EXISTS swipes_from_to_idx ON public.swipes (from_user, to_user);
CREATE INDEX IF NOT EXISTS swipes_peer_created_idx
  ON public.swipes (from_user, to_user, created_at DESC);

-- Notify recipient on play (was like).
CREATE OR REPLACE FUNCTION public.trg_notify_swipe_like()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.action <> 'play' THEN
    RETURN NEW;
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.swipes s
    WHERE s.from_user = NEW.to_user
      AND s.to_user = NEW.from_user
      AND s.action = 'play'
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
  WHEN (NEW.action = 'play')
  EXECUTE FUNCTION public.trg_notify_swipe_like();
