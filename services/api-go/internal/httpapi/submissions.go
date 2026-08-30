package httpapi

import (
	"encoding/json"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"

	"fitcalgary.ca/index/api/internal/storage"
)

func (s *Server) registerSubmissionRoutes(router chi.Router) {
	router.Get("/submissions", s.handle(s.listSubmissions))
	router.Post("/submissions", s.handle(s.createSubmission))
	router.Post("/submissions/{id}/uploads", s.handle(s.beginUpload))
	router.Post("/uploads/{id}/parts/{partNumber}", s.handle(s.signUploadPart))
	router.Post("/uploads/{id}/finalize", s.handle(s.finalizeUpload))
}

func (s *Server) listSubmissions(_ http.ResponseWriter, r *http.Request) (any, error) {
	rows, err := queryMaps(r.Context(), s.db, `SELECT s.id,s.claimed_metric,s.evidence_type,s.status,s.submitted_at,s.decided_at,s.created_at,d.display_name AS discipline,(SELECT json_agg(json_build_object('decision',r.decision,'comments',r.comments,'checklist',r.checklist_responses,'createdAt',r.created_at) ORDER BY r.created_at) FROM submission_reviews r WHERE r.submission_id=s.id) AS reviews FROM submissions s JOIN disciplines d ON d.id=s.discipline_id WHERE s.profile_id=$1 ORDER BY s.created_at DESC`, identity(r).ProfileID)
	return map[string]any{"data": rows}, err
}

type createSubmissionInput struct {
	DisciplineID        string          `json:"disciplineId"`
	ClaimedMetric       float64         `json:"claimedMetric"`
	EvidenceType        string          `json:"evidenceType"`
	ChecklistAcceptance map[string]bool `json:"checklistAcceptance"`
	ParentSubmissionID  *string         `json:"parentSubmissionId"`
}

func (s *Server) createSubmission(w http.ResponseWriter, r *http.Request) (any, error) {
	var body createSubmissionInput
	if err := decodeJSON(r, &body); err != nil {
		return nil, err
	}
	if !validUUID(body.DisciplineID) || body.ClaimedMetric <= 0 || !oneOf(body.EvidenceType, "VIDEO", "ACTIVITY_FILE", "EXTERNAL_ACTIVITY_REFERENCE") || (body.ParentSubmissionID != nil && !validUUID(*body.ParentSubmissionID)) {
		return nil, validation("submission fields are invalid")
	}
	owner := identity(r).ProfileID
	var banned bool
	if err := s.db.QueryRow(r.Context(), `SELECT EXISTS(SELECT 1 FROM bans WHERE profile_id=$1 AND lifted_at IS NULL AND (ends_at IS NULL OR ends_at>now()))`, owner).Scan(&banned); err != nil {
		return nil, err
	}
	if banned {
		return nil, &APIError{Status: http.StatusForbidden, Code: "ACCOUNT_RESTRICTED", Message: "This account cannot submit results"}
	}
	var eligible bool
	if err := s.db.QueryRow(r.Context(), `SELECT EXISTS(SELECT 1 FROM disciplines WHERE id=$1 AND active=true AND community_eligible=true)`, body.DisciplineID).Scan(&eligible); err != nil {
		return nil, err
	}
	if !eligible {
		return nil, &APIError{Status: http.StatusUnprocessableEntity, Code: "DISCIPLINE_INELIGIBLE", Message: "This discipline is unavailable for community submissions"}
	}
	checklist, _ := json.Marshal(body.ChecklistAcceptance)
	rows, err := queryMaps(r.Context(), s.db, `INSERT INTO submissions(profile_id,discipline_id,parent_submission_id,claimed_metric,evidence_type,checklist_acceptance,status) VALUES($1,$2,$3,$4,$5,$6,'DRAFT') RETURNING id,status,created_at`, owner, body.DisciplineID, body.ParentSubmissionID, body.ClaimedMetric, body.EvidenceType, checklist)
	if err != nil {
		return nil, err
	}
	created(w, rows[0])
	return nil, nil
}

type beginUploadInput struct {
	ContentType string `json:"contentType"`
	SizeBytes   int64  `json:"sizeBytes"`
}

func (s *Server) beginUpload(w http.ResponseWriter, r *http.Request) (any, error) {
	submissionID := chi.URLParam(r, "id")
	if !validUUID(submissionID) {
		return nil, validation("submission id must be a UUID")
	}
	var body beginUploadInput
	if err := decodeJSON(r, &body); err != nil {
		return nil, err
	}
	var status string
	if err := s.db.QueryRow(r.Context(), `SELECT status FROM submissions WHERE id=$1 AND profile_id=$2`, submissionID, identity(r).ProfileID).Scan(&status); err != nil {
		if err == pgx.ErrNoRows {
			return nil, &APIError{Status: http.StatusNotFound, Code: "NOT_FOUND", Message: "Submission not found"}
		}
		return nil, err
	}
	if status != "DRAFT" && status != "UPLOADING" {
		return nil, &APIError{Status: http.StatusConflict, Code: "INVALID_STATE", Message: "Submission cannot accept a new upload"}
	}
	key, uploadID, err := s.store.Begin(r.Context(), identity(r).Principal.Subject, submissionID, body.ContentType, body.SizeBytes)
	if err != nil {
		return nil, validation(err.Error())
	}
	var id string
	var expiresAt time.Time
	if err := s.db.QueryRow(r.Context(), `INSERT INTO upload_sessions(submission_id,storage_key,provider_upload_id,expected_size_bytes,content_type,status,expires_at) VALUES($1,$2,$3,$4,$5,'INITIALIZED',now()+interval '24 hours') RETURNING id,expires_at`, submissionID, key, uploadID, body.SizeBytes, body.ContentType).Scan(&id, &expiresAt); err != nil {
		return nil, err
	}
	if _, err := s.db.Exec(r.Context(), `UPDATE submissions SET status='UPLOADING',updated_at=now() WHERE id=$1`, submissionID); err != nil {
		return nil, err
	}
	created(w, map[string]any{"id": id, "partSizeBytes": 16 * 1024 * 1024, "expiresAt": expiresAt})
	return nil, nil
}

func (s *Server) signUploadPart(_ http.ResponseWriter, r *http.Request) (any, error) {
	uploadID := chi.URLParam(r, "id")
	part, err := positiveInt(chi.URLParam(r, "partNumber"), 0, 1, 10_000)
	if !validUUID(uploadID) || err != nil {
		return nil, validation("upload id or part number is invalid")
	}
	var key, providerID string
	var expiresAt time.Time
	if err := s.db.QueryRow(r.Context(), `SELECT u.storage_key,u.provider_upload_id,u.expires_at FROM upload_sessions u JOIN submissions s ON s.id=u.submission_id WHERE u.id=$1 AND s.profile_id=$2 AND u.status IN ('INITIALIZED','UPLOADING')`, uploadID, identity(r).ProfileID).Scan(&key, &providerID, &expiresAt); err != nil {
		if err == pgx.ErrNoRows {
			return nil, &APIError{Status: http.StatusNotFound, Code: "NOT_FOUND", Message: "Upload session not found"}
		}
		return nil, err
	}
	if time.Now().After(expiresAt) {
		return nil, &APIError{Status: http.StatusGone, Code: "UPLOAD_EXPIRED", Message: "Upload session expired"}
	}
	if _, err := s.db.Exec(r.Context(), `UPDATE upload_sessions SET status='UPLOADING',updated_at=now() WHERE id=$1`, uploadID); err != nil {
		return nil, err
	}
	url, err := s.store.SignPart(r.Context(), key, providerID, int32(part))
	if err != nil {
		return nil, err
	}
	return map[string]any{"url": url, "expiresIn": int(s.config.SignedURLTTL.Seconds())}, nil
}

type finalizeUploadInput struct {
	Parts    []storage.CompletedPart `json:"parts"`
	Checksum *string                 `json:"checksum"`
}

type uploadRecord struct {
	SubmissionID    string
	StorageKey      string
	ProviderUpload  string
	ExpectedSize    int64
	ContentType     string
	Status          string
	SubmissionState string
}

func (s *Server) finalizeUpload(_ http.ResponseWriter, r *http.Request) (any, error) {
	uploadID := chi.URLParam(r, "id")
	if !validUUID(uploadID) {
		return nil, validation("upload id must be a UUID")
	}
	var body finalizeUploadInput
	if err := decodeJSON(r, &body); err != nil {
		return nil, err
	}
	if len(body.Parts) == 0 || len(body.Parts) > 10_000 {
		return nil, validation("parts must contain between 1 and 10000 items")
	}
	for _, part := range body.Parts {
		if strings.TrimSpace(part.ETag) == "" || part.PartNumber < 1 || part.PartNumber > 10_000 {
			return nil, validation("multipart part is invalid")
		}
	}
	owner := identity(r).ProfileID
	var upload uploadRecord
	err := s.db.QueryRow(r.Context(), `SELECT u.submission_id,u.storage_key,u.provider_upload_id,u.expected_size_bytes,u.content_type,u.status,s.status FROM upload_sessions u JOIN submissions s ON s.id=u.submission_id WHERE u.id=$1 AND s.profile_id=$2`, uploadID, owner).Scan(&upload.SubmissionID, &upload.StorageKey, &upload.ProviderUpload, &upload.ExpectedSize, &upload.ContentType, &upload.Status, &upload.SubmissionState)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, &APIError{Status: http.StatusNotFound, Code: "NOT_FOUND", Message: "Upload session not found"}
		}
		return nil, err
	}
	if upload.Status == "COMPLETED" {
		var evidenceID string
		var retainUntil time.Time
		if err := s.db.QueryRow(r.Context(), `SELECT id,retain_until FROM submission_evidence WHERE upload_session_id=$1`, uploadID).Scan(&evidenceID, &retainUntil); err != nil {
			return nil, err
		}
		return map[string]any{"evidenceId": evidenceID, "retainUntil": retainUntil, "status": "PENDING_REVIEW"}, nil
	}
	if upload.Status != "INITIALIZED" && upload.Status != "UPLOADING" {
		return nil, &APIError{Status: http.StatusConflict, Code: "INVALID_STATE", Message: "Upload cannot be finalized"}
	}
	size, err := s.store.Complete(r.Context(), upload.StorageKey, upload.ProviderUpload, body.Parts)
	if err != nil {
		return nil, err
	}
	if size != upload.ExpectedSize {
		return nil, &APIError{Status: http.StatusUnprocessableEntity, Code: "SIZE_MISMATCH", Message: "Uploaded evidence size did not match the declared size"}
	}
	tx, err := s.db.Begin(r.Context())
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(r.Context()) //nolint:errcheck
	var evidenceID string
	var retainUntil time.Time
	if err := tx.QueryRow(r.Context(), `INSERT INTO submission_evidence(submission_id,upload_session_id,storage_key,content_type,size_bytes,checksum,retain_until) VALUES($1,$2,$3,$4,$5,$6,now()+($7||' days')::interval) RETURNING id,retain_until`, upload.SubmissionID, uploadID, upload.StorageKey, upload.ContentType, upload.ExpectedSize, body.Checksum, s.config.EvidenceRetentionDays).Scan(&evidenceID, &retainUntil); err != nil {
		return nil, err
	}
	if _, err := tx.Exec(r.Context(), `UPDATE upload_sessions SET status='COMPLETED',completed_at=now(),updated_at=now() WHERE id=$1`, uploadID); err != nil {
		return nil, err
	}
	if _, err := tx.Exec(r.Context(), `UPDATE submissions SET status='PENDING_REVIEW',submitted_at=COALESCE(submitted_at,now()),updated_at=now() WHERE id=$1`, upload.SubmissionID); err != nil {
		return nil, err
	}
	payload, _ := json.Marshal(map[string]any{"type": "SUBMISSION_RECEIVED", "submissionId": upload.SubmissionID, "profileId": owner})
	if _, err := tx.Exec(r.Context(), `INSERT INTO outbox_jobs(job_type,dedupe_key,payload) VALUES('NOTIFICATION',$1,$2) ON CONFLICT(dedupe_key) DO NOTHING`, "submission-received:"+upload.SubmissionID, payload); err != nil {
		return nil, err
	}
	if err := tx.Commit(r.Context()); err != nil {
		return nil, err
	}
	return map[string]any{"evidenceId": evidenceID, "retainUntil": retainUntil, "status": "PENDING_REVIEW"}, nil
}

func oneOf(value string, allowed ...string) bool {
	for _, candidate := range allowed {
		if value == candidate {
			return true
		}
	}
	return false
}
