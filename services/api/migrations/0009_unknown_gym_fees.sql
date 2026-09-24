-- Source estimates cannot be described as all-in when a mandatory fee is
-- unknown. Preserve the advertised recurring rate and source payload.
UPDATE gym_pricing AS price
SET pricing_complete = false,
    ongoing_monthly_cents = NULL,
    first_year_monthly_cents = NULL,
    updated_at = now()
FROM client_source_records AS source
WHERE source.dataset = 'GYMS'
  AND source.entity_type = 'GYM'
  AND source.entity_id = price.gym_id
  AND (
    source.payload #> '{pricing,annual_fee}' IS NULL OR
    source.payload #> '{pricing,annual_fee}' = 'null'::jsonb OR
    source.payload #> '{pricing,enrollment_fee}' IS NULL OR
    source.payload #> '{pricing,enrollment_fee}' = 'null'::jsonb
  );
