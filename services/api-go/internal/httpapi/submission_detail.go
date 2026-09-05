package httpapi

import (
	"encoding/json"
	"fitcalgary.ca/index/api/internal/auth"
	"github.com/go-chi/chi/v5"
	"net/http"
)

func checkRequiredChecklist(raw []byte, answers map[string]bool) error {
	var rules []struct {
		Key   string `json:"key"`
		Label string `json:"label"`
	}
	if err := json.Unmarshal(raw, &rules); err != nil {
		return err
	}
	for _, rule := range rules {
		if !answers[rule.Key] {
			return validation("Confirm each item in the discipline's published verification checklist")
		}
	}
	return nil
}

func (s *Server) getSubmission(_ http.ResponseWriter, r *http.Request) (any, error) {
	id := chi.URLParam(r, "id")
	if !validUUID(id) {
		return nil, validation("Invalid submission ID")
	}
	current := identity(r)
	rows, err := queryMaps(r.Context(), s.db, `SELECT s.id,s.profile_id,s.discipline_id,s.parent_submission_id,s.claimed_metric,s.evidence_type,s.status,s.division_id,s.board_type,s.checklist_acceptance,s.submitted_at,s.decided_at,d.display_name AS discipline,d.metric_type,d.unit,d.verification_checklist,p.display_name AS athlete,
 (SELECT json_agg(json_build_object('decision',rv.decision,'comments',rv.comments,'checklist',rv.checklist_responses,'createdAt',rv.created_at) ORDER BY rv.created_at) FROM submission_reviews rv WHERE rv.submission_id=s.id) AS reviews,
 (SELECT c.id FROM submissions c WHERE c.parent_submission_id=s.id AND c.status<>'CANCELLED' LIMIT 1) AS correction_id,
 (SELECT json_build_object('id',rs.id,'leaderboardId',rs.leaderboard_id,'displayMetric',rs.display_metric,'verificationType',rs.verification_type) FROM results rs WHERE rs.submission_id=s.id AND rs.invalidated_at IS NULL LIMIT 1) AS result
 FROM submissions s JOIN disciplines d ON d.id=s.discipline_id JOIN profiles p ON p.id=s.profile_id WHERE s.id=$1 AND (s.profile_id=$2 OR $3::boolean OR ($4::boolean AND (s.assigned_judge_id IS NULL OR s.assigned_judge_id=$2)))`, id, current.ProfileID, current.Principal.HasRole(auth.RoleAdmin), current.Principal.HasRole(auth.RoleJudge))
	if err != nil {
		return nil, err
	}
	if len(rows) == 0 {
		return nil, &APIError{Status: 404, Code: "NOT_FOUND", Message: "Submission not found"}
	}
	return rows[0], nil
}

func (s *Server) cancelSubmission(_ http.ResponseWriter, r *http.Request) (any, error) {
	id := chi.URLParam(r, "id")
	if !validUUID(id) {
		return nil, validation("Invalid submission ID")
	}
	tag, err := s.db.Exec(r.Context(), `UPDATE submissions SET status='CANCELLED',updated_at=now() WHERE id=$1 AND profile_id=$2 AND status IN ('DRAFT','UPLOADING','PENDING_REVIEW')`, id, identity(r).ProfileID)
	if err != nil {
		return nil, err
	}
	if tag.RowsAffected() != 1 {
		return nil, &APIError{Status: 409, Code: "INVALID_STATE", Message: "Submission cannot be withdrawn"}
	}
	return map[string]string{"status": "CANCELLED"}, nil
}
