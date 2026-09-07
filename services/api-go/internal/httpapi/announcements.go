package httpapi

import (
	"github.com/go-chi/chi/v5/middleware"
	"net/http"
	"strings"
)

// Explicit bounded recipients prevent accidental broadcasts. Request IDs make
// a retry safe; publication and delivery preferences remain server-authoritative.
func (s *Server) adminAnnouncement(_ http.ResponseWriter, r *http.Request) (any, error) {
	if err := adminOnly(r); err != nil {
		return nil, err
	}
	var body struct {
		RequestID  string   `json:"requestId"`
		ProfileIDs []string `json:"profileIds"`
		Title      string   `json:"title"`
		Body       string   `json:"body"`
		EventID    *string  `json:"eventId"`
	}
	if err := decodeJSON(r, &body); err != nil {
		return nil, err
	}
	body.Title = strings.TrimSpace(body.Title)
	body.Body = strings.TrimSpace(body.Body)
	if !validUUID(body.RequestID) || len(body.ProfileIDs) < 1 || len(body.ProfileIDs) > 100 || len(body.Title) < 2 || len(body.Title) > 100 || len(body.Body) < 2 || len(body.Body) > 1000 {
		return nil, validation("Provide a title, message and between 1 and 100 recipients")
	}
	unique := map[string]bool{}
	for _, id := range body.ProfileIDs {
		if !validUUID(id) || unique[id] {
			return nil, validation("Recipients must be distinct valid accounts")
		}
		unique[id] = true
	}
	if body.EventID != nil && !validUUID(*body.EventID) {
		return nil, validation("Invalid event")
	}
	tx, err := s.db.Begin(r.Context())
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(r.Context())
	if body.EventID != nil {
		var published bool
		if err := tx.QueryRow(r.Context(), `SELECT EXISTS(SELECT 1 FROM events WHERE id=$1 AND publish_status='PUBLISHED')`, *body.EventID).Scan(&published); err != nil {
			return nil, err
		}
		if !published {
			return nil, validation("Choose a published event")
		}
	}
	var count int
	if err := tx.QueryRow(r.Context(), `SELECT count(*) FROM profiles WHERE id=ANY($1::uuid[]) AND account_status='ACTIVE'`, body.ProfileIDs).Scan(&count); err != nil {
		return nil, err
	}
	if count != len(body.ProfileIDs) {
		return nil, validation("One or more recipients is unavailable")
	}
	kind := "ADMIN_ANNOUNCEMENT"
	if body.EventID != nil {
		kind = "EVENT_UPDATED"
	}
	created := 0
	for _, id := range body.ProfileIDs {
		payload := map[string]any{"type": kind, "profileId": id, "title": body.Title, "body": body.Body, "eventId": body.EventID}
		key := "announcement:" + identity(r).ProfileID + ":" + body.RequestID + ":" + id
		tag, err := tx.Exec(r.Context(), `INSERT INTO outbox_jobs(job_type,dedupe_key,payload) VALUES('NOTIFICATION',$1,$2) ON CONFLICT(dedupe_key) DO NOTHING`, key, payload)
		if err != nil {
			return nil, err
		}
		created += int(tag.RowsAffected())
	}
	if created > 0 {
		if _, err := tx.Exec(r.Context(), `INSERT INTO audit_logs(actor_profile_id,action,entity_type,entity_id,metadata,request_id) VALUES($1,'ANNOUNCEMENT_QUEUED','NOTIFICATION',$2,$3,$4)`, identity(r).ProfileID, body.RequestID, map[string]any{"recipientCount": created, "type": kind}, middleware.GetReqID(r.Context())); err != nil {
			return nil, err
		}
	}
	if err := tx.Commit(r.Context()); err != nil {
		return nil, err
	}
	return map[string]any{"queued": created, "preferencesRespected": true}, nil
}
