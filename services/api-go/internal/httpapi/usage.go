package httpapi

import (
	"context"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
)

// Limits are shared across service instances and tied to authenticated accounts,
// never to a caller-supplied forwarding header or an assumption that IP is identity.
func requestBudget(r *http.Request) (string, int) {
	if r.Method != "POST" && r.Method != "PUT" && r.Method != "DELETE" && r.Method != "PATCH" {
		return "", 0
	}
	path := r.URL.Path
	switch {
	case strings.HasPrefix(path, "/api/v1/analytics/"):
		return "analytics", 30
	case strings.HasPrefix(path, "/api/v1/admin/"):
		return "administration", 120
	case strings.HasPrefix(path, "/api/v1/judge/"):
		return "reviews", 60
	case strings.HasPrefix(path, "/api/v1/uploads/"):
		return "upload-parts", 600
	case strings.HasPrefix(path, "/api/v1/submissions"), strings.HasPrefix(path, "/api/v1/results/"):
		return "submissions", 40
	default:
		return "", 0
	}
}

func (s *Server) accountBudget(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		bucket, limit := requestBudget(r)
		if limit > 0 {
			var count int
			err := s.db.QueryRow(r.Context(), `WITH expired AS (DELETE FROM api_request_limits WHERE profile_id=$1 AND window_start<now()-interval '1 hour') INSERT INTO api_request_limits(profile_id,bucket,window_start,requests) VALUES($1,$2,date_trunc('minute',now()),1) ON CONFLICT(profile_id,bucket,window_start) DO UPDATE SET requests=api_request_limits.requests+1 RETURNING requests`, identity(r).ProfileID, bucket).Scan(&count)
			if err != nil {
				s.writeError(w, r, err)
				return
			}
			if count > limit {
				w.Header().Set("Retry-After", "60")
				s.writeError(w, r, &APIError{Status: 429, Code: "RATE_LIMITED", Message: "Please wait a moment before trying again."})
				return
			}
		}
		next.ServeHTTP(w, r)
	})
}

func metricFor(method, route string) string {
	key := method + " " + route
	return map[string]string{
		"GET /api/v1/gyms":                             "GYM_SEARCH",
		"GET /api/v1/gyms/{slug}":                      "GYM_VIEW",
		"GET /api/v1/clubs/{slug}":                     "CLUB_VIEW",
		"GET /api/v1/events/{slug}":                    "EVENT_VIEW",
		"GET /api/v1/leaderboards/{id}":                "BOARD_VIEW",
		"PUT /api/v1/saved-gyms/{gymId}":               "GYM_SAVED",
		"POST /api/v1/submissions":                     "SUBMISSION_CREATED",
		"POST /api/v1/results/community":               "COMMUNITY_RESULT_CREATED",
		"POST /api/v1/judge/submissions/{id}/decision": "REVIEW_DECISION",
	}[key]
}

// Hourly counters contain no identities, search terms, addresses or file metadata.
// A telemetry failure never changes a successfully completed product operation.
func (s *Server) productMetrics(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		response := middleware.NewWrapResponseWriter(w, r.ProtoMajor)
		next.ServeHTTP(response, r)
		if response.Status() < 200 || response.Status() >= 300 {
			return
		}
		name := metricFor(r.Method, chi.RouteContext(r.Context()).RoutePattern())
		if name == "" {
			return
		}
		ctx, cancel := context.WithTimeout(context.WithoutCancel(r.Context()), 200*time.Millisecond)
		defer cancel()
		if _, err := s.db.Exec(ctx, `INSERT INTO product_metrics(hour,event_name) VALUES(date_trunc('hour',now()),$1) ON CONFLICT(hour,event_name) DO UPDATE SET occurrences=product_metrics.occurrences+1`, name); err != nil {
			s.logger.Warn("product metrics temporarily unavailable")
		}
	})
}
