-- Preserve Client-supplied source fields without exposing research metadata in
-- public directory responses. Entity rows continue to use the existing schema.
CREATE TABLE client_source_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  dataset text NOT NULL CHECK (dataset IN ('GYMS','CLUBS','COMPETITIONS')),
  source_record_id text NOT NULL,
  entity_type text NOT NULL CHECK (entity_type IN ('GYM','CLUB','EVENT')),
  entity_id uuid NOT NULL,
  payload jsonb NOT NULL,
  confidence text,
  last_checked date,
  imported_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(dataset,source_record_id)
);
-- statement-breakpoint
CREATE INDEX idx_client_source_entity ON client_source_records(entity_type,entity_id);
-- statement-breakpoint
-- The approved competition dataset legitimately contains unscheduled records.
-- NULL remains unknown; the application must not manufacture a date.
ALTER TABLE events ALTER COLUMN start_at DROP NOT NULL;
-- statement-breakpoint
ALTER TABLE events DROP CONSTRAINT events_registration_status_check;
-- statement-breakpoint
ALTER TABLE events ADD CONSTRAINT events_registration_status_check CHECK (registration_status IN ('OPEN','CLOSED','NOT_APPLICABLE','UNKNOWN'));
