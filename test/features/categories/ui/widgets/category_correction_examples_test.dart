import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/ui/widgets/category_correction_examples.dart';

import '../../../../test_helper.dart';

/// Helper to find RichText widgets containing specific text.
Finder findRichTextContaining(String text) {
  return find.byWidgetPredicate((widget) {
    if (widget is RichText) {
      final plainText = widget.text.toPlainText();
      return plainText.contains(text);
    }
    return false;
  });
}

void main() {
  group('CategoryCorrectionExamples', () {
    testWidgets('displays empty state when no examples', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryCorrectionExamples(
            examples: null,
            onDeleteAt: (_) {},
          ),
        ),
      );

      // Verify section title is shown
      expect(find.text('Checklist Correction Examples'), findsOneWidget);

      // Verify empty state message
      expect(
        find.textContaining('No corrections captured yet'),
        findsOneWidget,
      );

      // Verify info icon for empty state
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('displays empty state with empty list', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryCorrectionExamples(
            examples: const [],
            onDeleteAt: (_) {},
          ),
        ),
      );

      expect(
        find.textContaining('No corrections captured yet'),
        findsOneWidget,
      );
    });

    testWidgets('displays correction examples', (tester) async {
      final examples = [
        ChecklistCorrectionExample(
          before: 'test flight',
          after: 'TestFlight',
          capturedAt: DateTime(2025, 1, 15, 10, 30),
        ),
        ChecklistCorrectionExample(
          before: 'mac OS',
          after: 'macOS',
          capturedAt: DateTime(2025, 1, 16, 14),
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

      // Verify section title
      expect(find.text('Checklist Correction Examples'), findsOneWidget);

      // Verify before texts are displayed (using RichText finder)
      expect(findRichTextContaining('test flight'), findsOneWidget);
      expect(findRichTextContaining('mac OS'), findsOneWidget);

      // Verify after texts are displayed (using RichText finder)
      expect(findRichTextContaining('TestFlight'), findsOneWidget);
      expect(findRichTextContaining('macOS'), findsOneWidget);
    });

    testWidgets('calls onDeleteAt with correct index when swiped',
        (tester) async {
      int? deletedIndex;

      final examples = [
        ChecklistCorrectionExample(
          before: 'first',
          after: 'FIRST',
          capturedAt: DateTime(2025, 1, 15),
        ),
        ChecklistCorrectionExample(
          before: 'second',
          after: 'SECOND',
          capturedAt: DateTime(2025, 1, 16),
        ),
      ];

      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryCorrectionExamples(
            examples: examples,
            onDeleteAt: (index) {
              deletedIndex = index;
            },
          ),
        ),
      );

      // Find all Dismissible widgets
      final dismissibleFinder = find.byType(Dismissible);
      expect(dismissibleFinder, findsNWidgets(2));

      // Swipe the first one left to dismiss
      await tester.drag(dismissibleFinder.first, const Offset(-500, 0));
      await tester.pumpAndSettle();

      // Verify onDeleteAt was called with index 0
      expect(deletedIndex, equals(0));
    });

    testWidgets('shows warning when threshold exceeded', (tester) async {
      // Create more than 400 examples (warning threshold)
      final examples = List.generate(
        410,
        (i) => ChecklistCorrectionExample(
          before: 'before $i',
          after: 'after $i',
          capturedAt: DateTime(2025),
        ),
      );

      await tester.pumpWidget(
        WidgetTestBench(
          child: SingleChildScrollView(
            child: CategoryCorrectionExamples(
              examples: examples,
              onDeleteAt: (_) {},
            ),
          ),
        ),
      );

      // Verify warning is shown
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.textContaining('410'), findsOneWidget);
    });

    testWidgets('does not show warning when below threshold', (tester) async {
      final examples = [
        ChecklistCorrectionExample(
          before: 'before',
          after: 'after',
          capturedAt: DateTime(2025),
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

      // Verify warning icon is NOT shown
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    });

    testWidgets('displays section description', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryCorrectionExamples(
            examples: const [],
            onDeleteAt: (_) {},
          ),
        ),
      );

      expect(
        find.textContaining('used to improve AI suggestions'),
        findsOneWidget,
      );
    });

    testWidgets('shows delete icon in swipe background', (tester) async {
      final examples = [
        ChecklistCorrectionExample(
          before: 'before',
          after: 'after',
          capturedAt: DateTime(2025),
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

      // Start a drag to reveal background
      final dismissibleFinder = find.byType(Dismissible);
      await tester.drag(dismissibleFinder, const Offset(-100, 0));
      await tester.pump();

      // Delete icon should be visible in background
      expect(find.byIcon(Icons.delete), findsOneWidget);
    });
  });

  group('Constants', () {
    test('kCorrectionExamplesWarningThreshold has correct value', () {
      expect(kCorrectionExamplesWarningThreshold, equals(400));
    });

    test('kMaxCorrectionExamplesForPrompt has correct value', () {
      expect(kMaxCorrectionExamplesForPrompt, equals(500));
    });
  });
}
