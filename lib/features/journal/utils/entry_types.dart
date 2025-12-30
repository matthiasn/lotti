/// Entry types available for filtering journal entries.
///
/// Used by:
/// - JournalPageController for filter state
/// - entry_type_gating.dart for computing allowed types
/// - Tests that reference entry types directly
const List<String> entryTypes = [
  'Task',
  'JournalEntry',
  'JournalEvent',
  'JournalAudio',
  'JournalImage',
  'MeasurementEntry',
  'SurveyEntry',
  'WorkoutEntry',
  'HabitCompletionEntry',
  'QuantitativeEntry',
  'Checklist',
  'ChecklistItem',
  'AiResponse',
];
