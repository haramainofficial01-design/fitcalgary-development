package httpapi

import (
	"net/http"

	"fitcalgary.ca/index/api/internal/domain"
	"github.com/go-chi/chi/v5"
)

func (s *Server) adminUpdatePricing(_ http.ResponseWriter, r *http.Request) (any, error) {
	if err := adminOnly(r); err != nil {
		return nil, err
	}
	gymID, id := chi.URLParam(r, "id"), chi.URLParam(r, "pricingId")
	if !validUUID(gymID) || !validUUID(id) {
		return nil, validation("Invalid gym or pricing ID")
	}
	var body pricingInput
	if err := decodeJSON(r, &body); err != nil {
		return nil, err
	}
	if err := validatePricing(body); err != nil {
		return nil, err
	}
	tx, err := s.db.Begin(r.Context())
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(r.Context())
	before, err := queryMaps(r.Context(), tx, `SELECT * FROM gym_pricing WHERE id=$1 AND gym_id=$2 FOR UPDATE`, id, gymID)
	if err != nil {
		return nil, err
	}
	if len(before) == 0 {
		return nil, &APIError{Status: 404, Code: "NOT_FOUND", Message: "Pricing plan not found"}
	}
	n := domain.NormalizePrice(domain.PriceInput{RecurringCents: body.RecurringCents, Frequency: body.BillingFrequency, MandatoryRecurringFeeCents: body.MandatoryRecurringFeeCents, MandatoryAnnualFeeCents: body.MandatoryAnnualFeeCents, InitiationFeeCents: body.InitiationFeeCents, Complete: body.PricingComplete})
	rows, err := queryMaps(r.Context(), tx, `UPDATE gym_pricing SET plan_name=$2,recurring_cents=$3,billing_frequency=$4,mandatory_recurring_fee_cents=$5,mandatory_annual_fee_cents=$6,initiation_fee_cents=$7,ongoing_monthly_cents=$8,first_year_monthly_cents=$9,pricing_complete=$10,source_url=$11,effective_from=$12,effective_to=$13,membership_type=$14,contract_months=$15,eligibility=$16,drop_in_cents=$17,trial_details=$18,notes=$19,last_verified_at=now(),updated_at=now() WHERE id=$1 RETURNING *`, id, body.PlanName, body.RecurringCents, body.BillingFrequency, body.MandatoryRecurringFeeCents, body.MandatoryAnnualFeeCents, body.InitiationFeeCents, n.OngoingMonthlyCents, n.FirstYearMonthlyCents, body.PricingComplete, body.SourceURL, body.EffectiveFrom, body.EffectiveTo, body.MembershipType, body.ContractMonths, body.Eligibility, body.DropInCents, body.TrialDetails, body.Notes)
	if err != nil {
		return nil, err
	}
	if err = auditTransaction(r, tx, "GYM_PRICING_UPDATED", "GYM", gymID, before[0], rows[0]); err != nil {
		return nil, err
	}
	if err = tx.Commit(r.Context()); err != nil {
		return nil, err
	}
	return rows[0], nil
}
