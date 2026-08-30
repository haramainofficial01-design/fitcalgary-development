package domain

import "math"

type PriceInput struct {
	RecurringCents             int
	Frequency                  string
	MandatoryRecurringFeeCents int
	MandatoryAnnualFeeCents    int
	InitiationFeeCents         int
	Complete                   bool
}

type NormalizedPrice struct {
	OngoingMonthlyCents   *int
	FirstYearMonthlyCents *int
}

func NormalizePrice(input PriceInput) NormalizedPrice {
	if !input.Complete {
		return NormalizedPrice{}
	}
	payments := map[string]float64{"WEEKLY": 52, "BIWEEKLY": 26, "MONTHLY": 12, "QUARTERLY": 4, "ANNUALLY": 1}[input.Frequency]
	if payments == 0 {
		return NormalizedPrice{}
	}
	ongoing := int(math.Round((float64(input.RecurringCents+input.MandatoryRecurringFeeCents)*payments + float64(input.MandatoryAnnualFeeCents)) / 12))
	firstYear := int(math.Round((float64(input.RecurringCents+input.MandatoryRecurringFeeCents)*payments + float64(input.MandatoryAnnualFeeCents+input.InitiationFeeCents)) / 12))
	return NormalizedPrice{OngoingMonthlyCents: &ongoing, FirstYearMonthlyCents: &firstYear}
}

func FormatTime(seconds float64) string {
	total := int(math.Round(seconds))
	return fmtInt(total/60) + ":" + twoDigits(total%60)
}

func fmtInt(value int) string {
	if value == 0 {
		return "0"
	}
	digits := make([]byte, 0, 12)
	for value > 0 {
		digits = append(digits, byte('0'+value%10))
		value /= 10
	}
	for i, j := 0, len(digits)-1; i < j; i, j = i+1, j-1 {
		digits[i], digits[j] = digits[j], digits[i]
	}
	return string(digits)
}

func twoDigits(value int) string {
	if value < 10 {
		return "0" + fmtInt(value)
	}
	return fmtInt(value)
}
