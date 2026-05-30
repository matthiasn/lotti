import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/projection/agent_event.dart';
import 'package:lotti/features/sync/vector_clock.dart';

const _vc = VectorClock({'h0': 1});

AgentEvent _ev({
  String id = 'e',
  String host = 'h0',
  AgentEventKind kind = AgentEventKind.message,
  List<String> parents = const [],
  VectorClock? vc,
}) => AgentEvent(
  id: id,
  hostId: host,
  kind: kind,
  causalParents: parents,
  vectorClock: vc ?? _vc,
);

extension _AnyParents on glados.Any {
  /// Lists of 0..6 parent ids drawn from a tiny alphabet, so duplicates and
  /// re-orderings are common.
  glados.Generator<List<String>> get parentIds =>
      glados.ListAnys(this).listWithLengthInRange(
        0,
        6,
        glados.AnyUtils(this).choose(['a', 'b', 'c', 'd']),
      );
}

void main() {
  group('AgentEvent — causalParents normalization', () {
    glados.Glados2(
      glados.any.parentIds,
      glados.any.int,
      glados.ExploreConfig(numRuns: 120),
    ).test('is insensitive to parent order and duplicates', (ids, seed) {
      final base = _ev(parents: ids);
      final reshuffled = _ev(parents: [...ids]..shuffle(Random(seed)));

      // Same logical event regardless of how the parents were listed.
      expect(reshuffled, base, reason: 'ids=$ids seed=$seed');
      // ...and the stored list is the sorted, de-duplicated set.
      expect(
        base.causalParents,
        ids.toSet().toList()..sort(),
        reason: 'ids=$ids',
      );
    }, tags: 'glados');

    test('collapses duplicate parents and sorts', () {
      expect(_ev(parents: ['b', 'a', 'b', 'a']).causalParents, ['a', 'b']);
    });

    test('exposes an unmodifiable causalParents list', () {
      expect(
        () => _ev(parents: ['a']).causalParents.add('b'),
        throwsUnsupportedError,
      );
    });
  });

  group('AgentEvent — equality', () {
    test('events with equal fields are equal', () {
      expect(_ev(parents: ['a', 'b']), _ev(parents: ['b', 'a']));
    });

    test('differs by id', () {
      expect(_ev(id: 'a'), isNot(_ev(id: 'b')));
    });

    test('differs by hostId', () {
      expect(_ev(), isNot(_ev(host: 'h1')));
    });

    test('differs by kind', () {
      expect(_ev(), isNot(_ev(kind: AgentEventKind.report)));
    });

    test('differs by vector clock', () {
      expect(
        _ev(vc: const VectorClock({'h0': 1})),
        isNot(_ev(vc: const VectorClock({'h0': 2}))),
      );
    });

    test('differs by causalParents content', () {
      expect(_ev(parents: ['a']), isNot(_ev(parents: ['a', 'b'])));
    });
  });
}
