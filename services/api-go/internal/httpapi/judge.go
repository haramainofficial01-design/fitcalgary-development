package httpapi

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/jackc/pgx/v5"

	"fitcalgary.ca/index/api/internal/auth"
	"fitcalgary.ca/index/api/internal/domain"
)

func (s *Server) registerJudgeRoutes(router chi.Router) {
	router.Get("/judge/queue", s.handle(s.judgeQueue))
	router.Get("/judge/submissions/{id}/evidence", s.handle(s.judgeEvidence))
	router.Post("/judge/submissions/{id}/decision", s.handle(s.judgeDecision))
}

func (s *Server) judgeQueue(_ http.ResponseWriter, r *http.Request) (any, error) {
	if err := requireRole(r, auth.RoleJudge, auth.RoleAdmin); err != nil {
		return nil, err
	}
	current := identity(r)
	rows, err := queryMaps(r.Context(), s.db, `SELECT s.id,s.claimed_metric,s.evidence_type,s.submitted_at,s.assigned_judge_id,d.display_name AS discipline,p.display_name AS athlete,e.retain_until,e.evidence_deleted_at,(s.parent_submission_id IS NOT NULL) AS resubmission FROM submissions s JOIN disciplines d ON d.id=s.discipline_id JOIN profiles p ON p.id=s.profile_id LEFT JOIN submission_evidence e ON e.submission_id=s.id WHERE s.status='PENDING_REVIEW' AND (s.assigned_judge_id IS NULL OR s.assigned_judge_id=$1 OR $2::boolean) ORDER BY e.retain_until NULLS LAST,s.submitted_at LIMIT 100`, current.ProfileID, current.Principal.HasRole(auth.RoleAdmin))
	return map[string]any{"data": rows}, err
}

func (s *Server) judgeEvidence(_ http.ResponseWriter, r *http.Request) (any, error) {
	if err := requireRole(r, auth.RoleJudge, auth.RoleAdmin); err != nil {
		return nil, err
	}
	submissionID := chi.URLParam(r, "id")
	if !validUUID(submissionID) {
		return nil, validation("submission id must be a UUID")
	}
	var key string
	var deletedAt *time.Time
	var assignedJudge *string
	if err := s.db.QueryRow(r.Context(), `SELECT e.storage_key,e.evidence_deleted_at,s.assigned_judge_id FROM submission_evidence e JOIN submissions s ON s.id=e.submission_id WHERE s.id=$1`, submissionID).Scan(&key, &deletedAt, &assignedJudge); err != nil {
		if err == pgx.ErrNoRows {
			return nil, &APIError{Status: http.StatusNotFound, Code: "NOT_FOUND", Message: "Evidence not found"}
		}
		return nil, err
	}
	current := identity(r)
	if assignedJudge != nil && *assignedJudge != current.ProfileID && !current.Principal.HasRole(auth.RoleAdmin) {
		return nil, &APIError{Status: http.StatusForbidden, Code: "NOT_ASSIGNED", Message: "Submission is assigned to another judge"}
	}
	if deletedAt != nil {
		return nil, &APIError{Status: http.StatusGone, Code: "EVIDENCE_DELETED", Message: "Evidence was deleted under the retention policy"}
	}
	if _, err := s.db.Exec(r.Context(), `INSERT INTO audit_logs(actor_profile_id,action,entity_type,entity_id,request_id) VALUES($1,'EVIDENCE_VIEWED','SUBMISSION',$2,$3)`, current.ProfileID, submissionID, middleware.GetReqID(r.Context())); err != nil {
		return nil, err
	}
	url, err := s.store.PlaybackURL(r.Context(), key)
	if err != nil {
		return nil, err
	}
	return map[string]any{"url": url, "expiresIn": int(s.config.SignedURLTTL.Seconds())}, nil
}

type judgeDecisionInput struct {
	Decision           string          `json:"decision"`
	ChecklistResponses map[string]bool `json:"checklistResponses"`
	Comments           *string         `json:"comments"`
}

type lockedSubmission struct {
	ID               string
	ProfileID        string
	DisciplineID     string
	ClaimedMetric    float64
	Status           string
	AssignedJudgeID  *string
	RankingDirection string
	RulesVersion     int
	DisplayName      string
	SexCategory      *string
	HomeGymID        *string
}

type rankedResult struct {
	ID        string
	ProfileID string
	Rank      int
}

func (s *Server) judgeDecision(_ http.ResponseWriter, r *http.Request) (any, error) {
	if err := requireRole(r, auth.RoleJudge, auth.RoleAdmin); err != nil {
		return nil, err
	}
	submissionID := chi.URLParam(r, "id")
	if !validUUID(submissionID) {
		return nil, validation("submission id must be a UUID")
	}
	var body judgeDecisionInput
	if err := decodeJSON(r, &body); err != nil {
		return nil, err
	}
	if !oneOf(body.Decision, "APPROVED", "REJECTED", "RESUBMISSION_REQUESTED") {
		return nil, validation("decision is invalid")
	}
	if body.Decision != "APPROVED" && (body.Comments == nil || strings.TrimSpace(*body.Comments) == "") {
		return nil, &APIError{Status: http.StatusUnprocessableEntity, Code: "COMMENT_REQUIRED", Message: "A clear judge comment is required when a result is not approved"}
	}
	if body.Comments != nil && len(*body.Comments) > 2_000 {
		return nil, validation("comments must be at most 2000 characters")
	}

	tx, err := s.db.Begin(r.Context())
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(r.Context()) //nolint:errcheck
	var submission lockedSubmission
	err = tx.QueryRow(r.Context(), `SELECT s.id,s.profile_id,s.discipline_id,s.claimed_metric,s.status,s.assigned_judge_id,d.ranking_direction,d.rules_version,p.display_name,p.sex_category,p.home_gym_id FROM submissions s JOIN disciplines d ON d.id=s.discipline_id JOIN profiles p ON p.id=s.profile_id WHERE s.id=$1 FOR UPDATE OF s`, submissionID).Scan(&submission.ID, &submission.ProfileID, &submission.DisciplineID, &submission.ClaimedMetric, &submission.Status, &submission.AssignedJudgeID, &submission.RankingDirection, &submission.RulesVersion, &submission.DisplayName, &submission.SexCategory, &submission.HomeGymID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, &APIError{Status: http.StatusNotFound, Code: "NOT_FOUND", Message: "Submission not found"}
		}
		return nil, err
	}
	current := identity(r)
	if submission.Status != "PENDING_REVIEW" {
		return nil, &APIError{Status: http.StatusConflict, Code: "ALREADY_DECIDED", Message: "Submission is no longer pending review"}
	}
	if submission.ProfileID == current.ProfileID {
		return nil, &APIError{Status: http.StatusForbidden, Code: "SELF_REVIEW_FORBIDDEN", Message: "A judge cannot review their own result"}
	}
	if submission.AssignedJudgeID != nil && *submission.AssignedJudgeID != current.ProfileID && !current.Principal.HasRole(auth.RoleAdmin) {
		return nil, &APIError{Status: http.StatusForbidden, Code: "NOT_ASSIGNED", Message: "Submission is assigned to another judge"}
	}
	checklist, _ := json.Marshal(body.ChecklistResponses)
	if _, err := tx.Exec(r.Context(), `INSERT INTO submission_reviews(submission_id,judge_profile_id,decision,checklist_responses,comments) VALUES($1,$2,$3,$4,$5)`, submissionID, current.ProfileID, body.Decision, checklist, body.Comments); err != nil {
		return nil, err
	}
	finalStatus := "REJECTED"
	if body.Decision == "APPROVED" {
		finalStatus = "APPROVED"
	}
	if _, err := tx.Exec(r.Context(), `UPDATE submissions SET status=$2,assigned_judge_id=COALESCE(assigned_judge_id,$3),decided_at=now(),updated_at=now() WHERE id=$1`, submissionID, finalStatus, current.ProfileID); err != nil {
		return nil, err
	}
	if body.Decision == "APPROVED" {
		if err := s.approveResult(r, tx, current, submission); err != nil {
			return nil, err
		}
	}
	notification, _ := json.Marshal(map[string]any{"type": "SUBMISSION_" + finalStatus, "submissionId": submissionID, "profileId": submission.ProfileID})
	if _, err := tx.Exec(r.Context(), `INSERT INTO outbox_jobs(job_type,dedupe_key,payload) VALUES('NOTIFICATION',$1,$2) ON CONFLICT(dedupe_key) DO NOTHING`, strings.ToLower(finalStatus)+":"+submissionID, notification); err != nil {
		return nil, err
	}
	after, _ := json.Marshal(map[string]any{"decision": body.Decision, "checklistResponses": body.ChecklistResponses})
	if _, err := tx.Exec(r.Context(), `INSERT INTO audit_logs(actor_profile_id,action,entity_type,entity_id,after_data,request_id) VALUES($1,$2,'SUBMISSION',$3,$4,$5)`, current.ProfileID, "RESULT_"+finalStatus, submissionID, after, middleware.GetReqID(r.Context())); err != nil {
		return nil, err
	}
	if err := tx.Commit(r.Context()); err != nil {
		return nil, err
	}
	return map[string]string{"status": finalStatus}, nil
}

func (s *Server) approveResult(r *http.Request, tx pgx.Tx, current requestIdentity, submission lockedSubmission) error {
	var regionID, divisionID, divisionLabel string
	if err := tx.QueryRow(r.Context(), `SELECT r.id,v.id,v.display_label FROM cities c JOIN regions r ON r.id=c.region_id CROSS JOIN divisions v WHERE c.id=(SELECT city_id FROM profiles WHERE id=$1) AND v.slug='open-all'`, submission.ProfileID).Scan(&regionID, &divisionID, &divisionLabel); err != nil {
		if err == pgx.ErrNoRows {
			return &APIError{Status: http.StatusUnprocessableEntity, Code: "PROFILE_REGION_REQUIRED", Message: "Profile city is required before a result can be approved"}
		}
		return err
	}
	lockKey := regionID + ":" + submission.DisciplineID + ":" + divisionID + ":COMMUNITY"
	if _, err := tx.Exec(r.Context(), `SELECT pg_advisory_xact_lock(hashtext($1))`, lockKey); err != nil {
		return err
	}
	var boardID string
	err := tx.QueryRow(r.Context(), `SELECT id FROM leaderboards WHERE region_id=$1 AND discipline_id=$2 AND division_id=$3 AND event_id IS NULL AND board_type='COMMUNITY' LIMIT 1`, regionID, submission.DisciplineID, divisionID).Scan(&boardID)
	if err == pgx.ErrNoRows {
		err = tx.QueryRow(r.Context(), `INSERT INTO leaderboards(region_id,discipline_id,division_id,board_type) VALUES($1,$2,$3,'COMMUNITY') RETURNING id`, regionID, submission.DisciplineID, divisionID).Scan(&boardID)
	}
	if err != nil {
		return err
	}
	before, err := boardRanks(r.Context(), tx, boardID, submission.RankingDirection)
	if err != nil {
		return err
	}
	displayMetric := domain.FormatTime(submission.ClaimedMetric)
	if submission.RankingDirection != "LOWER_IS_BETTER" {
		displayMetric = fmt.Sprintf("%g reps", submission.ClaimedMetric)
	}
	divisionSnapshot, _ := json.Marshal(map[string]any{"id": divisionID, "label": divisionLabel})
	profileSnapshot, _ := json.Marshal(map[string]any{"displayName": submission.DisplayName, "sexCategory": submission.SexCategory, "homeGymId": submission.HomeGymID})
	var resultID string
	if err := tx.QueryRow(r.Context(), `INSERT INTO results(profile_id,submission_id,leaderboard_id,normalized_metric,display_metric,verification_type,verified_at,verified_by,division_snapshot,profile_snapshot,discipline_rules_version) VALUES($1,$2,$3,$4,$5,'COMMUNITY_REVIEWED',now(),$6,$7,$8,$9) RETURNING id`, submission.ProfileID, submission.ID, boardID, submission.ClaimedMetric, displayMetric, current.ProfileID, divisionSnapshot, profileSnapshot, submission.RulesVersion).Scan(&resultID); err != nil {
		return err
	}
	after, err := boardRanks(r.Context(), tx, boardID, submission.RankingDirection)
	if err != nil {
		return err
	}
	previous := map[string]int{}
	for _, item := range before {
		previous[item.ID] = item.Rank
	}
	for _, item := range after {
		var prior any
		if oldRank, exists := previous[item.ID]; exists {
			prior = oldRank
		}
		if _, err := tx.Exec(r.Context(), `INSERT INTO ranking_history(leaderboard_id,result_id,previous_rank,current_rank) VALUES($1,$2,$3,$4)`, boardID, item.ID, prior, item.Rank); err != nil {
			return err
		}
		oldRank, existed := previous[item.ID]
		if existed && item.Rank > oldRank {
			payload, _ := json.Marshal(map[string]any{"type": "LEADERBOARD_PASSED", "leaderboardId": boardID, "newRank": item.Rank, "profileId": item.ProfileID, "passingAthleteDisplayName": submission.DisplayName})
			if _, err := tx.Exec(r.Context(), `INSERT INTO outbox_jobs(job_type,dedupe_key,payload) VALUES('NOTIFICATION',$1,$2) ON CONFLICT(dedupe_key) DO NOTHING`, "passed:"+resultID+":"+item.ID, payload); err != nil {
				return err
			}
		}
	}
	return nil
}

func boardRanks(ctx context.Context, tx pgx.Tx, boardID, direction string) ([]rankedResult, error) {
	order := "DESC"
	if direction == "LOWER_IS_BETTER" {
		order = "ASC"
	}
	rows, err := tx.Query(ctx, fmt.Sprintf(`SELECT rs.id,rs.profile_id,ROW_NUMBER() OVER(ORDER BY rs.normalized_metric %s,rs.verified_at,rs.id)::int AS rank FROM results rs WHERE rs.leaderboard_id=$1 AND rs.invalidated_at IS NULL ORDER BY rank`, order), boardID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	ranked := make([]rankedResult, 0)
	for rows.Next() {
		var item rankedResult
		if err := rows.Scan(&item.ID, &item.ProfileID, &item.Rank); err != nil {
			return nil, err
		}
		ranked = append(ranked, item)
	}
	return ranked, rows.Err()
}
