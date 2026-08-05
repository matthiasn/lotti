import 'package:lotti/classes/day_plan.dart';

import 'eval_models.dart';

/// Deterministic plan builders shared by the focused constraint suites.
final planDate = DateTime(2026, 7, 18);
final _dayId =
    'dayplan-${planDate.year}-'
    '${planDate.month.toString().padLeft(2, '0')}-'
    '${planDate.day.toString().padLeft(2, '0')}';

PlannedBlock block({
  required String id,
  required int startHour,
  required int endHour,
  String? taskId,
  String? note,
  String? reason,
  String? title,
  PlannedBlockType type = PlannedBlockType.ai,
  PlannedBlockState state = PlannedBlockState.drafted,
}) => PlannedBlock(
  id: id,
  categoryId: 'cat-1',
  startTime: DateTime(planDate.year, planDate.month, planDate.day, startHour),
  endTime: DateTime(planDate.year, planDate.month, planDate.day, endHour),
  taskId: taskId,
  note: note,
  reason: reason,
  title: title ?? id,
  type: type,
  state: state,
);

EvalRunOutcome outcome({
  List<PlannedBlock> blocks = const [],
  List<EvalCorpusTask> corpus = const [],
  List<String> decidedTaskIds = const [],
  Set<String> permittedOmissions = const {},
  Set<String> expectedOmissions = const {},
  Set<String> requiredTaskIds = const {},
  bool requiresConflictSurfaced = false,
  bool forbidsInventedWork = false,
  Set<String> conflictEscalationReasons = const {'overCommitted'},
  DateTime? now,
  bool planPersisted = true,
  int workingHoursStartHour = 9,
  int workingHoursEndHour = 17,
  Set<String>? visibleTaskIds,
  List<EvalToolCall> toolCalls = const [],
  int capacityMinutes = 480,
  EvalDirective? directive,
  Set<String> createdTaskIds = const {},
}) => EvalRunOutcome(
  inputs: EvalFixtureInputs(
    dayId: _dayId,
    planDate: planDate,
    corpus: corpus,
    decidedTaskIds: decidedTaskIds,
    permittedOmissions: permittedOmissions,
    expectedOmissions: expectedOmissions,
    requiredTaskIds: requiredTaskIds,
    requiresConflictSurfaced: requiresConflictSurfaced,
    forbidsInventedWork: forbidsInventedWork,
    conflictEscalationReasons: conflictEscalationReasons,
    now: now,
    visibleTaskIds: visibleTaskIds,
    workingHoursStartHour: workingHoursStartHour,
    workingHoursEndHour: workingHoursEndHour,
    capacityMinutes: capacityMinutes,
    directive: directive,
  ),
  blocks: blocks,
  toolCalls: toolCalls,
  planPersisted: planPersisted,
  createdTaskIds: createdTaskIds,
);
