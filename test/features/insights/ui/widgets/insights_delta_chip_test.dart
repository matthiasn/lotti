import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/insights/ui/widgets/insights_delta_chip.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('insightsDeltaPercent', () {
    test('rounds the percent change', () {
      expect(insightsDeltaPercent(120, 100), 20);
      expect(insightsDeltaPercent(80, 100), -20);
      expect(insightsDeltaPercent(100, 100), 0);
      expect(insightsDeltaPercent(118, 100), 18);
    });

    test('is null when there is no previous baseline', () {
      expect(insightsDeltaPercent(60, 0), isNull);
      expect(insightsDeltaPercent(0, 0), isNull);
    });
  });

  group('InsightsDeltaChip', () {
    Future<void> pump(
      WidgetTester tester, {
      required int current,
      required int previous,
    }) {
      return tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          InsightsDeltaChip(current: current, previous: previous),
        ),
      );
    }

    testWidgets('shows a signed up percent for growth', (tester) async {
      await pump(tester, current: 118, previous: 100);
      expect(find.text('+18%'), findsOneWidget);
    });

    testWidgets('shows a signed down percent for a decline', (tester) async {
      await pump(tester, current: 88, previous: 100);
      expect(find.text('-12%'), findsOneWidget);
    });

    testWidgets('shows "new" when there is no previous time', (tester) async {
      await pump(tester, current: 60, previous: 0);
      expect(find.text('new'), findsOneWidget);
    });

    testWidgets('renders nothing when both periods are empty', (tester) async {
      await pump(tester, current: 0, previous: 0);
      expect(find.textContaining('%'), findsNothing);
      expect(find.text('new'), findsNothing);
    });
  });
}
