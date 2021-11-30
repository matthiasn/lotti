import 'package:flutter/widgets.dart';
import 'package:lotti/blocs/journal/persistence_cubit.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:provider/src/provider.dart';
import 'package:research_package/model.dart';

Map<String, int> calculateScores({
  required Map<String, Set<String>> scoreDefinitions,
  required RPTaskResult taskResult,
}) {
  Map<String, dynamic> results = taskResult.results;
  Map<String, int> calculatedScores = {};

  for (MapEntry<String, Set<String>> scoreDefinition
      in scoreDefinitions.entries) {
    int score = 0;

    for (String questionId in scoreDefinition.value) {
      RPStepResult stepResult = results[questionId];
      RPImageChoice choice = stepResult.results['answer'];
      int value = choice.value;
      score = score + value;
    }

    calculatedScores[scoreDefinition.key] = score;
  }

  return calculatedScores;
}

Function(RPTaskResult) createResultCallback({
  required Map<String, Set<String>> scoreDefinitions,
  required BuildContext context,
}) {
  return (RPTaskResult taskResult) {
    context.read<PersistenceCubit>().createSurveyEntry(
          data: SurveyData(
            taskResult: taskResult,
            scoreDefinitions: scoreDefinitions,
            calculatedScores: calculateScores(
              scoreDefinitions: scoreDefinitions,
              taskResult: taskResult,
            ),
          ),
        );
  };
}
