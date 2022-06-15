import 'package:flutter/widgets.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:research_package/model.dart';

Map<String, int> calculateScores({
  required Map<String, Set<String>> scoreDefinitions,
  required RPTaskResult taskResult,
}) {
  final results = taskResult.results;
  final calculatedScores = <String, int>{};

  for (final scoreDefinition in scoreDefinitions.entries) {
    var score = 0;

    for (final questionId in scoreDefinition.value) {
      final stepResult = results[questionId] as RPStepResult;
      final choice = stepResult.results['answer'] as RPImageChoice;
      final value = choice.value as int;
      score = score + value;
    }

    calculatedScores[scoreDefinition.key] = score;
  }

  return calculatedScores;
}

void Function(RPTaskResult) createResultCallback({
  required Map<String, Set<String>> scoreDefinitions,
  required BuildContext context,
  String? linkedId,
}) {
  final persistenceLogic = getIt<PersistenceLogic>();

  return (RPTaskResult taskResult) {
    persistenceLogic.createSurveyEntry(
      data: SurveyData(
        taskResult: taskResult,
        scoreDefinitions: scoreDefinitions,
        calculatedScores: calculateScores(
          scoreDefinitions: scoreDefinitions,
          taskResult: taskResult,
        ),
      ),
      linkedId: linkedId,
    );
  };
}
