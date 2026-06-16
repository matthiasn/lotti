import 'package:flutter/widgets.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:research_package/model.dart';

/// Aggregates a completed [taskResult] into one integer per score bucket.
///
/// Data-driven and survey-agnostic: for each entry in [scoreDefinitions]
/// (bucket name -> set of question IDs) it reads each question's stored answer
/// (`stepResult.results['answer']`), extracts the numeric choice value
/// (`RPImageChoice.value`, or the first `RPChoice.value`), and sums them.
/// Missing or unanswered questions contribute 0.
Map<String, int> calculateScores({
  required Map<String, Set<String>> scoreDefinitions,
  required RPTaskResult taskResult,
}) {
  final results = taskResult.results;
  final calculatedScores = <String, int>{};

  for (final scoreDefinition in scoreDefinitions.entries) {
    var score = 0;

    for (final questionId in scoreDefinition.value) {
      final stepResult = results[questionId] as RPStepResult?;
      final choice = stepResult?.results['answer'];

      final int value;
      if (choice is RPImageChoice) {
        value = choice.value as int;
      } else if (choice is List<RPChoice>) {
        value = choice.firstOrNull?.value ?? 0;
      } else {
        value = 0;
      }

      score = score + value;
    }

    calculatedScores[scoreDefinition.key] = score;
  }

  return calculatedScores;
}

/// Builds the `onSubmit` callback handed to the survey runner.
///
/// The returned closure calculates the bucket scores via [calculateScores] and
/// persists them as a `JournalEntity.survey` through
/// [PersistenceLogic.createSurveyEntry], optionally linking it to [linkedId].
/// This is the only place the surveys feature writes data.
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
