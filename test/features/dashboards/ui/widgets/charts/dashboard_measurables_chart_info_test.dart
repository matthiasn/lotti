import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_measurables_chart_info.dart';

void main() {
  group('aggregationLabel', () {
    test('returns empty string for null', () {
      expect(aggregationLabel(null), '');
    });

    test('returns empty string for AggregationType.none', () {
      expect(aggregationLabel(AggregationType.none), '');
    });

    test('returns formatted label for dailySum', () {
      expect(
        aggregationLabel(AggregationType.dailySum),
        '[dailySum]',
      );
    });

    test('returns formatted label for dailyMax', () {
      expect(
        aggregationLabel(AggregationType.dailyMax),
        '[dailyMax]',
      );
    });
  });
}
