-- User-generated content reports (App Store safety).
-- Additive only; safe to apply on existing projects.

-- ---------------------------------------------------------------------------
-- Table
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id uuid NOT NULL,
  target_user_id uuid,
  message_id uuid,
  reason text NOT NULL,
  details text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT reports_target_or_message_chk CHECK (
    target_user_id IS NOT NULL OR message_id IS NOT NULL
  )
);

COMMENT ON TABLE public.reports IS
  'User reports; RLS restricts reads to reporter; inserts require reporter_id = auth.uid().';

-- Note: optional FK to public.messages(id) can be added later if types match (uuid).

-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_reports_reporter_id ON public.reports (reporter_id);
CREATE INDEX IF NOT EXISTS idx_reports_created_at ON public.reports (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_reports_target_user_id
  ON public.reports (target_user_id)
  WHERE target_user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_reports_message_id
  ON public.reports (message_id)
  WHERE message_id IS NOT NULL;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "reports_insert_self" ON public.reports;
CREATE POLICY "reports_insert_self" ON public.reports
  FOR INSERT TO authenticated
  WITH CHECK (reporter_id = auth.uid());

-- Review own submissions only; moderators use service role / dashboard (bypasses RLS).
DROP POLICY IF EXISTS "reports_select_own" ON public.reports;
CREATE POLICY "reports_select_own" ON public.reports
  FOR SELECT TO authenticated
  USING (reporter_id = auth.uid());

-- No UPDATE/DELETE for normal users (admins use service role).

GRANT SELECT, INSERT ON public.reports TO authenticated;
