export type BillingFrequency = 'WEEKLY'|'BIWEEKLY'|'MONTHLY'|'QUARTERLY'|'ANNUALLY';
export interface PriceInput { recurringCents: number; frequency: BillingFrequency; mandatoryRecurringFeeCents?: number; mandatoryAnnualFeeCents?: number; initiationFeeCents?: number; complete: boolean; }
export interface NormalizedPrice { paymentsPerYear: number; annualRecurringCents: number; ongoingMonthlyCents: number | null; firstYearMonthlyCents: number | null; complete: boolean; }
const payments: Record<BillingFrequency,number> = { WEEKLY:52, BIWEEKLY:26, MONTHLY:12, QUARTERLY:4, ANNUALLY:1 };
export function normalizePrice(input: PriceInput): NormalizedPrice {
  for (const value of [input.recurringCents,input.mandatoryRecurringFeeCents??0,input.mandatoryAnnualFeeCents??0,input.initiationFeeCents??0]) if (!Number.isInteger(value) || value < 0) throw new Error('Price components must be non-negative integer cents');
  const count=payments[input.frequency];
  const annualRecurringCents=(input.recurringCents+(input.mandatoryRecurringFeeCents??0))*count+(input.mandatoryAnnualFeeCents??0);
  return {paymentsPerYear:count,annualRecurringCents,ongoingMonthlyCents:input.complete?Math.round(annualRecurringCents/12):null,firstYearMonthlyCents:input.complete?Math.round((annualRecurringCents+(input.initiationFeeCents??0))/12):null,complete:input.complete};
}
