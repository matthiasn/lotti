import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tasks/ui/checklists/progress_indicator.dart';
import 'package:lotti/themes/colors.dart';

import '../../../../test_helper.dart';

void main() {
  group('ChecklistProgressIndicator', () {
    testWidgets('renders with correct size and padding', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          const ChecklistProgressIndicator(
            completionRate: 0.5,
            completedCount: 2,
            totalCount: 4,
          ),
        ),
      );

      // Verify widget is rendered
      expect(find.byType(ChecklistProgressIndicator), findsOneWidget);

      // Verify the padding is applied
      expect(find.byType(Padding), findsOneWidget);

      // Verify the SizedBox has correct dimensions
      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
      expect(sizedBox.width, 16);
      expect(sizedBox.height, 16);
    });

    testWidgets('renders CircularProgressIndicator with correct properties',
        (tester) async {
      const completionRate = 0.75;

      await tester.pumpWidget(
        createTestApp(
          const ChecklistProgressIndicator(
            completionRate: completionRate,
            completedCount: 3,
            totalCount: 4,
          ),
        ),
      );

      // Find the CircularProgressIndicator
      final progressIndicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );

      // Verify properties
      expect(progressIndicator.value, completionRate);
      expect(progressIndicator.strokeWidth, 5);
      expect(progressIndicator.semanticsLabel, 'Checklist progress');
      expect(progressIndicator.color, successColor);
      expect(progressIndicator.backgroundColor, failColor);
    });

    testWidgets('handles different completion rates correctly', (tester) async {
      // Test with 0% completion
      await tester.pumpWidget(
        createTestApp(
          const ChecklistProgressIndicator(
            completionRate: 0,
            completedCount: 0,
            totalCount: 5,
          ),
        ),
      );

      var progressIndicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(progressIndicator.value, 0.0);

      // Test with 100% completion
      await tester.pumpWidget(
        createTestApp(
          const ChecklistProgressIndicator(
            completionRate: 1,
            completedCount: 5,
            totalCount: 5,
          ),
        ),
      );

      progressIndicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(progressIndicator.value, 1.0);
    });

    testWidgets('renders correctly with empty checklist (totalCount = 0)',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          const ChecklistProgressIndicator(
            completionRate: 0,
            completedCount: 0,
            totalCount: 0,
          ),
        ),
      );

      // Verify widget still renders
      expect(find.byType(ChecklistProgressIndicator), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Progress indicator should show 0 completion
      final progressIndicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(progressIndicator.value, 0.0);
    });
  });
}
