package httpapi

import (
	"github.com/go-chi/chi/v5"
	"net/http"
	"strconv"
	"strings"
	"time"
)

// State is derived from persisted timestamps, not a client-side clock. Explicit
// cancellation/postponement wins over the temporal state. An event without an
// end time is treated as completed after its start, without inventing a duration.
const eventPhaseSQL = `CASE WHEN item.event_status='CANCELLED' THEN 'CANCELLED' WHEN item.event_status='POSTPONED' THEN 'POSTPONED' WHEN item.start_at IS NULL AND item.start_date IS NULL THEN 'UNSCHEDULED' WHEN item.start_at IS NULL AND (now() AT TIME ZONE 'America/Edmonton')::date<item.start_date THEN 'UPCOMING' WHEN item.start_at IS NULL AND (now() AT TIME ZONE 'America/Edmonton')::date=item.start_date THEN 'CURRENT' WHEN item.start_at IS NULL THEN 'COMPLETED' WHEN now()<item.start_at THEN 'UPCOMING' WHEN now()<=COALESCE(item.end_at,item.start_at) THEN 'CURRENT' ELSE 'COMPLETED' END`

func (s *Server) listContent(r *http.Request, events bool) (any, error) {
	p, err := parseList(r)
	if err != nil {
		return nil, err
	}
	sport := strings.TrimSpace(r.URL.Query().Get("sport"))
	if len(sport) > 100 {
		return nil, validation("sport is too long")
	}
	table, extra, order := "clubs", "", "lower(name),id"
	conditions := ` AND ($3::text IS NULL OR item.category=$3) AND ($4::text='' OR item.sport ILIKE '%' || $4 || '%')`
	args := []any{p.City, like(p.Query), p.Category, sport, p.PageSize, (p.Page - 1) * p.PageSize}
	if events {
		table, extra, order = "events", ", "+eventPhaseSQL+" AS phase", "COALESCE(start_at,start_date::timestamp AT TIME ZONE 'America/Edmonton') NULLS LAST,id"
		phase := strings.ToUpper(strings.TrimSpace(r.URL.Query().Get("phase")))
		if phase != "" && !oneOf(phase, "UPCOMING", "CURRENT", "COMPLETED", "CANCELLED", "POSTPONED", "UNSCHEDULED") {
			return nil, validation("invalid event phase")
		}
		month := r.URL.Query().Get("month")
		if month != "" {
			if _, err := time.Parse("2006-01", month); err != nil {
				return nil, validation("month must use YYYY-MM")
			}
		}
		open := false
		if raw := r.URL.Query().Get("open"); raw != "" {
			open, err = strconv.ParseBool(raw)
			if err != nil {
				return nil, validation("open must be true or false")
			}
		}
		conditions += ` AND ($7::text='' OR (` + eventPhaseSQL + `)=$7) AND ($8::text='' OR COALESCE(to_char(item.start_at AT TIME ZONE 'America/Edmonton','YYYY-MM'),to_char(item.start_date,'YYYY-MM'))=$8) AND (NOT $9::boolean OR (item.registration_status='OPEN' AND item.event_status='ACTIVE' AND COALESCE(item.registration_deadline,item.start_at,(item.start_date+1)::timestamp AT TIME ZONE 'America/Edmonton')>=now()))`
		args = append(args, phase, month, open)
	}
	rows, err := queryMaps(r.Context(), s.db, `WITH filtered AS (SELECT item.*,c.name AS city,c.slug AS city_slug`+extra+` FROM `+table+` item JOIN cities c ON c.id=item.city_id WHERE item.publish_status='PUBLISHED' AND c.slug=$1 AND ($2::text IS NULL OR item.name ILIKE $2 OR item.sport ILIKE $2 OR item.description ILIKE $2)`+conditions+`), page AS (SELECT * FROM filtered ORDER BY `+order+` LIMIT $5 OFFSET $6) SELECT (SELECT count(*) FROM filtered) AS total,COALESCE((SELECT jsonb_agg(page ORDER BY `+order+`) FROM page),'[]'::jsonb) AS data`, args...)
	if err != nil {
		return nil, err
	}
	rows[0]["page"] = p.Page
	rows[0]["pageSize"] = p.PageSize
	return rows[0], nil
}

func (s *Server) getClub(_ http.ResponseWriter, r *http.Request) (any, error) {
	return s.getContent(r, false)
}
func (s *Server) getEvent(_ http.ResponseWriter, r *http.Request) (any, error) {
	return s.getContent(r, true)
}
func (s *Server) getContent(r *http.Request, events bool) (any, error) {
	p, err := parseList(r)
	if err != nil {
		return nil, err
	}
	slug := chi.URLParam(r, "slug")
	if len(slug) > 180 || !slugPattern.MatchString(slug) {
		return nil, validation("invalid content slug")
	}
	table, extra := "clubs", ""
	if events {
		table, extra = "events", ", "+eventPhaseSQL+" AS phase"
	}
	rows, err := queryMaps(r.Context(), s.db, `SELECT item.*,c.name AS city,c.slug AS city_slug`+extra+` FROM `+table+` item JOIN cities c ON c.id=item.city_id WHERE (item.slug=$1 OR item.id::text=$1) AND c.slug=$2 AND item.publish_status='PUBLISHED'`, slug, p.City)
	if err != nil {
		return nil, err
	}
	if len(rows) == 0 {
		return nil, &APIError{Status: 404, Code: "NOT_FOUND", Message: "Content not found"}
	}
	return rows[0], nil
}
