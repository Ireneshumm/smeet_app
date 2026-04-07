-- Post likes (per user) + denormalized count on posts for feed.

ALTER TABLE public.posts
  ADD COLUMN IF NOT EXISTS likes_count integer NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS public.post_likes (
  post_id uuid NOT NULL REFERENCES public.posts (id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (post_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_post_likes_user_id ON public.post_likes (user_id);

ALTER TABLE public.post_likes ENABLE ROW LEVEL SECURITY;

-- Authenticated users can read likes; insert/delete own rows.
CREATE POLICY "post_likes_select_authenticated"
  ON public.post_likes FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "post_likes_insert_own"
  ON public.post_likes FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "post_likes_delete_own"
  ON public.post_likes FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION public._bump_post_likes_count()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.posts SET likes_count = likes_count + 1 WHERE id = NEW.post_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.posts SET likes_count = GREATEST(0, likes_count - 1) WHERE id = OLD.post_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_post_likes_bump ON public.post_likes;
CREATE TRIGGER trg_post_likes_bump
  AFTER INSERT OR DELETE ON public.post_likes
  FOR EACH ROW EXECUTE FUNCTION public._bump_post_likes_count();
