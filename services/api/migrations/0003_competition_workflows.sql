ALTER TABLE submissions DROP CONSTRAINT submissions_status_check;
ALTER TABLE submissions ADD CONSTRAINT submissions_status_check CHECK (status IN ('DRAFT','UPLOADING','PENDING_REVIEW','CHANGES_REQUESTED','APPROVED','REJECTED','CANCELLED'));
ALTER TABLE submissions ADD COLUMN division_id uuid REFERENCES divisions(id);
ALTER TABLE submissions ADD COLUMN board_type text NOT NULL DEFAULT 'OFFICIAL' CHECK (board_type IN ('OFFICIAL','COMMUNITY'));
ALTER TABLE disciplines ADD COLUMN minimum_metric numeric(20,6) NOT NULL DEFAULT 0;
ALTER TABLE disciplines ADD COLUMN maximum_metric numeric(20,6);
ALTER TABLE disciplines ADD CONSTRAINT discipline_metric_bounds CHECK (minimum_metric>=0 AND (maximum_metric IS NULL OR maximum_metric>minimum_metric));
ALTER TABLE results DROP CONSTRAINT results_verification_type_check;
ALTER TABLE results ADD CONSTRAINT results_verification_type_check CHECK (verification_type IN ('IN_PERSON','COMMUNITY_REVIEWED','VIDEO_REVIEWED','UNVERIFIED'));
ALTER TABLE profiles ADD COLUMN notification_preferences jsonb NOT NULL DEFAULT '{"eventUpdates":true,"announcements":true}'::jsonb;
CREATE UNIQUE INDEX idx_submission_single_correction ON submissions(parent_submission_id) WHERE parent_submission_id IS NOT NULL;
CREATE INDEX idx_results_owner_recent ON results(profile_id,verified_at DESC) WHERE invalidated_at IS NULL;
-- statement-breakpoint
CREATE VIEW ranked_results AS
WITH best AS (
 SELECT rs.*,l.board_type,l.visible,d.display_name AS discipline_name,d.slug AS discipline_slug,
 d.metric_type,d.unit,d.ranking_direction,d.id AS discipline_id,v.display_label AS division_label,
 p.display_name,CASE WHEN COALESCE((p.privacy->>'showGym')::boolean,true) THEN g.name END AS gym_name,
 COALESCE((p.privacy->>'publicProfile')::boolean,true) AS public_profile,
 ROW_NUMBER() OVER(PARTITION BY l.id,rs.profile_id ORDER BY
 CASE WHEN d.ranking_direction='LOWER_IS_BETTER' THEN rs.normalized_metric END ASC,
 CASE WHEN d.ranking_direction='HIGHER_IS_BETTER' THEN rs.normalized_metric END DESC,
 rs.verified_at,rs.id) AS personal_ordinal
 FROM results rs JOIN leaderboards l ON l.id=rs.leaderboard_id
 JOIN disciplines d ON d.id=l.discipline_id JOIN divisions v ON v.id=l.division_id
 JOIN profiles p ON p.id=rs.profile_id LEFT JOIN gyms g ON g.id=p.home_gym_id
 WHERE rs.invalidated_at IS NULL AND p.account_status='ACTIVE' AND d.active AND v.active
 AND ((l.board_type='OFFICIAL' AND rs.verification_type IN ('IN_PERSON','VIDEO_REVIEWED'))
 OR (l.board_type='COMMUNITY' AND rs.verification_type IN ('COMMUNITY_REVIEWED','UNVERIFIED')))
)
SELECT best.*,ROW_NUMBER() OVER(PARTITION BY leaderboard_id ORDER BY
 CASE WHEN ranking_direction='LOWER_IS_BETTER' THEN normalized_metric END ASC,
 CASE WHEN ranking_direction='HIGHER_IS_BETTER' THEN normalized_metric END DESC,
 verified_at,id)::int AS rank FROM best WHERE personal_ordinal=1;
