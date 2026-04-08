import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/genui/evolution_catalog_interactive_widgets.dart';
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
      await tester.pumpAndSettle();

      expect(find.text('Which approach works better?'), findsOneWidget);
    });

    testWidgets('renders both option texts', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Warm and encouraging phrasing.'), findsOneWidget);
      expect(find.text('Direct and fact-first phrasing.'), findsOneWidget);
    });

    testWidgets('renders labels', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('· Warmer'), findsOneWidget);
      expect(find.text('· More direct'), findsOneWidget);
    });

    testWidgets('renders option headers', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Option A'), findsOneWidget);
      expect(find.text('Option B'), findsOneWidget);
    });

    testWidgets('renders choose buttons', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

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
      await tester.pumpAndSettle();

      await tester.tap(find.text('Choose A'));
      await tester.pumpAndSettle();

      expect(selectedValue, 'I prefer Option A — Warmer');
    });

    testWidgets('calls onSelect with readable value when B tapped', (
      tester,
    ) async {
      String? selectedValue;
      await tester.pumpWidget(
        buildSubject(onSelect: (v) => selectedValue = v),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Choose B'));
      await tester.pumpAndSettle();

      expect(selectedValue, 'I prefer Option B — More direct');
    });

    testWidgets('disables both buttons after selection', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Choose A'));
      await tester.pumpAndSettle();

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
      await tester.pumpAndSettle();

      await tester.tap(find.text('Choose B'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('resets state when options change', (tester) async {
      var callCount = 0;
      await tester.pumpWidget(
        buildSubject(onSelect: (_) => callCount++),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Choose A'));
      await tester.pumpAndSettle();
      expect(callCount, 1);

      // Rebuild with different options — should reset.
      await tester.pumpWidget(
        buildSubject(
          optionA: 'New option A text.',
          optionB: 'New option B text.',
          onSelect: (_) => callCount++,
        ),
      );
      await tester.pumpAndSettle();

      // Should be able to select again.
      await tester.tap(find.text('Choose A'));
      await tester.pumpAndSettle();
      expect(callCount, 2);
    });

    testWidgets('works with empty labels', (tester) async {
      await tester.pumpWidget(
        buildSubject(labelA: '', labelB: ''),
      );
      await tester.pumpAndSettle();

      // Labels should not appear.
      expect(find.text('· '), findsNothing);
      // Options still render.
      expect(find.text('Option A'), findsOneWidget);
      expect(find.text('Option B'), findsOneWidget);
    });
  });
}
