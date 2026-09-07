package httpapi

import (
	"fmt"
	"net/http"
	"strconv"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
)

type listParams struct {
	Query    *string
	City     string
	Page     int
	PageSize int
	Category *string
}

func (s *Server) registerPublicRoutes(router chi.Router) {
	router.Get("/gyms", s.handle(s.listGyms))
	router.Get("/gyms/{slug}", s.handle(s.getGym))
	router.Get("/clubs", s.handle(s.listClubs))
	router.Get("/clubs/{slug}", s.handle(s.getClub))
	router.Get("/events", s.handle(s.listEvents))
	router.Get("/events/{slug}", s.handle(s.getEvent))
	router.Get("/disciplines", s.handle(s.listDisciplines))
	router.Get("/divisions", s.handle(s.listDivisions))
	router.Get("/cities", s.handle(s.listCities))
	router.Get("/leaderboards", s.handle(s.listLeaderboards))
	router.Get("/leaderboards/{id}", s.handle(s.getLeaderboard))
}

func parseList(r *http.Request) (listParams, error) {
	page, err := positiveInt(r.URL.Query().Get("page"), 1, 1, 1_000_000)
	if err != nil {
		return listParams{}, err
	}
	pageSize, err := positiveInt(r.URL.Query().Get("pageSize"), 20, 1, 100)
	if err != nil {
		return listParams{}, err
	}
	city := strings.TrimSpace(r.URL.Query().Get("city"))
	if city == "" {
		city = "calgary"
	}
	if len(city) > 80 {
		return listParams{}, validation("city is too long")
	}
	if len(r.URL.Query().Get("q")) > 120 || len(r.URL.Query().Get("category")) > 80 {
		return listParams{}, validation("search or category is too long")
	}
	return listParams{Query: optionalString(r.URL.Query().Get("q"), 120), City: city, Page: page, PageSize: pageSize, Category: optionalString(r.URL.Query().Get("category"), 80)}, nil
}

func (s *Server) listGyms(_ http.ResponseWriter, r *http.Request) (any, error) {
	params, err := parseList(r)
	if err != nil {
		return nil, err
	}
	filters, err := parseGymFilters(r)
	if err != nil {
		return nil, err
	}
	rows, err := queryMaps(r.Context(), s.db, `WITH directory AS (
SELECT g.id,g.slug,g.name,g.operator,g.neighbourhood AS area,c.name AS city,g.categories,g.amenities,
MIN(p.ongoing_monthly_cents) FILTER (WHERE p.pricing_complete) AS lowest_ongoing_monthly_cents,
MIN(p.first_year_monthly_cents) FILTER (WHERE p.pricing_complete) AS lowest_first_year_monthly_cents,
COALESCE(bool_and(p.pricing_complete),false) AS pricing_complete,g.updated_at
FROM gyms g JOIN cities c ON c.id=g.city_id
LEFT JOIN gym_pricing p ON p.gym_id=g.id AND (p.effective_from IS NULL OR p.effective_from<=CURRENT_DATE) AND (p.effective_to IS NULL OR p.effective_to>=CURRENT_DATE)
WHERE g.publish_status='PUBLISHED' AND c.slug=$1
AND ($2::text IS NULL OR g.name ILIKE $2 OR COALESCE(g.operator,'') ILIKE $2 OR COALESCE(g.neighbourhood,'') ILIKE $2)
AND ($3::text IS NULL OR $3=ANY(g.categories))
AND ($6::text IS NULL OR g.neighbourhood ILIKE '%' || $6 || '%')
AND ($7::text IS NULL OR $7=ANY(g.amenities)) GROUP BY g.id,c.name)
SELECT *,COUNT(*) OVER() AS total FROM directory
WHERE ($8::text='' OR ($8='complete' AND pricing_complete) OR ($8='incomplete' AND NOT pricing_complete))
AND ($9::int IS NULL OR lowest_ongoing_monthly_cents<=$9)
ORDER BY CASE WHEN $10='cost' THEN lowest_ongoing_monthly_cents END ASC NULLS LAST,lower(name),id
LIMIT $4 OFFSET $5`, params.City, like(params.Query), params.Category, params.PageSize, (params.Page-1)*params.PageSize, filters.Area, filters.Amenity, filters.Pricing, filters.MaxMonthly, filters.Sort)
	if err != nil {
		return nil, err
	}
	return paginated(rows, params.Page, params.PageSize), nil
}

func (s *Server) getGym(_ http.ResponseWriter, r *http.Request) (any, error) {
	slug := chi.URLParam(r, "slug")
	if strings.TrimSpace(slug) == "" || len(slug) > 180 {
		return nil, validation("invalid gym slug")
	}
	params, err := parseList(r)
	if err != nil {
		return nil, err
	}
	rows, err := queryMaps(r.Context(), s.db, `SELECT g.*,c.name AS city,c.slug AS city_slug,COALESCE(json_agg(p ORDER BY p.ongoing_monthly_cents NULLS LAST,p.id) FILTER (WHERE p.id IS NOT NULL),'[]') AS pricing FROM gyms g JOIN cities c ON c.id=g.city_id LEFT JOIN gym_pricing p ON p.gym_id=g.id AND (p.effective_from IS NULL OR p.effective_from<=CURRENT_DATE) AND (p.effective_to IS NULL OR p.effective_to>=CURRENT_DATE) WHERE g.slug=$1 AND c.slug=$2 AND g.publish_status='PUBLISHED' GROUP BY g.id,c.name,c.slug`, slug, params.City)
	if err != nil {
		return nil, err
	}
	if len(rows) == 0 {
		return nil, &APIError{Status: http.StatusNotFound, Code: "NOT_FOUND", Message: "Gym not found"}
	}
	return rows[0], nil
}

func (s *Server) listClubs(_ http.ResponseWriter, r *http.Request) (any, error) {
	return s.listContent(r, false)
}

func (s *Server) listEvents(_ http.ResponseWriter, r *http.Request) (any, error) {
	return s.listContent(r, true)
}

func (s *Server) listDisciplines(_ http.ResponseWriter, r *http.Request) (any, error) {
	rows, err := queryMaps(r.Context(), s.db, `SELECT id,slug,display_name,metric_type,unit,ranking_direction,evidence_type,official_eligible,community_eligible,rules_version,minimum_metric,maximum_metric,verification_checklist FROM disciplines WHERE active=true ORDER BY display_name`)
	return map[string]any{"data": rows}, err
}

func (s *Server) listLeaderboards(_ http.ResponseWriter, r *http.Request) (any, error) {
	discipline := optionalString(r.URL.Query().Get("discipline"), 120)
	division := optionalString(r.URL.Query().Get("division"), 120)
	region := optionalString(r.URL.Query().Get("region"), 120)
	boardType := optionalString(r.URL.Query().Get("boardType"), 40)
	if boardType != nil && !oneOf(*boardType, "OFFICIAL", "COMMUNITY") {
		return nil, validation("boardType must be OFFICIAL or COMMUNITY")
	}
	rows, err := queryMaps(r.Context(), s.db, `SELECT l.id,l.board_type,l.visible,l.event_id,d.id AS discipline_id,d.slug AS discipline_slug,d.display_name AS discipline_name,d.metric_type,d.unit,d.ranking_direction,v.id AS division_id,v.slug AS division_slug,v.display_label AS division_label,r.id AS region_id,r.slug AS region_slug,r.name AS region_name,e.name AS event_name,(SELECT count(*) FROM ranked_results rs WHERE rs.leaderboard_id=l.id) AS entry_count FROM leaderboards l JOIN disciplines d ON d.id=l.discipline_id JOIN divisions v ON v.id=l.division_id JOIN regions r ON r.id=l.region_id LEFT JOIN events e ON e.id=l.event_id WHERE l.visible=true AND d.active AND v.active AND ($1::text IS NULL OR d.slug=$1) AND ($2::text IS NULL OR v.slug=$2) AND ($3::text IS NULL OR r.slug=$3) AND ($4::text IS NULL OR l.board_type=$4) ORDER BY d.display_name,v.minimum_age NULLS FIRST,v.display_label,l.board_type`, discipline, division, region, boardType)
	if err != nil {
		return nil, err
	}
	return map[string]any{"data": rows}, nil
}

func (s *Server) getLeaderboard(_ http.ResponseWriter, r *http.Request) (any, error) {
	id := chi.URLParam(r, "id")
	if _, err := uuid.Parse(id); err != nil {
		return nil, validation("leaderboard id must be a UUID")
	}
	boards, err := queryMaps(r.Context(), s.db, `SELECT l.id,l.board_type,d.id AS discipline_id,d.slug,d.display_name,d.metric_type,d.unit,d.ranking_direction,v.id AS division_id,v.display_label,r.id AS region_id,r.name AS region_name FROM leaderboards l JOIN disciplines d ON d.id=l.discipline_id JOIN divisions v ON v.id=l.division_id JOIN regions r ON r.id=l.region_id WHERE l.id=$1 AND l.visible=true AND d.active AND v.active`, id)
	if err != nil {
		return nil, err
	}
	if len(boards) == 0 {
		return nil, &APIError{Status: http.StatusNotFound, Code: "NOT_FOUND", Message: "Leaderboard not found"}
	}
	board := boards[0]

	params, err := parseList(r)
	if err != nil {
		return nil, err
	}
	entries, err := queryMaps(r.Context(), s.db, `SELECT id AS result_id,rank,
 (SELECT rh.previous_rank FROM ranking_history rh WHERE rh.result_id=ranked_results.id ORDER BY rh.calculated_at DESC,rh.id DESC LIMIT 1) AS previous_rank,
 CASE WHEN public_profile THEN profile_id END AS profile_id,
 CASE WHEN public_profile THEN display_name ELSE 'Private athlete' END AS display_name,
 CASE WHEN public_profile THEN gym_name END AS gym_name,
 normalized_metric,display_metric,verified_at,verification_type
 FROM ranked_results WHERE leaderboard_id=$1 ORDER BY rank LIMIT $2 OFFSET $3`, id, params.PageSize, (params.Page-1)*params.PageSize)
	if err != nil {
		return nil, err
	}
	return map[string]any{
		"id": board["id"], "boardType": board["board_type"],
		"discipline": map[string]any{"id": board["discipline_id"], "slug": board["slug"], "name": board["display_name"], "metricType": board["metric_type"], "unit": board["unit"], "rankingDirection": board["ranking_direction"]},
		"division":   map[string]any{"id": board["division_id"], "label": board["display_label"]},
		"region":     map[string]any{"id": board["region_id"], "name": board["region_name"]}, "entries": entries,
	}, nil
}

func paginated(rows []map[string]any, page, pageSize int) map[string]any {
	var total int64
	if len(rows) > 0 {
		switch raw := rows[0]["total"].(type) {
		case int64:
			total = raw
		case int32:
			total = int64(raw)
		case string:
			total, _ = strconv.ParseInt(raw, 10, 64)
		}
	}
	for _, row := range rows {
		delete(row, "total")
	}
	return map[string]any{"data": rows, "page": page, "pageSize": pageSize, "total": total}
}

func positiveInt(raw string, fallback, minimum, maximum int) (int, error) {
	if strings.TrimSpace(raw) == "" {
		return fallback, nil
	}
	value, err := strconv.Atoi(raw)
	if err != nil || value < minimum || value > maximum {
		return 0, validation(fmt.Sprintf("value must be between %d and %d", minimum, maximum))
	}
	return value, nil
}

func optionalString(raw string, maximum int) *string {
	value := strings.TrimSpace(raw)
	if value == "" || len(value) > maximum {
		return nil
	}
	return &value
}

func like(value *string) *string {
	if value == nil {
		return nil
	}
	wrapped := "%" + *value + "%"
	return &wrapped
}

func validation(message string) error {
	return &APIError{Status: http.StatusUnprocessableEntity, Code: "VALIDATION_ERROR", Message: message}
}
