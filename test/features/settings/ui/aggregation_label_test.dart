import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/settings/ui/aggregation_label.dart';
import 'package:lotti/l10n/app_localizations_en.dart';

void main() {
  group('aggregationTypeLabel', () {
    final messages = AppLocalizationsEn();

    const expectedLabels = <AggregationType, String>{
      AggregationType.none: 'None',
      AggregationType.dailySum: 'Daily sum',
      AggregationType.dailyMax: 'Daily maximum',
      AggregationType.dailyAvg: 'Daily average',
      AggregationType.hourlySum: 'Hourly sum',
    };

    test('maps every aggregation type onto its localized label', () {
      // Exhaustive: a new enum value without a mapping fails here.
      for (final aggregationType in AggregationType.values) {
        expect(
          aggregationTypeLabel(messages, aggregationType),
          expectedLabels[aggregationType],
          reason: 'unexpected label for $aggregationType',
        );
      }
    });

    test('never leaks raw enum identifiers', () {
      for (final aggregationType in AggregationType.values) {
        expect(
          aggregationTypeLabel(messages, aggregationType),
          isNot(contains(aggregationType.name)),
        );
      }
    });
  });
}
