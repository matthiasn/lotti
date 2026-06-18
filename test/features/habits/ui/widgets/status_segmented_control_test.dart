import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/ds_segmented_toggle.dart';
import 'package:lotti/features/habits/state/habits_state.dart';
import 'package:lotti/features/habits/ui/widgets/status_segmented_control.dart';

import '../../../../widget_test_utils.dart';

void main() {
  // Pairs of (visible label text, the filter that segment maps to). The labels
  // come from app_en.arb: openNow -> 'due', pendingLater -> 'later',
  // completed -> 'done', all -> 'all'.
  const segments = <(String label, HabitDisplayFilter filter)>[
    ('due', HabitDisplayFilter.openNow),
    ('later', HabitDisplayFilter.pendingLater),
    ('done', HabitDisplayFilter.completed),
    ('all', HabitDisplayFilter.all),
  ];

  Future<void> pumpControl(
    WidgetTester tester, {
    required HabitDisplayFilter filter,
    required ValueChanged<HabitDisplayFilter> onValueChanged,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        HabitStatusSegmentedControl(
          filter: filter,
          onValueChanged: onValueChanged,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders all four localized segment labels', (tester) async {
    await pumpControl(
      tester,
      filter: HabitDisplayFilter.openNow,
      onValueChanged: (_) {},
    );

    for (final (label, _) in segments) {
      // Each segment renders its label twice: an invisible ghost (reserving the
      // selected/bold width) plus the visible label. So every label is present
      // exactly twice in the tree.
      expect(
        find.text(label),
        findsNWidgets(2),
        reason: 'segment "$label" should render its visible + ghost label',
      );
    }
  });

  testWidgets(
    'passes the current filter to DsSegmentedToggle.selected',
    (tester) async {
      for (final (_, filter) in segments) {
        await pumpControl(
          tester,
          filter: filter,
          onValueChanged: (_) {},
        );

        final toggle = tester.widget<DsSegmentedToggle<HabitDisplayFilter>>(
          find.byType(DsSegmentedToggle<HabitDisplayFilter>),
        );
        expect(toggle.selected, filter);
      }
    },
  );

  testWidgets(
    'tapping a non-selected segment calls onValueChanged with that filter',
    (tester) async {
      // Start selected on the first segment so every other segment is a real,
      // non-selected change when tapped.
      const initial = HabitDisplayFilter.openNow;

      for (final (label, expectedFilter) in segments) {
        if (expectedFilter == initial) continue;

        HabitDisplayFilter? captured;
        await pumpControl(
          tester,
          filter: initial,
          onValueChanged: (value) => captured = value,
        );

        // Both the ghost and the visible Text live inside the same InkWell, so
        // tapping either triggers the same onTap; use `.last` to target a
        // concrete, hit-testable Text node.
        await tester.tap(find.text(label).last);
        await tester.pump();

        expect(
          captured,
          expectedFilter,
          reason: 'tapping "$label" should report filter $expectedFilter',
        );
      }
    },
  );

  testWidgets(
    'tapping the already-selected segment still reports its filter',
    (tester) async {
      HabitDisplayFilter? captured;
      await pumpControl(
        tester,
        filter: HabitDisplayFilter.completed,
        onValueChanged: (value) => captured = value,
      );

      await tester.tap(find.text('done').last);
      await tester.pump();

      expect(captured, HabitDisplayFilter.completed);
    },
  );
}
