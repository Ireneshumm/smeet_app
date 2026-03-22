-- Game target level + end time (Phase 1 MVP)
ALTER TABLE public.games
  ADD COLUMN IF NOT EXISTS game_level text;

ALTER TABLE public.games
  ADD COLUMN IF NOT EXISTS ends_at timestamptz;

COMMENT ON COLUMN public.games.game_level IS 'Target/suitable level for this game (not creator profile level).';
COMMENT ON COLUMN public.games.ends_at IS 'Game end time (UTC).';
