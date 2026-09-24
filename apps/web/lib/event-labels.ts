export function eventPhaseLabel(phase: unknown): string {
  switch (phase) {
    case 'UPCOMING': return 'Upcoming';
    case 'CURRENT': return 'Happening now';
    case 'COMPLETED': return 'Past event';
    case 'CANCELLED': return 'Cancelled';
    case 'POSTPONED': return 'Postponed';
    case 'UNSCHEDULED': return 'Date to be announced';
    default: return 'Date not confirmed';
  }
}

export function eventRegistrationLabel(phase: unknown, status: unknown): string | undefined {
  if (phase !== 'UPCOMING' && phase !== 'CURRENT') return undefined;
  if (status === 'OPEN') return 'Registration listed open';
  if (status === 'CLOSED') return 'Registration closed';
  return undefined;
}
