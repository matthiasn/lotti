import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/genui/evolution_catalog_interactive_widgets.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';

import '../../../widget_test_utils.dart';

// ── CategoryRatingsCard helpers ────────────────────────────────────────────

Widget _buildRatingsCard({
  required List<Map<String, Object?>> categories,
  void Function(Map<String, int> ratings)? onSubmit,
}) {
  return makeTestableWidgetNoScroll(
    CategoryRatingsCard(
      categories: categories,
      onSubmit: onSubmit ?? (_) {},
    ),
  );
}

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

// ── ABComparisonCard helpers ────────────────────────────────────────────────

Widget _buildAbCard({
  String question = 'Which is better?',
  String optionA = 'Option A text.',
  String optionB = 'Option B text.',
  String labelA = 'Label A',
  String labelB = 'Label B',
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

void main() {
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  // ── CategoryRatingsCard ──────────────────────────────────────────────────

  group('CategoryRatingsCard', () {
    testWidgets('submits callback with correct ratings map', (tester) async {
      Map<String, int>? submitted;

      await tester.pumpWidget(
        _buildRatingsCard(
          categories: [
            {'name': 'quality', 'label': 'Quality'},
            {'name': 'speed', 'label': 'Speed'},
          ],
          onSubmit: (r) => submitted = r,
        ),
      );

      // Tap 3rd star for 'quality' and 5th star for 'speed'.
      final qualityRow = find
          .ancestor(of: find.text('Quality'), matching: find.byType(Padding))
          .first;
      final speedRow = find
          .ancestor(of: find.text('Speed'), matching: find.byType(Padding))
          .first;

      await tester.tap(
        find
            .descendant(of: qualityRow, matching: find.byType(GestureDetector))
            .at(2),
      );
      await tester.pump();

      await tester.tap(
        find
            .descendant(of: speedRow, matching: find.byType(GestureDetector))
            .at(4),
      );
      await tester.pump();

      // Find and tap the submit button.
      final submitBtn = tester
          .widgetList<DesignSystemButton>(find.byType(DesignSystemButton))
          .where((b) => b.onPressed != null)
          .first;
      await tester.tap(find.byWidget(submitBtn));
      await tester.pump();

      expect(submitted, {'quality': 3, 'speed': 5});
    });

    testWidgets('re-initializes state when categories list changes', (
      tester,
    ) async {
      // Start with one category set.
      await tester.pumpWidget(
        _buildRatingsCard(
          categories: [
            {'name': 'accuracy', 'label': 'Accuracy'},
          ],
        ),
      );
      await tester.pump();
      expect(find.text('Accuracy'), findsOneWidget);

      // Rebuild with a different category — didUpdateWidget should reset.
      await tester.pumpWidget(
        _buildRatingsCard(
          categories: [
            {'name': 'responsiveness', 'label': 'Responsiveness'},
          ],
        ),
      );
      await tester.pump();
      expect(find.text('Responsiveness'), findsOneWidget);
      // 'Accuracy' must be gone — the old category was replaced.
      expect(find.text('Accuracy'), findsNothing);
    });

    testWidgets(
      '_sameCategorySpec returns false when lists have different lengths',
      (tester) async {
        // Build with two categories, then rebuild with one — lengths differ, so
        // didUpdateWidget must re-initialize (exercises the a.length != b.length
        // branch inside _sameCategorySpec).
        Map<String, int>? submitted;

        await tester.pumpWidget(
          _buildRatingsCard(
            categories: [
              {'name': 'cat1', 'label': 'Cat 1'},
              {'name': 'cat2', 'label': 'Cat 2'},
            ],
            onSubmit: (r) => submitted = r,
          ),
        );
        await tester.pump();

        // Rate and submit with the two-category state.
        final catRow = find
            .ancestor(of: find.text('Cat 1'), matching: find.byType(Padding))
            .first;
        await tester.tap(
          find
              .descendant(of: catRow, matching: find.byType(GestureDetector))
              .at(1),
        );
        await tester.pump();

        final submitBtnBefore = tester
            .widgetList<DesignSystemButton>(find.byType(DesignSystemButton))
            .where((b) => b.onPressed != null)
            .first;
        await tester.tap(find.byWidget(submitBtnBefore));
        await tester.pump();

        expect(submitted, isNotNull);

        // Rebuild with a single category — _sameCategorySpec detects length
        // mismatch and resets _submitted, restoring the button.
        await tester.pumpWidget(
          _buildRatingsCard(
            categories: [
              {'name': 'cat1', 'label': 'Cat 1 Only'},
            ],
            onSubmit: (r) => submitted = r,
          ),
        );
        await tester.pump();

        // After reset the submit button must be enabled again.
        final submitBtnAfter = tester
            .widgetList<DesignSystemButton>(find.byType(DesignSystemButton))
            .where((b) => b.onPressed != null)
            .toList();
        expect(submitBtnAfter, isNotEmpty);
      },
    );

    testWidgets(
      '_sameCategorySpec returns false when names differ (same length)',
      (tester) async {
        // Start with category 'alpha', then switch to 'beta'.  Same list length
        // but different name triggers the name-check branch of _sameCategorySpec.
        Map<String, int>? submitted;

        await tester.pumpWidget(
          _buildRatingsCard(
            categories: [
              {'name': 'alpha', 'label': 'Alpha'},
            ],
            onSubmit: (r) => submitted = r,
          ),
        );
        await tester.pump();

        // Rate and submit to put widget in submitted state.
        final alphaRow = find
            .ancestor(of: find.text('Alpha'), matching: find.byType(Padding))
            .first;
        await tester.tap(
          find
              .descendant(of: alphaRow, matching: find.byType(GestureDetector))
              .at(2),
        );
        await tester.pump();

        final btnBefore = tester
            .widgetList<DesignSystemButton>(find.byType(DesignSystemButton))
            .where((b) => b.onPressed != null)
            .first;
        await tester.tap(find.byWidget(btnBefore));
        await tester.pump();
        expect(submitted, {'alpha': 3});

        // Rebuild with same-length list but different name — should reset.
        await tester.pumpWidget(
          _buildRatingsCard(
            categories: [
              {'name': 'beta', 'label': 'Beta'},
            ],
            onSubmit: (r) => submitted = r,
          ),
        );
        await tester.pump();

        expect(find.text('Beta'), findsOneWidget);
        // Submit button must be re-enabled after reset.
        final btnsAfter = tester
            .widgetList<DesignSystemButton>(find.byType(DesignSystemButton))
            .where((b) => b.onPressed != null)
            .toList();
        expect(btnsAfter, isNotEmpty);
      },
    );

    testWidgets(
      'does NOT re-initialize when same categories are re-supplied',
      (tester) async {
        // Rebuild with identical categories — _sameCategorySpec returns true so
        // didUpdateWidget must NOT reset the submitted state.
        Map<String, int>? submitted;

        await tester.pumpWidget(
          _buildRatingsCard(
            categories: [
              {'name': 'accuracy', 'label': 'Accuracy'},
            ],
            onSubmit: (r) => submitted = r,
          ),
        );
        await tester.pump();

        // Rate and submit.
        final row = find
            .ancestor(
              of: find.text('Accuracy'),
              matching: find.byType(Padding),
            )
            .first;
        await tester.tap(
          find
              .descendant(of: row, matching: find.byType(GestureDetector))
              .at(0),
        );
        await tester.pump();

        final submitBtn = tester
            .widgetList<DesignSystemButton>(find.byType(DesignSystemButton))
            .where((b) => b.onPressed != null)
            .first;
        await tester.tap(find.byWidget(submitBtn));
        await tester.pump();
        expect(submitted, isNotNull);

        // Rebuild with the same category list — no reset expected.
        await tester.pumpWidget(
          _buildRatingsCard(
            categories: [
              {'name': 'accuracy', 'label': 'Accuracy'},
            ],
            onSubmit: (r) => submitted = r,
          ),
        );
        await tester.pump();

        // The widget should still be in submitted state (button disabled /
        // replaced by confirmation row, indicated by no enabled DS button).
        final btnsAfter = tester
            .widgetList<DesignSystemButton>(find.byType(DesignSystemButton))
            .where((b) => b.onPressed != null)
            .toList();
        expect(btnsAfter, isEmpty);
      },
    );
  });

  // ── BinaryChoicePromptCard ───────────────────────────────────────────────

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

  group('ABComparisonCard didUpdateWidget', () {
    testWidgets('resets state when optionA changes', (tester) async {
      var callCount = 0;

      await tester.pumpWidget(
        _buildAbCard(
          optionA: 'Original A.',
          onSelect: (_) => callCount++,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Choose A'));
      await tester.pumpAndSettle();
      expect(callCount, 1);

      // Rebuild with new optionA — should reset.
      await tester.pumpWidget(
        _buildAbCard(
          optionA: 'Changed A.',
          onSelect: (_) => callCount++,
        ),
      );
      await tester.pumpAndSettle();

      // Buttons must be re-enabled after reset.
      final buttons = tester
          .widgetList<DesignSystemButton>(find.byType(DesignSystemButton))
          .toList();
      for (final btn in buttons) {
        expect(btn.onPressed, isNotNull);
      }
      expect(find.text('Changed A.'), findsOneWidget);
    });

    testWidgets('resets state when optionB changes', (tester) async {
      var callCount = 0;

      await tester.pumpWidget(
        _buildAbCard(
          optionB: 'Original B.',
          onSelect: (_) => callCount++,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Choose B'));
      await tester.pumpAndSettle();
      expect(callCount, 1);

      await tester.pumpWidget(
        _buildAbCard(
          optionB: 'Changed B.',
          onSelect: (_) => callCount++,
        ),
      );
      await tester.pumpAndSettle();

      final buttons = tester
          .widgetList<DesignSystemButton>(find.byType(DesignSystemButton))
          .toList();
      for (final btn in buttons) {
        expect(btn.onPressed, isNotNull);
      }
      expect(find.text('Changed B.'), findsOneWidget);
    });

    testWidgets('resets state when question changes', (tester) async {
      var callCount = 0;

      await tester.pumpWidget(
        _buildAbCard(
          question: 'Original question?',
          onSelect: (_) => callCount++,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Choose A'));
      await tester.pumpAndSettle();
      expect(callCount, 1);

      await tester.pumpWidget(
        _buildAbCard(
          question: 'New question?',
          onSelect: (_) => callCount++,
        ),
      );
      await tester.pumpAndSettle();

      final buttons = tester
          .widgetList<DesignSystemButton>(find.byType(DesignSystemButton))
          .toList();
      for (final btn in buttons) {
        expect(btn.onPressed, isNotNull);
      }
    });

    testWidgets('resets state when labelA changes', (tester) async {
      var callCount = 0;

      await tester.pumpWidget(
        _buildAbCard(
          labelA: 'Old Label A',
          onSelect: (_) => callCount++,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Choose A'));
      await tester.pumpAndSettle();
      expect(callCount, 1);

      await tester.pumpWidget(
        _buildAbCard(
          labelA: 'New Label A',
          onSelect: (_) => callCount++,
        ),
      );
      await tester.pumpAndSettle();

      final buttons = tester
          .widgetList<DesignSystemButton>(find.byType(DesignSystemButton))
          .toList();
      for (final btn in buttons) {
        expect(btn.onPressed, isNotNull);
      }
    });

    testWidgets('resets state when labelB changes', (tester) async {
      var callCount = 0;

      await tester.pumpWidget(
        _buildAbCard(
          labelB: 'Old Label B',
          onSelect: (_) => callCount++,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Choose B'));
      await tester.pumpAndSettle();
      expect(callCount, 1);

      await tester.pumpWidget(
        _buildAbCard(
          labelB: 'New Label B',
          onSelect: (_) => callCount++,
        ),
      );
      await tester.pumpAndSettle();

      final buttons = tester
          .widgetList<DesignSystemButton>(find.byType(DesignSystemButton))
          .toList();
      for (final btn in buttons) {
        expect(btn.onPressed, isNotNull);
      }
    });

    testWidgets('does NOT reset when identical props are re-supplied', (
      tester,
    ) async {
      var callCount = 0;

      await tester.pumpWidget(
        _buildAbCard(onSelect: (_) => callCount++),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Choose A'));
      await tester.pumpAndSettle();
      expect(callCount, 1);

      // Same props — should NOT reset.
      await tester.pumpWidget(
        _buildAbCard(onSelect: (_) => callCount++),
      );
      await tester.pumpAndSettle();

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
