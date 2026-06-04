import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/projection/content_digest.dart';
import 'package:lotti/features/agents/projection/input_events.dart';

import '../test_data/entity_factories.dart';
import '../test_data/link_factories.dart';
import 'capture_test_fixtures.dart';

/// A capture or retraction operation in a generated event history.
class _OpSpec {
  const _OpSpec({
    required this.entryId,
    required this.retract,
    required this.content,
    required this.timeBucket,
    required this.seq,
  });

  final String entryId;
  final bool retract;
  final String content;
  final int timeBucket;
  final int seq;

  DateTime get at => DateTime.utc(2024, 3, 10).add(Duration(days: timeBucket));
  String get id => 'op$seq';
  String get digest => ContentDigest.of({'text': content});

  /// Mirrors the projection's position key for [_realize]d ops (content links
  /// carry an entry-id-prefixed composite key; retraction messages their id).
  String get posKey => retract ? id : '$entryId|$id';
}

extension _AnyEvents on glados.Any {
  /// 0..10 capture/retraction op specs over a small entry/content/time pool, so
  /// edits, retractions, re-adds and same-time ties all arise.
  glados.Generator<List<_OpSpec>> get eventOps => glados.ListAnys(this)
      .listWithLengthInRange(0, 10, _opTuple)
      .map(
        (tuples) => [
          for (var i = 0; i < tuples.length; i++)
            _OpSpec(
              entryId: tuples[i].$1,
              retract: tuples[i].$2,
              content: tuples[i].$3,
              timeBucket: tuples[i].$4,
              seq: i,
            ),
        ],
      );

  /// Like [eventOps], but strictly time-ordered (each op later than the last)
  /// and capture-only — the single-device append path, where the append-only
  /// rendering guarantee must hold exactly.
  glados.Generator<List<_OpSpec>> get appendedCaptures => glados.ListAnys(this)
      .listWithLengthInRange(0, 10, _captureTuple)
      .map(
        (tuples) => [
          for (var i = 0; i < tuples.length; i++)
            _OpSpec(
              entryId: tuples[i].$1,
              retract: false,
              content: tuples[i].$2,
              timeBucket: i,
              seq: i,
            ),
        ],
      );

  glados.Generator<(String, bool, String, int)> get _opTuple =>
      glados.CombinableAny(this).combine4(
        glados.AnyUtils(this).choose(<String>['a', 'b', 'c']),
        glados.AnyUtils(this).choose(<bool>[true, false]),
        glados.AnyUtils(this).choose(<String>['x', 'y', 'z']),
        glados.IntAnys(this).intInRange(0, 5),
        (entryId, retract, content, timeBucket) =>
            (entryId, retract, content, timeBucket),
      );

  glados.Generator<(String, String)> get _captureTuple =>
      glados.CombinableAny(this).combine2(
        glados.AnyUtils(this).choose(<String>['a', 'b', 'c']),
        glados.AnyUtils(this).choose(<String>['x', 'y', 'z']),
        (entryId, content) => (entryId, content),
      );
}

/// Realizes op specs into the (messages, links) a real log would hold.
({List<AgentMessageEntity> messages, List<AgentLink> links}) _realize(
  List<_OpSpec> specs,
) {
  final messages = <AgentMessageEntity>[];
  final links = <AgentLink>[];
  for (final spec in specs) {
    if (spec.retract) {
      messages.add(
        makeTestMessage(
          id: spec.id,
          kind: AgentMessageKind.system,
          createdAt: spec.at,
          metadata: AgentMessageMetadata(retractsContentEntryId: spec.entryId),
        ),
      );
    } else {
      links.add(
        makeTestMessagePayloadLink(
          id: spec.id,
          createdAt: spec.at,
          toId: spec.digest,
          contentEntryId: spec.entryId,
          // sourceAt == at for every realized op, so the oracle's position
          // order below stays a faithful mirror of EventPosition's.
          sourceCreatedAt: spec.at,
        ),
      );
    }
  }
  return (messages: messages, links: links);
}

/// Position order over specs, matching [EventPosition]'s (at, sourceAt, key)
/// order — [_realize] pins `sourceAt == at`, so (at, posKey) is exact.
int _bySpecPosition(_OpSpec a, _OpSpec b) {
  final byTime = a.at.compareTo(b.at);
  if (byTime != 0) return byTime;
  return a.posKey.compareTo(b.posKey);
}

InputEventLog _project(List<_OpSpec> specs) {
  final realized = _realize(specs);
  return projectInputEvents(
    messages: realized.messages,
    links: realized.links,
  );
}

void main() {
  group('projectInputEvents', () {
    // ── generative properties ────────────────────────────────────────────────

    glados.Glados2(
      glados.any.eventOps,
      glados.any.shuffleSeed,
      glados.ExploreConfig(numRuns: 250),
    ).test('is a pure function of the op set, not its order', (specs, seed) {
      final ordered = _project(specs);
      final shuffled = _project(shuffledBySeed(specs, seed));
      expect(shuffled, ordered);
    }, tags: 'glados');

    glados.Glados(
      glados.any.eventOps,
      glados.ExploreConfig(numRuns: 250),
    ).test('marks exactly the non-first event per source as an edit', (specs) {
      final log = _project(specs);
      // Oracle: walk captures in position order, first per entry is not an
      // edit, every later one is.
      final captures = specs.where((s) => !s.retract).toList()
        ..sort(_bySpecPosition);
      final seen = <String>{};
      final expectedEdit = <String, bool>{
        for (final spec in captures) spec.posKey: !seen.add(spec.entryId),
      };
      expect(log.events, hasLength(captures.length));
      for (final event in log.events) {
        expect(event.isEdit, expectedEdit[event.position.key]);
      }
    }, tags: 'glados');

    glados.Glados(
      glados.any.eventOps,
      glados.ExploreConfig(numRuns: 250),
    ).test('visibleTailEvents suppresses exactly events with a later '
        'retraction of their source', (specs) {
      final log = _project(specs);
      final visible = visibleTailEvents(log: log);
      final visibleKeys = {for (final e in visible) e.position.key};

      for (final spec in specs.where((s) => !s.retract)) {
        final suppressed = specs.any(
          (r) =>
              r.retract &&
              r.entryId == spec.entryId &&
              _bySpecPosition(spec, r) < 0,
        );
        expect(
          visibleKeys.contains(spec.posKey),
          !suppressed,
          reason: 'event ${spec.id} of entry ${spec.entryId}',
        );
      }
    }, tags: 'glados');

    glados.Glados2(
      glados.any.eventOps,
      glados.any.shuffleSeed,
      glados.ExploreConfig(numRuns: 250),
    ).test('a cutoff yields exactly the strictly-later suffix of the '
        'no-cutoff tail', (specs, seed) {
      final log = _project(specs);
      final all = visibleTailEvents(log: log);
      if (all.isEmpty) return;
      final cutoff = all[seed % all.length].position;
      expect(
        visibleTailEvents(log: log, cutoff: cutoff),
        all.where((e) => e.position.isAfter(cutoff)).toList(),
      );
    }, tags: 'glados');

    glados.Glados2(
      glados.any.appendedCaptures,
      glados.any.shuffleSeed,
      glados.ExploreConfig(numRuns: 250),
    ).test(
      'single-device appends are render-stable: the earlier log is a strict '
      'prefix of the later one',
      (specs, seed) {
        final splitAt = specs.isEmpty ? 0 : seed % (specs.length + 1);
        final before = visibleTailEvents(
          log: _project(specs.sublist(0, splitAt)),
        );
        final after = visibleTailEvents(log: _project(specs));
        expect(after.sublist(0, before.length), before);
      },
      tags: 'glados',
    );

    // ── examples ─────────────────────────────────────────────────────────────

    test('an edit appends a new event; the earlier event is unchanged', () {
      final log = _project(const [
        _OpSpec(
          entryId: 'a',
          retract: false,
          content: 'x',
          timeBucket: 0,
          seq: 0,
        ),
        _OpSpec(
          entryId: 'a',
          retract: false,
          content: 'y',
          timeBucket: 1,
          seq: 1,
        ),
      ]);
      expect(log.events, hasLength(2));
      expect(log.events[0].isEdit, isFalse);
      expect(log.events[1].isEdit, isTrue);
      expect(log.events[0].contentDigest, ContentDigest.of({'text': 'x'}));
      expect(log.events[1].contentDigest, ContentDigest.of({'text': 'y'}));
      // Both render: nothing is folded into per-source state.
      expect(visibleTailEvents(log: log), log.events);
    });

    test('a source re-captured after its retraction is visible again', () {
      final log = _project(const [
        _OpSpec(
          entryId: 'a',
          retract: false,
          content: 'x',
          timeBucket: 0,
          seq: 0,
        ),
        _OpSpec(
          entryId: 'a',
          retract: true,
          content: 'x',
          timeBucket: 1,
          seq: 1,
        ),
        _OpSpec(
          entryId: 'a',
          retract: false,
          content: 'y',
          timeBucket: 2,
          seq: 2,
        ),
      ]);
      final visible = visibleTailEvents(log: log);
      expect(visible, hasLength(1));
      expect(visible.single.contentDigest, ContentDigest.of({'text': 'y'}));
    });

    test('skips soft-deleted links and pre-ADR-0020 references', () {
      final log = projectInputEvents(
        messages: const [],
        links: [
          makeTestMessagePayloadLink(
            id: 'l1',
            createdAt: DateTime.utc(2024, 3, 5),
            toId: ContentDigest.of({'text': 'x'}),
            contentEntryId: 'e1',
            sourceCreatedAt: DateTime.utc(2024, 3, 5),
            deletedAt: DateTime.utc(2024, 3, 6),
          ),
          // Pre-ADR-0020: no contentEntryId/sourceCreatedAt → not a capture.
          makeTestMessagePayloadLink(
            id: 'l2',
            createdAt: DateTime.utc(2024, 3, 5),
            toId: ContentDigest.of({'text': 'y'}),
          ),
        ],
      );
      expect(log.isEmpty, isTrue);
    });

    test('a same-instant batch orders by source chronology, not by id', () {
      // One wake captures an old task: every link shares createdAt, and the
      // entries must render in source order (months of entries, not shuffled).
      final batchAt = DateTime.utc(2024, 3, 10);
      final log = projectInputEvents(
        messages: const [],
        links: [
          makeTestMessagePayloadLink(
            id: 'z-link',
            createdAt: batchAt,
            toId: ContentDigest.of({'text': 'oldest'}),
            contentEntryId: 'e-old',
            sourceCreatedAt: DateTime.utc(2024),
          ),
          makeTestMessagePayloadLink(
            id: 'a-link',
            createdAt: batchAt,
            toId: ContentDigest.of({'text': 'newest'}),
            contentEntryId: 'e-new',
            sourceCreatedAt: DateTime.utc(2024, 2),
          ),
        ],
      );
      expect(
        [for (final e in log.events) e.contentEntryId],
        ['e-old', 'e-new'],
      );
    });

    test('EventPosition orders by time, then source chronology, then key', () {
      final t = DateTime.utc(2024, 3, 10);
      final a = EventPosition(at: t, sourceAt: t, key: 'a');
      final b = EventPosition(at: t, sourceAt: t, key: 'b');
      final earlierSource = EventPosition(
        at: t,
        sourceAt: t.subtract(const Duration(days: 1)),
        key: 'z',
      );
      final later = EventPosition(
        at: t.add(const Duration(minutes: 1)),
        sourceAt: t,
        key: 'a',
      );
      expect(a.compareTo(b), lessThan(0));
      expect(earlierSource.compareTo(a), lessThan(0));
      expect(later.isAfter(b), isTrue);
      expect(a.isAfter(a), isFalse);
    });
  });
}
