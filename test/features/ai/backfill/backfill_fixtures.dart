import 'package:lotti/classes/ai_response_type.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';

import '../../../helpers/entity_factories.dart';

/// A transcript long enough for the audio-summary run to accept (≥ 200 chars).
final String longTranscript = 'word ' * 60;

/// An audio entry in any of the states backfill detection distinguishes.
JournalAudio backfillAudio({
  String id = 'audio-1',
  String? transcript,
  String? text,
  DateTime? dateFrom,
  DateTime? deletedAt,
}) {
  final from = dateFrom ?? testFixedDate;
  return JournalAudio(
    meta: TestMetadataFactory.create(
      id: id,
      dateFrom: from,
    ).copyWith(deletedAt: deletedAt),
    data: AudioData(
      dateFrom: from,
      dateTo: from.add(const Duration(minutes: 1)),
      audioFile: '$id.aac',
      audioDirectory: '/audio/',
      duration: const Duration(minutes: 1),
      transcripts: transcript == null
          ? null
          : [
              AudioTranscript(
                created: from,
                library: 'test',
                model: 'test-model',
                detectedLanguage: 'en',
                transcript: transcript,
              ),
            ],
    ),
    entryText: text == null ? null : EntryText(plainText: text),
  );
}

/// An image entry, optionally with its own text.
JournalImage backfillImage({
  String id = 'image-1',
  String? text,
  DateTime? dateFrom,
}) => TestImageFactory.create(id: id, plainText: text, dateFrom: dateFrom);

/// An AI response of [type], as linked from a media entry.
AiResponseEntry backfillResponse(
  AiResponseType type, {
  String id = 'response-1',
  DateTime? deletedAt,
}) => TestAiResponseFactory.create(id: id, type: type, deletedAt: deletedAt);
