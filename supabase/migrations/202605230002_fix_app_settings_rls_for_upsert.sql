-- ============================================================
-- Migration: fix_app_settings_rls_for_upsert
-- Description: Allow safe INSERT/UPDATE/SELECT on app_settings
--              scoped to the authenticated user's company.
-- ============================================================

-- Ensure one row per company for deterministic upsert behavior.
CREATE UNIQUE INDEX IF NOT EXISTS idx_app_settings_company_id_unique
  ON public.app_settings (company_id);

ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

-- Remove old generic/legacy policies if they exist.
DROP POLICY IF EXISTS "app_settings_company_isolation" ON public.app_settings;
DROP POLICY IF EXISTS "app_settings_select_own_company" ON public.app_settings;
DROP POLICY IF EXISTS "app_settings_insert_own_company" ON public.app_settings;
DROP POLICY IF EXISTS "app_settings_update_own_company" ON public.app_settings;
DROP POLICY IF EXISTS "app_settings_delete_own_company" ON public.app_settings;

-- Read: only settings from the user's company.
CREATE POLICY "app_settings_select_own_company"
  ON public.app_settings
  FOR SELECT
  USING (
    company_id IN (
      SELECT company_id
      FROM public.profiles
      WHERE id = auth.uid()
    )
  );

-- Insert: allow only row for the user's company.
CREATE POLICY "app_settings_insert_own_company"
  ON public.app_settings
  FOR INSERT
  WITH CHECK (
    company_id IN (
      SELECT company_id
      FROM public.profiles
      WHERE id = auth.uid()
    )
  );

-- Update: allow only row for the user's company and keep company scope on write.
CREATE POLICY "app_settings_update_own_company"
  ON public.app_settings
  FOR UPDATE
  USING (
    company_id IN (
      SELECT company_id
      FROM public.profiles
      WHERE id = auth.uid()
    )
  )
  WITH CHECK (
    company_id IN (
      SELECT company_id
      FROM public.profiles
      WHERE id = auth.uid()
    )
  );

