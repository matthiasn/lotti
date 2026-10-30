import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/ds_segmented_toggle.dart';
import 'package:lotti/features/tts/ui/widgets/tts_gender_filter.dart';

import '../../../../widget_test_utils.dart';

void main() {
  testWidgets('offers Female and Male, reports the tapped value of the '
      "caller's own type, and leaves selection to the caller", (tester) async {
    final changes = <int>[];
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        TtsGenderFilter<int>(
          selected: 1,
          female: 1,
          male: 2,
          onChanged: changes.add,
        ),
      ),
    );

    final toggle = tester.widget<DsSegmentedToggle<int>>(
      find.byType(DsSegmentedToggle<int>),
    );
    expect(toggle.selected, 1);
    expect(toggle.segments.map((s) => (s.value, s.label)), [
      (1, 'Female'),
      (2, 'Male'),
    ]);

    await tester.tap(find.text('Male').first);
    await tester.pump();
    expect(changes, [2]);
    expect(
      tester
          .widget<DsSegmentedToggle<int>>(find.byType(DsSegmentedToggle<int>))
          .selected,
      1,
    );
  });
}
