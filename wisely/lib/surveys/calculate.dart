import 'package:flutter/foundation.dart';
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
}) {
  return (RPTaskResult taskResult) {
    Map<String, int> calculatedScores = calculateScores(
      scoreDefinitions: scoreDefinitions,
      taskResult: taskResult,
    );

    debugPrint('Scores: $calculatedScores');
  };
}
