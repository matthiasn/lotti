import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/ds_segmented_toggle.dart';
import 'package:lotti/widgets/misc/timespan_segmented_control.dart';

import '../../test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  DsSegmentedToggle<int> toggle(WidgetTester tester) =>
      tester.widget<DsSegmentedToggle<int>>(
        find.byType(DsSegmentedToggle<int>),
      );

  group('TimeSpanSegmentedControl', () {
    testWidgets('maps default day spans to DsSegmentedToggle segments', (
      tester,
    ) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: TimeSpanSegmentedControl(
            timeSpanDays: 90,
            onValueChanged: (_) {},
          ),
        ),
      );
      await tester.pump();

      final t = toggle(tester);
      expect(t.segments.map((s) => s.value).toList(), [30, 90, 180, 365]);
      expect(
        t.segments.map((s) => s.label).toList(),
        ['30d', '90d', '180d', '365d'],
      );
      // The current span is the selected segment.
      expect(t.selected, 90);
    });

    testWidgets('passes custom segments through and reflects the selection', (
      tester,
    ) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: TimeSpanSegmentedControl(
            timeSpanDays: 14,
            segments: const [7, 14, 28],
            onValueChanged: (_) {},
          ),
        ),
      );
      await tester.pump();

      final t = toggle(tester);
      expect(t.segments.map((s) => s.label).toList(), ['7d', '14d', '28d']);
      expect(t.selected, 14);
    });

    testWidgets('fires onValueChanged with the tapped span', (tester) async {
      final tapped = <int>[];
      await tester.pumpWidget(
        WidgetTestBench(
          child: TimeSpanSegmentedControl(
            timeSpanDays: 90,
            onValueChanged: tapped.add,
          ),
        ),
      );
      await tester.pump();

      // DsSegmentedToggle stacks an invisible ghost label behind the visible
      // one to reserve width, so each label matches two widgets; tapping the
      // first hits the shared InkWell.
      await tester.tap(find.text('30d').first);
      await tester.pump();
      await tester.tap(find.text('365d').first);
      await tester.pump();

      expect(tapped, [30, 365]);
    });
  });
}
