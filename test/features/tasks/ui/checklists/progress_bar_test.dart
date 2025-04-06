import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_widget.dart';
import 'package:lotti/themes/colors.dart';

import '../../../../test_helper.dart';

void main() {
  group('ProgressBar', () {
    testWidgets('shows correct progress for 0% completion', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          const ProgressBar(
            completionRate: 0,
            completedCount: 0,
            totalCount: 5,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the progress indicator is rendered with 0% progress
      final progressIndicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(progressIndicator.value, equals(0.0));

      // Verify the text shows 0/5
      expect(find.text('0/5'), findsOneWidget);
    });

    testWidgets('shows correct progress for 50% completion', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          const ProgressBar(
            completionRate: 0.5,
            completedCount: 2,
            totalCount: 4,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the progress indicator is rendered with 50% progress
      final progressIndicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(progressIndicator.value, equals(0.5));

      // Verify the text shows 2/4
      expect(find.text('2/4'), findsOneWidget);
    });

    testWidgets('shows correct progress for 100% completion', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          const ProgressBar(
            completionRate: 1,
            completedCount: 3,
            totalCount: 3,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the progress indicator is rendered with 100% progress
      final progressIndicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(progressIndicator.value, equals(1.0));

      // Verify the text shows 3/3
      expect(find.text('3/3'), findsOneWidget);
    });

    testWidgets('uses the success color for the progress indicator',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          const ProgressBar(
            completionRate: 0.5,
            completedCount: 1,
            totalCount: 2,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the progress indicator uses the success color
      final progressIndicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(progressIndicator.color, equals(successColor));
    });

    testWidgets('has appropriate semantics label', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          const ProgressBar(
            completionRate: 0.5,
            completedCount: 1,
            totalCount: 2,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the progress indicator has a semantics label
      final progressIndicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(progressIndicator.semanticsLabel, equals('Checklist progress'));
    });
  });
}
