import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/ui/widgets/category_correction_examples.dart';

import '../../../../test_helper.dart';

void main() {
  group('CategoryCorrectionExamples', () {
    Future<void> pumpExamples(
      WidgetTester tester, {
      List<ChecklistCorrectionExample>? examples,
      ValueChanged<int>? onDeleteAt,
    }) {
      return tester.pumpWidget(
        WidgetTestBench(
          child: SingleChildScrollView(
            child: CategoryCorrectionExamples(
              examples: examples,
              onDeleteAt: onDeleteAt ?? (_) {},
            ),
          ),
        ),
      );
    }

    testWidgets('shows empty state for null and empty lists', (tester) async {
      for (final examples in [null, <ChecklistCorrectionExample>[]]) {
        await pumpExamples(tester, examples: examples);

        expect(
          find.textContaining('No corrections captured yet'),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.info_outline), findsOneWidget);
      }
    });

    testWidgets('renders before/after text for each example', (tester) async {
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

      await pumpExamples(tester, examples: examples);

      Finder richTextContaining(String text) => find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains(text),
      );

      for (final e in examples) {
        expect(richTextContaining(e.before), findsOneWidget);
        expect(richTextContaining(e.after), findsOneWidget);
      }
    });

    testWidgets('dismiss calls onDeleteAt with correct index', (tester) async {
      int? deletedIndex;

      await pumpExamples(
        tester,
        examples: [
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
        ],
        onDeleteAt: (i) => deletedIndex = i,
      );

      await tester.drag(
        find.byKey(const ValueKey('correction-example-1')),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();

      expect(deletedIndex, equals(1));
    });

    testWidgets('shows warning only above threshold', (tester) async {
      // Below threshold — no warning
      await pumpExamples(
        tester,
        examples: List.generate(
          kCorrectionExamplesWarningThreshold,
          (i) => ChecklistCorrectionExample(
            before: 'b$i',
            after: 'a$i',
            capturedAt: DateTime(2025),
          ),
        ),
      );
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);

      // Above threshold — warning visible
      await pumpExamples(
        tester,
        examples: List.generate(
          kCorrectionExamplesWarningThreshold + 1,
          (i) => ChecklistCorrectionExample(
            before: 'b$i',
            after: 'a$i',
            capturedAt: DateTime(2025),
          ),
        ),
      );
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });
  });
}
