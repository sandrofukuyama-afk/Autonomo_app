-- ============================================================
-- Migration: add_receipt_paid_status
-- Description: Persists receipt payment status on receipts table
-- ============================================================

ALTER TABLE public.receipts
  ADD COLUMN IF NOT EXISTS is_paid BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS paid_at TIMESTAMPTZ;

-- Backfill old rows that already had an entry linked.
UPDATE public.receipts
SET
  is_paid = TRUE,
  paid_at = COALESCE(paid_at, now())
WHERE entry_id IS NOT NULL
  AND (is_paid = FALSE OR is_paid IS NULL);

CREATE INDEX IF NOT EXISTS idx_receipts_is_paid
  ON public.receipts (is_paid);
