import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/surveys/definitions/panas_survey.dart';
import 'package:lotti/features/surveys/ui/fill_survey_page.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:research_package/research_package.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockDomainLogger mockDomainLogger;

  setUp(() {
    mockDomainLogger = MockDomainLogger();
  });

  void verifyCancelLogged(String message) {
    verify(
      () => mockDomainLogger.log(
        LogDomain.general,
        message,
        subDomain: 'SurveyWidget',
      ),
    ).called(1);
  }

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
    Locale? locale,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(body: SurveyWidget(task, resultCallback)),
        locale: locale,
        overrides: [domainLoggerProvider.overrideWithValue(mockDomainLogger)],
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
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
      // callback): driving it with a null result must log the cancellation and
      // must never invoke resultCallback.
      var submitFired = false;
      final wiredRpuiTask = await pumpSurvey(
        tester,
        task: buildTask('cancel_wiring'),
        resultCallback: (_) => submitFired = true,
      );
      wiredRpuiTask.onCancel!(null);
      expect(submitFired, isFalse);
      verifyCancelLogged('Survey cancelled without a result');
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

    testWidgets('PANAS choices fit after advancing from instructions', (
      tester,
    ) async {
      await pumpSurvey(
        tester,
        task: createPanasSurveyTask(
          await AppLocalizations.delegate.load(const Locale('en')),
        ),
        resultCallback: (_) {},
      );

      final messages = await AppLocalizations.delegate.load(
        const Locale('en'),
      );
      await tester.tap(find.text(messages.surveyNextButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Interested'), findsOneWidget);
      expect(find.text('Very slightly or not at all'), findsOneWidget);
      expect(find.text('Extremely'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('uses the active locale for Research Package controls', (
      tester,
    ) async {
      await pumpSurvey(
        tester,
        task: createPanasSurveyTask(
          await AppLocalizations.delegate.load(const Locale('de')),
        ),
        resultCallback: (_) {},
        locale: const Locale('de'),
      );

      expect(find.text('Weiter'), findsOneWidget);
      expect(find.text('1 von 22'), findsOneWidget);

      await tester.tap(find.text('Weiter'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Interessiert'), findsOneWidget);
    });

    testWidgets(
      'onCancel with a non-null result logs only the step-result count',
      (tester) async {
        var callbackFired = false;
        final rpuiTask = await pumpSurvey(
          tester,
          task: buildTask('cancel_task'),
          resultCallback: (_) => callbackFired = true,
        );

        final result = RPTaskResult(identifier: 'cancel_result_id')
          ..setStepResultForIdentifier(
            'q1',
            RPStepResult(
              identifier: 'q1',
              questionTitle: 'How do you feel?',
              answerFormat: RPChoiceAnswerFormat(
                answerStyle: RPChoiceAnswerStyle.SingleChoice,
                choices: [RPChoice(text: 'Private answer', value: 1)],
              ),
            ),
          );
        rpuiTask.onCancel!(result);

        // The cancel path does not invoke the submit callback.
        expect(callbackFired, isFalse);

        // Only the count reaches the log — never the answers themselves.
        verifyCancelLogged('Survey cancelled with 1 step results');
        verifyNever(
          () => mockDomainLogger.log(
            any(),
            any(that: contains('Private answer')),
            subDomain: any(named: 'subDomain'),
            level: any(named: 'level'),
          ),
        );
      },
    );

    testWidgets('onCancel with a null result logs a cancellation without one', (
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
      verifyCancelLogged('Survey cancelled without a result');
      verifyNoMoreInteractions(mockDomainLogger);
    });
  });
}
