CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'inquiry_source') THEN
    CREATE TYPE inquiry_source AS ENUM ('webhook', 'email', 'telegram', 'crm', 'manual', 'other');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'inquiry_classification') THEN
    CREATE TYPE inquiry_classification AS ENUM ('rfq', 'question', 'spam', 'manual_review', 'other');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'inquiry_status') THEN
    CREATE TYPE inquiry_status AS ENUM ('new', 'accepted', 'needs_clarification', 'manual_review', 'rejected');
  END IF;
END;
$$;

CREATE TABLE IF NOT EXISTS inquiries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  received_at TIMESTAMPTZ,
  source inquiry_source NOT NULL DEFAULT 'other',
  external_id TEXT,
  raw_subject TEXT,
  raw_body TEXT NOT NULL,
  raw_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  classification inquiry_classification NOT NULL DEFAULT 'manual_review',
  confidence NUMERIC(4, 3) CHECK (confidence IS NULL OR (confidence >= 0 AND confidence <= 1)),
  status inquiry_status NOT NULL DEFAULT 'manual_review',
  name TEXT,
  company TEXT,
  email TEXT,
  phone TEXT,
  product_or_service TEXT,
  quantity TEXT,
  deadline TEXT,
  summary TEXT,
  validation_flags JSONB NOT NULL DEFAULT '[]'::jsonb,
  manager_comment TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_inquiries_created_at ON inquiries (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_inquiries_status ON inquiries (status);
CREATE INDEX IF NOT EXISTS idx_inquiries_classification ON inquiries (classification);
CREATE INDEX IF NOT EXISTS idx_inquiries_email ON inquiries (email);
CREATE INDEX IF NOT EXISTS idx_inquiries_phone ON inquiries (phone);

CREATE TABLE IF NOT EXISTS inquiry_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  inquiry_id UUID NOT NULL REFERENCES inquiries(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  event_type TEXT NOT NULL,
  old_status inquiry_status,
  new_status inquiry_status,
  message TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_inquiry_events_inquiry_id ON inquiry_events (inquiry_id);
CREATE INDEX IF NOT EXISTS idx_inquiry_events_created_at ON inquiry_events (created_at DESC);

CREATE TABLE IF NOT EXISTS processing_errors (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  source inquiry_source NOT NULL DEFAULT 'other',
  workflow_name TEXT,
  workflow_node TEXT,
  execution_id TEXT,
  error_message TEXT NOT NULL,
  retry_count INTEGER NOT NULL DEFAULT 0 CHECK (retry_count >= 0),
  raw_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  resolved_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_processing_errors_created_at ON processing_errors (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_processing_errors_resolved_at ON processing_errors (resolved_at);
