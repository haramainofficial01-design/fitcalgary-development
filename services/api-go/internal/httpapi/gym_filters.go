package httpapi

import (
	"net/http"
	"strconv"
	"strings"
)

type gymFilters struct {
	Area, Amenity *string
	Pricing, Sort string
	MaxMonthly    *int
}

func parseGymFilters(r *http.Request) (gymFilters, error) {
	q := r.URL.Query()
	f := gymFilters{Pricing: q.Get("pricing"), Sort: q.Get("sort")}
	if !oneOf(f.Pricing, "", "complete", "incomplete") || !oneOf(f.Sort, "", "cost", "name") {
		return f, validation("invalid pricing filter or sort")
	}
	if len(q.Get("area")) > 100 || len(q.Get("amenity")) > 80 {
		return f, validation("area or amenity is too long")
	}
	f.Area = optionalString(strings.TrimSpace(q.Get("area")), 100)
	f.Amenity = optionalString(strings.TrimSpace(q.Get("amenity")), 80)
	if raw := q.Get("maxMonthlyCents"); raw != "" {
		n, err := strconv.Atoi(raw)
		if err != nil || n < 0 || n > 100000000 {
			return f, validation("maxMonthlyCents must be a nonnegative integer up to 100000000")
		}
		f.MaxMonthly = &n
	}
	return f, nil
}
