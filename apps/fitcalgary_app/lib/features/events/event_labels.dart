String eventPhaseLabel(String? phase) => switch (phase) {
  'UPCOMING' => 'UPCOMING',
  'CURRENT' => 'HAPPENING NOW',
  'COMPLETED' => 'PAST EVENT',
  'CANCELLED' => 'CANCELLED',
  'POSTPONED' => 'POSTPONED',
  'UNSCHEDULED' => 'DATE TO BE ANNOUNCED',
  _ => 'DATE NOT CONFIRMED',
};

String? eventRegistrationLabel(String? phase, String? status) {
  if (phase != 'UPCOMING' && phase != 'CURRENT') return null;
  return switch (status) {
    'OPEN' => 'REGISTRATION LISTED OPEN',
    'CLOSED' => 'REGISTRATION CLOSED',
    _ => null,
  };
}
