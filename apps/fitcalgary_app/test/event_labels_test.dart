import 'package:fitcalgary_app/features/events/event_labels.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('event phases communicate past and unconfirmed dates', () {
    expect(eventPhaseLabel('UPCOMING'), 'UPCOMING');
    expect(eventPhaseLabel('COMPLETED'), 'PAST EVENT');
    expect(eventPhaseLabel('UNSCHEDULED'), 'DATE TO BE ANNOUNCED');
    expect(eventPhaseLabel(null), 'DATE NOT CONFIRMED');
  });

  test('stale registration state is not shown for old or undated events', () {
    expect(eventRegistrationLabel('COMPLETED', 'OPEN'), isNull);
    expect(eventRegistrationLabel('UNSCHEDULED', 'OPEN'), isNull);
    expect(
      eventRegistrationLabel('UPCOMING', 'OPEN'),
      'REGISTRATION LISTED OPEN',
    );
  });
}
