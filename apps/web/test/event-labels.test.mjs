import assert from 'node:assert/strict';
import test from 'node:test';
import { eventPhaseLabel, eventRegistrationLabel } from '../lib/event-labels.ts';

test('event phases are readable and unknown dates are not treated as upcoming', () => {
  assert.equal(eventPhaseLabel('UPCOMING'), 'Upcoming');
  assert.equal(eventPhaseLabel('COMPLETED'), 'Past event');
  assert.equal(eventPhaseLabel('UNSCHEDULED'), 'Date to be announced');
  assert.equal(eventPhaseLabel(null), 'Date not confirmed');
});

test('stale registration status does not advertise past or undated entry', () => {
  assert.equal(eventRegistrationLabel('COMPLETED', 'OPEN'), undefined);
  assert.equal(eventRegistrationLabel('UNSCHEDULED', 'OPEN'), undefined);
  assert.equal(eventRegistrationLabel('UPCOMING', 'OPEN'), 'Registration listed open');
});
