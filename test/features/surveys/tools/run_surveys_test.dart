import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/surveys/definitions/cfq11_survey.dart';
import 'package:lotti/features/surveys/definitions/ghq12_survey.dart';
import 'package:lotti/features/surveys/definitions/panas_survey.dart';
import 'package:lotti/features/surveys/tools/run_surveys.dart';
import 'package:lotti/features/surveys/ui/fill_survey_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:research_package/model.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

/// Builds a single-choice step result whose answer carries [value], matching
/// the shape that `calculateScores` extracts (a `List<RPChoice>`).
RPStepResult _choiceStep(String id, int value) => RPStepResult(
  identifier: id,
  questionTitle: id,
  answerFormat: RPChoiceAnswerFormat(
    answerStyle: RPChoiceAnswerStyle.SingleChoice,
    choices: [RPChoice(text: 'a', value: value)],
  ),
)..setResult(<RPChoice>[RPChoice(text: 'a', value: value)]);

void main() {
  setUpAll(registerAllFallbackValues);

  late MockPersistenceLogic mockPersistence;

  setUp(() async {
    DevLogger.suppressOutput = true;
    await getIt.reset();
    mockPersistence = MockPersistenceLogic();
    // The result callbacks built by the runners resolve PersistenceLogic and
    // invoke createSurveyEntry when the survey is submitted.
    when(
      () => mockPersistence.createSurveyEntry(
        data: any(named: 'data'),
        linkedId: any(named: 'linkedId'),
      ),
    ).thenAnswer((_) async => true);
    getIt.registerSingleton<PersistenceLogic>(mockPersistence);
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
    // Bound the wait: the Wolt modal entrance animation settles well within
    // 500ms, so an unbounded pumpAndSettle (default 10s timeout) is unnecessary.
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
  }

  final runnerCases =
      <
        ({
          String label,
          void Function(BuildContext, {String? linkedId}) run,
          String expectedId,
          Map<String, Set<String>> scoreDefinitions,
          // Question ids (one per score group) paired with the value to answer
          // them with; the runner's score definitions turn these into
          // [expectedScores].
          List<({String questionId, int value})> answers,
          Map<String, int> expectedScores,
        })
      >[
        (
          label: 'runCfq11',
          run: (context, {linkedId}) => runCfq11(
            context: context,
            themeData: Theme.of(context),
            linkedId: linkedId,
          ),
          expectedId: cfq11SurveyTask.identifier,
          scoreDefinitions: cfq11ScoreDefinitions,
          answers: const [
            (questionId: 'cfq11Step1', value: 2),
            (questionId: 'cfq11Step2', value: 3),
          ],
          expectedScores: const {'CFQ11': 5},
        ),
        (
          label: 'runGhq12',
          run: (context, {linkedId}) => runGhq12(
            context: context,
            themeData: Theme.of(context),
            linkedId: linkedId,
          ),
          expectedId: ghq12SurveyTask.identifier,
          scoreDefinitions: ghq12ScoreDefinitions,
          answers: const [
            (questionId: 'ghq12Step1', value: 1),
            (questionId: 'ghq12Step2', value: 2),
          ],
          expectedScores: const {'GHQ12': 3},
        ),
        (
          label: 'runPanas',
          run: (context, {linkedId}) => runPanas(
            context: context,
            themeData: Theme.of(context),
            linkedId: linkedId,
          ),
          expectedId: panasSurveyTask.identifier,
          scoreDefinitions: panasScoreDefinitions,
          answers: const [
            (questionId: 'panasQuestion1', value: 4),
            (questionId: 'panasQuestion2', value: 1),
          ],
          expectedScores: const {
            'Positive Affect Score': 4,
            'Negative Affect Score': 1,
          },
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
      // Opening the survey must not yet persist anything.
      verifyNever(
        () => mockPersistence.createSurveyEntry(
          data: any(named: 'data'),
          linkedId: any(named: 'linkedId'),
        ),
      );
    });

    testWidgets(
      '${testCase.label} wires a callback that persists scored results',
      (tester) async {
        await pumpRunner(
          tester,
          (context) => testCase.run(context, linkedId: 'linked-42'),
        );

        final surveyWidget = tester.widget<SurveyWidget>(
          find.byType(SurveyWidget),
        );

        // Drive the real callback the runner wired into the widget, as the
        // research_package survey would on submission.
        final taskResult = RPTaskResult(identifier: testCase.expectedId);
        for (final answer in testCase.answers) {
          taskResult.setStepResultForIdentifier(
            answer.questionId,
            _choiceStep(answer.questionId, answer.value),
          );
        }
        surveyWidget.resultCallback(taskResult);

        final captured =
            verify(
                  () => mockPersistence.createSurveyEntry(
                    data: captureAny(named: 'data'),
                    linkedId: 'linked-42',
                  ),
                ).captured.single
                as SurveyData;

        // The runner-supplied score definitions and the computed scores for the
        // answered questions must reach persistence unchanged.
        expect(captured.scoreDefinitions, testCase.scoreDefinitions);
        expect(captured.calculatedScores, testCase.expectedScores);
        expect(captured.taskResult, same(taskResult));
      },
    );

    testWidgets(
      '${testCase.label} forwards a null linkedId when none is supplied',
      (tester) async {
        await pumpRunner(tester, testCase.run);

        final surveyWidget = tester.widget<SurveyWidget>(
          find.byType(SurveyWidget),
        );
        surveyWidget.resultCallback(
          RPTaskResult(identifier: testCase.expectedId),
        );

        verify(
          () => mockPersistence.createSurveyEntry(
            data: any(named: 'data'),
            // ignore: avoid_redundant_argument_values
            linkedId: null,
          ),
        ).called(1);
      },
    );
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

    // runSurvey wires the caller's callback straight through, so driving it
    // routes to that closure and never touches PersistenceLogic.
    surveyWidget.resultCallback(RPTaskResult(identifier: 'custom-survey'));
    expect(callbackInvoked, isTrue);
    verifyNever(
      () => mockPersistence.createSurveyEntry(
        data: any(named: 'data'),
        linkedId: any(named: 'linkedId'),
      ),
    );
  });
}
