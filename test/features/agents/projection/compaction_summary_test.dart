import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/projection/compaction_summary.dart';
import 'package:lotti/features/agents/projection/input_capture.dart';
import 'package:lotti/features/agents/projection/input_events.dart';

import 'capture_test_fixtures.dart';

EventPosition _pos(int p) => EventPosition(
  at: DateTime.utc(2024, 3).add(Duration(minutes: p)),
  sourceAt: DateTime.utc(2024, 3).add(Duration(minutes: p)),
  key: 'ev$p',
);

SummaryCheckpoint _summary(
  String id, {
  required Map<String, String> covers,
  int? cutoff,
  String? digest,
  String text = 'summary',
}) => SummaryCheckpoint(
  id: id,
  contentDigest: digest ?? 'c-$id',
  coveredSources: covers,
  summaryText: text,
  cutoff: cutoff == null ? null : _pos(cutoff),
);

RetractionEvent _retraction(String entryId, int p) =>
    RetractionEvent(position: _pos(p), contentEntryId: entryId);

TailLine _line(
  String entryId,
  String text, {
  int day = 10,
  bool edited = false,
}) => TailLine(
  source: RenderedSource(
    contentEntryId: entryId,
    sourceCreatedAt: DateTime.utc(2024, 3, day),
    content: {'entryType': 'text', 'text': text},
  ),
  edited: edited,
);

extension _AnySummaries on glados.Any {
  /// 0..5 (coverage mask, cutoff) pairs over a 4-source pool; bit b set ⇒ the
  /// summary covers source `e$b`.
  glados.Generator<List<(int, int)>> get summarySpecs =>
      glados.ListAnys(this).listWithLengthInRange(
        0,
        5,
        glados.CombinableAny(this).combine2(
          glados.IntAnys(this).intInRange(0, 16),
          glados.IntAnys(this).intInRange(0, 10),
          (mask, cutoff) => (mask, cutoff),
        ),
      );

  /// 0..4 retractions (source index, position).
  glados.Generator<List<(int, int)>> get retractionSpecs =>
      glados.ListAnys(this).listWithLengthInRange(
        0,
        4,
        glados.CombinableAny(this).combine2(
          glados.IntAnys(this).intInRange(0, 4),
          glados.IntAnys(this).intInRange(0, 12),
          (entry, pos) => (entry, pos),
        ),
      );
}

void main() {
  group('selectActiveSummary', () {
    // ── generative properties ────────────────────────────────────────────────

    glados.Glados3(
      glados.any.summarySpecs,
      glados.any.retractionSpecs,
      glados.any.shuffleSeed,
      glados.ExploreConfig(numRuns: 250),
    ).test(
      'is order-independent and picks the greatest-cutoff valid candidate',
      (specs, retractionPairs, seed) {
        final summaries = [
          for (var i = 0; i < specs.length; i++)
            _summary(
              's$i',
              cutoff: specs[i].$2,
              covers: {
                for (var b = 0; b < 4; b++)
                  if (specs[i].$1 & (1 << b) != 0) 'e$b': 'd',
              },
            ),
        ];
        final retractions = [
          for (final (entry, pos) in retractionPairs)
            _retraction('e$entry', pos),
        ]..sort((a, b) => a.position.compareTo(b.position));

        final ordered = selectActiveSummary(
          summaries: summaries,
          retractions: retractions,
        );
        final shuffled = selectActiveSummary(
          summaries: shuffledBySeed(summaries, seed),
          retractions: retractions,
        );
        expect(shuffled, ordered);

        // Oracle: valid ⇔ no covered source retracted after the cutoff.
        bool isValid(SummaryCheckpoint s) => !retractions.any(
          (r) =>
              r.position.isAfter(s.cutoff!) &&
              s.coveredSources.containsKey(r.contentEntryId),
        );
        final valid = summaries.where(isValid).toList();
        if (valid.isEmpty) {
          expect(ordered, isNull);
        } else {
          expect(ordered, isNotNull);
          expect(isValid(ordered!), isTrue);
          for (final candidate in valid) {
            expect(
              ordered.cutoff!.compareTo(candidate.cutoff!),
              greaterThanOrEqualTo(0),
            );
          }
        }
      },
      tags: 'glados',
    );

    // ── examples ─────────────────────────────────────────────────────────────

    test('no summaries → no active checkpoint', () {
      expect(
        selectActiveSummary(summaries: const [], retractions: const []),
        isNull,
      );
    });

    test('picks the checkpoint covering the longest log prefix', () {
      final active = selectActiveSummary(
        summaries: [
          _summary('s1', cutoff: 3, covers: {'e0': 'd'}),
          _summary('s2', cutoff: 7, covers: {'e0': 'd', 'e1': 'd'}),
        ],
        retractions: const [],
      );
      expect(active!.id, 's2');
    });

    test('a checkpoint without a cutoff is never selected', () {
      final active = selectActiveSummary(
        summaries: [
          _summary('s1', covers: {'e0': 'd'}),
        ],
        retractions: const [],
      );
      expect(active, isNull);
    });

    test('an edit after the cutoff does NOT invalidate the checkpoint', () {
      // Edits append post-cutoff events that render in the tail; no retraction
      // is involved, so the checkpoint stays active (prefix-stable prompt).
      final active = selectActiveSummary(
        summaries: [
          _summary('s1', cutoff: 5, covers: {'e0': 'd-old'}),
        ],
        retractions: const [],
      );
      expect(active!.id, 's1');
    });

    test('a post-cutoff retraction of a covered source invalidates', () {
      final active = selectActiveSummary(
        summaries: [
          _summary('s1', cutoff: 5, covers: {'e0': 'd'}),
        ],
        retractions: [_retraction('e0', 6)],
      );
      expect(active, isNull);
    });

    test('a pre-cutoff retraction of a covered source does not invalidate '
        '(the source was re-captured before the fold)', () {
      final active = selectActiveSummary(
        summaries: [
          _summary('s1', cutoff: 5, covers: {'e0': 'd'}),
        ],
        retractions: [_retraction('e0', 2)],
      );
      expect(active!.id, 's1');
    });

    test('a retraction of an uncovered source does not invalidate', () {
      final active = selectActiveSummary(
        summaries: [
          _summary('s1', cutoff: 5, covers: {'e0': 'd'}),
        ],
        retractions: [_retraction('e9', 6)],
      );
      expect(active!.id, 's1');
    });

    test('falls back to an older valid checkpoint when the newest is '
        'invalidated', () {
      final active = selectActiveSummary(
        summaries: [
          _summary('s1', cutoff: 3, covers: {'e0': 'd'}),
          _summary('s2', cutoff: 7, covers: {'e0': 'd', 'e1': 'd'}),
        ],
        // e1 retracted at 8: s2 (covers e1, cutoff 7) dies; s1 survives.
        retractions: [_retraction('e1', 8)],
      );
      expect(active!.id, 's1');
    });

    test('breaks equal-cutoff ties by (contentDigest, id)', () {
      final active = selectActiveSummary(
        summaries: [
          _summary('s2', cutoff: 5, covers: {'e0': 'd'}, digest: 'cB'),
          _summary('s1', cutoff: 5, covers: {'e0': 'd'}, digest: 'cA'),
        ],
        retractions: const [],
      );
      expect(active!.contentDigest, 'cA');
    });

    test('SummaryCheckpoint value equality follows its fields', () {
      SummaryCheckpoint make() =>
          _summary('s1', cutoff: 1, covers: {'e0': 'd'});
      expect(make(), make());
      expect(make(), isNot(_summary('s1', cutoff: 2, covers: {'e0': 'd'})));
      expect(make(), isNot(_summary('s1', cutoff: 1, covers: {'e0': 'x'})));
    });
  });

  group('assembleCompactedTaskLog', () {
    test('renders the summary above the verbatim tail', () {
      final text = assembleCompactedTaskLog(
        summaryText: 'Earlier: did X and Y.',
        tail: [_line('e1', 'most recent note', day: 12)],
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
        tail: [_line('e1', 'only note')],
      );
      expect(text, isNot(contains('Summary of earlier activity')));
      expect(text, contains('only note'));
    });

    test('returns empty when there is neither summary nor tail', () {
      expect(assembleCompactedTaskLog(tail: const []), isEmpty);
    });

    test(
      'tags an edit event so the model knows it supersedes a line above',
      () {
        final text = assembleCompactedTaskLog(
          tail: [
            _line('e1', 'original wording'),
            _line('e1', 'corrected wording', day: 12, edited: true),
          ],
        );
        expect(text, contains('(text) original wording'));
        expect(text, contains('(text, edited) corrected wording'));
        expect(
          text.indexOf('original'),
          lessThan(text.indexOf('corrected')),
        );
      },
    );

    test('renders an audio entry transcript when its text is empty', () {
      final text = assembleCompactedTaskLog(
        tail: [
          TailLine(
            source: RenderedSource(
              contentEntryId: 'e1',
              sourceCreatedAt: DateTime.utc(2024, 3, 11),
              content: const {
                'entryType': 'audio',
                'text': '',
                'audioTranscript': 'spoken words',
              },
            ),
          ),
        ],
      );
      expect(text, contains('spoken words'));
    });

    test('renders the per-entry duration when it carries information', () {
      final text = assembleCompactedTaskLog(
        tail: [
          TailLine(
            source: RenderedSource(
              contentEntryId: 'e1',
              sourceCreatedAt: DateTime.utc(2024, 3, 11),
              content: const {
                'entryType': 'audio',
                'loggedDuration': '00:30',
                'text': 'spoke for a while',
              },
            ),
          ),
        ],
      );
      expect(text, contains('· 00:30'));
      expect(text, contains('spoke for a while'));
    });

    test('combines the edited tag with the duration tag', () {
      final text = assembleCompactedTaskLog(
        tail: [
          TailLine(
            source: RenderedSource(
              contentEntryId: 'e1',
              sourceCreatedAt: DateTime.utc(2024, 3, 11),
              content: const {
                'entryType': 'text',
                'loggedDuration': '00:18',
                'text': 'reworded note',
              },
            ),
            edited: true,
          ),
        ],
      );
      expect(text, contains('(text, edited · 00:18) reworded note'));
    });

    test('omits a zero per-entry duration', () {
      final text = assembleCompactedTaskLog(
        tail: [
          TailLine(
            source: RenderedSource(
              contentEntryId: 'e1',
              sourceCreatedAt: DateTime.utc(2024, 3, 11),
              content: const {
                'entryType': 'text',
                'loggedDuration': '00:00',
                'text': 'no time logged',
              },
            ),
          ),
        ],
      );
      expect(text, isNot(contains('·')));
    });

    test(
      'trims trailing whitespace from a body so lines stay single lines',
      () {
        final text = assembleCompactedTaskLog(
          tail: [
            _line('e1', 'note with trailing newline\n'),
            _line('e2', 'second', day: 12),
          ],
        );
        expect(text, contains('note with trailing newline\n- ['));
      },
    );

    test('renders tail entries in the given (event) order', () {
      final text = assembleCompactedTaskLog(
        tail: [_line('e1', 'first'), _line('e2', 'second', day: 11)],
      );
      expect(text.indexOf('first'), lessThan(text.indexOf('second')));
    });
  });
}
