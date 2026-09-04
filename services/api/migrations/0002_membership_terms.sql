-- Additive membership metadata. Unknown Client terms remain NULL.
ALTER TABLE gym_pricing
 ADD COLUMN membership_type text CHECK (length(membership_type)<=100),
 ADD COLUMN contract_months integer CHECK (contract_months>=0 AND contract_months<=120),
 ADD COLUMN eligibility text CHECK (length(eligibility)<=500),
 ADD COLUMN drop_in_cents integer CHECK (drop_in_cents>=0),
 ADD COLUMN trial_details text CHECK (length(trial_details)<=1000),
 ADD COLUMN notes text CHECK (length(notes)<=2000);
