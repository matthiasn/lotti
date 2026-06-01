import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/surveys/definitions/cfq11_survey.dart';
import 'package:lotti/features/surveys/definitions/ghq12_survey.dart';
import 'package:lotti/features/surveys/definitions/panas_survey.dart';
import 'package:lotti/features/surveys/tools/run_surveys.dart';
import 'package:lotti/features/surveys/ui/fill_survey_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:research_package/model.dart';

import '../../../mocks/mocks.dart';

void main() {
  setUp(() async {
    DevLogger.suppressOutput = true;
    await getIt.reset();
    // The result callbacks built by the runners resolve PersistenceLogic.
    getIt.registerSingleton<PersistenceLogic>(MockPersistenceLogic());
  });

  tearDown(() async {
    DevLogger.suppressOutput = false;
    await getIt.reset();
  });

  Future<void> pumpRunner(
    WidgetTester tester,
    void Function(BuildContext) run,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => run(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  final runnerCases =
      <({String label, void Function(BuildContext) run, String expectedId})>[
        (
          label: 'runCfq11',
          run: (context) =>
              runCfq11(context: context, themeData: Theme.of(context)),
          expectedId: cfq11SurveyTask.identifier,
        ),
        (
          label: 'runGhq12',
          run: (context) =>
              runGhq12(context: context, themeData: Theme.of(context)),
          expectedId: ghq12SurveyTask.identifier,
        ),
        (
          label: 'runPanas',
          run: (context) =>
              runPanas(context: context, themeData: Theme.of(context)),
          expectedId: panasSurveyTask.identifier,
        ),
      ];

  for (final testCase in runnerCases) {
    testWidgets('${testCase.label} opens its survey in a modal', (
      tester,
    ) async {
      await pumpRunner(tester, testCase.run);

      final surveyWidget = tester.widget<SurveyWidget>(
        find.byType(SurveyWidget),
      );
      expect(surveyWidget.task.identifier, testCase.expectedId);
    });
  }

  testWidgets('runSurvey shows the provided task without firing the callback', (
    tester,
  ) async {
    final task = RPOrderedTask(
      identifier: 'custom-survey',
      steps: [
        RPInstructionStep(
          identifier: 'intro',
          title: 'Welcome',
          text: 'A custom survey',
        ),
      ],
    );
    var callbackInvoked = false;

    await pumpRunner(
      tester,
      (context) => runSurvey(
        task: task,
        themeData: Theme.of(context),
        context: context,
        resultCallback: (_) => callbackInvoked = true,
      ),
    );

    final surveyWidget = tester.widget<SurveyWidget>(find.byType(SurveyWidget));
    expect(surveyWidget.task, same(task));
    // The callback only runs when the survey is submitted, not on open.
    expect(callbackInvoked, isFalse);
  });
}
