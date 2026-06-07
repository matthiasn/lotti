import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/projection/agent_projection.dart';
import 'package:lotti/features/agents/projection/canonical_order.dart';
import 'package:lotti/features/agents/projection/shadow_projection.dart';

import '../test_data/entity_factories.dart';
import 'projection_test_fixtures.dart';

AgentLink _prevLink(String child, String parent) => AgentLink.messagePrev(
  id: 'lnk-$child-$parent',
  fromId: child,
  toId: parent,
  createdAt: DateTime(2024),
  updatedAt: DateTime(2024),
  vectorClock: null,
);

ShadowProjectionReport _compare(
  List<AgentMessageEntity> messages,
  List<AgentLink> links,
  String? liveHeadId,
) => compareShadowProjection(
  messages: messages,
  links: links,
  liveHeadId: liveHeadId,
);

void main() {
  group('compareShadowProjection', () {
    test('empty log and no live head → empty', () {
      final report = _compare(const [], const [], null);

      expect(report.status, ShadowProjectionStatus.empty);
      expect(report.projectedHeadIds, isEmpty);
    });

    test('live head but empty log → mismatch', () {
      expect(
        _compare(const [], const [], 'ghost').status,
        ShadowProjectionStatus.mismatch,
      );
    });

    test('linear chain whose single head matches the live head → match', () {
      final report = _compare(
        [
          makeTestMessage(id: 'a'),
          makeTestMessage(id: 'b'),
          makeTestMessage(id: 'c'),
        ],
        [_prevLink('b', 'a'), _prevLink('c', 'b')],
        'c',
      );

      expect(report.status, ShadowProjectionStatus.match);
      expect(report.projectedHeadIds, ['c']);
    });

    test('single head that differs from the live head → mismatch', () {
      final report = _compare(
        [makeTestMessage(id: 'a'), makeTestMessage(id: 'b')],
        [_prevLink('b', 'a')],
        'a', // live head stale; projection head is b
      );

      expect(report.status, ShadowProjectionStatus.mismatch);
      expect(report.projectedHeadIds, ['b']);
    });

    test('a fork yields ≥2 heads → forked (expected divergence)', () {
      final report = _compare(
        [
          makeTestMessage(id: 'a'),
          makeTestMessage(id: 'b'),
          makeTestMessage(id: 'c'),
        ],
        [_prevLink('b', 'a'), _prevLink('c', 'a')],
        'b', // live tracks one of the two heads
      );

      expect(report.status, ShadowProjectionStatus.forked);
      expect(report.projectedHeadIds.toSet(), {'b', 'c'});
    });

    test('non-empty projection with no live head → mismatch, not forked', () {
      // Same fork, but the live state tracks no head at all — that is a
      // genuine mismatch, since `forked` means "live tracks one of the tips".
      final report = _compare(
        [
          makeTestMessage(id: 'a'),
          makeTestMessage(id: 'b'),
          makeTestMessage(id: 'c'),
        ],
        [_prevLink('b', 'a'), _prevLink('c', 'a')],
        null,
      );

      expect(report.status, ShadowProjectionStatus.mismatch);
      expect(report.projectedHeadIds.toSet(), {'b', 'c'});
    });

    test('a fork where live head tracks a non-tip (parent) → mismatch', () {
      // Live tracks parent 'a', which is not one of the tips {b, c}.
      final report = _compare(
        [
          makeTestMessage(id: 'a'),
          makeTestMessage(id: 'b'),
          makeTestMessage(id: 'c'),
        ],
        [_prevLink('b', 'a'), _prevLink('c', 'a')],
        'a',
      );

      expect(report.status, ShadowProjectionStatus.mismatch);
      expect(report.projectedHeadIds.toSet(), {'b', 'c'});
    });

    test('reports are value-equal by their fields', () {
      final report = _compare([makeTestMessage(id: 'a')], const [], 'a');

      expect(
        report,
        const ShadowProjectionReport(
          status: ShadowProjectionStatus.match,
          projectedHeadIds: ['a'],
          liveHeadId: 'a',
          danglingParentIds: [],
        ),
      );
      expect(
        report,
        isNot(
          const ShadowProjectionReport(
            status: ShadowProjectionStatus.empty,
            projectedHeadIds: [],
            liveHeadId: null,
            danglingParentIds: [],
          ),
        ),
      );
    });

    test('a cycle in the links is captured as error, not thrown', () {
      final report = _compare(
        [makeTestMessage(id: 'a'), makeTestMessage(id: 'b')],
        [_prevLink('a', 'b'), _prevLink('b', 'a')],
        null,
      );

      expect(report.status, ShadowProjectionStatus.error);
      // The captured `e.toString()` names the structural defect — a cycle in
      // the messagePrev edges surfaces as ProjectionCycleException, not just
      // some non-null string.
      expect(report.error, contains('ProjectionCycleException'));
    });
  });

  group('compareShadowProjection — properties', () {
    List<AgentMessageEntity> messagesOf(GeneratedDag dag) => [
      for (final e in dag.events)
        makeTestMessage(id: e.id, vectorClock: e.vectorClock),
    ];
    List<AgentLink> linksOf(GeneratedDag dag) => [
      for (final e in dag.events)
        for (final parent in e.causalParents) _prevLink(e.id, parent),
    ];

    glados.Glados(
      glados.any.projectionDag,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'projected heads equal the kernel heads for the materialized log',
      (
        dag,
      ) {
        final expected = project(canonicalOrder(dag.events)).headIds.toSet();
        final report = compareShadowProjection(
          messages: messagesOf(dag),
          links: linksOf(dag),
          liveHeadId: null,
        );

        expect(report.projectedHeadIds.toSet(), expected, reason: '$dag');
      },
      tags: 'glados',
    );

    glados.Glados2(
      glados.any.projectionDag,
      glados.any.shuffleSeed,
      glados.ExploreConfig(numRuns: 150),
    ).test(
      'status is the biconditional of liveHeadId vs the projected tips',
      (
        dag,
        selector,
      ) {
        final heads = project(canonicalOrder(dag.events)).headIds.toSet();
        final present = {for (final e in dag.events) e.id};
        final nonHeads = present.difference(heads);

        // Vary the live head across the four meaningful categories so each
        // invariant below actually has teeth across runs.
        final liveHeadId = switch (selector % 4) {
          0 when heads.isNotEmpty => (heads.toList()..sort()).first, // a tip
          1 when nonHeads.isNotEmpty =>
            (nonHeads.toList()..sort()).first, // present non-tip
          2 => 'absent-id', // not in the log at all
          _ => null, // no live head
        };

        final status = compareShadowProjection(
          messages: messagesOf(dag),
          links: linksOf(dag),
          liveHeadId: liveHeadId,
        ).status;

        // Each status holds *iff* its defining predicate over independently
        // computed heads — necessary and sufficient, in both directions, rather
        // than re-running the implementation's branch ladder.
        final liveIsTip = liveHeadId != null && heads.contains(liveHeadId);
        final why = 'sel=$selector live=$liveHeadId heads=$heads';

        expect(
          status == ShadowProjectionStatus.match,
          liveIsTip && heads.length == 1,
          reason: why,
        );
        expect(
          status == ShadowProjectionStatus.forked,
          liveIsTip && heads.length > 1,
          reason: why,
        );
        expect(
          status == ShadowProjectionStatus.empty,
          heads.isEmpty && liveHeadId == null,
          reason: why,
        );
        expect(
          status == ShadowProjectionStatus.mismatch,
          !liveIsTip && !(heads.isEmpty && liveHeadId == null),
          reason: why,
        );
      },
      tags: 'glados',
    );

    glados.Glados2(
      glados.any.projectionDag,
      glados.any.shuffleSeed,
      glados.ExploreConfig(numRuns: 120),
    ).test('report is invariant under input shuffle', (dag, seed) {
      final baseline = compareShadowProjection(
        messages: messagesOf(dag),
        links: linksOf(dag),
        liveHeadId: null,
      );
      final shuffled = compareShadowProjection(
        messages: messagesOf(dag)..shuffle(Random(seed)),
        links: linksOf(dag)..shuffle(Random(seed)),
        liveHeadId: null,
      );

      expect(shuffled, baseline, reason: 'seed=$seed $dag');
    }, tags: 'glados');
  });
}
