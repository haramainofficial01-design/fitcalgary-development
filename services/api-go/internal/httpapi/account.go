package httpapi

import (
	"encoding/json"
	"fmt"
	"net/http"
	"regexp"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/google/uuid"

	"fitcalgary.ca/index/api/internal/security"
)

var usernamePattern = regexp.MustCompile(`^[a-z0-9_]{3,30}$`)

func (s *Server) registerAccountRoutes(router chi.Router) {
	router.Get("/auth/context", s.handle(s.authContext))
	router.Get("/profile", s.handle(s.getProfile))
	router.Get("/profile/performance", s.handle(s.getProfilePerformance))
	router.Patch("/profile", s.handle(s.updateProfile))
	router.Delete("/profile", s.handle(s.deleteProfile))
	router.Get("/saved-gyms", s.handle(s.listSavedGyms))
	router.Put("/saved-gyms/{gymId}", s.handle(s.saveGym))
	router.Delete("/saved-gyms/{gymId}", s.handle(s.unsaveGym))
	router.Get("/notifications", s.handle(s.listNotifications))
	router.Get("/notification-devices", s.handle(s.listNotificationDevices))
	router.Post("/notification-devices", s.handle(s.registerNotificationDevice))
	router.Put("/notification-devices/{id}", s.handle(s.refreshNotificationDevice))
	router.Delete("/notification-devices/{id}", s.handle(s.removeNotificationDevice))
	router.Get("/watch/summary", s.handle(s.watchSummary))
}

func (s *Server) authContext(_ http.ResponseWriter, r *http.Request) (any, error) {
	current := identity(r)
	return map[string]any{"subject": current.Principal.Subject, "roles": current.Principal.Roles, "profileId": current.ProfileID, "emailVerified": current.Principal.EmailVerified}, nil
}

func (s *Server) getProfile(_ http.ResponseWriter, r *http.Request) (any, error) {
	rows, err := queryMaps(r.Context(), s.db, `SELECT p.id,p.username,p.display_name,p.photo_url,p.bio,p.date_of_birth,p.sex_category,p.home_gym_id,p.privacy,p.created_at,g.name AS home_gym_name,c.name AS city FROM profiles p LEFT JOIN gyms g ON g.id=p.home_gym_id LEFT JOIN cities c ON c.id=p.city_id WHERE p.id=$1`, identity(r).ProfileID)
	if err != nil {
		return nil, err
	}
	if len(rows) == 0 {
		return nil, &APIError{Status: http.StatusNotFound, Code: "NOT_FOUND", Message: "Profile not found"}
	}
	rows[0]["roles"] = identity(r).Principal.Roles
	return rows[0], nil
}

func (s *Server) getProfilePerformance(_ http.ResponseWriter, r *http.Request) (any, error) {
	owner := identity(r).ProfileID
	rows, err := queryMaps(r.Context(), s.db, `WITH ranked AS (
SELECT rs.id AS result_id,rs.profile_id,rs.normalized_metric,rs.display_metric,rs.verified_at,rs.verification_type,
l.id AS leaderboard_id,l.board_type,d.id AS discipline_id,d.slug AS discipline_slug,d.display_name AS discipline_name,
d.metric_type,d.unit,d.ranking_direction,v.display_label AS division_label,
ROW_NUMBER() OVER(PARTITION BY l.id ORDER BY
CASE WHEN d.ranking_direction='LOWER_IS_BETTER' THEN rs.normalized_metric END ASC NULLS LAST,
CASE WHEN d.ranking_direction='HIGHER_IS_BETTER' THEN rs.normalized_metric END DESC NULLS LAST,
rs.verified_at,rs.id)::int AS rank
FROM results rs JOIN leaderboards l ON l.id=rs.leaderboard_id
JOIN disciplines d ON d.id=l.discipline_id JOIN divisions v ON v.id=l.division_id
WHERE rs.invalidated_at IS NULL)
SELECT result_id,normalized_metric,display_metric,verified_at,verification_type,leaderboard_id,board_type,
discipline_id,discipline_slug,discipline_name,metric_type,unit,ranking_direction,division_label,rank
FROM ranked WHERE profile_id=$1 ORDER BY verified_at DESC,result_id LIMIT 100`, owner)
	if err != nil {
		return nil, err
	}
	best, err := queryMaps(r.Context(), s.db, `WITH candidates AS (
SELECT rs.id AS result_id,rs.profile_id,rs.normalized_metric,rs.display_metric,rs.verified_at,rs.verification_type,
l.id AS leaderboard_id,l.board_type,d.id AS discipline_id,d.slug AS discipline_slug,d.display_name AS discipline_name,
d.metric_type,d.unit,d.ranking_direction,v.display_label AS division_label,
ROW_NUMBER() OVER(PARTITION BY rs.profile_id,d.id,l.board_type ORDER BY
CASE WHEN d.ranking_direction='LOWER_IS_BETTER' THEN rs.normalized_metric END ASC NULLS LAST,
CASE WHEN d.ranking_direction='HIGHER_IS_BETTER' THEN rs.normalized_metric END DESC NULLS LAST,
rs.verified_at,rs.id)::int AS best_ordinal
FROM results rs JOIN leaderboards l ON l.id=rs.leaderboard_id
JOIN disciplines d ON d.id=l.discipline_id JOIN divisions v ON v.id=l.division_id
WHERE rs.invalidated_at IS NULL)
SELECT result_id,normalized_metric,display_metric,verified_at,verification_type,leaderboard_id,board_type,
discipline_id,discipline_slug,discipline_name,metric_type,unit,ranking_direction,division_label
FROM candidates WHERE profile_id=$1 AND best_ordinal=1 ORDER BY discipline_name,board_type`, owner)
	if err != nil {
		return nil, err
	}
	return map[string]any{"results": rows, "personalBests": best}, nil
}

func (s *Server) deleteProfile(w http.ResponseWriter, r *http.Request) (any, error) {
	current := identity(r)
	tx, err := s.db.Begin(r.Context())
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(r.Context()) //nolint:errcheck
	before, err := queryMaps(r.Context(), tx, `SELECT id,email,username,display_name,account_status,created_at FROM profiles WHERE id=$1 FOR UPDATE`, current.ProfileID)
	if err != nil {
		return nil, err
	}
	if len(before) == 0 {
		return nil, &APIError{Status: http.StatusNotFound, Code: "NOT_FOUND", Message: "Profile not found"}
	}
	if _, err := tx.Exec(r.Context(), `DELETE FROM saved_gyms WHERE profile_id=$1`, current.ProfileID); err != nil {
		return nil, err
	}
	if _, err := tx.Exec(r.Context(), `DELETE FROM notification_devices WHERE profile_id=$1`, current.ProfileID); err != nil {
		return nil, err
	}
	if _, err := tx.Exec(r.Context(), `DELETE FROM notifications WHERE profile_id=$1`, current.ProfileID); err != nil {
		return nil, err
	}
	if _, err := tx.Exec(r.Context(), `DELETE FROM user_roles WHERE profile_id=$1`, current.ProfileID); err != nil {
		return nil, err
	}
	if _, err := tx.Exec(r.Context(), `UPDATE submission_evidence SET retain_until=LEAST(retain_until,now()) WHERE submission_id IN (SELECT id FROM submissions WHERE profile_id=$1) AND evidence_deleted_at IS NULL`, current.ProfileID); err != nil {
		return nil, err
	}
	if _, err := tx.Exec(r.Context(), `UPDATE profiles SET email=NULL,username=NULL,display_name='Deleted athlete',photo_url=NULL,bio=NULL,date_of_birth=NULL,sex_category=NULL,home_gym_id=NULL,city_id=NULL,privacy='{"publicProfile":false,"showGym":false}'::jsonb,account_status='DELETED',deleted_at=now(),updated_at=now() WHERE id=$1`, current.ProfileID); err != nil {
		return nil, err
	}
	disablePayload, _ := json.Marshal(map[string]any{"subject": current.Principal.Subject, "profileId": current.ProfileID})
	if _, err := tx.Exec(r.Context(), `INSERT INTO outbox_jobs(job_type,dedupe_key,payload) VALUES('IDENTITY_DISABLE',$1,$2) ON CONFLICT(dedupe_key) DO NOTHING`, "identity-disable:"+current.ProfileID, disablePayload); err != nil {
		return nil, err
	}
	beforeJSON, _ := json.Marshal(before[0])
	if _, err := tx.Exec(r.Context(), `INSERT INTO audit_logs(actor_profile_id,action,entity_type,entity_id,before_data,after_data,request_id) VALUES($1,'PROFILE_DELETION_REQUESTED','PROFILE',$1,$2,'{"accountStatus":"DELETED"}'::jsonb,$3)`, current.ProfileID, beforeJSON, requestID(r)); err != nil {
		return nil, err
	}
	if err := tx.Commit(r.Context()); err != nil {
		return nil, err
	}
	accepted(w, map[string]any{"status": "DELETION_REQUESTED", "identityProviderAction": "QUEUED", "historicalResultsPreserved": true})
	return nil, nil
}

func (s *Server) updateProfile(_ http.ResponseWriter, r *http.Request) (any, error) {
	var body map[string]json.RawMessage
	if err := decodeJSON(r, &body); err != nil {
		return nil, err
	}
	allowed := map[string]bool{"username": true, "displayName": true, "bio": true, "dateOfBirth": true, "sexCategory": true, "homeGymId": true, "privacy": true}
	for key := range body {
		if !allowed[key] {
			return nil, validation("unknown profile field: " + key)
		}
	}
	sets := make([]string, 0, len(body)+1)
	args := []any{identity(r).ProfileID}
	add := func(expression string, value any) {
		args = append(args, value)
		sets = append(sets, fmt.Sprintf(expression, len(args)))
	}
	for _, key := range []string{"username", "displayName", "bio", "dateOfBirth", "sexCategory", "homeGymId", "privacy"} {
		raw, present := body[key]
		if !present {
			continue
		}
		switch key {
		case "username":
			var value string
			if json.Unmarshal(raw, &value) != nil || !usernamePattern.MatchString(value) {
				return nil, validation("username must be 3–30 lowercase letters, digits, or underscores")
			}
			add("username=$%d", value)
		case "displayName":
			var value string
			if json.Unmarshal(raw, &value) != nil || len(strings.TrimSpace(value)) < 2 || len(value) > 80 {
				return nil, validation("displayName must be between 2 and 80 characters")
			}
			add("display_name=$%d", strings.TrimSpace(value))
		case "bio":
			var value *string
			if json.Unmarshal(raw, &value) != nil || (value != nil && len(*value) > 280) {
				return nil, validation("bio must be at most 280 characters")
			}
			add("bio=$%d", value)
		case "dateOfBirth":
			var value *string
			if json.Unmarshal(raw, &value) != nil {
				return nil, validation("dateOfBirth is invalid")
			}
			if value != nil {
				if _, err := time.Parse("2006-01-02", *value); err != nil {
					return nil, validation("dateOfBirth must use YYYY-MM-DD")
				}
			}
			add("date_of_birth=$%d::date", value)
		case "sexCategory":
			var value *string
			if json.Unmarshal(raw, &value) != nil || (value != nil && *value != "MEN" && *value != "WOMEN" && *value != "UNDISCLOSED") {
				return nil, validation("sexCategory is invalid")
			}
			add("sex_category=$%d", value)
		case "homeGymId":
			var value *string
			if json.Unmarshal(raw, &value) != nil || (value != nil && !validUUID(*value)) {
				return nil, validation("homeGymId must be a UUID or null")
			}
			if value != nil {
				var available bool
				if err := s.db.QueryRow(r.Context(), `SELECT EXISTS(SELECT 1 FROM gyms WHERE id=$1 AND publish_status='PUBLISHED')`, *value).Scan(&available); err != nil {
					return nil, err
				}
				if !available {
					return nil, validation("homeGymId must identify a published gym")
				}
			}
			add("home_gym_id=$%d::uuid", value)
		case "privacy":
			var value map[string]bool
			if json.Unmarshal(raw, &value) != nil {
				return nil, validation("privacy is invalid")
			}
			for privacyKey := range value {
				if privacyKey != "publicProfile" && privacyKey != "showGym" {
					return nil, validation("unknown privacy field: " + privacyKey)
				}
			}
			encoded, _ := json.Marshal(value)
			add("privacy=privacy||$%d::jsonb", encoded)
		}
	}
	if len(sets) == 0 {
		return s.getProfile(nil, r)
	}
	sets = append(sets, "updated_at=now()")
	query := `UPDATE profiles SET ` + strings.Join(sets, ",") + ` WHERE id=$1 RETURNING id,username,display_name,bio,date_of_birth,sex_category,home_gym_id,privacy,updated_at`
	rows, err := queryMaps(r.Context(), s.db, query, args...)
	if err != nil {
		return nil, err
	}
	return rows[0], nil
}

func (s *Server) listSavedGyms(_ http.ResponseWriter, r *http.Request) (any, error) {
	rows, err := queryMaps(r.Context(), s.db, `SELECT g.id,g.slug,g.name,g.operator,g.neighbourhood AS area,c.name AS city,s.created_at FROM saved_gyms s JOIN gyms g ON g.id=s.gym_id JOIN cities c ON c.id=g.city_id WHERE s.profile_id=$1 AND g.publish_status='PUBLISHED' ORDER BY s.created_at DESC,g.id`, identity(r).ProfileID)
	return map[string]any{"data": rows}, err
}

func (s *Server) saveGym(w http.ResponseWriter, r *http.Request) (any, error) {
	gymID := chi.URLParam(r, "gymId")
	if !validUUID(gymID) {
		return nil, validation("gymId must be a UUID")
	}
	result, err := s.db.Exec(r.Context(), `INSERT INTO saved_gyms(profile_id,gym_id) SELECT $1,id FROM gyms WHERE id=$2 AND publish_status='PUBLISHED' ON CONFLICT(profile_id,gym_id) DO UPDATE SET gym_id=EXCLUDED.gym_id`, identity(r).ProfileID, gymID)
	if err != nil {
		return nil, err
	}
	if result.RowsAffected() == 0 {
		return nil, &APIError{Status: http.StatusNotFound, Code: "NOT_FOUND", Message: "Gym not found"}
	}
	noContent(w)
	return nil, nil
}

func (s *Server) unsaveGym(w http.ResponseWriter, r *http.Request) (any, error) {
	gymID := chi.URLParam(r, "gymId")
	if !validUUID(gymID) {
		return nil, validation("gymId must be a UUID")
	}
	if _, err := s.db.Exec(r.Context(), `DELETE FROM saved_gyms WHERE profile_id=$1 AND gym_id=$2`, identity(r).ProfileID, gymID); err != nil {
		return nil, err
	}
	noContent(w)
	return nil, nil
}

func (s *Server) listNotifications(_ http.ResponseWriter, r *http.Request) (any, error) {
	rows, err := queryMaps(r.Context(), s.db, `SELECT id,type,title,body,deep_link,created_at,opened_at FROM notifications WHERE profile_id=$1 ORDER BY created_at DESC LIMIT 100`, identity(r).ProfileID)
	return map[string]any{"data": rows}, err
}

type notificationDeviceInput struct {
	Platform string `json:"platform"`
	Token    string `json:"token"`
}

func validateDevice(body notificationDeviceInput) error {
	if !oneOf(body.Platform, "IOS", "ANDROID", "WEB") || len(strings.TrimSpace(body.Token)) < 20 || len(body.Token) > 4096 {
		return validation("notification device platform or token is invalid")
	}
	return nil
}

func (s *Server) listNotificationDevices(_ http.ResponseWriter, r *http.Request) (any, error) {
	rows, err := queryMaps(r.Context(), s.db, `SELECT id,platform,enabled,last_seen_at,invalidated_at,created_at FROM notification_devices WHERE profile_id=$1 ORDER BY last_seen_at DESC`, identity(r).ProfileID)
	return map[string]any{"data": rows}, err
}

func (s *Server) registerNotificationDevice(w http.ResponseWriter, r *http.Request) (any, error) {
	var body notificationDeviceInput
	if err := decodeJSON(r, &body); err != nil {
		return nil, err
	}
	if err := validateDevice(body); err != nil {
		return nil, err
	}
	encrypted, err := s.cipher.Encrypt(strings.TrimSpace(body.Token))
	if err != nil {
		return nil, err
	}
	hash := security.HashToken(strings.TrimSpace(body.Token))
	rows, err := queryMaps(r.Context(), s.db, `INSERT INTO notification_devices(profile_id,platform,token_hash,encrypted_token,enabled,last_seen_at,invalidated_at) VALUES($1,$2,$3,$4,true,now(),NULL) ON CONFLICT(token_hash) DO UPDATE SET profile_id=EXCLUDED.profile_id,platform=EXCLUDED.platform,encrypted_token=EXCLUDED.encrypted_token,enabled=true,last_seen_at=now(),invalidated_at=NULL RETURNING id,platform,enabled,last_seen_at,created_at`, identity(r).ProfileID, body.Platform, hash, encrypted)
	if err != nil {
		return nil, err
	}
	created(w, rows[0])
	return nil, nil
}

func (s *Server) refreshNotificationDevice(_ http.ResponseWriter, r *http.Request) (any, error) {
	id := chi.URLParam(r, "id")
	if !validUUID(id) {
		return nil, validation("notification device id must be a UUID")
	}
	var body notificationDeviceInput
	if err := decodeJSON(r, &body); err != nil {
		return nil, err
	}
	if err := validateDevice(body); err != nil {
		return nil, err
	}
	encrypted, err := s.cipher.Encrypt(strings.TrimSpace(body.Token))
	if err != nil {
		return nil, err
	}
	rows, err := queryMaps(r.Context(), s.db, `UPDATE notification_devices SET platform=$3,token_hash=$4,encrypted_token=$5,enabled=true,last_seen_at=now(),invalidated_at=NULL WHERE id=$1 AND profile_id=$2 RETURNING id,platform,enabled,last_seen_at,created_at`, id, identity(r).ProfileID, body.Platform, security.HashToken(strings.TrimSpace(body.Token)), encrypted)
	if err != nil {
		return nil, err
	}
	if len(rows) == 0 {
		return nil, &APIError{Status: http.StatusNotFound, Code: "NOT_FOUND", Message: "Notification device not found"}
	}
	return rows[0], nil
}

func (s *Server) removeNotificationDevice(w http.ResponseWriter, r *http.Request) (any, error) {
	id := chi.URLParam(r, "id")
	if !validUUID(id) {
		return nil, validation("notification device id must be a UUID")
	}
	result, err := s.db.Exec(r.Context(), `DELETE FROM notification_devices WHERE id=$1 AND profile_id=$2`, id, identity(r).ProfileID)
	if err != nil {
		return nil, err
	}
	if result.RowsAffected() == 0 {
		return nil, &APIError{Status: http.StatusNotFound, Code: "NOT_FOUND", Message: "Notification device not found"}
	}
	noContent(w)
	return nil, nil
}

func (s *Server) watchSummary(_ http.ResponseWriter, r *http.Request) (any, error) {
	owner := identity(r).ProfileID
	profiles, err := queryMaps(r.Context(), s.db, `SELECT display_name,city_id FROM profiles WHERE id=$1`, owner)
	if err != nil || len(profiles) == 0 {
		return nil, err
	}
	rankings, err := queryMaps(r.Context(), s.db, `WITH ranked AS (SELECT rs.id,rs.profile_id,l.board_type,d.display_name AS discipline,v.display_label AS division,ROW_NUMBER() OVER(PARTITION BY l.id ORDER BY CASE WHEN d.ranking_direction='LOWER_IS_BETTER' THEN rs.normalized_metric END ASC NULLS LAST,CASE WHEN d.ranking_direction='HIGHER_IS_BETTER' THEN rs.normalized_metric END DESC NULLS LAST,rs.verified_at,rs.id)::int AS rank FROM results rs JOIN leaderboards l ON l.id=rs.leaderboard_id JOIN disciplines d ON d.id=l.discipline_id JOIN divisions v ON v.id=l.division_id WHERE rs.invalidated_at IS NULL) SELECT id,discipline,rank,division,board_type FROM ranked WHERE profile_id=$1 ORDER BY rank LIMIT 8`, owner)
	if err != nil {
		return nil, err
	}
	results, err := queryMaps(r.Context(), s.db, `SELECT rs.id,d.display_name AS discipline,rs.display_metric AS mark,rs.verified_at FROM results rs JOIN leaderboards l ON l.id=rs.leaderboard_id JOIN disciplines d ON d.id=l.discipline_id WHERE rs.profile_id=$1 AND rs.invalidated_at IS NULL ORDER BY rs.verified_at DESC LIMIT 8`, owner)
	if err != nil {
		return nil, err
	}
	submissions, err := queryMaps(r.Context(), s.db, `SELECT s.id,d.display_name AS discipline,s.status,s.updated_at FROM submissions s JOIN disciplines d ON d.id=s.discipline_id WHERE s.profile_id=$1 ORDER BY s.updated_at DESC LIMIT 8`, owner)
	if err != nil {
		return nil, err
	}
	events, err := queryMaps(r.Context(), s.db, `SELECT e.id,e.name,e.start_at,e.location FROM events e WHERE e.city_id=$1 AND e.publish_status='PUBLISHED' AND e.event_status='ACTIVE' AND e.start_at>=now() ORDER BY e.start_at LIMIT 8`, profiles[0]["city_id"])
	if err != nil {
		return nil, err
	}
	return map[string]any{"displayName": profiles[0]["display_name"], "rankings": rankings, "results": results, "submissions": submissions, "events": events, "refreshedAt": time.Now().UTC().Format(time.RFC3339Nano)}, nil
}

func validUUID(value string) bool {
	_, err := uuid.Parse(value)
	return err == nil
}

func requestID(r *http.Request) string {
	return middleware.GetReqID(r.Context())
}
