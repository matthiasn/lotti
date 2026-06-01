import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/projection/content_digest.dart';

import 'capture_test_fixtures.dart';

void main() {
  group('ContentDigest.of', () {
    // ── generative properties ────────────────────────────────────────────────

    glados.Glados2(
      glados.any.jsonScalars,
      glados.any.shuffleSeed,
      glados.ExploreConfig(numRuns: 200),
    ).test('is permutation-invariant over map keys', (values, seed) {
      final entries = [
        for (var i = 0; i < values.length; i++) MapEntry('k$i', values[i]),
      ];
      final ordered = Map<String, Object?>.fromEntries(entries);
      final reordered = Map<String, Object?>.fromEntries(
        shuffledBySeed(entries, seed),
      );
      expect(ContentDigest.of(reordered), ContentDigest.of(ordered));
    }, tags: 'glados');

    glados.Glados(
      glados.any.contentMap,
      glados.ExploreConfig(numRuns: 200),
    ).test('is stable across a JSON encode/decode round-trip', (map) {
      final round = jsonDecode(jsonEncode(map)) as Map<String, dynamic>;
      expect(ContentDigest.of(round), ContentDigest.of(map));
    }, tags: 'glados');

    glados.Glados(
      glados.any.contentMap,
      glados.ExploreConfig(numRuns: 200),
    ).test('emits a version-tagged base64url digest with no padding', (map) {
      final digest = ContentDigest.of(map);
      expect(digest, startsWith('${ContentDigest.version}:'));
      final body = digest.substring('${ContentDigest.version}:'.length);
      expect(body, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
    }, tags: 'glados');

    glados.Glados(
      glados.any.contentMap,
      glados.ExploreConfig(numRuns: 120),
    ).test('is deterministic (a fresh copy hashes identically)', (map) {
      expect(ContentDigest.of({...map}), ContentDigest.of(map));
    }, tags: 'glados');

    // ── normalization examples ───────────────────────────────────────────────

    test('normalizes integral doubles to their integer form', () {
      expect(ContentDigest.of(1), ContentDigest.of(1.0));
      expect(ContentDigest.of({'a': 1}), ContentDigest.of({'a': 1.0}));
      expect(ContentDigest.of([1, 2]), ContentDigest.of([1.0, 2.0]));
    });

    test('keeps a non-integral double distinct from its floor', () {
      expect(ContentDigest.of(2.5), isNot(ContentDigest.of(2)));
    });

    test('normalizes DateTime to UTC', () {
      final local = DateTime(2024, 6, 2, 15, 30);
      expect(ContentDigest.of(local), ContentDigest.of(local.toUtc()));
    });

    test('is permutation-invariant for nested maps', () {
      final a = {
        'outer': {'x': 1, 'y': 2},
      };
      final b = {
        'outer': {'y': 2, 'x': 1},
      };
      expect(ContentDigest.of(a), ContentDigest.of(b));
    });

    // ── distinctness examples ────────────────────────────────────────────────

    test('treats list order as significant', () {
      expect(ContentDigest.of([1, 2]), isNot(ContentDigest.of([2, 1])));
    });

    test('distinguishes structurally different content', () {
      final digests = <String>{
        ContentDigest.of({'a': 1}),
        ContentDigest.of({'a': 2}),
        ContentDigest.of({'b': 1}),
        ContentDigest.of(null),
        ContentDigest.of(''),
        ContentDigest.of(<String, Object?>{}),
        ContentDigest.of(<Object?>[]),
      };
      expect(digests.length, 7);
    });

    test('does not conflate a string key with a numeric-looking one', () {
      // Canonicalization sorts by the *string* form, so these must not collide.
      expect(
        ContentDigest.of({'2': 'a', '10': 'b'}),
        isNot(ContentDigest.of({'2': 'b', '10': 'a'})),
      );
    });

    // ── error path ───────────────────────────────────────────────────────────

    test('throws ArgumentError on non-JSON-able content', () {
      expect(
        () => ContentDigest.of(const Duration(seconds: 1)),
        throwsArgumentError,
      );
      expect(
        () => ContentDigest.of(<String, Object?>{'bad': Object()}),
        throwsArgumentError,
      );
    });
  });
}
