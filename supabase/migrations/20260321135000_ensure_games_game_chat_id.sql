-- ---------------------------------------------------------------------------
-- games.game_chat_id (required for group chat + join_game)
-- ---------------------------------------------------------------------------
-- This column is also added in 20260321120000_smeet_mvp_phases.sql (section 3).
-- Use this migration as a safe, idempotent repair if that step was skipped
-- (e.g. only part of 20000 was run, or an older DB never had the column).
--
-- Why it matters:
-- - The Flutter create-game flow INSERTs into public.chats, then UPDATEs
--   public.games SET game_chat_id = <new chat id>.
-- - public.join_game (see 20260321140000_game_chat_join_read.sql) SELECTs
--   games.game_chat_id and INSERTs into chat_members when gc_id IS NOT NULL.
-- Without this column, the UPDATE fails or is ignored and joiners never join
-- the group chat.
--
-- Prerequisite: public.chats exists (standard Smeet schema).
-- ---------------------------------------------------------------------------

ALTER TABLE public.games
  ADD COLUMN IF NOT EXISTS game_chat_id uuid REFERENCES public.chats(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.games.game_chat_id IS 'FK to the game group chat row in public.chats; app sets this after creating the chat.';
