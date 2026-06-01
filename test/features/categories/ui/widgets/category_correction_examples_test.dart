import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/ui/widgets/category_correction_examples.dart';

import '../../../../test_helper.dart';

void main() {
  // A fixed date used for deterministic capturedAt values.
  final fixedDate = DateTime(2024, 3, 15, 10, 30);

  ChecklistCorrectionExample makeExample({
    String before = 'wrong text',
    String after = 'correct text',
    DateTime? capturedAt,
  }) {
    return ChecklistCorrectionExample(
      before: before,
      after: after,
      capturedAt: capturedAt,
    );
  }

  group('CategoryCorrectionExamples — empty state', () {
    testWidgets('shows section title and description', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryCorrectionExamples(
            examples: null,
            onDeleteAt: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Checklist Correction Examples'), findsOneWidget);
      expect(
        find.text(
          'When you manually correct checklist items, those corrections are '
          'saved here and used to improve AI suggestions.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows empty-state message when examples is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryCorrectionExamples(
            examples: null,
            onDeleteAt: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text(
          'No corrections captured yet. Edit a checklist item to add your '
          'first example.',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('shows empty-state message when examples is an empty list', (
      tester,
    ) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryCorrectionExamples(
            examples: const [],
            onDeleteAt: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text(
          'No corrections captured yet. Edit a checklist item to add your '
          'first example.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('does not show warning banner when no examples', (
      tester,
    ) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryCorrectionExamples(
            examples: null,
            onDeleteAt: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    });
  });

  group('CategoryCorrectionExamples — populated state', () {
    testWidgets('displays before → after text for each example', (
      tester,
    ) async {
      final examples = [
        makeExample(before: 'orignal', after: 'original'),
        makeExample(before: 'teh', after: 'the'),
      ];

      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryCorrectionExamples(
            examples: examples,
            onDeleteAt: (_) {},
          ),
        ),
      );
      await tester.pump();

      // Both before/after values appear inside RichText spans.
      expect(
        find.textContaining('"orignal"', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('"original"', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('"teh"', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('"the"', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('shows arrow separator between before and after', (
      tester,
    ) async {
      final examples = [makeExample(before: 'old', after: 'new')];

      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryCorrectionExamples(
            examples: examples,
            onDeleteAt: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining(' → ', findRichText: true), findsOneWidget);
    });

    testWidgets('shows formatted capturedAt date when present', (
      tester,
    ) async {
      final examples = [
        makeExample(
          before: 'orignal',
          after: 'original',
          capturedAt: fixedDate,
        ),
      ];

      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryCorrectionExamples(
            examples: examples,
            onDeleteAt: (_) {},
          ),
        ),
      );
      await tester.pump();

      // Date should be formatted as M/d/y h:mm a — just verify it contains
      // the year and the day, which are locale-invariant in this format.
      expect(find.textContaining('2024'), findsOneWidget);
    });

    testWidgets('omits date row when capturedAt is null', (tester) async {
      final examples = [
        makeExample(before: 'orignal', after: 'original'),
      ];

      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryCorrectionExamples(
            examples: examples,
            onDeleteAt: (_) {},
          ),
        ),
      );
      await tester.pump();

      // Only the title, description, and the example tile text should appear —
      // no date text at all.
      expect(find.textContaining('2024'), findsNothing);
    });

    testWidgets('does not show warning banner below threshold', (tester) async {
      final examples = List.generate(
        10, // well below 400
        (i) => makeExample(before: 'b$i', after: 'a$i'),
      );

      await tester.pumpWidget(
        WidgetTestBench(
          surfaceConstraints: const BoxConstraints(
            minWidth: 800,
            minHeight: 800,
          ),
          child: SingleChildScrollView(
            child: CategoryCorrectionExamples(
              examples: examples,
              onDeleteAt: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    });

    testWidgets('renders all tiles for a small list', (tester) async {
      final examples = [
        makeExample(before: 'first', after: 'corrected first'),
        makeExample(before: 'second', after: 'corrected second'),
        makeExample(before: 'third', after: 'corrected third'),
      ];

      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryCorrectionExamples(
            examples: examples,
            onDeleteAt: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(
        find.textContaining('"first"', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('"second"', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('"third"', findRichText: true),
        findsOneWidget,
      );
    });
  });

  group('CategoryCorrectionExamples — warning banner', () {
    testWidgets('shows warning banner when count exceeds threshold', (
      tester,
    ) async {
      // Generate 401 examples to exceed kCorrectionExamplesWarningThreshold
      // (which is 400). Wrap in a scrollable so the list does not overflow the
      // test surface during layout.
      final examples = List.generate(
        401,
        (i) => makeExample(before: 'b$i', after: 'a$i'),
      );

      await tester.pumpWidget(
        WidgetTestBench(
          surfaceConstraints: const BoxConstraints(
            minWidth: 800,
            minHeight: 800,
          ),
          child: SingleChildScrollView(
            child: CategoryCorrectionExamples(
              examples: examples,
              onDeleteAt: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      // Warning text should mention the count and the max prompt limit.
      expect(find.textContaining('401'), findsOneWidget);
      expect(
        find.textContaining('$kMaxCorrectionExamplesForPrompt'),
        findsOneWidget,
      );
    });

    testWidgets('warning banner is absent at exactly the threshold', (
      tester,
    ) async {
      final examples = List.generate(
        kCorrectionExamplesWarningThreshold,
        (i) => makeExample(before: 'b$i', after: 'a$i'),
      );

      await tester.pumpWidget(
        WidgetTestBench(
          surfaceConstraints: const BoxConstraints(
            minWidth: 800,
            minHeight: 800,
          ),
          child: SingleChildScrollView(
            child: CategoryCorrectionExamples(
              examples: examples,
              onDeleteAt: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    });
  });

  group('CategoryCorrectionExamples — delete interaction', () {
    testWidgets('onDeleteAt is called with correct index on swipe-to-delete', (
      tester,
    ) async {
      final deletedIndices = <int>[];

      final examples = [
        makeExample(before: 'first', after: 'corrected first'),
        makeExample(before: 'second', after: 'corrected second'),
      ];

      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryCorrectionExamples(
            examples: examples,
            onDeleteAt: deletedIndices.add,
          ),
        ),
      );
      await tester.pump();

      // Swipe the first tile (index 0) from right to left to trigger delete.
      await tester.drag(
        find.byKey(const ValueKey('correction-example-0')),
        const Offset(-600, 0),
      );
      await tester.pumpAndSettle();

      expect(deletedIndices, contains(0));
    });

    testWidgets('delete background shows delete icon during swipe', (
      tester,
    ) async {
      final examples = [makeExample(before: 'x', after: 'y')];

      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryCorrectionExamples(
            examples: examples,
            onDeleteAt: (_) {},
          ),
        ),
      );
      await tester.pump();

      // Start a drag to reveal the background.
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('correction-example-0'))),
      );
      await gesture.moveBy(const Offset(-200, 0));
      await tester.pump();

      expect(find.byIcon(Icons.delete), findsOneWidget);

      await gesture.cancel();
      await tester.pumpAndSettle();
    });

    testWidgets('each tile has a unique Dismissible key', (tester) async {
      final examples = List.generate(
        3,
        (i) => makeExample(before: 'b$i', after: 'a$i'),
      );

      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryCorrectionExamples(
            examples: examples,
            onDeleteAt: (_) {},
          ),
        ),
      );
      await tester.pump();

      for (var i = 0; i < 3; i++) {
        expect(
          find.byKey(ValueKey('correction-example-$i')),
          findsOneWidget,
        );
      }
    });
  });

  group(
    'kCorrectionExamplesWarningThreshold and kMaxCorrectionExamplesForPrompt constants',
    () {
      test('warning threshold has expected value', () {
        expect(kCorrectionExamplesWarningThreshold, equals(400));
      });

      test('max prompt examples has expected value', () {
        expect(kMaxCorrectionExamplesForPrompt, equals(500));
      });
    },
  );
}
