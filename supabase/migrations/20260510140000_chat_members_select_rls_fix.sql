-- Fix SELECT on chat_members: previous policy referenced chat_members inside itself,
-- causing infinite RLS recursion and PostgREST 500 on /rest/v1/chat_members.

CREATE OR REPLACE FUNCTION public.is_chat_member(p_chat_id uuid, p_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.chat_members cm
    WHERE cm.chat_id = p_chat_id
      AND cm.user_id = p_user_id
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_chat_member(uuid, uuid) TO authenticated;

DROP POLICY IF EXISTS "users can read chat members" ON public.chat_members;
CREATE POLICY "users can read chat members" ON public.chat_members
  FOR SELECT TO authenticated
  USING (public.is_chat_member(chat_id, auth.uid()));
