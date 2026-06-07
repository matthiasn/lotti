import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/genui/ab_comparison_card.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';

import '../../../widget_test_utils.dart';

void main() {
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  Widget buildSubject({
    String question = 'Which approach works better?',
    String optionA = 'Warm and encouraging phrasing.',
    String optionB = 'Direct and fact-first phrasing.',
    String labelA = 'Warmer',
    String labelB = 'More direct',
    ValueChanged<String>? onSelect,
  }) {
    return makeTestableWidgetNoScroll(
      ABComparisonCard(
        question: question,
        optionA: optionA,
        optionB: optionB,
        labelA: labelA,
        labelB: labelB,
        onSelect: onSelect ?? (_) {},
      ),
    );
  }

  group('ABComparisonCard', () {
    testWidgets('renders question text', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.text('Which approach works better?'), findsOneWidget);
    });

    testWidgets('renders both option texts', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.text('Warm and encouraging phrasing.'), findsOneWidget);
      expect(find.text('Direct and fact-first phrasing.'), findsOneWidget);
    });

    testWidgets('renders labels', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.text('· Warmer'), findsOneWidget);
      expect(find.text('· More direct'), findsOneWidget);
    });

    testWidgets('renders option headers', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.text('Option A'), findsOneWidget);
      expect(find.text('Option B'), findsOneWidget);
    });

    testWidgets('renders choose buttons', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.text('Choose A'), findsOneWidget);
      expect(find.text('Choose B'), findsOneWidget);
    });

    testWidgets('calls onSelect with readable value when A tapped', (
      tester,
    ) async {
      String? selectedValue;
      await tester.pumpWidget(
        buildSubject(onSelect: (v) => selectedValue = v),
      );
      await tester.pump();

      await tester.tap(find.text('Choose A'));
      await tester.pump();

      expect(selectedValue, 'I prefer Option A — Warmer');
    });

    testWidgets('calls onSelect with readable value when B tapped', (
      tester,
    ) async {
      String? selectedValue;
      await tester.pumpWidget(
        buildSubject(onSelect: (v) => selectedValue = v),
      );
      await tester.pump();

      await tester.tap(find.text('Choose B'));
      await tester.pump();

      expect(selectedValue, 'I prefer Option B — More direct');
    });

    testWidgets('disables both buttons after selection', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      await tester.tap(find.text('Choose A'));
      await tester.pump();

      // Both buttons should be disabled after selection.
      final buttons = tester
          .widgetList<DesignSystemButton>(find.byType(DesignSystemButton))
          .toList();
      expect(buttons, hasLength(2));
      for (final button in buttons) {
        expect(button.onPressed, isNull);
      }
    });

    testWidgets('shows check icon on selected card', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      await tester.tap(find.text('Choose B'));
      await tester.pump();

      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('resets state when options change', (tester) async {
      var callCount = 0;
      await tester.pumpWidget(
        buildSubject(onSelect: (_) => callCount++),
      );
      await tester.pump();

      await tester.tap(find.text('Choose A'));
      await tester.pump();
      expect(callCount, 1);

      // Rebuild with different options — should reset.
      await tester.pumpWidget(
        buildSubject(
          optionA: 'New option A text.',
          optionB: 'New option B text.',
          onSelect: (_) => callCount++,
        ),
      );
      await tester.pump();

      // Should be able to select again.
      await tester.tap(find.text('Choose A'));
      await tester.pump();
      expect(callCount, 2);
    });

    testWidgets('works with empty labels', (tester) async {
      await tester.pumpWidget(
        buildSubject(labelA: '', labelB: ''),
      );
      await tester.pump();

      // Labels should not appear.
      expect(find.text('· '), findsNothing);
      // Options still render.
      expect(find.text('Option A'), findsOneWidget);
      expect(find.text('Option B'), findsOneWidget);
    });
  });

  group('ABComparisonCard didUpdateWidget', () {
    final resetScenarios =
        <
          ({
            String field,
            Widget Function(ValueChanged<String> onSelect) before,
            Widget Function(ValueChanged<String> onSelect) after,
            String tap,
            String? expectAfter,
          })
        >[
          (
            field: 'optionA',
            before: (s) => buildSubject(optionA: 'Original A.', onSelect: s),
            after: (s) => buildSubject(optionA: 'Changed A.', onSelect: s),
            tap: 'Choose A',
            expectAfter: 'Changed A.',
          ),
          (
            field: 'optionB',
            before: (s) => buildSubject(optionB: 'Original B.', onSelect: s),
            after: (s) => buildSubject(optionB: 'Changed B.', onSelect: s),
            tap: 'Choose B',
            expectAfter: 'Changed B.',
          ),
          (
            field: 'question',
            before: (s) =>
                buildSubject(question: 'Original question?', onSelect: s),
            after: (s) =>
                buildSubject(question: 'Changed question?', onSelect: s),
            tap: 'Choose A',
            expectAfter: 'Changed question?',
          ),
          (
            field: 'labelA',
            before: (s) => buildSubject(labelA: 'Old Label A', onSelect: s),
            after: (s) => buildSubject(labelA: 'New Label A', onSelect: s),
            tap: 'Choose A',
            expectAfter: null,
          ),
          (
            field: 'labelB',
            before: (s) => buildSubject(labelB: 'Old Label B', onSelect: s),
            after: (s) => buildSubject(labelB: 'New Label B', onSelect: s),
            tap: 'Choose B',
            expectAfter: null,
          ),
        ];

    for (final scenario in resetScenarios) {
      testWidgets('resets state when ${scenario.field} changes', (
        tester,
      ) async {
        var callCount = 0;

        await tester.pumpWidget(scenario.before((_) => callCount++));
        await tester.pump();

        await tester.tap(find.text(scenario.tap));
        await tester.pump();
        expect(callCount, 1);

        // Rebuild with the changed prop — the selection state must reset.
        await tester.pumpWidget(scenario.after((_) => callCount++));
        await tester.pump();

        // Buttons must be re-enabled after the reset.
        final buttons = tester
            .widgetList<DesignSystemButton>(find.byType(DesignSystemButton))
            .toList();
        for (final btn in buttons) {
          expect(btn.onPressed, isNotNull);
        }
        if (scenario.expectAfter != null) {
          expect(find.text(scenario.expectAfter!), findsOneWidget);
        }
      });
    }

    testWidgets('does NOT reset when identical props are re-supplied', (
      tester,
    ) async {
      var callCount = 0;

      await tester.pumpWidget(
        buildSubject(onSelect: (_) => callCount++),
      );
      await tester.pump();

      await tester.tap(find.text('Choose A'));
      await tester.pump();
      expect(callCount, 1);

      // Same props — should NOT reset.
      await tester.pumpWidget(
        buildSubject(onSelect: (_) => callCount++),
      );
      await tester.pump();

      // Buttons should remain disabled.
      final buttons = tester
          .widgetList<DesignSystemButton>(find.byType(DesignSystemButton))
          .toList();
      for (final btn in buttons) {
        expect(btn.onPressed, isNull);
      }
    });
  });
}
