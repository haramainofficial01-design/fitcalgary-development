package httpapi

import (
	"net/http/httptest"
	"testing"
)

func TestRequestBudgetBoundaries(t *testing.T) {
	for _, item := range []struct {
		method, path, bucket string
		limit                int
	}{
		{"GET", "/api/v1/submissions", "", 0},
		{"POST", "/api/v1/submissions", "submissions", 40},
		{"POST", "/api/v1/uploads/opaque/parts/1", "upload-parts", 600},
		{"POST", "/api/v1/admin/announcements", "administration", 120},
		{"POST", "/api/v1/judge/submissions/opaque/decision", "reviews", 60},
	} {
		bucket, limit := requestBudget(httptest.NewRequest(item.method, item.path, nil))
		if bucket != item.bucket || limit != item.limit {
			t.Fatalf("wrong budget for %s", item.path)
		}
	}
}

func TestMetricAllowlist(t *testing.T) {
	if metricFor("GET", "/api/v1/gyms/{slug}") != "GYM_VIEW" {
		t.Fatal("gym view untracked")
	}
	for _, route := range []string{"/api/v1/profile", "/api/v1/judge/submissions/{id}/evidence", "/api/v1/admin/users", "/api/v1/uploads/{id}/parts/{part}"} {
		if metricFor("GET", route) != "" {
			t.Fatal("sensitive route entered telemetry")
		}
	}
}
