package main

import (
	"encoding/json"
	"path/filepath"
	"strings"
	"testing"
)

func TestClientApprovedSourcesDecodeWithoutRecordLoss(t *testing.T) {
	dataDir := filepath.Join("..", "..", "..", "..", "data", "client-approved")
	tests := []struct {
		file, wrapper string
		want          int
		validate      func(json.RawMessage) bool
	}{
		{"fitcalgary_gyms.json", "", 273, func(raw json.RawMessage) bool {
			var row gymRecord
			return json.Unmarshal(raw, &row) == nil && clean(row.GymID) != "" && clean(row.LocationName) != ""
		}},
		{"sport_clubs.json", "clubs", 743, func(raw json.RawMessage) bool {
			var row clubRecord
			return json.Unmarshal(raw, &row) == nil && clean(row.ID) != "" && clean(row.ClubName) != "" && clean(row.Sport) != ""
		}},
		{"calgary_sport_competitions.json", "", 531, func(raw json.RawMessage) bool {
			var row eventRecord
			return json.Unmarshal(raw, &row) == nil && clean(row.ID) != "" && clean(row.Name) != ""
		}},
	}
	for _, tc := range tests {
		rows, err := decodeRows(filepath.Join(dataDir, tc.file), tc.wrapper)
		if err != nil {
			t.Fatalf("%s: %v", tc.file, err)
		}
		if len(rows) != tc.want {
			t.Fatalf("%s: got %d records, want %d", tc.file, len(rows), tc.want)
		}
		seen := map[string]bool{}
		for i, raw := range rows {
			if !tc.validate(raw) {
				t.Fatalf("%s record %d failed required-field validation", tc.file, i+1)
			}
			var key string
			switch tc.file {
			case "fitcalgary_gyms.json":
				var row gymRecord
				_ = json.Unmarshal(raw, &row)
				key = row.GymID
			case "sport_clubs.json":
				var row clubRecord
				_ = json.Unmarshal(raw, &row)
				key = row.ID
			default:
				var row eventRecord
				_ = json.Unmarshal(raw, &row)
				key = row.ID
			}
			key = strings.ToLower(strings.TrimSpace(key))
			if seen[key] {
				t.Fatalf("%s duplicate source id %q", tc.file, key)
			}
			seen[key] = true
		}
	}
}

func TestUnknownAndQuoteOnlyValuesStayUnknown(t *testing.T) {
	for _, value := range []string{"", " ", "'", `"`, "unknown", "N/A", "not available"} {
		if clean(value) != "" {
			t.Fatalf("expected %q to be omitted", value)
		}
	}
	if parseDate("2026-27 season") != nil {
		t.Fatal("a season range must not become a manufactured event date")
	}
	if parseDate("registration date not fetched") != nil {
		t.Fatal("missing date must remain nil")
	}
	if got := parseDate("Verified 2026-09-06"); got == nil || got.Format("2006-01-02") != "2026-09-06" {
		t.Fatalf("exact supplied date not preserved: %v", got)
	}
}

func TestEventDayRequiresOneExplicitCalendarDate(t *testing.T) {
	for source, expected := range map[string]string{
		"Sep 26, 2026": "2026-09-26",
		"Oct 24, 2026": "2026-10-24",
		"Dec 12, 2026": "2026-12-12",
	} {
		got := parseEventDay(source)
		if got == nil || got.Format("2006-01-02") != expected {
			t.Fatalf("%q: expected %s, got %v", source, expected, got)
		}
	}
	for _, source := range []string{
		"2026-27 season", "June 2027 (unconfirmed)",
		"Sep 26, 2026; Oct 1, 2026", "Expected Sep 26, 2026",
		"registration date not fetched", "2026 edition listed online",
	} {
		if got := parseEventDay(source); got != nil {
			t.Fatalf("%q must not become a single event day: %v", source, got)
		}
	}
}

func TestStableSourceSlugs(t *testing.T) {
	if got := slug("Calgary Sport & Social Club (CSSC) - CLB-0012"); got != "calgary-sport-social-club-cssc-clb-0012" {
		t.Fatalf("unexpected slug %q", got)
	}
}

func TestAllInPricingRequiresKnownMandatoryFees(t *testing.T) {
	ongoing, firstYear := 2500, 2700
	row := gymRecord{}
	if confirmedAllInPricing(row, &ongoing, &firstYear) {
		t.Fatal("unknown fees must not be treated as zero-dollar fees")
	}
	zero := 0.0
	row.Pricing.AnnualFee = &zero
	row.Pricing.EnrollmentFee = &zero
	if !confirmedAllInPricing(row, &ongoing, &firstYear) {
		t.Fatal("explicit zero-dollar fees permit a complete all-in estimate")
	}
	if confirmedAllInPricing(row, nil, &firstYear) {
		t.Fatal("missing normalized cost cannot be complete")
	}
}
