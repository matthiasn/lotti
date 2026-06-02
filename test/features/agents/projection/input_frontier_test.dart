import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/projection/content_digest.dart';
import 'package:lotti/features/agents/projection/input_frontier.dart';

import '../test_data/entity_factories.dart';
import '../test_data/link_factories.dart';
import 'capture_test_fixtures.dart';

/// A capture or retraction operation in a generated frontier history.
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
}

extension _AnyFrontier on glados.Any {
  /// 0..10 capture/retraction op specs over a small entry/content/time pool, so
  /// changes, retractions, re-adds and same-time ties all arise.
  glados.Generator<List<_OpSpec>> get frontierOps => glados.ListAnys(this)
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

  glados.Generator<(String, bool, String, int)> get _opTuple =>
      glados.CombinableAny(this).combine4(
        glados.AnyUtils(this).choose(<String>['a', 'b', 'c']),
        glados.AnyUtils(this).choose(<bool>[true, false]),
        glados.AnyUtils(this).choose(<String>['x', 'y', 'z']),
        glados.IntAnys(this).intInRange(0, 5),
        (entryId, retract, content, timeBucket) =>
            (entryId, retract, content, timeBucket),
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
          sourceCreatedAt: DateTime.utc(2024, 3, 10),
        ),
      );
    }
  }
  return (messages: messages, links: links);
}

/// The frontier folded independently of [projectInputFrontier], by the same
/// `(createdAt, id)` order, as the reference oracle.
Map<String, String> _expectedDigests(List<_OpSpec> specs) {
  final sorted = [...specs]
    ..sort((a, b) {
      final byTime = a.at.compareTo(b.at);
      if (byTime != 0) return byTime;
      return a.id.compareTo(b.id);
    });
  final frontier = <String, String>{};
  for (final spec in sorted) {
    if (spec.retract) {
      frontier.remove(spec.entryId);
    } else {
      frontier[spec.entryId] = spec.digest;
    }
  }
  return frontier;
}

void main() {
  group('projectInputFrontier', () {
    // ── generative properties ────────────────────────────────────────────────

    glados.Glados(
      glados.any.frontierOps,
      glados.ExploreConfig(numRuns: 300),
    ).test('matches a latest-wins (createdAt, id) fold of the log', (specs) {
      final log = _realize(specs);
      final frontier = projectInputFrontier(
        messages: log.messages,
        links: log.links,
      );
      expect(inputFrontierDigests(frontier), _expectedDigests(specs));
    }, tags: 'glados');

    glados.Glados2(
      glados.any.frontierOps,
      glados.any.shuffleSeed,
      glados.ExploreConfig(numRuns: 300),
    ).test('is independent of message/link arrival order', (specs, seed) {
      final log = _realize(specs);
      final ordered = projectInputFrontier(
        messages: log.messages,
        links: log.links,
      );
      final shuffled = projectInputFrontier(
        messages: shuffledBySeed(log.messages, seed),
        links: shuffledBySeed(log.links, seed),
      );
      expect(inputFrontierDigests(shuffled), inputFrontierDigests(ordered));
    }, tags: 'glados');

    // ── examples ─────────────────────────────────────────────────────────────

    AgentLink capture(
      String entryId,
      String content, {
      required String id,
      required int day,
    }) => makeTestMessagePayloadLink(
      id: id,
      createdAt: DateTime.utc(2024, 3, day),
      toId: ContentDigest.of({'text': content}),
      contentEntryId: entryId,
      sourceCreatedAt: DateTime.utc(2024, 3, 5),
    );

    AgentMessageEntity retraction(
      String entryId, {
      required String id,
      required int day,
    }) => makeTestMessage(
      id: id,
      kind: AgentMessageKind.system,
      createdAt: DateTime.utc(2024, 3, day),
      metadata: AgentMessageMetadata(retractsContentEntryId: entryId),
    );

    test('a single capture is in the frontier', () {
      final frontier = projectInputFrontier(
        messages: const [],
        links: [capture('e1', 'hello', id: 'l1', day: 1)],
      );
      expect(frontier.keys, ['e1']);
      expect(
        frontier['e1']!.contentDigest,
        ContentDigest.of({'text': 'hello'}),
      );
    });

    test('the latest capture per source wins', () {
      final frontier = projectInputFrontier(
        messages: const [],
        links: [
          capture('e1', 'old', id: 'l1', day: 1),
          capture('e1', 'new', id: 'l2', day: 5),
        ],
      );
      expect(frontier['e1']!.contentDigest, ContentDigest.of({'text': 'new'}));
    });

    test('a retraction after the capture removes the source', () {
      final frontier = projectInputFrontier(
        messages: [retraction('e1', id: 'r1', day: 5)],
        links: [capture('e1', 'hello', id: 'l1', day: 1)],
      );
      expect(frontier, isEmpty);
    });

    test('a capture after a retraction restores the source', () {
      final frontier = projectInputFrontier(
        messages: [retraction('e1', id: 'r1', day: 3)],
        links: [
          capture('e1', 'first', id: 'l1', day: 1),
          capture('e1', 'again', id: 'l2', day: 5),
        ],
      );
      expect(
        frontier['e1']!.contentDigest,
        ContentDigest.of({'text': 'again'}),
      );
    });

    test('a soft-deleted capture link is ignored', () {
      final frontier = projectInputFrontier(
        messages: const [],
        links: [
          makeTestMessagePayloadLink(
            id: 'l1',
            createdAt: DateTime.utc(2024, 3, 5),
            toId: ContentDigest.of({'text': 'x'}),
            contentEntryId: 'e1',
            sourceCreatedAt: DateTime.utc(2024, 3, 5),
            deletedAt: DateTime.utc(2024, 3, 2),
          ),
        ],
      );
      expect(frontier, isEmpty);
    });

    test('a pre-ADR-0020 payload link without provenance is ignored', () {
      final frontier = projectInputFrontier(
        messages: const [],
        links: [
          makeTestMessagePayloadLink(
            id: 'l1',
            toId: 'legacy-payload-uuid',
          ),
        ],
      );
      expect(frontier, isEmpty);
    });

    test('a non-retraction message does not affect the frontier', () {
      final frontier = projectInputFrontier(
        messages: [
          makeTestMessage(
            id: 'm1',
            kind: AgentMessageKind.user,
            createdAt: DateTime.utc(2024, 3, 9),
          ),
        ],
        links: [capture('e1', 'hello', id: 'l1', day: 1)],
      );
      expect(frontier.keys, ['e1']);
    });
  });

  group('two-device convergence', () {
    AgentLink cap(
      String entryId,
      String content, {
      required String id,
      required int day,
    }) => makeTestMessagePayloadLink(
      id: id,
      createdAt: DateTime.utc(2024, 3, day),
      toId: ContentDigest.of({'text': content}),
      contentEntryId: entryId,
      sourceCreatedAt: DateTime.utc(2024, 3, 5),
    );

    AgentMessageEntity ret(
      String entryId, {
      required String id,
      required int day,
    }) => makeTestMessage(
      id: id,
      kind: AgentMessageKind.system,
      createdAt: DateTime.utc(2024, 3, day),
      metadata: AgentMessageMetadata(retractsContentEntryId: entryId),
    );

    test('concurrent edits on two devices converge to the later capture', () {
      // Both devices independently captured the same source; after sync each
      // holds the union and folds to the same latest-createdAt content.
      final union = projectInputFrontier(
        messages: const [],
        links: [
          cap('e1', 'deviceA', id: 'a1', day: 1),
          cap('e1', 'deviceB', id: 'b1', day: 2),
        ],
      );
      final reordered = projectInputFrontier(
        messages: const [],
        links: [
          cap('e1', 'deviceB', id: 'b1', day: 2),
          cap('e1', 'deviceA', id: 'a1', day: 1),
        ],
      );
      expect(union['e1']!.contentDigest, ContentDigest.of({'text': 'deviceB'}));
      expect(reordered, union);
    });

    test(
      'concurrent same-instant edits break ties deterministically by id',
      () {
        final ab = projectInputFrontier(
          messages: const [],
          links: [
            cap('e1', 'fromA', id: 'a1', day: 1),
            cap('e1', 'fromB', id: 'b1', day: 1),
          ],
        );
        final ba = projectInputFrontier(
          messages: const [],
          links: [
            cap('e1', 'fromB', id: 'b1', day: 1),
            cap('e1', 'fromA', id: 'a1', day: 1),
          ],
        );
        // The higher id wins the (createdAt, id) order; both devices agree.
        expect(ab['e1']!.contentDigest, ContentDigest.of({'text': 'fromB'}));
        expect(ba, ab);
      },
    );

    test(
      'a retraction on one device and a later re-capture on another converge',
      () {
        final frontier = projectInputFrontier(
          messages: [ret('e1', id: 'a-ret', day: 3)],
          links: [
            cap('e1', 'original', id: 'a1', day: 1),
            cap('e1', 'revived', id: 'b1', day: 4),
          ],
        );
        expect(
          frontier['e1']!.contentDigest,
          ContentDigest.of({'text': 'revived'}),
        );
      },
    );
  });
}
