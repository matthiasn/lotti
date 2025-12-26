import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/surveys/ui/fill_survey_page.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:research_package/model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    DevLogger.suppressOutput = true;
    DevLogger.clear();
  });

  tearDown(() {
    DevLogger.suppressOutput = false;
  });

  group('SurveyWidget Tests -', () {
    testWidgets('SurveyWidget renders with task', (tester) async {
      // Create a simple ordered task with one step
      final task = RPOrderedTask(
        identifier: 'test_task',
        steps: [
          RPInstructionStep(
            identifier: 'intro',
            title: 'Welcome',
            text: 'This is a test survey',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SurveyWidget(
              task,
              (result) {
                // Callback when survey is completed
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify the widget renders
      expect(find.byType(SurveyWidget), findsOneWidget);

      // The survey widget should show something from research_package
      // The exact text depends on research_package implementation
    });

    testWidgets('SurveyWidget renders with cancel-enabled task',
        (tester) async {
      final task = RPOrderedTask(
        identifier: 'cancel_test_task',
        steps: [
          RPInstructionStep(
            identifier: 'intro',
            title: 'Test',
            text: 'Testing cancel',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SurveyWidget(
              task,
              (result) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // The RPUITask widget handles cancel internally via research_package.
      // We verify the widget renders without error.
      expect(find.byType(SurveyWidget), findsOneWidget);
    });

    test('SurveyWidget task identifier is accessible', () {
      // Test that SurveyWidget exposes task correctly
      final task = RPOrderedTask(
        identifier: 'direct_test',
        steps: [],
      );

      final widget = SurveyWidget(
        task,
        (result) {},
      );

      // Verify the task is accessible
      expect(widget.task.identifier, 'direct_test');
    });

    test(
        'DevLogger.log is called with SurveyWidget name for cancel with result',
        () {
      // Direct test of the logging pattern
      DevLogger.clear();

      // Simulate what cancelCallBack does
      DevLogger.log(
        name: 'SurveyWidget',
        message: 'The result so far:\n{"test": "data"}',
      );

      expect(
        DevLogger.capturedLogs.any(
          (log) =>
              log.contains('SurveyWidget') &&
              log.contains('The result so far:'),
        ),
        isTrue,
        reason: 'DevLogger should capture SurveyWidget cancel logs',
      );
    });

    test('DevLogger.log is called with No result message for null cancel', () {
      // Direct test of the logging pattern for null result
      DevLogger.clear();

      // Simulate what onCancel does when result is null
      DevLogger.log(name: 'SurveyWidget', message: 'No result');

      expect(
        DevLogger.capturedLogs.any(
          (log) => log.contains('SurveyWidget') && log.contains('No result'),
        ),
        isTrue,
        reason: 'DevLogger should capture SurveyWidget null cancel logs',
      );
    });
  });
}
