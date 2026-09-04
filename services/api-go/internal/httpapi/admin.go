package httpapi

import (
	"encoding/json"
	"net/http"
	"regexp"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"

	"fitcalgary.ca/index/api/internal/auth"
	"fitcalgary.ca/index/api/internal/domain"
)

var slugPattern = regexp.MustCompile(`^[a-z0-9-]+$`)

func (s *Server) registerAdminRoutes(router chi.Router) {
	router.Get("/admin/overview", s.handle(s.adminOverview))
	router.Get("/admin/reference-data", s.handle(s.adminReferenceData))
	router.Get("/admin/users", s.handle(s.adminUsers))
	router.Get("/admin/gyms", s.handle(s.adminGyms))
	router.Post("/admin/gyms", s.handle(s.adminCreateGym))
	router.Put("/admin/gyms/{id}", s.handle(s.adminUpdateGym))
	router.Post("/admin/gyms/{id}/pricing", s.handle(s.adminCreatePricing))
	router.Get("/admin/events", s.handle(s.adminEvents))
	router.Post("/admin/events", s.handle(s.adminCreateEvent))
	router.Put("/admin/settings/{key}", s.handle(s.adminUpdateSetting))
	router.Put("/admin/users/{profileId}/roles/{role}", s.handle(s.adminGrantRole))
	router.Delete("/admin/users/{profileId}/roles/{role}", s.handle(s.adminRevokeRole))
	router.Get("/admin/audit-log", s.handle(s.adminAuditLog))
}

func adminOnly(r *http.Request) error { return requireRole(r, auth.RoleAdmin) }

func (s *Server) adminOverview(_ http.ResponseWriter, r *http.Request) (any, error) {
	if err := adminOnly(r); err != nil {
		return nil, err
	}
	rows, err := queryMaps(r.Context(), s.db, `SELECT (SELECT count(*) FROM profiles WHERE account_status='ACTIVE') AS total_users,(SELECT count(*) FROM submissions WHERE status='PENDING_REVIEW') AS pending_submissions,(SELECT count(*) FROM submission_evidence WHERE evidence_deleted_at IS NULL AND retain_until<now()+interval '48 hours') AS evidence_nearing_expiry,(SELECT count(*) FROM gyms WHERE publish_status='PUBLISHED') AS published_gyms,(SELECT count(*) FROM events WHERE publish_status='PUBLISHED' AND start_at>now()) AS upcoming_events,(SELECT count(*) FROM notifications WHERE delivery_status='FAILED') AS failed_notifications`)
	if err != nil {
		return nil, err
	}
	return rows[0], nil
}

func (s *Server) adminReferenceData(_ http.ResponseWriter, r *http.Request) (any, error) {
	if err := adminOnly(r); err != nil {
		return nil, err
	}
	regions, err := queryMaps(r.Context(), s.db, `SELECT r.id,r.slug,r.name,r.active,p.code AS province_code,p.name AS province_name FROM regions r JOIN provinces p ON p.id=r.province_id ORDER BY p.code,r.name`)
	if err != nil {
		return nil, err
	}
	cities, err := queryMaps(r.Context(), s.db, `SELECT c.id,c.slug,c.name,c.active,c.region_id,r.name AS region_name FROM cities c JOIN regions r ON r.id=c.region_id ORDER BY r.name,c.name`)
	if err != nil {
		return nil, err
	}
	brands, err := queryMaps(r.Context(), s.db, `SELECT id,slug,name,website_url FROM gym_brands ORDER BY name`)
	if err != nil {
		return nil, err
	}
	disciplines, err := queryMaps(r.Context(), s.db, `SELECT id,slug,display_name,metric_type,unit,ranking_direction,official_eligible,community_eligible,active,rules_version FROM disciplines ORDER BY display_name`)
	if err != nil {
		return nil, err
	}
	divisions, err := queryMaps(r.Context(), s.db, `SELECT id,slug,display_label,minimum_age,maximum_age,minimum_inclusive,maximum_inclusive,open,sex_category,active,version FROM divisions ORDER BY minimum_age NULLS FIRST,display_label`)
	if err != nil {
		return nil, err
	}
	return map[string]any{"regions": regions, "cities": cities, "brands": brands, "disciplines": disciplines, "divisions": divisions}, nil
}

func (s *Server) adminUsers(_ http.ResponseWriter, r *http.Request) (any, error) {
	if err := adminOnly(r); err != nil {
		return nil, err
	}
	page, err := positiveInt(r.URL.Query().Get("page"), 1, 1, 1_000_000)
	if err != nil {
		return nil, err
	}
	pageSize, err := positiveInt(r.URL.Query().Get("pageSize"), 50, 1, 100)
	if err != nil {
		return nil, err
	}
	query := optionalString(r.URL.Query().Get("q"), 100)
	rows, err := queryMaps(r.Context(), s.db, `SELECT p.id,p.email,p.username,p.display_name,p.account_status,p.created_at,p.updated_at,COALESCE(array_agg(ur.role ORDER BY ur.role) FILTER (WHERE ur.role IS NOT NULL),'{}') AS roles,COUNT(*) OVER() AS total FROM profiles p LEFT JOIN user_roles ur ON ur.profile_id=p.id WHERE ($1::text IS NULL OR p.email ILIKE $1 OR p.username ILIKE $1 OR p.display_name ILIKE $1) GROUP BY p.id ORDER BY p.created_at DESC LIMIT $2 OFFSET $3`, like(query), pageSize, (page-1)*pageSize)
	if err != nil {
		return nil, err
	}
	return paginated(rows, page, pageSize), nil
}

func (s *Server) adminGyms(_ http.ResponseWriter, r *http.Request) (any, error) {
	if err := adminOnly(r); err != nil {
		return nil, err
	}
	rows, err := queryMaps(r.Context(), s.db, `SELECT g.*,c.name AS city,(SELECT count(*) FROM gym_pricing p WHERE p.gym_id=g.id) AS pricing_count FROM gyms g JOIN cities c ON c.id=g.city_id ORDER BY g.updated_at DESC LIMIT 250`)
	return map[string]any{"data": rows}, err
}

type gymInput struct {
	CityID        string   `json:"cityId"`
	BrandID       *string  `json:"brandId"`
	Slug          string   `json:"slug"`
	Name          string   `json:"name"`
	Operator      *string  `json:"operator"`
	Description   *string  `json:"description"`
	AddressLine1  *string  `json:"addressLine1"`
	Neighbourhood *string  `json:"neighbourhood"`
	PostalCode    *string  `json:"postalCode"`
	WebsiteURL    *string  `json:"websiteUrl"`
	Telephone     *string  `json:"telephone"`
	Categories    []string `json:"categories"`
	Amenities     []string `json:"amenities"`
	SourceURL     *string  `json:"sourceUrl"`
	PublishStatus string   `json:"publishStatus"`
}

func validateGym(body *gymInput) error {
	body.Name = strings.TrimSpace(body.Name)
	if !validUUID(body.CityID) || (body.BrandID != nil && !validUUID(*body.BrandID)) || !slugPattern.MatchString(body.Slug) || len(body.Slug) > 140 || len(body.Name) < 2 || len(body.Name) > 180 {
		return validation("gym identity fields are invalid")
	}
	if body.PublishStatus == "" {
		body.PublishStatus = "DRAFT"
	}
	if !oneOf(body.PublishStatus, "DRAFT", "PUBLISHED", "ARCHIVED") || len(body.Categories) > 30 || len(body.Amenities) > 100 {
		return validation("gym status or taxonomy is invalid")
	}
	if body.Categories == nil {
		body.Categories = []string{}
	}
	if body.Amenities == nil {
		body.Amenities = []string{}
	}
	return nil
}

func (s *Server) adminCreateGym(w http.ResponseWriter, r *http.Request) (any, error) {
	if err := adminOnly(r); err != nil {
		return nil, err
	}
	var body gymInput
	if err := decodeJSON(r, &body); err != nil {
		return nil, err
	}
	if err := validateGym(&body); err != nil {
		return nil, err
	}
	rows, err := queryMaps(r.Context(), s.db, `INSERT INTO gyms(city_id,brand_id,slug,name,operator,description,address_line1,neighbourhood,postal_code,website_url,telephone,categories,amenities,source_url,publish_status,last_verified_at) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,CASE WHEN $15='PUBLISHED' THEN now() END) RETURNING *`, body.CityID, body.BrandID, body.Slug, body.Name, body.Operator, body.Description, body.AddressLine1, body.Neighbourhood, body.PostalCode, body.WebsiteURL, body.Telephone, body.Categories, body.Amenities, body.SourceURL, body.PublishStatus)
	if err != nil {
		return nil, err
	}
	if err := s.audit(r, "GYM_CREATED", "GYM", rows[0]["id"], nil, rows[0]); err != nil {
		return nil, err
	}
	created(w, rows[0])
	return nil, nil
}

func (s *Server) adminUpdateGym(_ http.ResponseWriter, r *http.Request) (any, error) {
	if err := adminOnly(r); err != nil {
		return nil, err
	}
	id := chi.URLParam(r, "id")
	if !validUUID(id) {
		return nil, validation("gym id must be a UUID")
	}
	var body gymInput
	if err := decodeJSON(r, &body); err != nil {
		return nil, err
	}
	if err := validateGym(&body); err != nil {
		return nil, err
	}
	before, err := queryMaps(r.Context(), s.db, `SELECT * FROM gyms WHERE id=$1`, id)
	if err != nil {
		return nil, err
	}
	if len(before) == 0 {
		return nil, &APIError{Status: http.StatusNotFound, Code: "NOT_FOUND", Message: "Gym not found"}
	}
	rows, err := queryMaps(r.Context(), s.db, `UPDATE gyms SET city_id=$2,brand_id=$3,slug=$4,name=$5,operator=$6,description=$7,address_line1=$8,neighbourhood=$9,postal_code=$10,website_url=$11,telephone=$12,categories=$13,amenities=$14,source_url=$15,publish_status=$16,last_verified_at=CASE WHEN $16='PUBLISHED' THEN COALESCE(last_verified_at,now()) ELSE last_verified_at END,updated_at=now() WHERE id=$1 RETURNING *`, id, body.CityID, body.BrandID, body.Slug, body.Name, body.Operator, body.Description, body.AddressLine1, body.Neighbourhood, body.PostalCode, body.WebsiteURL, body.Telephone, body.Categories, body.Amenities, body.SourceURL, body.PublishStatus)
	if err != nil {
		return nil, err
	}
	if err := s.audit(r, "GYM_UPDATED", "GYM", id, before[0], rows[0]); err != nil {
		return nil, err
	}
	return rows[0], nil
}

type pricingInput struct {
	PlanName                   string  `json:"planName"`
	RecurringCents             int     `json:"recurringCents"`
	BillingFrequency           string  `json:"billingFrequency"`
	MandatoryRecurringFeeCents int     `json:"mandatoryRecurringFeeCents"`
	MandatoryAnnualFeeCents    int     `json:"mandatoryAnnualFeeCents"`
	InitiationFeeCents         int     `json:"initiationFeeCents"`
	PricingComplete            bool    `json:"pricingComplete"`
	SourceURL                  *string `json:"sourceUrl"`
	EffectiveFrom              *string `json:"effectiveFrom"`
	EffectiveTo                *string `json:"effectiveTo"`
	MembershipType             *string `json:"membershipType"`
	ContractMonths             *int    `json:"contractMonths"`
	Eligibility                *string `json:"eligibility"`
	DropInCents                *int    `json:"dropInCents"`
	TrialDetails               *string `json:"trialDetails"`
	Notes                      *string `json:"notes"`
}

func (s *Server) adminCreatePricing(w http.ResponseWriter, r *http.Request) (any, error) {
	if err := adminOnly(r); err != nil {
		return nil, err
	}
	gymID := chi.URLParam(r, "id")
	if !validUUID(gymID) {
		return nil, validation("gym id must be a UUID")
	}
	var body pricingInput
	if err := decodeJSON(r, &body); err != nil {
		return nil, err
	}
	if strings.TrimSpace(body.PlanName) == "" || len(body.PlanName) > 160 || body.RecurringCents < 0 || body.MandatoryRecurringFeeCents < 0 || body.MandatoryAnnualFeeCents < 0 || body.InitiationFeeCents < 0 || !oneOf(body.BillingFrequency, "WEEKLY", "BIWEEKLY", "MONTHLY", "QUARTERLY", "ANNUALLY") {
		return nil, validation("pricing fields are invalid")
	}
	if body.EffectiveFrom != nil {
		if _, err := time.Parse("2006-01-02", *body.EffectiveFrom); err != nil {
			return nil, validation("effectiveFrom must use YYYY-MM-DD")
		}
	}
	if body.EffectiveTo != nil {
		if _, err := time.Parse("2006-01-02", *body.EffectiveTo); err != nil {
			return nil, validation("effectiveTo must use YYYY-MM-DD")
		}
		if body.EffectiveFrom != nil && *body.EffectiveTo < *body.EffectiveFrom {
			return nil, validation("effectiveTo precedes effectiveFrom")
		}
	}
	if err := validateMembershipTerms(body); err != nil {
		return nil, err
	}
	normalized := domain.NormalizePrice(domain.PriceInput{RecurringCents: body.RecurringCents, Frequency: body.BillingFrequency, MandatoryRecurringFeeCents: body.MandatoryRecurringFeeCents, MandatoryAnnualFeeCents: body.MandatoryAnnualFeeCents, InitiationFeeCents: body.InitiationFeeCents, Complete: body.PricingComplete})
	rows, err := queryMaps(r.Context(), s.db, `INSERT INTO gym_pricing(gym_id,plan_name,recurring_cents,billing_frequency,mandatory_recurring_fee_cents,mandatory_annual_fee_cents,initiation_fee_cents,ongoing_monthly_cents,first_year_monthly_cents,pricing_complete,source_url,effective_from,last_verified_at,effective_to,membership_type,contract_months,eligibility,drop_in_cents,trial_details,notes) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,now(),$13,$14,$15,$16,$17,$18,$19) RETURNING *`, gymID, body.PlanName, body.RecurringCents, body.BillingFrequency, body.MandatoryRecurringFeeCents, body.MandatoryAnnualFeeCents, body.InitiationFeeCents, normalized.OngoingMonthlyCents, normalized.FirstYearMonthlyCents, body.PricingComplete, body.SourceURL, body.EffectiveFrom, body.EffectiveTo, body.MembershipType, body.ContractMonths, body.Eligibility, body.DropInCents, body.TrialDetails, body.Notes)
	if err != nil {
		return nil, err
	}
	if err := s.audit(r, "GYM_PRICING_CREATED", "GYM", gymID, nil, rows[0]); err != nil {
		return nil, err
	}
	created(w, rows[0])
	return nil, nil
}

func (s *Server) adminEvents(_ http.ResponseWriter, r *http.Request) (any, error) {
	if err := adminOnly(r); err != nil {
		return nil, err
	}
	rows, err := queryMaps(r.Context(), s.db, `SELECT e.*,c.name AS city FROM events e JOIN cities c ON c.id=e.city_id ORDER BY e.start_at DESC LIMIT 250`)
	return map[string]any{"data": rows}, err
}

type eventInput struct {
	CityID                  string   `json:"cityId"`
	Slug                    string   `json:"slug"`
	Name                    string   `json:"name"`
	Organizer               *string  `json:"organizer"`
	Category                *string  `json:"category"`
	Description             *string  `json:"description"`
	StartAt                 string   `json:"startAt"`
	EndAt                   *string  `json:"endAt"`
	RegistrationDeadline    *string  `json:"registrationDeadline"`
	RegistrationStatus      string   `json:"registrationStatus"`
	Location                *string  `json:"location"`
	ExternalRegistrationURL *string  `json:"externalRegistrationUrl"`
	Sport                   *string  `json:"sport"`
	OfficialFitCalgary      bool     `json:"officialFitcalgary"`
	Tags                    []string `json:"tags"`
	SourceURL               *string  `json:"sourceUrl"`
	EventStatus             string   `json:"eventStatus"`
	PublishStatus           string   `json:"publishStatus"`
}

func (s *Server) adminCreateEvent(w http.ResponseWriter, r *http.Request) (any, error) {
	if err := adminOnly(r); err != nil {
		return nil, err
	}
	var body eventInput
	if err := decodeJSON(r, &body); err != nil {
		return nil, err
	}
	if body.RegistrationStatus == "" {
		body.RegistrationStatus = "OPEN"
	}
	if body.EventStatus == "" {
		body.EventStatus = "ACTIVE"
	}
	if body.PublishStatus == "" {
		body.PublishStatus = "DRAFT"
	}
	if !validUUID(body.CityID) || !slugPattern.MatchString(body.Slug) || len(strings.TrimSpace(body.Name)) < 2 || !oneOf(body.RegistrationStatus, "OPEN", "CLOSED", "NOT_APPLICABLE") || !oneOf(body.EventStatus, "ACTIVE", "CANCELLED", "POSTPONED") || !oneOf(body.PublishStatus, "DRAFT", "PUBLISHED", "ARCHIVED") {
		return nil, validation("event fields are invalid")
	}
	if _, err := time.Parse(time.RFC3339, body.StartAt); err != nil {
		return nil, validation("startAt must be an RFC3339 timestamp")
	}
	if body.Tags == nil {
		body.Tags = []string{}
	}
	rows, err := queryMaps(r.Context(), s.db, `INSERT INTO events(city_id,slug,name,organizer,category,description,start_at,end_at,registration_deadline,registration_status,location,external_registration_url,sport,official_fitcalgary,tags,source_url,event_status,publish_status) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18) RETURNING *`, body.CityID, body.Slug, strings.TrimSpace(body.Name), body.Organizer, body.Category, body.Description, body.StartAt, body.EndAt, body.RegistrationDeadline, body.RegistrationStatus, body.Location, body.ExternalRegistrationURL, body.Sport, body.OfficialFitCalgary, body.Tags, body.SourceURL, body.EventStatus, body.PublishStatus)
	if err != nil {
		return nil, err
	}
	if err := s.audit(r, "EVENT_CREATED", "EVENT", rows[0]["id"], nil, rows[0]); err != nil {
		return nil, err
	}
	created(w, rows[0])
	return nil, nil
}

func (s *Server) adminUpdateSetting(_ http.ResponseWriter, r *http.Request) (any, error) {
	if err := adminOnly(r); err != nil {
		return nil, err
	}
	key := chi.URLParam(r, "key")
	if !regexp.MustCompile(`^[a-z0-9_]+$`).MatchString(key) {
		return nil, validation("setting key is invalid")
	}
	var body struct {
		Value  any  `json:"value"`
		Public bool `json:"public"`
	}
	if err := decodeJSON(r, &body); err != nil {
		return nil, err
	}
	before, err := queryMaps(r.Context(), s.db, `SELECT * FROM app_settings WHERE key=$1`, key)
	if err != nil {
		return nil, err
	}
	encoded, _ := json.Marshal(body.Value)
	rows, err := queryMaps(r.Context(), s.db, `INSERT INTO app_settings(key,value,public,updated_by) VALUES($1,$2,$3,$4) ON CONFLICT(key) DO UPDATE SET value=EXCLUDED.value,public=EXCLUDED.public,updated_by=EXCLUDED.updated_by,updated_at=now() RETURNING *`, key, encoded, body.Public, identity(r).ProfileID)
	if err != nil {
		return nil, err
	}
	var old any
	if len(before) > 0 {
		old = before[0]
	}
	if err := s.audit(r, "SETTING_UPDATED", "SETTING", key, old, rows[0]); err != nil {
		return nil, err
	}
	return rows[0], nil
}

func (s *Server) adminGrantRole(w http.ResponseWriter, r *http.Request) (any, error) {
	if err := adminOnly(r); err != nil {
		return nil, err
	}
	profileID, role := chi.URLParam(r, "profileId"), chi.URLParam(r, "role")
	if !validUUID(profileID) || !validRole(role) {
		return nil, validation("profile id or role is invalid")
	}
	if _, err := s.db.Exec(r.Context(), `INSERT INTO user_roles(profile_id,role,granted_by) VALUES($1,$2,$3) ON CONFLICT DO NOTHING`, profileID, role, identity(r).ProfileID); err != nil {
		return nil, err
	}
	if err := s.audit(r, "ROLE_GRANTED", "PROFILE", profileID, nil, map[string]string{"role": role}); err != nil {
		return nil, err
	}
	noContent(w)
	return nil, nil
}

func (s *Server) adminRevokeRole(w http.ResponseWriter, r *http.Request) (any, error) {
	if err := adminOnly(r); err != nil {
		return nil, err
	}
	profileID, role := chi.URLParam(r, "profileId"), chi.URLParam(r, "role")
	if !validUUID(profileID) || !validRole(role) {
		return nil, validation("profile id or role is invalid")
	}
	if profileID == identity(r).ProfileID && role == "ADMIN" {
		return nil, &APIError{Status: http.StatusConflict, Code: "SELF_ADMIN_REMOVAL", Message: "An administrator cannot remove their own admin role"}
	}
	if _, err := s.db.Exec(r.Context(), `DELETE FROM user_roles WHERE profile_id=$1 AND role=$2`, profileID, role); err != nil {
		return nil, err
	}
	if err := s.audit(r, "ROLE_REVOKED", "PROFILE", profileID, map[string]string{"role": role}, nil); err != nil {
		return nil, err
	}
	noContent(w)
	return nil, nil
}

func (s *Server) adminAuditLog(_ http.ResponseWriter, r *http.Request) (any, error) {
	if err := adminOnly(r); err != nil {
		return nil, err
	}
	rows, err := queryMaps(r.Context(), s.db, `SELECT a.*,p.display_name AS actor FROM audit_logs a LEFT JOIN profiles p ON p.id=a.actor_profile_id ORDER BY a.created_at DESC LIMIT 500`)
	return map[string]any{"data": rows}, err
}

func (s *Server) audit(r *http.Request, action, entityType string, entityID, before, after any) error {
	beforeJSON, _ := json.Marshal(before)
	afterJSON, _ := json.Marshal(after)
	_, err := s.db.Exec(r.Context(), `INSERT INTO audit_logs(actor_profile_id,action,entity_type,entity_id,before_data,after_data,request_id) VALUES($1,$2,$3,$4,$5,$6,$7)`, identity(r).ProfileID, action, entityType, entityID, nullJSON(before, beforeJSON), nullJSON(after, afterJSON), middleware.GetReqID(r.Context()))
	return err
}

func nullJSON(value any, encoded []byte) any {
	if value == nil {
		return nil
	}
	return encoded
}

func validRole(role string) bool {
	return oneOf(role, "USER", "MODERATOR", "ADMIN", "PERSONAL_TRAINER", "JUDGE")
}
