import 'package:flutter/widgets.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
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
  String? linkedId,
}) {
  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();

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
