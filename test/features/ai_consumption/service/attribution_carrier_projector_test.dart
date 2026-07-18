import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai_consumption/service/attribution_carrier_projector.dart';

import '../test_utils.dart';

void main() {
  final createdAt = DateTime(2026, 3, 15, 12);

  Metadata metadata(String id) => Metadata(
    id: id,
    createdAt: createdAt,
    updatedAt: createdAt,
    dateFrom: createdAt,
    dateTo: createdAt,
  );

  test('extracts the terminal envelope from an AI response carrier', () {
    final envelope = makeAiTerminalEnvelope();
    final entity = JournalEntity.aiResponse(
      meta: metadata('output-1'),
      data: AiResponseData(
        model: 'model',
        systemMessage: 'system',
        prompt: 'prompt',
        thoughts: '',
        response: 'response',
        aiAttribution: envelope,
      ),
    );

    expect(terminalEnvelopesFromJournalEntity(entity), [envelope]);
  });

  test('extracts independently attributed transcripts from audio', () {
    final first = makeAiTerminalEnvelope(attributionId: 'first');
    final second = makeAiTerminalEnvelope(attributionId: 'second');
    final entity = JournalEntity.journalAudio(
      meta: metadata('audio-1'),
      data: AudioData(
        dateFrom: createdAt,
        dateTo: createdAt,
        audioFile: 'audio.m4a',
        audioDirectory: '/audio',
        duration: const Duration(seconds: 2),
        transcripts: [
          AudioTranscript(
            created: createdAt,
            library: 'provider',
            model: 'model',
            detectedLanguage: 'en',
            transcript: 'one',
            aiAttribution: first,
          ),
          AudioTranscript(
            created: createdAt,
            library: 'provider',
            model: 'model',
            detectedLanguage: 'en',
            transcript: 'two',
            aiAttribution: second,
          ),
        ],
      ),
    );

    expect(terminalEnvelopesFromJournalEntity(entity), [first, second]);
  });
}
