import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/audio_transcript_timing.dart';
import 'package:lotti/features/agents/model/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_audio_excerpt.dart';

import 'query_audio_test_utils.dart';

void main() {
  QueryAudioExcerpt? locate({
    QueryEvidence? evidence,
    AudioTranscriptTiming? timing,
    Duration duration = const Duration(minutes: 10),
  }) => queryAudioExcerpt(
    evidence: evidence ?? audioEvidence(),
    timing: timing ?? audioTiming(),
    duration: duration,
  );

  test('uses reported timing with one minute of listening context', () {
    final result = locate()!;
    expect(result.start, const Duration(seconds: 95));
    expect(result.end, const Duration(seconds: 155));
  });

  test('matches words across segments and tolerates formatting only', () {
    final result = locate(
      evidence: audioEvidence(
        text: '[Speaker 1]\nKEEP the two—stage feeder latch!',
      ),
      timing: audioTiming(
        segments: const [
          AudioTimedSegment(
            text: 'Keep the two-stage',
            startMilliseconds: 0,
            endMilliseconds: 5000,
          ),
          AudioTimedSegment(
            text: 'feeder latch.',
            startMilliseconds: 8000,
            endMilliseconds: 10000,
          ),
        ],
      ),
    )!;
    expect(result.start, Duration.zero);
    expect(result.end, const Duration(seconds: 35));
    expect(
      locate(evidence: audioEvidence(text: 'Replace the feeder latch')),
      isNull,
    );
  });

  test('keeps a long quotation intact and clamps to recording bounds', () {
    final result = locate(
      timing: audioTiming(
        segments: const [
          AudioTimedSegment(
            text: queryAudioWords,
            startMilliseconds: 0,
            endMilliseconds: 180000,
          ),
        ],
      ),
      duration: const Duration(minutes: 3),
    )!;
    expect(result.start, Duration.zero);
    expect(result.end, const Duration(minutes: 3));
  });

  test('refuses ambiguous repeated speech, even with overlapping matches', () {
    expect(
      locate(
        timing: audioTiming(
          segments: [
            ...audioTiming().segments,
            audioTiming().segments.single.copyWith(
              startMilliseconds: 140000,
              endMilliseconds: 150000,
            ),
          ],
        ),
      ),
      isNull,
    );
    expect(
      locate(
        evidence: audioEvidence(text: 'go go'),
        timing: audioTiming(
          segments: [audioTiming().segments.single.copyWith(text: 'go go go')],
        ),
      ),
      isNull,
    );
  });

  test(
    'rejects stale source versions, invalid passages and wrong source kinds',
    () {
      for (final evidence in [
        audioEvidence().copyWith(fingerprint: 'edited'),
        audioEvidence().copyWith(start: -1),
        audioEvidence().copyWith(kind: QuerySourceKind.text),
        audioEvidence(text: '…'),
        audioEvidence(
          text: '$queryAudioWords plus words that were never spoken',
        ),
      ]) {
        expect(locate(evidence: evidence), isNull);
      }
    },
  );

  test(
    'rejects malformed timing as a whole without joining across bad rows',
    () {
      final segment = audioTiming().segments.single;
      for (final segments in <List<AudioTimedSegment>>[
        [],
        [segment.copyWith(startMilliseconds: -1)],
        [segment.copyWith(endMilliseconds: 120000)],
        [segment.copyWith(endMilliseconds: 700000)],
        [segment, segment.copyWith(startMilliseconds: 1000)],
        [
          segment,
          segment.copyWith(startMilliseconds: 125000, endMilliseconds: 129000),
        ],
        [segment.copyWith(text: '')],
        List.filled(30001, segment),
        [segment.copyWith(text: 'x' * 2000001)],
      ]) {
        expect(locate(timing: audioTiming(segments: segments)), isNull);
      }
      expect(locate(duration: Duration.zero), isNull);
    },
  );

  glados.Glados(glados.any.positiveIntOrZero).test(
    'returned excerpts always include the matched speech',
    (seed) {
      final start = seed % 500000;
      final end = start + 10000;
      final result = locate(
        timing: audioTiming(
          segments: [
            AudioTimedSegment(
              text: queryAudioWords,
              startMilliseconds: start,
              endMilliseconds: end,
            ),
          ],
        ),
      )!;
      expect(result.start.inMilliseconds, inInclusiveRange(0, start));
      expect(result.end.inMilliseconds, inInclusiveRange(end, 600000));
    },
    tags: 'glados',
  );
}
