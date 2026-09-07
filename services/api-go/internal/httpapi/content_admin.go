package httpapi

import (
	"encoding/json"
	"net/http"
	"net/url"
	"sort"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
)

type clubInput struct {
	CityID            string   `json:"cityId"`
	Slug              string   `json:"slug"`
	Name              string   `json:"name"`
	Sport             string   `json:"sport"`
	Category          *string  `json:"category"`
	Description       *string  `json:"description"`
	Address           *string  `json:"address"`
	WebsiteURL        *string  `json:"websiteUrl"`
	RegistrationURL   *string  `json:"registrationUrl"`
	Eligibility       *string  `json:"eligibility"`
	AgeCategories     []string `json:"ageCategories"`
	SeasonInformation *string  `json:"seasonInformation"`
	Tags              []string `json:"tags"`
	SourceURL         *string  `json:"sourceUrl"`
	PublishStatus     string   `json:"publishStatus"`
}

func safeContentURL(value *string) bool {
	if value == nil || *value == "" {
		return true
	}
	u, err := url.Parse(*value)
	return err == nil && len(*value) <= 2048 && (u.Scheme == "https" || u.Scheme == "http") && u.Hostname() != "" && u.User == nil
}

func contentStrings(values ...*string) error {
	for _, v := range values {
		if v != nil && len(*v) > 10000 {
			return validation("content field is too long")
		}
	}
	return nil
}

func contentTags(values []string) error {
	if len(values) > 30 {
		return validation("too many tags")
	}
	for _, value := range values {
		if len(value) > 100 {
			return validation("tag is too long")
		}
	}
	return nil
}

func validContentIdentity(city, slug, name, status string) bool {
	return validUUID(city) && len(slug) > 0 && len(slug) <= 180 && slugPattern.MatchString(slug) && len(strings.TrimSpace(name)) >= 2 && len(name) <= 200 && oneOf(status, "DRAFT", "PUBLISHED", "ARCHIVED")
}

func (s *Server) adminClubs(_ http.ResponseWriter, r *http.Request) (any, error) {
	if err := adminOnly(r); err != nil {
		return nil, err
	}
	rows, err := queryMaps(r.Context(), s.db, `SELECT cl.*,c.name AS city FROM clubs cl JOIN cities c ON c.id=cl.city_id ORDER BY cl.updated_at DESC LIMIT 250`)
	return map[string]any{"data": rows}, err
}
func (s *Server) adminCreateClub(w http.ResponseWriter, r *http.Request) (any, error) {
	return s.saveClub(w, r, false)
}
func (s *Server) adminUpdateClub(w http.ResponseWriter, r *http.Request) (any, error) {
	return s.saveClub(w, r, true)
}
func (s *Server) adminUpdateEvent(w http.ResponseWriter, r *http.Request) (any, error) {
	return s.saveEvent(w, r, true)
}

func (s *Server) saveClub(w http.ResponseWriter, r *http.Request, update bool) (any, error) {
	if err := adminOnly(r); err != nil {
		return nil, err
	}
	var b clubInput
	if err := decodeJSON(r, &b); err != nil {
		return nil, err
	}
	if b.PublishStatus == "" {
		b.PublishStatus = "DRAFT"
	}
	if !validContentIdentity(b.CityID, b.Slug, b.Name, b.PublishStatus) || len(strings.TrimSpace(b.Sport)) < 2 || len(b.Sport) > 100 {
		return nil, validation("club fields are invalid")
	}
	for _, v := range []*string{b.WebsiteURL, b.RegistrationURL, b.SourceURL} {
		if !safeContentURL(v) {
			return nil, validation("links must be HTTP or HTTPS without embedded credentials")
		}
	}
	if err := contentStrings(b.Category, b.Description, b.Address, b.Eligibility, b.SeasonInformation); err != nil {
		return nil, err
	}
	if err := contentTags(b.Tags); err != nil {
		return nil, err
	}
	if err := contentTags(b.AgeCategories); err != nil {
		return nil, err
	}
	if b.Tags == nil {
		b.Tags = []string{}
	}
	if b.AgeCategories == nil {
		b.AgeCategories = []string{}
	}
	fields := map[string]any{"city_id": b.CityID, "slug": b.Slug, "name": strings.TrimSpace(b.Name), "sport": strings.TrimSpace(b.Sport), "category": b.Category, "description": b.Description, "address": b.Address, "website_url": b.WebsiteURL, "registration_url": b.RegistrationURL, "eligibility": b.Eligibility, "age_categories": b.AgeCategories, "season_information": b.SeasonInformation, "tags": b.Tags, "source_url": b.SourceURL, "publish_status": b.PublishStatus}
	return s.saveContent(w, r, "clubs", "CLUB", fields, update)
}

func (s *Server) saveEvent(w http.ResponseWriter, r *http.Request, update bool) (any, error) {
	if err := adminOnly(r); err != nil {
		return nil, err
	}
	var b eventInput
	if err := decodeJSON(r, &b); err != nil {
		return nil, err
	}
	if b.PublishStatus == "" {
		b.PublishStatus = "DRAFT"
	}
	if b.EventStatus == "" {
		b.EventStatus = "ACTIVE"
	}
	if b.RegistrationStatus == "" {
		b.RegistrationStatus = "OPEN"
	}
	if !validContentIdentity(b.CityID, b.Slug, b.Name, b.PublishStatus) || !oneOf(b.EventStatus, "ACTIVE", "CANCELLED", "POSTPONED") || !oneOf(b.RegistrationStatus, "OPEN", "CLOSED", "UNKNOWN", "NOT_APPLICABLE") {
		return nil, validation("event fields are invalid")
	}
	var start *time.Time
	if strings.TrimSpace(b.StartAt) != "" {
		parsed, err := time.Parse(time.RFC3339, b.StartAt)
		if err != nil {
			return nil, validation("startAt must be an RFC3339 timestamp")
		}
		start = &parsed
	}
	if b.EndAt != nil {
		end, err := time.Parse(time.RFC3339, *b.EndAt)
		if err != nil || (start != nil && end.Before(*start)) {
			return nil, validation("endAt must be a timestamp at or after startAt")
		}
	}
	if b.RegistrationDeadline != nil {
		if _, err := time.Parse(time.RFC3339, *b.RegistrationDeadline); err != nil {
			return nil, validation("registrationDeadline must be an RFC3339 timestamp")
		}
	}
	for _, v := range []*string{b.ExternalRegistrationURL, b.SourceURL, b.ImageURL} {
		if !safeContentURL(v) {
			return nil, validation("links must be HTTP or HTTPS without embedded credentials")
		}
	}
	if err := contentStrings(b.Organizer, b.Category, b.Description, b.Location, b.Sport, b.EntryRequirements); err != nil {
		return nil, err
	}
	if err := contentTags(b.Tags); err != nil {
		return nil, err
	}
	if b.Tags == nil {
		b.Tags = []string{}
	}
	var startValue any
	if start != nil {
		startValue = b.StartAt
	}
	fields := map[string]any{"city_id": b.CityID, "slug": b.Slug, "name": strings.TrimSpace(b.Name), "organizer": b.Organizer, "category": b.Category, "description": b.Description, "start_at": startValue, "end_at": b.EndAt, "registration_deadline": b.RegistrationDeadline, "registration_status": b.RegistrationStatus, "location": b.Location, "external_registration_url": b.ExternalRegistrationURL, "sport": b.Sport, "official_fitcalgary": b.OfficialFitCalgary, "tags": b.Tags, "source_url": b.SourceURL, "event_status": b.EventStatus, "publish_status": b.PublishStatus, "entry_requirements": b.EntryRequirements, "image_url": b.ImageURL}
	return s.saveContent(w, r, "events", "EVENT", fields, update)
}

// Table names and field names come only from the typed handlers above, never
// request identifiers. Full PUT replaces editable fields; archive preserves IDs
// and relationships. Content mutation and its audit record commit atomically.
func (s *Server) saveContent(w http.ResponseWriter, r *http.Request, table, entity string, fields map[string]any, update bool) (any, error) {
	id := chi.URLParam(r, "id")
	if update && !validUUID(id) {
		return nil, validation("content id must be a UUID")
	}
	tx, err := s.db.Begin(r.Context())
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(r.Context())
	var before any
	if update {
		rows, err := queryMaps(r.Context(), tx, "SELECT * FROM "+table+" WHERE id=$1 FOR UPDATE", id)
		if err != nil {
			return nil, err
		}
		if len(rows) == 0 {
			return nil, &APIError{Status: 404, Code: "NOT_FOUND", Message: "Content not found"}
		}
		before = rows[0]
	}
	encoded, err := json.Marshal(fields)
	if err != nil {
		return nil, err
	}
	columns := make([]string, 0, len(fields))
	for k := range fields {
		columns = append(columns, k)
	}
	sort.Strings(columns)
	sql := "INSERT INTO " + table + " (" + strings.Join(columns, ",") + ") SELECT " + strings.Join(columns, ",") + " FROM jsonb_populate_record(NULL::" + table + ",$1) RETURNING *"
	args := []any{encoded}
	action := entity + "_CREATED"
	if update {
		assignments := make([]string, 0, len(columns))
		for _, c := range columns {
			assignments = append(assignments, c+"=input."+c)
		}
		sql = "UPDATE " + table + " AS target SET " + strings.Join(assignments, ",") + ",updated_at=now() FROM jsonb_populate_record(NULL::" + table + ",$1) AS input WHERE target.id=$2 RETURNING target.*"
		args = append(args, id)
		action = entity + "_UPDATED"
	}
	rows, err := queryMaps(r.Context(), tx, sql, args...)
	if err != nil {
		return nil, err
	}
	beforeJSON, err := json.Marshal(before)
	if err != nil {
		return nil, err
	}
	afterJSON, err := json.Marshal(rows[0])
	if err != nil {
		return nil, err
	}
	_, err = tx.Exec(r.Context(), `INSERT INTO audit_logs(actor_profile_id,action,entity_type,entity_id,before_data,after_data,request_id) VALUES($1,$2,$3,$4,$5,$6,$7)`, identity(r).ProfileID, action, entity, rows[0]["id"], nullJSON(before, beforeJSON), afterJSON, middleware.GetReqID(r.Context()))
	if err != nil {
		return nil, err
	}
	if err = tx.Commit(r.Context()); err != nil {
		return nil, err
	}
	if !update {
		created(w, rows[0])
		return nil, nil
	}
	return rows[0], nil
}
