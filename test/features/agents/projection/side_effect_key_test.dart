import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/projection/content_digest.dart';
import 'package:lotti/features/agents/projection/side_effect_key.dart';

import 'capture_test_fixtures.dart';

extension _AnyKey on glados.Any {
  /// A `{contentEntryId → contentDigest}` frontier: 0..5 entries with distinct
  /// keys (`e0`, `e1`, …) and digest values from a small pool, so reorderings
  /// of the *same* logical frontier arise naturally.
  glados.Generator<Map<String, String>> get frontier => glados.ListAnys(this)
      .listWithLengthInRange(
        0,
        5,
        glados.AnyUtils(this).choose(<String>['d1', 'd2', 'd3']),
      )
      .map(
        (values) => {for (var i = 0; i < values.length; i++) 'e$i': values[i]},
      );
}

Map<String, String> _shuffled(Map<String, String> m, int seed) =>
    Map.fromEntries(shuffledBySeed(m.entries.toList(), seed));

String _key({
  String agentId = 'agent-1',
  String behaviorKind = 'subscription',
  String frontier = 'fd',
  String triggerId = 'trig',
  String toolName = 'set_status',
}) => sideEffectKey(
  agentId: agentId,
  behaviorKind: behaviorKind,
  frontierDigest: frontier,
  triggerId: triggerId,
  toolName: toolName,
);

void main() {
  group('frontierDigest', () {
    // ── generative properties ────────────────────────────────────────────────

    glados.Glados2(
      glados.any.frontier,
      glados.any.shuffleSeed,
      glados.ExploreConfig(numRuns: 300),
    ).test('depends only on the frontier set, not insertion order', (
      frontier,
      seed,
    ) {
      expect(
        frontierDigest(frontier),
        frontierDigest(_shuffled(frontier, seed)),
      );
    }, tags: 'glados');

    glados.Glados(
      glados.any.frontier,
      glados.ExploreConfig(numRuns: 300),
    ).test('is domain-tagged and versioned (cannot collide with an untagged '
        'digest of the same map)', (frontier) {
      expect(frontierDigest(frontier), isNot(ContentDigest.of(frontier)));
      expect(frontierDigest(frontier), startsWith('${ContentDigest.version}:'));
    }, tags: 'glados');

    // ── examples ─────────────────────────────────────────────────────────────

    test('an empty frontier yields a stable, versioned digest', () {
      expect(frontierDigest(const {}), frontierDigest({}));
      expect(frontierDigest(const {}), startsWith('${ContentDigest.version}:'));
    });

    test('a changed content version changes the digest', () {
      expect(frontierDigest({'e0': 'd1'}), isNot(frontierDigest({'e0': 'd2'})));
    });

    test('an added source changes the digest', () {
      expect(
        frontierDigest({'e0': 'd1'}),
        isNot(frontierDigest({'e0': 'd1', 'e1': 'd2'})),
      );
    });
  });

  group('sideEffectKey', () {
    // ── generative property: the frontier component flows through ──────────────

    glados.Glados2(
      glados.any.frontier,
      glados.any.frontier,
      glados.ExploreConfig(numRuns: 300),
    ).test('distinct frontiers produce distinct keys (all else equal)', (
      f1,
      f2,
    ) {
      final d1 = frontierDigest(f1);
      final d2 = frontierDigest(f2);
      if (d1 != d2) {
        expect(_key(frontier: d1), isNot(_key(frontier: d2)));
      } else {
        expect(_key(frontier: d1), _key(frontier: d2));
      }
    }, tags: 'glados');

    // ── examples ─────────────────────────────────────────────────────────────

    test('is deterministic and versioned', () {
      expect(_key(), _key());
      expect(_key(), startsWith('${ContentDigest.version}:'));
    });

    test('every component changes the key', () {
      const base = {
        'agentId': 'agent-1',
        'behaviorKind': 'subscription',
        'frontierDigest': 'fd',
        'triggerId': 'trig',
        'toolName': 'set_status',
      };
      String keyFrom(Map<String, String> f) => sideEffectKey(
        agentId: f['agentId']!,
        behaviorKind: f['behaviorKind']!,
        frontierDigest: f['frontierDigest']!,
        triggerId: f['triggerId']!,
        toolName: f['toolName']!,
      );
      final baseKey = keyFrom(base);
      for (final field in base.keys) {
        final perturbed = {...base, field: '${base[field]}-changed'};
        expect(
          keyFrom(perturbed),
          isNot(baseKey),
          reason: 'changing $field must change the key',
        );
      }
    });

    test('keys components distinctly — adjacent fields do not alias', () {
      // A separator-less concatenation of (agentId, behaviorKind) would make
      // ('a','bc') and ('ab','c') collide; keying each field distinctly does not.
      expect(
        _key(agentId: 'a', behaviorKind: 'bc'),
        isNot(_key(agentId: 'ab', behaviorKind: 'c')),
      );
    });
  });
}
