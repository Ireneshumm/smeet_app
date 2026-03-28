-- Optional intro video for Swipe cards (Phase 1 media). Fallback: latest video post, then avatar.
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS swipe_intro_video_url text;

COMMENT ON COLUMN public.profiles.swipe_intro_video_url IS
  'HTTPS URL to a short intro video for Swipe; empty means use latest video post then avatar.';
