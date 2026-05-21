-- ============================================================
-- Migration: add_clients_table
-- Description: Creates the clients table with full address
-- ============================================================

CREATE TABLE IF NOT EXISTS public.clients (
  id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  company_id      UUID NOT NULL,
  name            TEXT NOT NULL,
  email           TEXT,
  phone           TEXT,
  postal_code     TEXT,
  province        TEXT,
  city            TEXT,
  neighborhood    TEXT,
  street_number   TEXT,
  apartment       TEXT,
  created_at      TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at      TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_clients_company_id
  ON public.clients (company_id);

CREATE INDEX IF NOT EXISTS idx_clients_created_at
  ON public.clients (created_at DESC);

ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "clients_company_isolation" ON public.clients;
CREATE POLICY "clients_company_isolation"
  ON public.clients
  FOR ALL
  USING (
    company_id IN (
      SELECT company_id FROM public.profiles
      WHERE id = auth.uid()
    )
  );
