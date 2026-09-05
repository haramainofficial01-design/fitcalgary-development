-- A withdrawn correction must not permanently block correcting its parent.
-- Historical cancelled attempts remain available in the athlete's history.
DROP INDEX idx_submission_single_correction;
CREATE UNIQUE INDEX idx_submission_single_correction ON submissions(parent_submission_id)
WHERE parent_submission_id IS NOT NULL AND status <> 'CANCELLED';
