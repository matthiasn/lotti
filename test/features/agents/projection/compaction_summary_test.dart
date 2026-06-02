import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/projection/compaction_summary.dart';
import 'package:lotti/features/agents/projection/input_capture.dart';

import 'capture_test_fixtures.dart';

SummaryCheckpoint _summary(
  String id, {
  required Map<String, String> covers,
  String? digest,
  String text = 'summary',
}) => SummaryCheckpoint(
  id: id,
  contentDigest: digest ?? 'c-$id',
  coveredSources: covers,
  summaryText: text,
);

RenderedSource _src(String entryId, String text, {int day = 10}) =>
    RenderedSource(
      contentEntryId: entryId,
      sourceCreatedAt: DateTime.utc(2024, 3, day),
      content: {'entryType': 'text', 'text': text},
    );

extension _AnySummaries on glados.Any {
  /// 0..5 coverage masks over a 4-source frontier; bit b set ⇒ the summary
  /// covers source `e$b`.
  glados.Generator<List<int>> get coverageMasks => glados.ListAnys(
    this,
  ).listWithLengthInRange(0, 5, glados.IntAnys(this).intInRange(0, 16));
}

void main() {
  group('selectActiveSummary', () {
    // ── generative properties ────────────────────────────────────────────────

    glados.Glados2(
      glados.any.coverageMasks,
      glados.any.shuffleSeed,
      glados.ExploreConfig(numRuns: 250),
    ).test(
      'is independent of summary order and covers the most sources',
      (
        masks,
        seed,
      ) {
        const frontier = {'e0': 'd', 'e1': 'd', 'e2': 'd', 'e3': 'd'};
        final summaries = [
          for (var i = 0; i < masks.length; i++)
            _summary(
              's$i',
              covers: {
                for (var b = 0; b < 4; b++)
                  if (masks[i] & (1 << b) != 0) 'e$b': 'd',
              },
            ),
        ];

        final ordered = selectActiveSummary(
          frontier: frontier,
          summaries: summaries,
        );
        final shuffled = selectActiveSummary(
          frontier: frontier,
          summaries: shuffledBySeed(summaries, seed),
        );
        expect(shuffled, ordered);

        // All generated summaries are complete (digest 'd' matches), so the
        // active one covers no fewer sources than any other.
        final activeCount = ordered.checkpoint?.coveredSources.length ?? 0;
        for (final summary in summaries) {
          expect(summary.coveredSources.length, lessThanOrEqualTo(activeCount));
        }
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.any.coverageMasks,
      glados.ExploreConfig(numRuns: 250),
    ).test('covered and uncovered partition the frontier', (masks) {
      const frontier = {'e0': 'd', 'e1': 'd', 'e2': 'd', 'e3': 'd'};
      final summaries = [
        for (var i = 0; i < masks.length; i++)
          _summary(
            's$i',
            covers: {
              for (var b = 0; b < 4; b++)
                if (masks[i] & (1 << b) != 0) 'e$b': 'd',
            },
          ),
      ];

      final active = selectActiveSummary(
        frontier: frontier,
        summaries: summaries,
      );
      final covered = active.checkpoint?.coveredSources.keys.toSet() ?? {};
      expect(
        {...covered, ...active.uncoveredEntryIds},
        frontier.keys.toSet(),
      );
      expect(covered.intersection(active.uncoveredEntryIds.toSet()), isEmpty);
    }, tags: 'glados');

    // ── examples ─────────────────────────────────────────────────────────────

    test('no summaries → no active checkpoint, everything is the tail', () {
      final active = selectActiveSummary(
        frontier: const {'e0': 'd0', 'e1': 'd1'},
        summaries: const [],
      );
      expect(active.checkpoint, isNull);
      expect(active.uncoveredEntryIds, ['e0', 'e1']);
    });

    test('picks the summary covering the most sources', () {
      final active = selectActiveSummary(
        frontier: const {'e0': 'd', 'e1': 'd', 'e2': 'd'},
        summaries: [
          _summary('s1', covers: {'e0': 'd'}),
          _summary('s2', covers: {'e0': 'd', 'e1': 'd'}),
        ],
      );
      expect(active.checkpoint!.id, 's2');
      expect(active.uncoveredEntryIds, ['e2']);
    });

    test('excludes a stale summary whose covered source was edited', () {
      // s1 covered e0 at digest 'old', but the frontier now has e0 at 'new'.
      final active = selectActiveSummary(
        frontier: const {'e0': 'new'},
        summaries: [
          _summary('s1', covers: {'e0': 'old'}),
        ],
      );
      expect(active.checkpoint, isNull);
      expect(active.uncoveredEntryIds, ['e0']);
    });

    test(
      'breaks ties between equal-coverage summaries by (contentDigest, id)',
      () {
        final active = selectActiveSummary(
          frontier: const {'e0': 'd'},
          summaries: [
            _summary('s2', covers: {'e0': 'd'}, digest: 'cB'),
            _summary('s1', covers: {'e0': 'd'}, digest: 'cA'),
          ],
        );
        // Lowest (contentDigest, id) wins → 'cA'.
        expect(active.checkpoint!.contentDigest, 'cA');
      },
    );

    test('SummaryCheckpoint value equality follows its fields', () {
      SummaryCheckpoint make() => _summary('s1', covers: {'e0': 'd'});
      expect(make(), make());
      expect(make(), isNot(_summary('s1', covers: {'e0': 'other'})));
    });
  });

  group('assembleCompactedTaskLog', () {
    test('renders the summary above the verbatim tail', () {
      final text = assembleCompactedTaskLog(
        summaryText: 'Earlier: did X and Y.',
        tail: [_src('e1', 'most recent note', day: 12)],
      );
      expect(text, contains('Summary of earlier activity'));
      expect(text, contains('Earlier: did X and Y.'));
      expect(text, contains('Recent entries'));
      expect(text, contains('most recent note'));
      expect(
        text.indexOf('Summary of earlier activity'),
        lessThan(text.indexOf('Recent entries')),
      );
    });

    test('omits the summary section when there is no summary', () {
      final text = assembleCompactedTaskLog(
        tail: [_src('e1', 'only note')],
      );
      expect(text, isNot(contains('Summary of earlier activity')));
      expect(text, contains('only note'));
    });

    test('returns empty when there is neither summary nor tail', () {
      expect(assembleCompactedTaskLog(tail: const []), isEmpty);
    });

    test('renders an audio entry transcript when its text is empty', () {
      final text = assembleCompactedTaskLog(
        tail: [
          RenderedSource(
            contentEntryId: 'e1',
            sourceCreatedAt: DateTime.utc(2024, 3, 11),
            content: const {
              'entryType': 'audio',
              'text': '',
              'audioTranscript': 'spoken words',
            },
          ),
        ],
      );
      expect(text, contains('spoken words'));
    });

    test('renders the per-entry duration when it carries information', () {
      final text = assembleCompactedTaskLog(
        tail: [
          RenderedSource(
            contentEntryId: 'e1',
            sourceCreatedAt: DateTime.utc(2024, 3, 11),
            content: const {
              'entryType': 'audio',
              'loggedDuration': '00:30',
              'text': 'spoke for a while',
            },
          ),
        ],
      );
      expect(text, contains('· 00:30'));
      expect(text, contains('spoke for a while'));
    });

    test('omits a zero per-entry duration', () {
      final text = assembleCompactedTaskLog(
        tail: [
          RenderedSource(
            contentEntryId: 'e1',
            sourceCreatedAt: DateTime.utc(2024, 3, 11),
            content: const {
              'entryType': 'text',
              'loggedDuration': '00:00',
              'text': 'no time logged',
            },
          ),
        ],
      );
      expect(text, isNot(contains('·')));
    });

    test('renders tail entries in the given (canonical) order', () {
      final text = assembleCompactedTaskLog(
        tail: [_src('e1', 'first'), _src('e2', 'second', day: 11)],
      );
      expect(text.indexOf('first'), lessThan(text.indexOf('second')));
    });
  });
}
