package httpapi

import (
	"math"
	"testing"
	"time"
)

func TestDivisionAndMetricRules(t *testing.T) {
	date := time.Date(2026, 9, 4, 0, 0, 0, 0, time.UTC)
	birth := time.Date(2003, 9, 5, 0, 0, 0, 0, time.UTC)
	min, max := 18, 22
	women, men := "WOMEN", "MEN"
	if !divisionEligible(&birth, &women, date, &min, &max, true, true, false, &women) {
		t.Fatal("birthday boundary excluded eligible athlete")
	}
	if divisionEligible(&birth, &women, date.AddDate(0, 0, 1), &min, &max, true, true, false, &women) {
		t.Fatal("over-age athlete eligible")
	}
	if divisionEligible(&birth, &men, date, nil, nil, true, true, true, &women) {
		t.Fatal("sex category bypassed in open division")
	}
	if divisionEligible(nil, &women, date, &min, &max, true, true, false, &women) {
		t.Fatal("missing DOB accepted")
	}
	for _, v := range []float64{-1, 0, 2.5, math.NaN(), math.Inf(1)} {
		if validMetric(v, 0, nil, "REPETITIONS") {
			t.Fatalf("invalid repetition value %v", v)
		}
	}
	upper := 100.0
	if !validMetric(100, 1, &upper, "WEIGHT") || validMetric(101, 1, &upper, "WEIGHT") {
		t.Fatal("configured limits ignored")
	}
	if resultLabel(125.5, "WEIGHT", "kg") != "125.5 kg" || resultLabel(942, "TIME", "seconds") != "15:42" {
		t.Fatal("metric formatting lost units")
	}
	raw := []byte(`[{"key":"form","label":"Form follows the rules"}]`)
	if checkRequiredChecklist(raw, map[string]bool{"visible": true}) == nil {
		t.Fatal("missing published check accepted")
	}
	if err := checkRequiredChecklist(raw, map[string]bool{"form": true}); err != nil {
		t.Fatal(err)
	}
}
