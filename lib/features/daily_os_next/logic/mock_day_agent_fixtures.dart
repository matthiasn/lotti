// Scripted fixture data for the mock day agent — categories, the demo
// task corpus, per-task scripted outcomes, and the shared agenda roll-up.
//
// A standalone library (no longer a `part`) so the capture and planning
// collaborators can share the same scripted data without a part-file web.
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';

/// Scripted "Work" category.
const mockWorkCategory = DayAgentCategory(
  id: 'cat_work',
  name: 'Work',
  colorHex: '5ED4B7',
);

/// Scripted "Health" category.
const mockHealthCategory = DayAgentCategory(
  id: 'cat_health',
  name: 'Health',
  colorHex: '7AB889',
);

/// Scripted "Meals" category.
const mockMealsCategory = DayAgentCategory(
  id: 'cat_meals',
  name: 'Meals',
  colorHex: '4AB6E8',
);

/// Scripted "Study" category.
const mockStudyCategory = DayAgentCategory(
  id: 'cat_study',
  name: 'Study',
  colorHex: 'FBA336',
);

/// Scripted "Buffer" category.
const mockBufferCategory = DayAgentCategory(
  id: 'cat_buffer',
  name: 'Buffer',
  colorHex: '8E8E8E',
);

/// Scripted shutdown outcome blurb for [taskId], or `null` when none.
String? scriptedOutcome(String taskId) {
  switch (taskId) {
    case 't_deck_review':
      return 'Deck reviewed by Sarah, sent to leadership.';
    case 't_onboarding_doc':
      return 'Onboarding doc back on track — picked up where you left off.';
    case 't_morning_run':
      return '5 km logged before the day starts.';
  }
  return null;
}

/// Scripted progress fraction for [taskId], or `null` when none.
double? scriptedProgress(String taskId) {
  switch (taskId) {
    case 't_onboarding_doc':
      return 0.4;
    case 't_deck_review':
      return 0.6;
  }
  return null;
}

/// Scripted task corpus surfaced by `surfaceTaskCorpus`.
const scriptedTaskCorpus = <TaskCorpusItem>[
  TaskCorpusItem(
    title: 'Deck review — Q2 leadership update',
    category: mockWorkCategory,
    state: TaskCorpusState.inProgress,
  ),
  TaskCorpusItem(
    title: 'Finish the Onboarding doc',
    category: mockWorkCategory,
    state: TaskCorpusState.inProgress,
  ),
  TaskCorpusItem(
    title: 'Reschedule dentist',
    category: mockHealthCategory,
    state: TaskCorpusState.overdue,
  ),
  TaskCorpusItem(
    title: 'Review outstanding invoices',
    category: mockWorkCategory,
    state: TaskCorpusState.scheduled,
  ),
  TaskCorpusItem(
    title: 'Read 30 pages',
    category: mockStudyCategory,
    state: TaskCorpusState.recurring,
  ),
  TaskCorpusItem(
    title: 'Call mom re: Sunday',
    category: mockMealsCategory,
    state: TaskCorpusState.backlog,
  ),
  TaskCorpusItem(
    title: 'Morning run · 5km',
    category: mockHealthCategory,
    state: TaskCorpusState.done,
  ),
];

/// Roll the placed blocks up into one [AgendaItem] per task. Blocks
/// without a taskId (buffers, calendar events) are not surfaced on
/// the Agenda — that screen is intent-first.
List<AgendaItem> agendaFor(List<TimeBlock> blocks) {
  final byTask = <String, List<TimeBlock>>{};
  for (final block in blocks) {
    final id = block.taskId;
    if (id == null) continue;
    byTask.putIfAbsent(id, () => <TimeBlock>[]).add(block);
  }

  AgendaItem buildItem(String taskId, List<TimeBlock> linked) {
    final outcome = scriptedOutcome(taskId);
    final estimate = linked.fold<int>(
      0,
      (acc, b) => acc + b.duration.inMinutes,
    );
    final state = linked.any((b) => b.state == TimeBlockState.inProgress)
        ? AgendaItemState.inProgress
        : AgendaItemState.open;
    return AgendaItem(
      id: 'agenda_$taskId',
      taskId: taskId,
      title: linked.first.title,
      category: linked.first.category,
      linkedBlockIds: linked.map((b) => b.id).toList(),
      outcome: outcome,
      totalEstimateMinutes: estimate,
      progress: scriptedProgress(taskId),
      state: state,
    );
  }

  return byTask.entries
      .map((entry) => buildItem(entry.key, entry.value))
      .toList();
}
