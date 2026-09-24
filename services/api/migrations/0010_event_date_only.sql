-- A source may confirm an event day without confirming a start time.
-- Keep that fact separate from a timed event to avoid inventing a clock time.
ALTER TABLE events ADD COLUMN start_date date;
-- statement-breakpoint
CREATE INDEX idx_events_start_date ON events(start_date) WHERE start_date IS NOT NULL;
-- statement-breakpoint
-- The source payload is retained by the approved-data importer. Backfill only
-- exact single-day strings independently corroborated on organizer pages.
UPDATE events AS event
SET start_date = CASE source.source_record_id
  WHEN 'YYC-172' THEN DATE '2026-09-26'
  WHEN 'YYC-506' THEN DATE '2026-10-24'
  WHEN 'YYC-508' THEN DATE '2026-12-12'
END
FROM client_source_records AS source
WHERE source.dataset = 'COMPETITIONS'
  AND source.entity_id = event.id
  AND event.start_at IS NULL
  AND event.start_date IS NULL
  AND (source.source_record_id, source.payload->>'next_dates') IN (
    ('YYC-172', 'Sep 26, 2026'),
    ('YYC-506', 'Oct 24, 2026'),
    ('YYC-508', 'Dec 12, 2026')
  );
