-- ============================================================
-- Migration: add_receivables_control
-- Description: Adds billed/installment metadata and schedules
-- ============================================================

ALTER TABLE public.receipts
  ADD COLUMN IF NOT EXISTS due_date DATE,
  ADD COLUMN IF NOT EXISTS payment_condition TEXT NOT NULL DEFAULT 'a_vista',
  ADD COLUMN IF NOT EXISTS down_payment_amount NUMERIC(14, 2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS installments_count INTEGER NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS installment_value NUMERIC(14, 2);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'receipts_payment_condition_check'
  ) THEN
    ALTER TABLE public.receipts
      ADD CONSTRAINT receipts_payment_condition_check
      CHECK (payment_condition IN ('a_vista', 'faturado', 'parcelado'));
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.receipt_payment_schedules (
  id                 UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  company_id         UUID NOT NULL,
  receipt_id         UUID NOT NULL REFERENCES public.receipts(id) ON DELETE CASCADE,
  installment_number INTEGER NOT NULL DEFAULT 1,
  due_date           DATE NOT NULL,
  amount             NUMERIC(14, 2) NOT NULL DEFAULT 0,
  paid_amount        NUMERIC(14, 2),
  status             TEXT NOT NULL DEFAULT 'pending',
  paid_at            TIMESTAMPTZ,
  payment_method     TEXT,
  notes              TEXT,
  created_at         TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at         TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_receipt_payment_schedules_company_id
  ON public.receipt_payment_schedules (company_id);

CREATE INDEX IF NOT EXISTS idx_receipt_payment_schedules_receipt_id
  ON public.receipt_payment_schedules (receipt_id);

CREATE INDEX IF NOT EXISTS idx_receipt_payment_schedules_due_date
  ON public.receipt_payment_schedules (due_date ASC);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'receipt_payment_schedules_status_check'
  ) THEN
    ALTER TABLE public.receipt_payment_schedules
      ADD CONSTRAINT receipt_payment_schedules_status_check
      CHECK (status IN ('pending', 'paid', 'overdue'));
  END IF;
END $$;

ALTER TABLE public.receipt_payment_schedules ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "receipt_payment_schedules_company_isolation"
  ON public.receipt_payment_schedules;

CREATE POLICY "receipt_payment_schedules_company_isolation"
  ON public.receipt_payment_schedules
  FOR ALL
  USING (
    company_id IN (
      SELECT company_id FROM public.profiles
      WHERE id = auth.uid()
    )
  );
