import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart'
    show
        Any,
        AnyUtils,
        CombinableAny,
        ExploreConfig,
        Generator,
        GeneratorUtils,
        Glados,
        IntAnys,
        ListAnys,
        any;
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/surveys/tools/calculate.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:mocktail/mocktail.dart' as mt;
import 'package:research_package/model.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

/// How a generated answer is stored on its step result. Each shape maps to a
/// branch of [calculateScores]'s value extraction.
enum _AnswerKind {
  /// Single `RPChoice` in a list — the common case.
  choiceList,

  /// A list whose first choice carries the value and a decoy second choice
  /// that must be ignored (`firstOrNull` semantics).
  choiceListDecoy,

  /// An `RPImageChoice` whose `value` is read via `as int`.
  imageChoice,

  /// An empty choice list — `firstOrNull` is null, contributes 0.
  emptyList,

  /// No step result is recorded for the question at all, contributes 0.
  missing,

  /// A non-choice answer (e.g. a String), contributes 0.
  wrongType,
}

/// Which score group a question is assigned to (or none).
enum _GroupSlot { none, a, b, c }

class _AnswerSpec {
  const _AnswerSpec({
    required this.kind,
    required this.value,
    required this.slot,
  });

  final _AnswerKind kind;
  final int value;
  final _GroupSlot slot;

  /// The score contribution [calculateScores] should attribute to this answer.
  int get effectiveValue => switch (kind) {
    _AnswerKind.choiceList ||
    _AnswerKind.choiceListDecoy ||
    _AnswerKind.imageChoice => value,
    _AnswerKind.emptyList ||
    _AnswerKind.missing ||
    _AnswerKind.wrongType => 0,
  };

  @override
  String toString() => '_AnswerSpec(kind: $kind, value: $value, slot: $slot)';
}

class _ScoreScenario {
  const _ScoreScenario({required this.specs});

  final List<_AnswerSpec> specs;

  String _questionId(int index) => 'q$index';

  RPStepResult? _stepResultFor(String id, _AnswerSpec spec) {
    final format = RPChoiceAnswerFormat(
      answerStyle: RPChoiceAnswerStyle.SingleChoice,
      choices: [RPChoice(text: 'a', value: spec.value)],
    );
    RPStepResult step() => RPStepResult(
      identifier: id,
      questionTitle: id,
      answerFormat: format,
    );
    switch (spec.kind) {
      case _AnswerKind.missing:
        return null;
      case _AnswerKind.choiceList:
        return step()..setResult(<RPChoice>[RPChoice(text: 'a', value: spec.value)]);
      case _AnswerKind.choiceListDecoy:
        return step()
          ..setResult(<RPChoice>[
            RPChoice(text: 'a', value: spec.value),
            RPChoice(text: 'decoy', value: spec.value + 7),
          ]);
      case _AnswerKind.imageChoice:
        return step()
          ..setResult(
            RPImageChoice(imageUrl: 'i', description: 'd', value: spec.value),
          );
      case _AnswerKind.emptyList:
        return step()..setResult(<RPChoice>[]);
      case _AnswerKind.wrongType:
        return step()..setResult('not-a-choice');
    }
  }

  RPTaskResult get taskResult {
    final result = RPTaskResult(identifier: 'generated-survey');
    for (final (index, spec) in specs.indexed) {
      final id = _questionId(index);
      final stepResult = _stepResultFor(id, spec);
      if (stepResult != null) {
        result.setStepResultForIdentifier(id, stepResult);
      }
    }
    return result;
  }

  Set<String> _groupIds(_GroupSlot slot) => {
    for (final (index, spec) in specs.indexed)
      if (spec.slot == slot) _questionId(index),
  };

  Map<String, Set<String>> get scoreDefinitions => {
    'A': _groupIds(_GroupSlot.a),
    'B': _groupIds(_GroupSlot.b),
    'C': _groupIds(_GroupSlot.c),
  };

  int _sumFor(_GroupSlot slot) =>
      specs.where((s) => s.slot == slot).fold(0, (a, s) => a + s.effectiveValue);

  Map<String, int> get expectedScores => {
    'A': _sumFor(_GroupSlot.a),
    'B': _sumFor(_GroupSlot.b),
    'C': _sumFor(_GroupSlot.c),
  };

  @override
  String toString() => '_ScoreScenario(specs: $specs)';
}

extension _AnyScoreScenario on Any {
  Generator<_AnswerKind> get answerKind => choose(_AnswerKind.values);

  Generator<_GroupSlot> get groupSlot => choose(_GroupSlot.values);

  Generator<_AnswerSpec> get answerSpec => combine3(
    answerKind,
    intInRange(-5, 11),
    groupSlot,
    (_AnswerKind kind, int value, _GroupSlot slot) =>
        _AnswerSpec(kind: kind, value: value, slot: slot),
  );

  Generator<_ScoreScenario> get scoreScenario => listWithLengthInRange(
    0,
    12,
    answerSpec,
  ).map((specs) => _ScoreScenario(specs: specs));
}

RPStepResult _choiceStep(String id, int value) => RPStepResult(
  identifier: id,
  questionTitle: id,
  answerFormat: RPChoiceAnswerFormat(
    answerStyle: RPChoiceAnswerStyle.SingleChoice,
    choices: [RPChoice(text: 'a', value: value)],
  ),
)..setResult(<RPChoice>[RPChoice(text: 'a', value: value)]);

void main() {
  group('calculateScores', () {
    test('returns 0 for a score group with no questions', () {
      final scores = calculateScores(
        scoreDefinitions: {'Empty': <String>{}},
        taskResult: RPTaskResult(identifier: 't'),
      );
      expect(scores, {'Empty': 0});
    });

    test('treats a missing step result as 0', () {
      final scores = calculateScores(
        scoreDefinitions: {
          'S': {'q0'},
        },
        taskResult: RPTaskResult(identifier: 't'),
      );
      expect(scores, {'S': 0});
    });

    test('treats an empty choice list as 0', () {
      final taskResult = RPTaskResult(identifier: 't')
        ..setStepResultForIdentifier(
          'q0',
          RPStepResult(
            identifier: 'q0',
            questionTitle: 'q0',
            answerFormat: RPChoiceAnswerFormat(
              answerStyle: RPChoiceAnswerStyle.SingleChoice,
              choices: const [],
            ),
          )..setResult(<RPChoice>[]),
        );
      final scores = calculateScores(
        scoreDefinitions: {
          'S': {'q0'},
        },
        taskResult: taskResult,
      );
      expect(scores, {'S': 0});
    });

    test('treats a non-choice answer as 0', () {
      final taskResult = RPTaskResult(identifier: 't')
        ..setStepResultForIdentifier(
          'q0',
          RPStepResult(
            identifier: 'q0',
            questionTitle: 'q0',
            answerFormat: RPChoiceAnswerFormat(
              answerStyle: RPChoiceAnswerStyle.SingleChoice,
              choices: const [],
            ),
          )..setResult('garbage'),
        );
      final scores = calculateScores(
        scoreDefinitions: {
          'S': {'q0'},
        },
        taskResult: taskResult,
      );
      expect(scores, {'S': 0});
    });

    test('reads the value from an image choice', () {
      final taskResult = RPTaskResult(identifier: 't')
        ..setStepResultForIdentifier(
          'q0',
          RPStepResult(
            identifier: 'q0',
            questionTitle: 'q0',
            answerFormat: RPChoiceAnswerFormat(
              answerStyle: RPChoiceAnswerStyle.SingleChoice,
              choices: const [],
            ),
          )..setResult(
            RPImageChoice(imageUrl: 'i', description: 'd', value: 4),
          ),
        );
      final scores = calculateScores(
        scoreDefinitions: {
          'S': {'q0'},
        },
        taskResult: taskResult,
      );
      expect(scores, {'S': 4});
    });

    test('only the first choice in a list contributes', () {
      final taskResult = RPTaskResult(identifier: 't')
        ..setStepResultForIdentifier('q0', _choiceStep('q0', 2));
      final scores = calculateScores(
        scoreDefinitions: {
          'S': {'q0'},
        },
        taskResult: taskResult,
      );
      expect(scores, {'S': 2});
    });

    test('sums values across all questions in a group', () {
      final taskResult = RPTaskResult(identifier: 't')
        ..setStepResultForIdentifier('q0', _choiceStep('q0', 1))
        ..setStepResultForIdentifier('q1', _choiceStep('q1', 2))
        ..setStepResultForIdentifier('q2', _choiceStep('q2', 3));
      final scores = calculateScores(
        scoreDefinitions: {
          'Total': {'q0', 'q1', 'q2'},
        },
        taskResult: taskResult,
      );
      expect(scores, {'Total': 6});
    });

    test('a question shared by two groups counts toward both', () {
      final taskResult = RPTaskResult(identifier: 't')
        ..setStepResultForIdentifier('q0', _choiceStep('q0', 5));
      final scores = calculateScores(
        scoreDefinitions: {
          'A': {'q0'},
          'B': {'q0'},
        },
        taskResult: taskResult,
      );
      expect(scores, {'A': 5, 'B': 5});
    });

    Glados(any.scoreScenario, ExploreConfig(numRuns: 150)).test(
      'sums the effective value of each group across any answer shapes',
      (scenario) {
        final scores = calculateScores(
          scoreDefinitions: scenario.scoreDefinitions,
          taskResult: scenario.taskResult,
        );
        expect(scores, scenario.expectedScores, reason: '$scenario');
      },
      tags: 'glados',
    );
  });

  group('createResultCallback', () {
    setUpAll(registerAllFallbackValues);

    late MockPersistenceLogic mockPersistence;

    setUp(() async {
      await getIt.reset();
      mockPersistence = MockPersistenceLogic();
      mt.when(
        () => mockPersistence.createSurveyEntry(
          data: mt.any(named: 'data'),
          linkedId: mt.any(named: 'linkedId'),
        ),
      ).thenAnswer((_) async => true);
      getIt.registerSingleton<PersistenceLogic>(mockPersistence);
    });

    tearDown(() async {
      await getIt.reset();
    });

    testWidgets('persists a survey entry with the computed scores', (
      tester,
    ) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox();
          },
        ),
      );

      final scoreDefinitions = {
        'S': {'q0', 'q1'},
      };
      final callback = createResultCallback(
        scoreDefinitions: scoreDefinitions,
        context: capturedContext,
        linkedId: 'linked-123',
      );

      final taskResult = RPTaskResult(identifier: 't')
        ..setStepResultForIdentifier('q0', _choiceStep('q0', 2))
        ..setStepResultForIdentifier('q1', _choiceStep('q1', 3));

      callback(taskResult);

      final captured = mt.verify(
        () => mockPersistence.createSurveyEntry(
          data: mt.captureAny(named: 'data'),
          linkedId: 'linked-123',
        ),
      ).captured.single as SurveyData;

      expect(captured.scoreDefinitions, scoreDefinitions);
      expect(captured.calculatedScores, {'S': 5});
      expect(captured.taskResult, same(taskResult));
    });

    testWidgets('passes a null linkedId through to persistence', (
      tester,
    ) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox();
          },
        ),
      );

      final callback = createResultCallback(
        scoreDefinitions: const {},
        context: capturedContext,
      );
      callback(RPTaskResult(identifier: 't'));

      mt.verify(
        () => mockPersistence.createSurveyEntry(
          data: mt.any(named: 'data'),
          // ignore: avoid_redundant_argument_values
          linkedId: null,
        ),
      ).called(1);
    });
  });
}
