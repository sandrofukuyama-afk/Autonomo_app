-- ============================================================
-- Migration: add_service_catalog_and_receipt_metadata
-- Description: Creates a service catalog and stores receipt item metadata
-- ============================================================

-- Service catalog used by receipt issuance
CREATE TABLE IF NOT EXISTS public.service_catalog (
  id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  company_id      UUID NOT NULL,
  name            TEXT NOT NULL,
  description     TEXT,
  default_amount  NUMERIC(14, 2),
  created_at      TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at      TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_service_catalog_company_id
  ON public.service_catalog (company_id);

CREATE INDEX IF NOT EXISTS idx_service_catalog_created_at
  ON public.service_catalog (created_at DESC);

ALTER TABLE public.service_catalog ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "service_catalog_company_isolation" ON public.service_catalog;
CREATE POLICY "service_catalog_company_isolation"
  ON public.service_catalog
  FOR ALL
  USING (
    company_id IN (
      SELECT company_id FROM public.profiles
      WHERE id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "receipts_company_isolation" ON public.receipts;
CREATE POLICY "receipts_company_isolation"
  ON public.receipts
  FOR ALL
  USING (
    company_id IN (
      SELECT company_id FROM public.profiles
      WHERE id = auth.uid()
    )
  );

-- Extra metadata for receipts so the UI can distinguish products vs services.
ALTER TABLE public.receipts
  ADD COLUMN IF NOT EXISTS document_kind TEXT NOT NULL DEFAULT 'ryoushuusho',
  ADD COLUMN IF NOT EXISTS item_type TEXT NOT NULL DEFAULT 'product',
  ADD COLUMN IF NOT EXISTS service_id UUID;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'receipts_item_type_check'
  ) THEN
    ALTER TABLE public.receipts
      ADD CONSTRAINT receipts_item_type_check
      CHECK (item_type IN ('product', 'service'));
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'receipts_document_kind_check'
  ) THEN
    ALTER TABLE public.receipts
      ADD CONSTRAINT receipts_document_kind_check
      CHECK (document_kind IN ('seikyuusho', 'ryoushuusho'));
  END IF;
END $$;
