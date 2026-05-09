-- Smeet: dedupe swipes + enforce one row per (from_user, to_user)

-- 1. Dedupe: keep only the most recent swipe per pair
DELETE FROM public.swipes a
USING public.swipes b
WHERE a.from_user = b.from_user
  AND a.to_user   = b.to_user
  AND a.created_at < b.created_at;

-- 2. Add unique constraint
ALTER TABLE public.swipes
  ADD CONSTRAINT swipes_from_to_unique UNIQUE (from_user, to_user);

-- 3. Index for fast "exclude already swiped" lookups
CREATE INDEX IF NOT EXISTS swipes_from_user_idx
  ON public.swipes (from_user, to_user);

COMMENT ON CONSTRAINT swipes_from_to_unique ON public.swipes IS
  'Smeet: one swipe row per (from_user, to_user). UPSERT in app code allows users to change their mind.';
