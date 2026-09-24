-- The six public registration links below were confirmed to return HTTP 404.
-- Preserve the supplied source payload for audit; hide only the broken action.
UPDATE events AS event
SET external_registration_url = NULL,
    updated_at = now()
FROM client_source_records AS source
WHERE source.dataset = 'COMPETITIONS'
  AND source.entity_id = event.id
  AND (
    (source.source_record_id = 'YYC-159' AND source.payload->>'website' = 'https://k25sports.com/flag')
    OR (source.source_record_id IN ('YYC-163','YYC-165','YYC-167') AND source.payload->>'website' = 'https://www.stampeders.com/stampeders-foundation-amateur-football-registration/')
    OR (source.source_record_id = 'YYC-419' AND source.payload->>'website' = 'https://www.calgarysportsclub.com/leagues/handball/rules')
    OR (source.source_record_id = 'YYC-458' AND source.payload->>'website' = 'https://www.calgarysportsclub.com/tournaments')
  )
  AND event.external_registration_url = source.payload->>'website';
