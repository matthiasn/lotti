import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/daily_os_next/state/realtime_transcript_selection.dart';

void main() {
  group('selectFinalTranscript', () {
    test('empty batch never replaces realtime', () {
      expect(
        selectFinalTranscript(
          realtimeTranscript: 'hello there',
          batchTranscript: '',
          usedTranscriptFallback: false,
        ),
        'hello there',
      );
    });

    test('empty batch wins over empty realtime is still empty realtime', () {
      expect(
        selectFinalTranscript(
          realtimeTranscript: '',
          batchTranscript: '',
          usedTranscriptFallback: true,
        ),
        '',
      );
    });

    test('batch wins when realtime is empty', () {
      expect(
        selectFinalTranscript(
          realtimeTranscript: '',
          batchTranscript: 'recovered text',
          usedTranscriptFallback: false,
        ),
        'recovered text',
      );
    });

    test('batch wins when realtime used its fallback path', () {
      expect(
        selectFinalTranscript(
          realtimeTranscript: 'short',
          batchTranscript: 'b',
          usedTranscriptFallback: true,
        ),
        'b',
      );
    });

    test('near-identical batch does not displace realtime', () {
      // Batch only 3 chars longer — below the 8-char margin.
      expect(
        selectFinalTranscript(
          realtimeTranscript: 'a good transcript',
          batchTranscript: 'a good transcript.',
          usedTranscriptFallback: false,
        ),
        'a good transcript',
      );
    });

    test('batch wins when meaningfully longer than realtime', () {
      const realtime = 'this got cut';
      const batch = '$realtime off mid sentence by the truncation';
      expect(
        selectFinalTranscript(
          realtimeTranscript: realtime,
          batchTranscript: batch,
          usedTranscriptFallback: false,
        ),
        batch,
      );
    });

    test('honours a custom margin', () {
      // With margin 0, any longer batch wins.
      expect(
        selectFinalTranscript(
          realtimeTranscript: 'ab',
          batchTranscript: 'abc',
          usedTranscriptFallback: false,
          margin: 0,
        ),
        'abc',
      );
    });

    glados.Glados3<String, String, bool>(
      glados.any.choose(const ['', 'r', 'realtime transcript here']),
      glados.any.choose(const ['', 'b', 'a much longer batch transcript text']),
      glados.any.bool,
    ).test('only ever returns one of the two inputs', (
      realtime,
      batch,
      usedFallback,
    ) {
      final result = selectFinalTranscript(
        realtimeTranscript: realtime,
        batchTranscript: batch,
        usedTranscriptFallback: usedFallback,
      );
      expect(
        result == realtime || result == batch,
        isTrue,
        reason: 'realtime="$realtime" batch="$batch" fallback=$usedFallback',
      );
    }, tags: 'glados');

    glados.Glados2<String, bool>(
      glados.any.choose(const ['', 'r', 'realtime transcript here']),
      glados.any.bool,
    ).test('empty batch always yields realtime regardless of fallback', (
      realtime,
      usedFallback,
    ) {
      expect(
        selectFinalTranscript(
          realtimeTranscript: realtime,
          batchTranscript: '',
          usedTranscriptFallback: usedFallback,
        ),
        realtime,
        reason: 'realtime="$realtime" fallback=$usedFallback',
      );
    }, tags: 'glados');
  });
}
