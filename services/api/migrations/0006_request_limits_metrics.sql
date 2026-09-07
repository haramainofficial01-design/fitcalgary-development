CREATE TABLE api_request_limits (
 profile_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
 bucket text NOT NULL,
 window_start timestamptz NOT NULL,
 requests integer NOT NULL CHECK(requests>0),
 PRIMARY KEY(profile_id,bucket,window_start)
);
-- statement-breakpoint
CREATE INDEX api_request_limits_expiry ON api_request_limits(window_start);
-- statement-breakpoint
CREATE TABLE product_metrics (
 hour timestamptz NOT NULL,
 event_name text NOT NULL,
 occurrences bigint NOT NULL DEFAULT 1 CHECK(occurrences>0),
 PRIMARY KEY(hour,event_name)
);
