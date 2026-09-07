package httpapi

import (
	"net/http"
	"strings"

	"fitcalgary.ca/index/api/internal/auth"
	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/jackc/pgx/v5"
)

type moderationInput struct {
	Action string `json:"action"`
	Reason string `json:"reason"`
}

// Moderators can record concerns; only administrators change account access.
// Effective access is checked from profiles on every authenticated request.
func (s *Server) moderateAccount(_ http.ResponseWriter, r *http.Request) (any, error) {
	if err := requireRole(r, auth.RoleModerator, auth.RoleAdmin); err != nil {
		return nil, err
	}
	var body moderationInput
	if err := decodeJSON(r, &body); err != nil {
		return nil, err
	}
	target := chi.URLParam(r, "profileId")
	body.Reason = strings.TrimSpace(body.Reason)
	if !validUUID(target) || !oneOf(body.Action, "NOTE", "SUSPEND", "BAN", "RESTORE") || len(body.Reason) < 5 || len(body.Reason) > 2000 {
		return nil, validation("Choose a valid action and provide a reason between 5 and 2000 characters")
	}
	current := identity(r)
	if body.Action != "NOTE" {
		if err := adminOnly(r); err != nil {
			return nil, err
		}
		if target == current.ProfileID {
			return nil, &APIError{Status: 409, Code: "SELF_MODERATION", Message: "You cannot change your own account access"}
		}
	}
	tx, err := s.db.Begin(r.Context())
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(r.Context())
	var previous string
	if err := tx.QueryRow(r.Context(), `SELECT account_status FROM profiles WHERE id=$1 FOR UPDATE`, target).Scan(&previous); err != nil {
		if err == pgx.ErrNoRows {
			return nil, &APIError{Status: 404, Code: "NOT_FOUND", Message: "Account not found"}
		}
		return nil, err
	}
	if previous == "DELETED" {
		return nil, &APIError{Status: 409, Code: "DELETED_ACCOUNT", Message: "A deleted account cannot be modified"}
	}
	next := previous
	switch body.Action {
	case "SUSPEND":
		next = "SUSPENDED"
	case "BAN":
		next = "BANNED"
	case "RESTORE":
		next = "ACTIVE"
	}
	if next != previous {
		if _, err := tx.Exec(r.Context(), `UPDATE profiles SET account_status=$2,updated_at=now() WHERE id=$1`, target, next); err != nil {
			return nil, err
		}
	}
	metadata := map[string]any{"previousStatus": previous, "status": next}
	if _, err := tx.Exec(r.Context(), `INSERT INTO moderation_actions(target_profile_id,actor_profile_id,action,reason,metadata) VALUES($1,$2,$3,$4,$5)`, target, current.ProfileID, body.Action, body.Reason, metadata); err != nil {
		return nil, err
	}
	if _, err := tx.Exec(r.Context(), `INSERT INTO audit_logs(actor_profile_id,action,entity_type,entity_id,before_data,after_data,request_id) VALUES($1,$2,'PROFILE',$3,$4,$5,$6)`, current.ProfileID, "ACCOUNT_"+body.Action, target, map[string]any{"accountStatus": previous}, map[string]any{"accountStatus": next, "reason": body.Reason}, middleware.GetReqID(r.Context())); err != nil {
		return nil, err
	}
	if err := tx.Commit(r.Context()); err != nil {
		return nil, err
	}
	return map[string]any{"profileId": target, "accountStatus": next}, nil
}
