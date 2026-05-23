-- ============================================================
-- Migration: allow_reshiito_document_kind
-- Description: Adds 'reshiito' as a valid receipts.document_kind value
-- ============================================================

ALTER TABLE public.receipts
  DROP CONSTRAINT IF EXISTS receipts_document_kind_check;

ALTER TABLE public.receipts
  ADD CONSTRAINT receipts_document_kind_check
  CHECK (document_kind IN ('seikyuusho', 'ryoushuusho', 'reshiito'));
