-- Per-user blocking (client-enforced + RLS). Additive migration.

CREATE TABLE IF NOT EXISTS public.blocked_users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  blocked_user_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT blocked_users_no_self CHECK (user_id <> blocked_user_id),
  CONSTRAINT blocked_users_unique_pair UNIQUE (user_id, blocked_user_id)
);

COMMENT ON TABLE public.blocked_users IS
  'Rows where user_id blocked blocked_user_id; RLS limits access to own rows.';

CREATE INDEX IF NOT EXISTS idx_blocked_users_user_id ON public.blocked_users (user_id);
CREATE INDEX IF NOT EXISTS idx_blocked_users_blocked_user_id
  ON public.blocked_users (blocked_user_id);
CREATE INDEX IF NOT EXISTS idx_blocked_users_created_at ON public.blocked_users (created_at DESC);

ALTER TABLE public.blocked_users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "blocked_users_insert_own" ON public.blocked_users;
CREATE POLICY "blocked_users_insert_own" ON public.blocked_users
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

-- Outgoing: rows I created. Incoming: rows where I am the blocked user (for client filtering).
DROP POLICY IF EXISTS "blocked_users_select_own" ON public.blocked_users;
CREATE POLICY "blocked_users_select_own" ON public.blocked_users
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    OR blocked_user_id = auth.uid()
  );

DROP POLICY IF EXISTS "blocked_users_delete_own" ON public.blocked_users;
CREATE POLICY "blocked_users_delete_own" ON public.blocked_users
  FOR DELETE TO authenticated
  USING (user_id = auth.uid());

GRANT SELECT, INSERT, DELETE ON public.blocked_users TO authenticated;
