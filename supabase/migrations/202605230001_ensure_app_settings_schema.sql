-- ============================================================
-- Migration: ensure_app_settings_schema
-- Description: Ensure app_settings exists with the columns and
--              RLS policies required by the Flutter app.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.app_settings (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  company_id UUID NOT NULL,
  full_name TEXT,
  display_name TEXT,
  phone TEXT,
  postal_code TEXT,
  prefecture TEXT,
  city TEXT,
  address_line1 TEXT,
  address_line2 TEXT,
  business_type TEXT,
  language TEXT NOT NULL DEFAULT 'pt',
  currency TEXT NOT NULL DEFAULT 'JPY',
  fiscal_year_start_month INTEGER NOT NULL DEFAULT 1,
  filing_type TEXT NOT NULL DEFAULT 'white_return',
  consumption_tax_status TEXT NOT NULL DEFAULT 'exempt',
  invoice_registered BOOLEAN NOT NULL DEFAULT FALSE,
  invoice_registration_no TEXT,
  handles_reduced_tax_rate BOOLEAN NOT NULL DEFAULT TRUE,
  use_two_tenths_special_rule BOOLEAN NOT NULL DEFAULT FALSE,
  bookkeeping_method TEXT NOT NULL DEFAULT 'simple',
  fiscal_notes TEXT,
  closed_fiscal_months TEXT[] NOT NULL DEFAULT '{}',
  entry_categories TEXT[] NOT NULL DEFAULT '{}',
  expense_categories TEXT[] NOT NULL DEFAULT '{}',
  bank_account_info TEXT,
  smtp_host TEXT,
  smtp_port INTEGER DEFAULT 587,
  smtp_username TEXT,
  smtp_password TEXT,
  smtp_sender_name TEXT,
  smtp_use_ssl BOOLEAN DEFAULT FALSE,
  smtp_enabled BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.app_settings
  ADD COLUMN IF NOT EXISTS full_name TEXT,
  ADD COLUMN IF NOT EXISTS display_name TEXT,
  ADD COLUMN IF NOT EXISTS phone TEXT,
  ADD COLUMN IF NOT EXISTS postal_code TEXT,
  ADD COLUMN IF NOT EXISTS prefecture TEXT,
  ADD COLUMN IF NOT EXISTS city TEXT,
  ADD COLUMN IF NOT EXISTS address_line1 TEXT,
  ADD COLUMN IF NOT EXISTS address_line2 TEXT,
  ADD COLUMN IF NOT EXISTS business_type TEXT,
  ADD COLUMN IF NOT EXISTS language TEXT NOT NULL DEFAULT 'pt',
  ADD COLUMN IF NOT EXISTS currency TEXT NOT NULL DEFAULT 'JPY',
  ADD COLUMN IF NOT EXISTS fiscal_year_start_month INTEGER NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS filing_type TEXT NOT NULL DEFAULT 'white_return',
  ADD COLUMN IF NOT EXISTS consumption_tax_status TEXT NOT NULL DEFAULT 'exempt',
  ADD COLUMN IF NOT EXISTS invoice_registered BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS invoice_registration_no TEXT,
  ADD COLUMN IF NOT EXISTS handles_reduced_tax_rate BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS use_two_tenths_special_rule BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS bookkeeping_method TEXT NOT NULL DEFAULT 'simple',
  ADD COLUMN IF NOT EXISTS fiscal_notes TEXT,
  ADD COLUMN IF NOT EXISTS closed_fiscal_months TEXT[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS entry_categories TEXT[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS expense_categories TEXT[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS bank_account_info TEXT,
  ADD COLUMN IF NOT EXISTS smtp_host TEXT,
  ADD COLUMN IF NOT EXISTS smtp_port INTEGER DEFAULT 587,
  ADD COLUMN IF NOT EXISTS smtp_username TEXT,
  ADD COLUMN IF NOT EXISTS smtp_password TEXT,
  ADD COLUMN IF NOT EXISTS smtp_sender_name TEXT,
  ADD COLUMN IF NOT EXISTS smtp_use_ssl BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS smtp_enabled BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

CREATE UNIQUE INDEX IF NOT EXISTS idx_app_settings_company_id_unique
  ON public.app_settings (company_id);

ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "app_settings_company_isolation" ON public.app_settings;
DROP POLICY IF EXISTS "app_settings_select_own_company" ON public.app_settings;
DROP POLICY IF EXISTS "app_settings_insert_own_company" ON public.app_settings;
DROP POLICY IF EXISTS "app_settings_update_own_company" ON public.app_settings;
DROP POLICY IF EXISTS "app_settings_delete_own_company" ON public.app_settings;

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
