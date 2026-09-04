package httpapi

func validateMembershipTerms(body pricingInput) error {
	for _, item := range []struct {
		value *string
		max   int
	}{{body.MembershipType, 100}, {body.Eligibility, 500}, {body.TrialDetails, 1000}, {body.Notes, 2000}} {
		if item.value != nil && len(*item.value) > item.max {
			return validation("membership details are too long")
		}
	}
	if body.ContractMonths != nil && (*body.ContractMonths < 0 || *body.ContractMonths > 120) {
		return validation("contractMonths must be between 0 and 120")
	}
	if body.DropInCents != nil && (*body.DropInCents < 0 || *body.DropInCents > 100000000) {
		return validation("dropInCents is outside the supported range")
	}
	for _, cents := range []int{body.RecurringCents, body.MandatoryRecurringFeeCents, body.MandatoryAnnualFeeCents, body.InitiationFeeCents} {
		if cents > 100000000 {
			return validation("pricing exceeds the supported range")
		}
	}
	return nil
}
