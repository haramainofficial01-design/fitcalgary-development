CREATE TABLE notification_deliveries (
 notification_id uuid NOT NULL REFERENCES notifications(id) ON DELETE CASCADE,
 device_id uuid NOT NULL REFERENCES notification_devices(id) ON DELETE CASCADE,
 status text NOT NULL DEFAULT 'QUEUED' CHECK(status IN ('QUEUED','DELIVERED','FAILED','SUPPRESSED')),
 attempt_count integer NOT NULL DEFAULT 0,
 available_at timestamptz NOT NULL DEFAULT now(),
 provider_message_id text,
 last_error_code text,
 delivered_at timestamptz,
 PRIMARY KEY(notification_id,device_id)
);
-- statement-breakpoint
CREATE INDEX notification_deliveries_pending ON notification_deliveries(available_at) WHERE status='QUEUED';
