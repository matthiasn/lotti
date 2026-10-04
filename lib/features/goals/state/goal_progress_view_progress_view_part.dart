part of 'goal_progress_view.dart';

Future<GoalProgressView?> _progressView(
  Ref ref,
  String agentId,
  int? historyDays,
) async {
  // Invalidation runs onDispose before the scheduled rebuild replaces Ref.
  // Guard the computation itself, including that interval between generations.
  var disposed = false;
  ref.onDispose(() => disposed = true);
  final health = await ref.watch(goalAgentHealthProvider(agentId).future);
  // A dependency may complete after navigation or a reload disposed this
  // computation. Never register a timer or read another provider in that case.
  if (disposed) return null;
  final spec = health.spec;
  if (spec == null) return null;
  final reference = clock.now();
  final nextMidnight = DateTime(
    reference.year,
    reference.month,
    reference.day + 1,
  );
  final midnightTimer = Timer(
    nextMidnight.difference(reference),
    ref.invalidateSelf,
  );
  ref.onDispose(midnightTimer.cancel);
  final signals = await ref
      .watch(goalSignalReaderProvider)
      .read(
        criteria: spec.criteria,
        reference: reference,
        // Six weeks for the reliability tail; wider when the page's
        // shared range reaches further back (plus a week so rolling
        // verdicts at the span's oldest day still see their window).
        shortTermDays: math.max(43, (historyDays ?? 0) + 7),
      );

  if (disposed) return null;
  final habitIds = <String>{};
  void collect(GoalCriterion criterion) {
    switch (criterion) {
      case GoalCriterionHabit(:final habitId):
        habitIds.add(habitId);
      case GoalCriterionMetric() ||
          GoalCriterionMeasurable() ||
          GoalCriterionCategoryTime() ||
          GoalCriterionLabelTime():
        return;
      case GoalCriterionAllOf(criteria: final children):
        children.forEach(collect);
      case GoalCriterionAnyOf(criteria: final children):
        children.forEach(collect);
      case GoalCriterionAtLeastCount(criteria: final children):
        children.forEach(collect);
    }
  }

  collect(spec.criteria);
  final db = ref.watch(journalDbProvider);
  final names = <String, String>{};
  final measurableDefinitions = <String, MeasurableDataType>{};
  final categoryNames = <String, String>{};
  final labelNames = <String, String>{};
  for (final habitId in habitIds) {
    final habit = await db.getHabitById(habitId);
    if (habit != null) names[habitId] = habit.name;
  }
  final measurableIds = <String>{};
  final categoryIds = <String>{};
  final labelIds = <String>{};
  void collectDefinitions(GoalCriterion criterion) {
    switch (criterion) {
      case GoalCriterionMeasurable(:final dataTypeId):
        measurableIds.add(dataTypeId);
      case GoalCriterionCategoryTime(:final categoryId):
        categoryIds.add(categoryId);
      case GoalCriterionLabelTime(:final labelId, :final categoryId):
        labelIds.add(labelId);
        if (categoryId != null) categoryIds.add(categoryId);
      case GoalCriterionMetric() || GoalCriterionHabit():
        return;
      case GoalCriterionAllOf(criteria: final children):
        children.forEach(collectDefinitions);
      case GoalCriterionAnyOf(criteria: final children):
        children.forEach(collectDefinitions);
      case GoalCriterionAtLeastCount(criteria: final children):
        children.forEach(collectDefinitions);
    }
  }

  collectDefinitions(spec.criteria);
  for (final measurableId in measurableIds) {
    final definition = await db.getMeasurableDataTypeById(measurableId);
    if (definition != null) {
      measurableDefinitions[measurableId] = definition;
    }
  }
  for (final categoryId in categoryIds) {
    final definition = await db.getCategoryById(categoryId);
    if (definition != null) categoryNames[categoryId] = definition.name;
  }
  for (final labelId in labelIds) {
    final definition = await db.getLabelDefinitionById(labelId);
    if (definition != null) labelNames[labelId] = definition.name;
  }
  if (disposed) return null;
  final captureDecisions = measurableIds.isEmpty
      ? const <String, GoalMeasurableCaptureDecision>{}
      : await ref.watch(
          goalMeasurableCaptureDecisionsProvider(agentId).future,
        );
  if (disposed) return null;
  final agentRecordedMeasurementIds = {
    for (final decision in captureDecisions.values)
      if (decision.recorded) ...decision.entryIds,
  };
  final recordedMeasurementProvenanceById = {
    for (final decision in captureDecisions.values)
      if (decision.recorded &&
          decision.recordedAt != null &&
          decision.agentName != null)
        for (final entryId in decision.entryIds)
          entryId: GoalRecordedMeasurementProvenance(
            agentName: decision.agentName!,
            recordedAt: decision.recordedAt!,
          ),
  };
  return buildGoalProgressView(
    criteria: spec.criteria,
    signals: signals,
    reference: reference,
    historyDays: historyDays,
    habitNames: names,
    measurableDefinitions: measurableDefinitions,
    categoryNames: categoryNames,
    labelNames: labelNames,
    agentRecordedMeasurementIds: agentRecordedMeasurementIds,
    recordedMeasurementProvenanceById: recordedMeasurementProvenanceById,
  );
}
