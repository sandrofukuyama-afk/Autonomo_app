-- ============================================================
-- Migration: add_receipts_and_smtp
-- Description: Creates receipts table and adds SMTP config fields
-- ============================================================

-- ─── TABLE: receipts ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.receipts (
  id               UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  company_id       UUID NOT NULL,
  entry_id         UUID,
  receipt_number   TEXT NOT NULL,
  issue_date       DATE NOT NULL,
  client_name      TEXT,
  client_email     TEXT,
  description      TEXT NOT NULL,
  amount           NUMERIC(14, 2) NOT NULL DEFAULT 0,
  tax_amount       NUMERIC(14, 2) NOT NULL DEFAULT 0,
  payment_method   TEXT,
  notes            TEXT,
  format           TEXT NOT NULL DEFAULT 'a4',
  language         TEXT NOT NULL DEFAULT 'pt',
  issued_by        TEXT,
  company_address  TEXT,
  company_phone    TEXT,
  invoice_number   TEXT,
  created_at       TIMESTAMPTZ DEFAULT now() NOT NULL,
  CONSTRAINT receipts_format_check
    CHECK (format IN ('thermal_58', 'thermal_80', 'a5', 'a4', 'email'))
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_receipts_company_id ON public.receipts (company_id);
CREATE INDEX IF NOT EXISTS idx_receipts_entry_id   ON public.receipts (entry_id);
CREATE INDEX IF NOT EXISTS idx_receipts_issue_date ON public.receipts (issue_date DESC);

-- RLS
ALTER TABLE public.receipts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "receipts_company_isolation" ON public.receipts;
CREATE POLICY "receipts_company_isolation"
  ON public.receipts
  FOR ALL
  USING (
    company_id IN (
      SELECT company_id FROM public.app_settings
      WHERE company_id::text = auth.uid()::text
    )
  );

-- ─── SMTP COLUMNS IN app_settings ───────────────────────────
ALTER TABLE public.app_settings
  ADD COLUMN IF NOT EXISTS smtp_host        TEXT,
  ADD COLUMN IF NOT EXISTS smtp_port        INTEGER DEFAULT 587,
  ADD COLUMN IF NOT EXISTS smtp_username    TEXT,
  ADD COLUMN IF NOT EXISTS smtp_password    TEXT,
  ADD COLUMN IF NOT EXISTS smtp_sender_name TEXT,
  ADD COLUMN IF NOT EXISTS smtp_use_ssl     BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS smtp_enabled     BOOLEAN DEFAULT FALSE;
