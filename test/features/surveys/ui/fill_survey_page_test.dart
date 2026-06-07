import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/surveys/ui/fill_survey_page.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:research_package/research_package.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    DevLogger.suppressOutput = true;
    DevLogger.clear();
  });

  tearDown(() {
    DevLogger.suppressOutput = false;
  });

  RPOrderedTask buildTask(String identifier) => RPOrderedTask(
    identifier: identifier,
    steps: [
      RPInstructionStep(
        identifier: 'intro',
        title: 'Welcome',
        text: 'This is a test survey',
      ),
    ],
  );

  /// Pumps a [SurveyWidget] and returns the rendered [RPUITask] so tests can
  /// drive the real `onSubmit` / `onCancel` closures defined in
  /// `SurveyWidget.build`.
  Future<RPUITask> pumpSurvey(
    WidgetTester tester, {
    required RPOrderedTask task,
    required void Function(RPTaskResult) resultCallback,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SurveyWidget(task, resultCallback),
        ),
      ),
    );
    await tester.pump();
    return tester.widget<RPUITask>(find.byType(RPUITask));
  }

  group('SurveyWidget', () {
    testWidgets('builds an RPUITask wired to the provided task and callback', (
      tester,
    ) async {
      final task = buildTask('build_task');
      void cb(RPTaskResult _) {}

      final rpuiTask = await pumpSurvey(
        tester,
        task: task,
        resultCallback: cb,
      );

      // The RPUITask is built with the exact task passed in and the
      // resultCallback wired directly to onSubmit.
      expect(rpuiTask.task, same(task));
      expect(rpuiTask.task.identifier, 'build_task');
      expect(rpuiTask.onSubmit, same(cb));

      // onCancel is wired to SurveyWidget's local closure (not the submit
      // callback): driving it with a null result must log 'No result' and must
      // never invoke resultCallback.
      var submitFired = false;
      final wiredRpuiTask = await pumpSurvey(
        tester,
        task: buildTask('cancel_wiring'),
        resultCallback: (_) => submitFired = true,
      );
      wiredRpuiTask.onCancel!(null);
      expect(submitFired, isFalse);
      expect(DevLogger.capturedLogs, contains('[SurveyWidget] No result'));
    });

    testWidgets('onSubmit forwards the result to resultCallback', (
      tester,
    ) async {
      RPTaskResult? submitted;
      final rpuiTask = await pumpSurvey(
        tester,
        task: buildTask('submit_task'),
        resultCallback: (result) => submitted = result,
      );

      final result = RPTaskResult(identifier: 'submit_result');
      rpuiTask.onSubmit!(result);

      // The widget passes resultCallback straight through to RPUITask.onSubmit,
      // so driving onSubmit must deliver the same result instance.
      expect(submitted, same(result));
      expect(submitted!.identifier, 'submit_result');
    });

    testWidgets(
      'onCancel with a non-null result logs the encoded result via cancelCallBack',
      (tester) async {
        var callbackFired = false;
        final rpuiTask = await pumpSurvey(
          tester,
          task: buildTask('cancel_task'),
          resultCallback: (_) => callbackFired = true,
        );

        final result = RPTaskResult(identifier: 'cancel_result_id');
        rpuiTask.onCancel!(result);

        // cancelCallBack does not invoke the submit callback.
        expect(callbackFired, isFalse);

        // The produced log line is "[SurveyWidget] The result so far:\n<json>".
        final logLine = DevLogger.capturedLogs.singleWhere(
          (log) => log.contains('The result so far:'),
          orElse: () => '',
        );
        expect(logLine, contains('[SurveyWidget]'));

        // The JSON body produced by SurveyWidget._encode must be valid JSON and
        // must contain the result's identifier under the "identifier" key.
        final jsonBody = logLine.split('The result so far:\n').last;
        final decoded = jsonDecode(jsonBody) as Map<String, dynamic>;
        expect(decoded['identifier'], 'cancel_result_id');

        // _encode uses an indented encoder, so the body is pretty-printed.
        expect(jsonBody, contains('\n'));
      },
    );

    testWidgets('onCancel with a null result logs "No result"', (
      tester,
    ) async {
      var callbackFired = false;
      final rpuiTask = await pumpSurvey(
        tester,
        task: buildTask('null_cancel_task'),
        resultCallback: (_) => callbackFired = true,
      );

      rpuiTask.onCancel!(null);

      expect(callbackFired, isFalse);
      expect(
        DevLogger.capturedLogs,
        contains('[SurveyWidget] No result'),
      );
      // The null branch must not emit the encoded-result log line.
      expect(
        DevLogger.capturedLogs.any((log) => log.contains('The result so far:')),
        isFalse,
      );
    });
  });
}
