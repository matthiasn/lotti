import 'package:lotti/classes/audio_transcript_timing.dart';
import 'package:lotti/features/agents/model/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_journal_crawler.dart';

import '../../../test_data/test_data.dart';

const queryAudioWords = 'Keep the two-stage feeder latch.';

QueryEvidence audioEvidence({String text = queryAudioWords}) {
  final source = QuerySourceDocument.fromEntry(testAudioEntryWithTranscripts)!;
  return QueryEvidence(
    source: QuerySourceRef(
      id: testAudioEntryWithTranscripts.meta.id,
      categoryId: testAudioEntryWithTranscripts.meta.categoryId,
      private: false,
      categoryPrivate: false,
    ),
    kind: QuerySourceKind.recording,
    label: 'Habitat review',
    sourceDate: DateTime(2026, 7, 17),
    textVersion: source.version,
    fingerprint: source.fingerprint,
    sourceText: text,
    start: 0,
    end: text.length,
    summary: '',
  );
}

AudioTranscriptTiming audioTiming({
  List<AudioTimedSegment>? segments,
}) => AudioTranscriptTiming(
  createdAt: DateTime(2026, 7, 17),
  audioSha256: 'audio-sha256',
  sourceFingerprint: audioEvidence().fingerprint,
  sourceVersion: audioEvidence().textVersion,
  providerId: 'mistral',
  model: 'voxtral-mini-latest',
  segments:
      segments ??
      const [
        AudioTimedSegment(
          text: queryAudioWords,
          startMilliseconds: 120000,
          endMilliseconds: 130000,
        ),
      ],
);
