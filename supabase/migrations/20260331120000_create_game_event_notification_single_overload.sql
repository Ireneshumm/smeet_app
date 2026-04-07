-- PostgREST RPC with named args (p_type, p_game_id, p_payload) becomes ambiguous when
-- two overloads exist: (text, uuid, jsonb) vs (uuid, jsonb, text). Keep one signature only.
DROP FUNCTION IF EXISTS public.create_game_event_notification(uuid, jsonb, text);
