-- Account deletion requests (App Store account deletion path; processed server-side later).
-- Additive migration.

CREATE TABLE IF NOT EXISTS public.account_deletion_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL UNIQUE,
  status text NOT NULL DEFAULT 'pending',
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT account_deletion_requests_status_chk CHECK (
    status IN ('pending', 'processing', 'completed', 'cancelled')
  )
);

COMMENT ON TABLE public.account_deletion_requests IS
  'One row per user requesting account deletion; staff/service role processes outside the client.';

CREATE INDEX IF NOT EXISTS idx_account_deletion_requests_status_created
  ON public.account_deletion_requests (status, created_at DESC);

ALTER TABLE public.account_deletion_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "account_deletion_requests_insert_self" ON public.account_deletion_requests;
CREATE POLICY "account_deletion_requests_insert_self" ON public.account_deletion_requests
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "account_deletion_requests_select_self" ON public.account_deletion_requests;
CREATE POLICY "account_deletion_requests_select_self" ON public.account_deletion_requests
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

-- Allow user to withdraw a pending request (optional UX).
DROP POLICY IF EXISTS "account_deletion_requests_delete_own_pending" ON public.account_deletion_requests;
CREATE POLICY "account_deletion_requests_delete_own_pending" ON public.account_deletion_requests
  FOR DELETE TO authenticated
  USING (user_id = auth.uid() AND status = 'pending');

-- Allow user to re-submit after status completed/cancelled (single row per user_id).
DROP POLICY IF EXISTS "account_deletion_requests_update_self" ON public.account_deletion_requests;
CREATE POLICY "account_deletion_requests_update_self" ON public.account_deletion_requests
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

GRANT SELECT, INSERT, UPDATE, DELETE ON public.account_deletion_requests TO authenticated;
