-- Migration 07: Support reports table and RLS policies

CREATE TABLE IF NOT EXISTS public.support_reports (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    subject text NOT NULL,
    message text NOT NULL,
    category text NOT NULL DEFAULT 'general',
    status text NOT NULL DEFAULT 'open',
    admin_notes text,
    created_at timestamptz NOT NULL DEFAULT now(),
    resolved_at timestamptz
);

-- Enable RLS
ALTER TABLE public.support_reports ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS support_reports_select ON public.support_reports;
DROP POLICY IF EXISTS support_reports_insert ON public.support_reports;
DROP POLICY IF EXISTS support_reports_admin_select ON public.support_reports;
DROP POLICY IF EXISTS support_reports_admin_update ON public.support_reports;

-- Users can read their own reports
CREATE POLICY support_reports_select ON public.support_reports
    FOR SELECT USING (user_id = auth.uid());

-- Users can insert their own reports
CREATE POLICY support_reports_insert ON public.support_reports
    FOR INSERT WITH CHECK (user_id = auth.uid());

-- Admins can read all reports
CREATE POLICY support_reports_admin_select ON public.support_reports
    FOR SELECT USING (public.is_admin());

-- Admins can update status, admin_notes, resolved_at
CREATE POLICY support_reports_admin_update ON public.support_reports
    FOR UPDATE USING (public.is_admin());

GRANT SELECT, INSERT ON public.support_reports TO authenticated;
GRANT UPDATE (status, admin_notes, resolved_at) ON public.support_reports TO authenticated;
