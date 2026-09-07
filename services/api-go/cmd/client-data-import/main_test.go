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

func TestStableSourceSlugs(t *testing.T) {
	if got := slug("Calgary Sport & Social Club (CSSC) - CLB-0012"); got != "calgary-sport-social-club-cssc-clb-0012" {
		t.Fatalf("unexpected slug %q", got)
	}
}
