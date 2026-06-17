import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/journal/state/linked_entries_activity_filter.dart';

import '../../../test_data/test_data.dart';

AiResponseEntry _aiResponse({AiResponseType? type}) {
  return AiResponseEntry(
    meta: Metadata(
      id: 'ai-response-$type',
      createdAt: DateTime(2024, 3, 15),
      dateFrom: DateTime(2024, 3, 15),
      dateTo: DateTime(2024, 3, 15),
      updatedAt: DateTime(2024, 3, 15),
    ),
    data: AiResponseData(
      model: 'test-model',
      systemMessage: 'system',
      prompt: 'prompt',
      thoughts: '',
      response: 'response',
      type: type,
    ),
  );
}

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

    test('coding prompt (promptGeneration) maps to code', () {
      expect(
        LinkedEntryActivityFilter.fromEntity(
          _aiResponse(type: AiResponseType.promptGeneration),
        ),
        LinkedEntryActivityFilter.code,
      );
    });

    test('non-coding AiResponseEntry kinds return null (always render)', () {
      // Only AiResponseType.promptGeneration is a coding prompt. Every other
      // AiResponseEntry kind is not part of the activity taxonomy and should
      // always be visible regardless of the Code pill state.
      for (final type in [
        AiResponseType.audioTranscription,
        AiResponseType.imageAnalysis,
        AiResponseType.imagePromptGeneration,
        AiResponseType.imageGeneration,
      ]) {
        expect(
          LinkedEntryActivityFilter.fromEntity(_aiResponse(type: type)),
          isNull,
          reason: '$type should not map to the code pill',
        );
      }
    });

    test('AiResponseEntry with null type returns null (always render)', () {
      expect(
        LinkedEntryActivityFilter.fromEntity(_aiResponse()),
        isNull,
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
    test('exposes exactly Timer / Audio / Images / Code', () {
      expect(LinkedEntryActivityFilter.values, [
        LinkedEntryActivityFilter.timer,
        LinkedEntryActivityFilter.audio,
        LinkedEntryActivityFilter.images,
        LinkedEntryActivityFilter.code,
      ]);
    });
  });
}
