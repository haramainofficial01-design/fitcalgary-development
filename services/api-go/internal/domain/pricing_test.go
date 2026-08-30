package domain

import "testing"

func TestNormalizeBiweeklyUsesTwentySixPayments(t *testing.T) {
	got := NormalizePrice(PriceInput{RecurringCents: 1_500, Frequency: "BIWEEKLY", Complete: true})
	if got.OngoingMonthlyCents == nil || *got.OngoingMonthlyCents != 3_250 {
		t.Fatalf("expected 3250 monthly cents, got %#v", got.OngoingMonthlyCents)
	}
}

func TestNormalizeIncludesMandatoryAndFirstYearFees(t *testing.T) {
	got := NormalizePrice(PriceInput{RecurringCents: 2_000, Frequency: "MONTHLY", MandatoryRecurringFeeCents: 100, MandatoryAnnualFeeCents: 1_200, InitiationFeeCents: 600, Complete: true})
	if got.OngoingMonthlyCents == nil || *got.OngoingMonthlyCents != 2_200 {
		t.Fatalf("unexpected ongoing price: %#v", got.OngoingMonthlyCents)
	}
	if got.FirstYearMonthlyCents == nil || *got.FirstYearMonthlyCents != 2_250 {
		t.Fatalf("unexpected first-year price: %#v", got.FirstYearMonthlyCents)
	}
}

func TestIncompletePricingDoesNotInventAValue(t *testing.T) {
	got := NormalizePrice(PriceInput{RecurringCents: 2_000, Frequency: "MONTHLY", Complete: false})
	if got.OngoingMonthlyCents != nil || got.FirstYearMonthlyCents != nil {
		t.Fatalf("incomplete pricing must remain unknown: %#v", got)
	}
}

func TestFormatTime(t *testing.T) {
	if got := FormatTime(942); got != "15:42" {
		t.Fatalf("expected 15:42, got %s", got)
	}
}
