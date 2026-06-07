// Scripted fixture data for the mock day agent — categories, the demo
// task corpus, and per-task scripted outcomes. Part of the mock_day_agent
// library so the agent keeps referring to them by their private names.
part of 'mock_day_agent.dart';

const _work = DayAgentCategory(
  id: 'cat_work',
  name: 'Work',
  colorHex: '5ED4B7',
);
const _health = DayAgentCategory(
  id: 'cat_health',
  name: 'Health',
  colorHex: '7AB889',
);
const _meals = DayAgentCategory(
  id: 'cat_meals',
  name: 'Meals',
  colorHex: '4AB6E8',
);
const _study = DayAgentCategory(
  id: 'cat_study',
  name: 'Study',
  colorHex: 'FBA336',
);
const DayAgentCategory _buffer = DayAgentCategory(
  id: 'cat_buffer',
  name: 'Buffer',
  colorHex: '8E8E8E',
);

String? _scriptedOutcome(String taskId) {
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

double? _scriptedProgress(String taskId) {
  switch (taskId) {
    case 't_onboarding_doc':
      return 0.4;
    case 't_deck_review':
      return 0.6;
  }
  return null;
}

const _scriptedTaskCorpus = <TaskCorpusItem>[
  TaskCorpusItem(
    id: 't_deck_review',
    title: 'Deck review — Q2 leadership update',
    category: _work,
    state: TaskCorpusState.inProgress,
    updatedLabel: 'today',
  ),
  TaskCorpusItem(
    id: 't_onboarding_doc',
    title: 'Finish the Onboarding doc',
    category: _work,
    state: TaskCorpusState.inProgress,
    updatedLabel: 'yesterday',
  ),
  TaskCorpusItem(
    id: 't_dentist',
    title: 'Reschedule dentist',
    category: _health,
    state: TaskCorpusState.overdue,
    updatedLabel: '3 days ago',
  ),
  TaskCorpusItem(
    id: 't_invoices',
    title: 'Review outstanding invoices',
    category: _work,
    state: TaskCorpusState.scheduled,
    updatedLabel: 'today',
  ),
  TaskCorpusItem(
    id: 't_dnd_book',
    title: 'Read 30 pages',
    category: _study,
    state: TaskCorpusState.recurring,
    updatedLabel: 'May 18',
  ),
  TaskCorpusItem(
    id: 't_sunday_call',
    title: 'Call mom re: Sunday',
    category: _meals,
    state: TaskCorpusState.backlog,
    updatedLabel: '2 weeks ago',
  ),
  TaskCorpusItem(
    id: 't_morning_run_done',
    title: 'Morning run · 5km',
    category: _health,
    state: TaskCorpusState.done,
    updatedLabel: 'today',
  ),
];
