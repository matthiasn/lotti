import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/journal/state/linked_entries_activity_filter.dart';

import '../../../test_data/test_data.dart';

void main() {
  group('LinkedEntryActivityFilter.fromEntity', () {
    test('JournalEntry maps to timer (Time Tracker cards)', () {
      expect(
        LinkedEntryActivityFilter.fromEntity(testTextEntry),
        LinkedEntryActivityFilter.timer,
      );
    });

    test('JournalAudio maps to audio', () {
      expect(
        LinkedEntryActivityFilter.fromEntity(testAudioEntry),
        LinkedEntryActivityFilter.audio,
      );
    });

    test('JournalImage maps to images', () {
      expect(
        LinkedEntryActivityFilter.fromEntity(testImageEntry),
        LinkedEntryActivityFilter.images,
      );
    });

    test('Task is not in the activity taxonomy and returns null', () {
      expect(
        LinkedEntryActivityFilter.fromEntity(testTask),
        isNull,
      );
    });

    test('Other entity types fall through to null (always render)', () {
      // HabitCompletion, Workout, Rating — none of these have a pill, so
      // they should always be visible regardless of filter state.
      expect(
        LinkedEntryActivityFilter.fromEntity(testHabitCompletionEntry),
        isNull,
      );
      expect(
        LinkedEntryActivityFilter.fromEntity(testWorkoutRunning),
        isNull,
      );
      expect(
        LinkedEntryActivityFilter.fromEntity(testRatingEntry),
        isNull,
      );
    });
  });

  group('LinkedEntryActivityFilter enum', () {
    test('exposes exactly Timer / Audio / Images', () {
      expect(LinkedEntryActivityFilter.values, [
        LinkedEntryActivityFilter.timer,
        LinkedEntryActivityFilter.audio,
        LinkedEntryActivityFilter.images,
      ]);
    });
  });
}
