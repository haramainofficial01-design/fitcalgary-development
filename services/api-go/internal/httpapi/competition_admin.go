package httpapi

import (
	"encoding/json"
	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"math"
	"net/http"
	"strings"
)

var administrativeQueries = map[string]string{
	"disciplines":   `SELECT * FROM disciplines ORDER BY display_name`,
	"divisions":     `SELECT * FROM divisions ORDER BY minimum_age NULLS FIRST,display_label`,
	"leaderboards":  `SELECT l.*,d.display_name AS discipline,v.display_label AS division,r.name AS region,(SELECT count(*) FROM ranked_results rr WHERE rr.leaderboard_id=l.id) AS athletes FROM leaderboards l JOIN disciplines d ON d.id=l.discipline_id JOIN divisions v ON v.id=l.division_id JOIN regions r ON r.id=l.region_id ORDER BY d.display_name,v.display_label LIMIT 500`,
	"submissions":   `SELECT s.id,s.profile_id,s.discipline_id,s.claimed_metric,s.status,s.board_type,s.assigned_judge_id,s.submitted_at,s.decided_at,p.display_name AS athlete,d.display_name AS discipline FROM submissions s JOIN profiles p ON p.id=s.profile_id JOIN disciplines d ON d.id=s.discipline_id ORDER BY s.created_at DESC LIMIT 250`,
	"notifications": `SELECT id,profile_id,type,title,delivery_status,attempt_count,last_error_code,created_at,opened_at FROM notifications ORDER BY created_at DESC LIMIT 250`,
	"settings":      `SELECT key,value,public,updated_at FROM app_settings WHERE key<>'development_fixture_batch' ORDER BY key`,
	"pricing":       `SELECT p.*,g.name AS gym FROM gym_pricing p JOIN gyms g ON g.id=p.gym_id ORDER BY p.updated_at DESC LIMIT 500`,
	"moderation":    `SELECT m.id,m.target_profile_id,p.display_name,m.action,m.reason,m.created_at FROM moderation_actions m LEFT JOIN profiles p ON p.id=m.target_profile_id ORDER BY m.created_at DESC LIMIT 250`,
	"analytics":     `SELECT event_name,count(*) AS occurrences,max(occurred_at) AS latest FROM analytics_events GROUP BY event_name ORDER BY occurrences DESC LIMIT 100`,
}

func (s *Server) registerCompetitionAdmin(router chi.Router) {
	for key := range administrativeQueries {
		resource := key
		router.Get("/admin/"+resource, s.handle(func(_ http.ResponseWriter, r *http.Request) (any, error) {
			if err := adminOnly(r); err != nil {
				return nil, err
			}
			rows, err := queryMaps(r.Context(), s.db, administrativeQueries[resource])
			return map[string]any{"data": rows}, err
		}))
	}
	router.Post("/admin/disciplines", s.handle(s.adminSaveDiscipline))
	router.Put("/admin/disciplines/{id}", s.handle(s.adminSaveDiscipline))
	router.Post("/admin/divisions", s.handle(s.adminSaveDivision))
	router.Put("/admin/divisions/{id}", s.handle(s.adminSaveDivision))
	router.Post("/admin/leaderboards", s.handle(s.adminSaveBoard))
	router.Put("/admin/leaderboards/{id}", s.handle(s.adminSaveBoard))
}

type disciplineInput struct {
	Slug              string   `json:"slug"`
	DisplayName       string   `json:"displayName"`
	MetricType        string   `json:"metricType"`
	Unit              string   `json:"unit"`
	RankingDirection  string   `json:"rankingDirection"`
	EvidenceType      string   `json:"evidenceType"`
	MinimumMetric     float64  `json:"minimumMetric"`
	MaximumMetric     *float64 `json:"maximumMetric"`
	OfficialEligible  bool     `json:"officialEligible"`
	CommunityEligible bool     `json:"communityEligible"`
	Active            bool     `json:"active"`
	Checklist         []struct {
		Key   string `json:"key"`
		Label string `json:"label"`
	} `json:"verificationChecklist"`
}

func validateDiscipline(b disciplineInput) error {
	if len(b.Slug) > 120 || !slugPattern.MatchString(b.Slug) || len(strings.TrimSpace(b.DisplayName)) < 2 || len(b.DisplayName) > 180 || len(strings.TrimSpace(b.Unit)) == 0 || len(b.Unit) > 30 {
		return validation("Discipline name, slug or unit is invalid")
	}
	if !oneOf(b.MetricType, "TIME", "REPETITIONS", "WEIGHT", "DISTANCE", "POINTS", "CUSTOM_NUMERIC") || !oneOf(b.RankingDirection, "LOWER_IS_BETTER", "HIGHER_IS_BETTER") || !oneOf(b.EvidenceType, "VIDEO", "ACTIVITY_OR_OFFICIAL") {
		return validation("Choose a supported metric, ranking direction and evidence type")
	}
	if math.IsNaN(b.MinimumMetric) || math.IsInf(b.MinimumMetric, 0) || b.MinimumMetric < 0 || (b.MaximumMetric != nil && (!validMetric(*b.MaximumMetric, 0, nil, "WEIGHT") || *b.MaximumMetric <= b.MinimumMetric)) {
		return validation("Metric bounds are invalid")
	}
	if len(b.Checklist) > 40 {
		return validation("Too many verification checks")
	}
	keys := map[string]bool{}
	for _, c := range b.Checklist {
		if c.Key == "" || len(c.Key) > 80 || keys[c.Key] || strings.TrimSpace(c.Label) == "" || len(c.Label) > 500 {
			return validation("Verification checks need unique keys and clear labels")
		}
		keys[c.Key] = true
	}
	return nil
}
func auditTransaction(r *http.Request, tx pgx.Tx, action, entity string, id, before, after any) error {
	old, _ := json.Marshal(before)
	next, _ := json.Marshal(after)
	_, err := tx.Exec(r.Context(), `INSERT INTO audit_logs(actor_profile_id,action,entity_type,entity_id,before_data,after_data,request_id) VALUES($1,$2,$3,$4,$5,$6,$7)`, identity(r).ProfileID, action, entity, id, nullJSON(before, old), nullJSON(after, next), middleware.GetReqID(r.Context()))
	return err
}
func administrativeID(r *http.Request) (string, error) {
	if r.Method == http.MethodPost {
		return uuid.NewString(), nil
	}
	id := chi.URLParam(r, "id")
	if !validUUID(id) {
		return "", validation("Invalid record ID")
	}
	return id, nil
}
func (s *Server) adminSaveDiscipline(w http.ResponseWriter, r *http.Request) (any, error) {
	if err := adminOnly(r); err != nil {
		return nil, err
	}
	var b disciplineInput
	if err := decodeJSON(r, &b); err != nil {
		return nil, err
	}
	if err := validateDiscipline(b); err != nil {
		return nil, err
	}
	id, err := administrativeID(r)
	if err != nil {
		return nil, err
	}
	tx, err := s.db.Begin(r.Context())
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(r.Context())
	before, err := queryMaps(r.Context(), tx, `SELECT * FROM disciplines WHERE id=$1 FOR UPDATE`, id)
	if err != nil {
		return nil, err
	}
	if r.Method == http.MethodPut && len(before) == 0 {
		return nil, pgx.ErrNoRows
	}
	if len(before) > 0 {
		var activeWork bool
		if err = tx.QueryRow(r.Context(), `SELECT EXISTS(SELECT 1 FROM submissions WHERE discipline_id=$1 AND status IN ('DRAFT','UPLOADING','PENDING_REVIEW'))`, id).Scan(&activeWork); err != nil {
			return nil, err
		}
		if activeWork {
			return nil, &APIError{Status: 409, Code: "RULES_IN_USE", Message: "Resolve active submissions before changing their discipline rules"}
		}
		var results bool
		if err = tx.QueryRow(r.Context(), `SELECT EXISTS(SELECT 1 FROM results rs JOIN leaderboards l ON l.id=rs.leaderboard_id WHERE l.discipline_id=$1)`, id).Scan(&results); err != nil {
			return nil, err
		}
		if results && (before[0]["metric_type"] != b.MetricType || before[0]["unit"] != b.Unit || before[0]["ranking_direction"] != b.RankingDirection) {
			return nil, &APIError{Status: 409, Code: "METRIC_IN_USE", Message: "Create a new discipline to change the metric of existing results"}
		}
	}
	if b.Checklist == nil {
		b.Checklist = []struct {
			Key   string `json:"key"`
			Label string `json:"label"`
		}{}
	}
	checklist, _ := json.Marshal(b.Checklist)
	rows, err := queryMaps(r.Context(), tx, `INSERT INTO disciplines(id,slug,display_name,metric_type,unit,ranking_direction,evidence_type,minimum_metric,maximum_metric,official_eligible,community_eligible,active,verification_checklist) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13) ON CONFLICT(id) DO UPDATE SET slug=EXCLUDED.slug,display_name=EXCLUDED.display_name,metric_type=EXCLUDED.metric_type,unit=EXCLUDED.unit,ranking_direction=EXCLUDED.ranking_direction,evidence_type=EXCLUDED.evidence_type,minimum_metric=EXCLUDED.minimum_metric,maximum_metric=EXCLUDED.maximum_metric,official_eligible=EXCLUDED.official_eligible,community_eligible=EXCLUDED.community_eligible,active=EXCLUDED.active,verification_checklist=EXCLUDED.verification_checklist,rules_version=disciplines.rules_version+1,updated_at=now() RETURNING *`, id, b.Slug, b.DisplayName, b.MetricType, b.Unit, b.RankingDirection, b.EvidenceType, b.MinimumMetric, b.MaximumMetric, b.OfficialEligible, b.CommunityEligible, b.Active, checklist)
	if err != nil {
		return nil, err
	}
	if err = auditTransaction(r, tx, "DISCIPLINE_SAVED", "DISCIPLINE", id, before, rows[0]); err != nil {
		return nil, err
	}
	if err = tx.Commit(r.Context()); err != nil {
		return nil, err
	}
	if r.Method == http.MethodPost {
		created(w, rows[0])
		return nil, nil
	}
	return rows[0], nil
}

type divisionInput struct {
	Slug             string `json:"slug"`
	Label            string `json:"displayLabel"`
	MinimumAge       *int   `json:"minimumAge"`
	MaximumAge       *int   `json:"maximumAge"`
	MinimumInclusive bool   `json:"minimumInclusive"`
	MaximumInclusive bool   `json:"maximumInclusive"`
	Open             bool   `json:"open"`
	SexCategory      string `json:"sexCategory"`
	Active           bool   `json:"active"`
}

func (s *Server) adminSaveDivision(w http.ResponseWriter, r *http.Request) (any, error) {
	if err := adminOnly(r); err != nil {
		return nil, err
	}
	var b divisionInput
	if err := decodeJSON(r, &b); err != nil {
		return nil, err
	}
	if !slugPattern.MatchString(b.Slug) || len(b.Slug) > 120 || len(strings.TrimSpace(b.Label)) < 2 || len(b.Label) > 120 || !oneOf(b.SexCategory, "ALL", "MEN", "WOMEN") || (b.MinimumAge != nil && (*b.MinimumAge < 0 || *b.MinimumAge > 120)) || (b.MaximumAge != nil && (*b.MaximumAge < 0 || *b.MaximumAge > 120)) || (b.MinimumAge != nil && b.MaximumAge != nil && *b.MinimumAge > *b.MaximumAge) || (b.Open && (b.MinimumAge != nil || b.MaximumAge != nil)) {
		return nil, validation("Division category or age bounds are invalid")
	}
	id, err := administrativeID(r)
	if err != nil {
		return nil, err
	}
	tx, err := s.db.Begin(r.Context())
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(r.Context())
	before, err := queryMaps(r.Context(), tx, `SELECT * FROM divisions WHERE id=$1 FOR UPDATE`, id)
	if err != nil {
		return nil, err
	}
	if r.Method == http.MethodPut && len(before) == 0 {
		return nil, pgx.ErrNoRows
	}
	if len(before) > 0 {
		var used bool
		if err = tx.QueryRow(r.Context(), `SELECT EXISTS(SELECT 1 FROM leaderboards WHERE division_id=$1) OR EXISTS(SELECT 1 FROM submissions WHERE division_id=$1)`, id).Scan(&used); err != nil {
			return nil, err
		}
		if used {
			return nil, &APIError{Status: 409, Code: "DIVISION_IN_USE", Message: "Create a new division version rather than changing eligibility attached to existing performances"}
		}
	}
	rows, err := queryMaps(r.Context(), tx, `INSERT INTO divisions(id,slug,display_label,minimum_age,maximum_age,minimum_inclusive,maximum_inclusive,open,sex_category,active) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) ON CONFLICT(id) DO UPDATE SET slug=EXCLUDED.slug,display_label=EXCLUDED.display_label,minimum_age=EXCLUDED.minimum_age,maximum_age=EXCLUDED.maximum_age,minimum_inclusive=EXCLUDED.minimum_inclusive,maximum_inclusive=EXCLUDED.maximum_inclusive,open=EXCLUDED.open,sex_category=EXCLUDED.sex_category,active=EXCLUDED.active,version=divisions.version+1,updated_at=now() RETURNING *`, id, b.Slug, b.Label, b.MinimumAge, b.MaximumAge, b.MinimumInclusive, b.MaximumInclusive, b.Open, b.SexCategory, b.Active)
	if err != nil {
		return nil, err
	}
	if err = auditTransaction(r, tx, "DIVISION_SAVED", "DIVISION", id, before, rows[0]); err != nil {
		return nil, err
	}
	if err = tx.Commit(r.Context()); err != nil {
		return nil, err
	}
	if r.Method == http.MethodPost {
		created(w, rows[0])
		return nil, nil
	}
	return rows[0], nil
}
func (s *Server) adminSaveBoard(w http.ResponseWriter, r *http.Request) (any, error) {
	if err := adminOnly(r); err != nil {
		return nil, err
	}
	var b struct {
		RegionID     string `json:"regionId"`
		DisciplineID string `json:"disciplineId"`
		DivisionID   string `json:"divisionId"`
		BoardType    string `json:"boardType"`
		Visible      bool   `json:"visible"`
	}
	if err := decodeJSON(r, &b); err != nil {
		return nil, err
	}
	if !validUUID(b.RegionID) || !validUUID(b.DisciplineID) || !validUUID(b.DivisionID) || !oneOf(b.BoardType, "OFFICIAL", "COMMUNITY") {
		return nil, validation("Board configuration is invalid")
	}
	tx, err := s.db.Begin(r.Context())
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(r.Context())
	var id string
	if r.Method == http.MethodPost {
		id, err = ensureBoard(r, tx, b.RegionID, b.DisciplineID, b.DivisionID, b.BoardType)
	} else {
		id, err = administrativeID(r)
	}
	if err != nil {
		return nil, err
	}
	before, err := queryMaps(r.Context(), tx, `SELECT * FROM leaderboards WHERE id=$1 FOR UPDATE`, id)
	if err != nil {
		return nil, err
	}
	if len(before) == 0 {
		return nil, pgx.ErrNoRows
	}
	if before[0]["region_id"] != b.RegionID || before[0]["discipline_id"] != b.DisciplineID || before[0]["division_id"] != b.DivisionID || before[0]["board_type"] != b.BoardType {
		return nil, validation("Create a different board to change its discipline, division, region or verification class")
	}
	rows, err := queryMaps(r.Context(), tx, `UPDATE leaderboards SET visible=$2,updated_at=now() WHERE id=$1 RETURNING *`, id, b.Visible)
	if err != nil {
		return nil, err
	}
	if err = auditTransaction(r, tx, "BOARD_VISIBILITY_SET", "LEADERBOARD", id, before[0], rows[0]); err != nil {
		return nil, err
	}
	if err = tx.Commit(r.Context()); err != nil {
		return nil, err
	}
	if r.Method == http.MethodPost {
		created(w, rows[0])
		return nil, nil
	}
	return rows[0], nil
}
