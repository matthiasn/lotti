import 'dart:math' as math;

import 'package:glados/glados.dart';
import 'package:lotti/features/ai_chat/services/realtime_transcript_merge.dart';

void main() {
  group('confirmedTextDelta examples', () {
    test('returns the suffix after a suffix/prefix overlap (re-chunking)', () {
      // The backend re-confirmed from mid-word: previous ends with the
      // beginning of next, so only the unseen tail is the delta.
      expect(
        confirmedTextDelta(previous: 'hello wor', next: 'world!'),
        'ld!',
      );
    });

    test('falls back to the common-prefix remainder on divergence', () {
      // No overlap between previous's suffix and next's prefix — the backend
      // rewrote the tail, so the delta is everything after the shared prefix.
      expect(confirmedTextDelta(previous: 'abcX', next: 'abcY'), 'Y');
    });

    test('returns empty for identical transcripts', () {
      expect(confirmedTextDelta(previous: 'same', next: 'same'), isEmpty);
    });
  });

  group('moreCompleteTranscript examples', () {
    test('prefers accumulated deltas when trimmed-longer than final text', () {
      expect(
        moreCompleteTranscript(
          finalText: 'short  ',
          accumulatedText: 'short and more',
        ),
        'short and more',
      );
    });

    test('prefers final text on equal trimmed length', () {
      expect(
        moreCompleteTranscript(
          finalText: 'final text',
          accumulatedText: ' final text ',
        ),
        'final text',
      );
    });
  });

  group('confirmedTextDelta properties', () {
    Glados2(
      any.stringOf('ab '),
      any.stringOf('ab '),
      ExploreConfig(numRuns: 150),
    ).test(
      'delta extraction: append remainder, prefix truncation, suffix law',
      (a, b) {
        // Empty previous: the whole confirmed text is the delta.
        expect(
          confirmedTextDelta(previous: '', next: a),
          a,
          reason: 'a="$a"',
        );

        // Growth: when next extends previous, the delta is the remainder.
        expect(
          confirmedTextDelta(previous: a, next: '$a$b'),
          b,
          reason: 'a="$a" b="$b"',
        );

        // Truncation/rewind: when next is a prefix of previous, nothing new
        // was confirmed.
        if (a.isNotEmpty) {
          expect(
            confirmedTextDelta(previous: '$a$b', next: a),
            isEmpty,
            reason: 'a="$a" b="$b"',
          );
        }

        // Universal law: whatever the relationship, the delta is always a
        // suffix of next — appending it never duplicates confirmed text.
        final d = confirmedTextDelta(previous: a, next: b);
        expect(b.endsWith(d), isTrue, reason: 'a="$a" b="$b" d="$d"');
      },
      tags: 'glados',
    );
  });

  group('moreCompleteTranscript properties', () {
    Glados2(
      any.stringOf('xy \t'),
      any.stringOf('xy \t'),
      ExploreConfig(numRuns: 120),
    ).test(
      'always returns one input, with the longer trimmed content',
      (finalText, accumulatedText) {
        final result = moreCompleteTranscript(
          finalText: finalText,
          accumulatedText: accumulatedText,
        );
        final reason = 'final="$finalText" accumulated="$accumulatedText"';

        // Closure: the result is one of the two candidates, untrimmed.
        expect(
          result == finalText || result == accumulatedText,
          isTrue,
          reason: reason,
        );
        // Completeness: the pick carries the longer trimmed transcript.
        expect(
          result.trim().length,
          math.max(finalText.trim().length, accumulatedText.trim().length),
          reason: reason,
        );
        // Tie-break: equal trimmed lengths keep the backend's final text.
        if (finalText.trim().length == accumulatedText.trim().length) {
          expect(result, finalText, reason: reason);
        }
      },
      tags: 'glados',
    );
  });
}
