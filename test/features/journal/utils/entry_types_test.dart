import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/journal/utils/entry_types.dart';

void main() {
  group('entryTypes', () {
    // These strings are persisted JournalEntity `runtimeType` discriminators
    // (used by JournalPageController filters and entry_type_gating). An
    // accidental rename/removal would silently break filtering and gating, so
    // the exact set is pinned as a regression guard.
    test('pins the exact set of journal entry-type discriminators', () {
      expect(entryTypes, <String>[
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
      ]);
    });

    test('contains no duplicates and no empty entries', () {
      expect(entryTypes.toSet(), hasLength(entryTypes.length));
      expect(entryTypes.any((t) => t.trim().isEmpty), isFalse);
    });
  });
}
