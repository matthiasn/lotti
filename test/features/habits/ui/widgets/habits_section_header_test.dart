import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/habits/ui/widgets/habits_section_header.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Future<void> pumpHeader(
    WidgetTester tester, {
    required String label,
    required int count,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        HabitsSectionHeader(label: label, count: count),
      ),
    );
    await tester.pump();
  }

  // (label, count) pairs covering distinct labels and counts, including a
  // multi-digit count to prove the count is rendered as its string form.
  const cases = <({String label, int count})>[
    (label: 'Due now', count: 4),
    (label: 'Later today', count: 0),
    (label: 'Completed', count: 12),
  ];

  for (final c in cases) {
    testWidgets(
      'renders label "${c.label}" with count ${c.count}',
      (tester) async {
        await pumpHeader(tester, label: c.label, count: c.count);

        expect(find.text(c.label), findsOneWidget);
        expect(find.text('${c.count}'), findsOneWidget);
      },
    );

    testWidgets(
      'count ${c.count} sits inside a DecoratedBox pill',
      (tester) async {
        await pumpHeader(tester, label: c.label, count: c.count);

        // The count Text must be a descendant of a DecoratedBox (the pill),
        // proving the pill styling wraps the count and not the label.
        expect(
          find.descendant(
            of: find.byType(DecoratedBox),
            matching: find.text('${c.count}'),
          ),
          findsOneWidget,
        );

        // The label, by contrast, is not inside the pill.
        expect(
          find.descendant(
            of: find.byType(DecoratedBox),
            matching: find.text(c.label),
          ),
          findsNothing,
        );
      },
    );
  }

  testWidgets('label uses a bold (semiBold) subtitle weight', (tester) async {
    await pumpHeader(tester, label: 'Due now', count: 4);

    final labelText = tester.widget<Text>(find.text('Due now'));
    expect(labelText.style?.fontWeight, FontWeight.w600);
  });
}
