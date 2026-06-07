import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/genui/binary_choice_prompt_card.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';

import '../../../widget_test_utils.dart';

// ── BinaryChoicePromptCard helpers ─────────────────────────────────────────

Widget _buildBinaryCard({
  String question = 'Are you sure?',
  String detail = '',
  String confirmLabel = 'Yes',
  String dismissLabel = 'No',
  String confirmValue = 'yes',
  String dismissValue = 'no',
  ValueChanged<String>? onSelect,
}) {
  return makeTestableWidgetNoScroll(
    BinaryChoicePromptCard(
      question: question,
      detail: detail,
      confirmLabel: confirmLabel,
      dismissLabel: dismissLabel,
      confirmValue: confirmValue,
      dismissValue: dismissValue,
      onSelect: onSelect ?? (_) {},
    ),
  );
}

void main() {
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  group('BinaryChoicePromptCard', () {
    testWidgets('calls onSelect with dismissValue when dismiss button tapped', (
      tester,
    ) async {
      String? selected;
      await tester.pumpWidget(
        _buildBinaryCard(
          dismissValue: 'no_thanks',
          onSelect: (v) => selected = v,
        ),
      );

      await tester.tap(find.text('No'));
      await tester.pump();

      expect(selected, 'no_thanks');
    });

    testWidgets('disables both buttons after dismiss selection', (
      tester,
    ) async {
      await tester.pumpWidget(_buildBinaryCard());

      await tester.tap(find.text('No'));
      await tester.pump();

      final buttons = tester
          .widgetList<DesignSystemButton>(find.byType(DesignSystemButton))
          .toList();
      expect(buttons, hasLength(2));
      for (final btn in buttons) {
        expect(btn.onPressed, isNull);
      }
    });

    testWidgets('resets submitted state when question changes', (tester) async {
      var callCount = 0;

      await tester.pumpWidget(
        _buildBinaryCard(
          question: 'First question?',
          onSelect: (_) => callCount++,
        ),
      );
      await tester.pump();

      // Select confirm to mark submitted.
      await tester.tap(find.text('Yes'));
      await tester.pump();
      expect(callCount, 1);

      // Change the question — didUpdateWidget should reset _submitted.
      await tester.pumpWidget(
        _buildBinaryCard(
          question: 'Second question?',
          onSelect: (_) => callCount++,
        ),
      );
      await tester.pump();

      // Both buttons should be re-enabled.
      final buttons = tester
          .widgetList<DesignSystemButton>(find.byType(DesignSystemButton))
          .toList();
      for (final btn in buttons) {
        expect(btn.onPressed, isNotNull);
      }

      // Can submit again.
      await tester.tap(find.text('Yes'));
      await tester.pump();
      expect(callCount, 2);
    });

    testWidgets('resets submitted state when confirmValue changes', (
      tester,
    ) async {
      var callCount = 0;

      await tester.pumpWidget(
        _buildBinaryCard(
          confirmValue: 'value_1',
          onSelect: (_) => callCount++,
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Yes'));
      await tester.pump();
      expect(callCount, 1);

      // Change confirmValue — triggers reset via didUpdateWidget.
      await tester.pumpWidget(
        _buildBinaryCard(
          confirmValue: 'value_2',
          onSelect: (_) => callCount++,
        ),
      );
      await tester.pump();

      final buttons = tester
          .widgetList<DesignSystemButton>(find.byType(DesignSystemButton))
          .toList();
      for (final btn in buttons) {
        expect(btn.onPressed, isNotNull);
      }
    });

    testWidgets('resets submitted state when dismissValue changes', (
      tester,
    ) async {
      var callCount = 0;

      await tester.pumpWidget(
        _buildBinaryCard(
          dismissValue: 'old_dismiss',
          onSelect: (_) => callCount++,
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Yes'));
      await tester.pump();
      expect(callCount, 1);

      // Change dismissValue — triggers reset via didUpdateWidget.
      await tester.pumpWidget(
        _buildBinaryCard(
          dismissValue: 'new_dismiss',
          onSelect: (_) => callCount++,
        ),
      );
      await tester.pump();

      final buttons = tester
          .widgetList<DesignSystemButton>(find.byType(DesignSystemButton))
          .toList();
      for (final btn in buttons) {
        expect(btn.onPressed, isNotNull);
      }
    });

    testWidgets('does NOT reset when prompt is unchanged', (tester) async {
      var callCount = 0;

      await tester.pumpWidget(
        _buildBinaryCard(onSelect: (_) => callCount++),
      );
      await tester.pump();
      await tester.tap(find.text('Yes'));
      await tester.pump();
      expect(callCount, 1);

      // Rebuild with identical props — submitted state must be preserved.
      await tester.pumpWidget(
        _buildBinaryCard(onSelect: (_) => callCount++),
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

  // ── ABComparisonCard didUpdateWidget ────────────────────────────────────
}
