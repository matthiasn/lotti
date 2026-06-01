import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/projection/content_digest.dart';
import 'package:lotti/features/agents/projection/input_capture.dart';

import 'capture_test_fixtures.dart';

/// Mirrors the private canonical order in `input_capture.dart` so the test can
/// assert the references come back already sorted.
int _canonicalOrder(CaptureReference a, CaptureReference b) {
  final byTime = a.sourceCreatedAt.compareTo(b.sourceCreatedAt);
  if (byTime != 0) return byTime;
  final byEntry = a.contentEntryId.compareTo(b.contentEntryId);
  if (byEntry != 0) return byEntry;
  return a.contentDigest.compareTo(b.contentDigest);
}

void main() {
  group('captureSources', () {
    // ── generative properties ────────────────────────────────────────────────

    glados.Glados(
      glados.any.renderedSources,
      glados.ExploreConfig(numRuns: 250),
    ).test(
      'payloads are unique by digest and cover the distinct contents',
      (
        sources,
      ) {
        final result = captureSources(sources);
        final digests = result.payloads.map((p) => p.contentDigest).toList();
        expect(digests.toSet().length, digests.length, reason: 'unique');
        final expected = sources
            .map((s) => ContentDigest.of(s.content))
            .toSet();
        expect(digests.toSet(), expected);
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.any.renderedSources,
      glados.ExploreConfig(numRuns: 250),
    ).test('every reference resolves to a payload and every payload is '
        'referenced', (sources) {
      final result = captureSources(sources);
      final payloadDigests = result.payloads
          .map((p) => p.contentDigest)
          .toSet();
      final refDigests = result.references.map((r) => r.contentDigest).toSet();
      expect(refDigests, payloadDigests);
    }, tags: 'glados');

    glados.Glados(
      glados.any.renderedSources,
      glados.ExploreConfig(numRuns: 250),
    ).test('emits one reference per distinct (entry, digest) pair', (sources) {
      final result = captureSources(sources);
      final expected = sources
          .map((s) => '${s.contentEntryId}|${ContentDigest.of(s.content)}')
          .toSet();
      expect(result.references.length, expected.length);
    }, tags: 'glados');

    glados.Glados(
      glados.any.renderedSources,
      glados.ExploreConfig(numRuns: 250),
    ).test('returns references in canonical assembly order', (sources) {
      final references = captureSources(sources).references;
      final sorted = [...references]..sort(_canonicalOrder);
      expect(references, sorted);
    }, tags: 'glados');

    glados.Glados2(
      glados.any.renderedSources,
      glados.any.shuffleSeed,
      glados.ExploreConfig(numRuns: 250),
    ).test('is permutation-invariant', (sources, seed) {
      expect(
        captureSources(shuffledBySeed(sources, seed)),
        captureSources(sources),
      );
    }, tags: 'glados');

    glados.Glados(
      glados.any.renderedSources,
      glados.ExploreConfig(numRuns: 200),
    ).test('is idempotent under duplicated input', (sources) {
      expect(
        captureSources([...sources, ...sources]),
        captureSources(sources),
      );
    }, tags: 'glados');

    // ── examples ─────────────────────────────────────────────────────────────

    test('returns empty for no sources', () {
      expect(captureSources(const <RenderedSource>[]).isEmpty, isTrue);
    });

    test(
      'shares one payload across identical content from distinct entries',
      () {
        const content = {'text': 'shared note'};
        final result = captureSources([
          RenderedSource(
            contentEntryId: 'e1',
            sourceCreatedAt: DateTime.utc(2024, 3, 10),
            content: content,
          ),
          RenderedSource(
            contentEntryId: 'e2',
            sourceCreatedAt: DateTime.utc(2024, 3, 11),
            content: content,
          ),
        ]);
        expect(result.payloads, hasLength(1));
        expect(result.references, hasLength(2));
        expect(result.references.map((r) => r.contentEntryId).toSet(), {
          'e1',
          'e2',
        });
      },
    );

    test('emits a distinct payload per content version of one entry', () {
      final result = captureSources([
        RenderedSource(
          contentEntryId: 'e1',
          sourceCreatedAt: DateTime.utc(2024, 3, 10),
          content: const {'text': 'v1'},
        ),
        RenderedSource(
          contentEntryId: 'e1',
          sourceCreatedAt: DateTime.utc(2024, 3, 11),
          content: const {'text': 'v2'},
        ),
      ]);
      expect(result.payloads, hasLength(2));
      expect(result.references, hasLength(2));
    });

    test('orders references by sourceCreatedAt then entry id', () {
      final result = captureSources([
        RenderedSource(
          contentEntryId: 'zeta',
          sourceCreatedAt: DateTime.utc(2024, 3, 12),
          content: const {'text': 'c'},
        ),
        RenderedSource(
          contentEntryId: 'alpha',
          sourceCreatedAt: DateTime.utc(2024, 3, 10),
          content: const {'text': 'a'},
        ),
        RenderedSource(
          contentEntryId: 'beta',
          sourceCreatedAt: DateTime.utc(2024, 3, 10),
          content: const {'text': 'b'},
        ),
      ]);
      expect(result.references.map((r) => r.contentEntryId).toList(), [
        'alpha',
        'beta',
        'zeta',
      ]);
    });

    test(
      'keeps the earliest sourceCreatedAt on an exact (entry, content) '
      'collision, independent of order',
      () {
        RenderedSource src(int day) => RenderedSource(
          contentEntryId: 'e1',
          sourceCreatedAt: DateTime.utc(2024, 3, day),
          content: const {'text': 'same'},
        );
        final forward = captureSources([src(5), src(2)]);
        final reverse = captureSources([src(2), src(5)]);
        expect(forward.references, hasLength(1));
        expect(
          forward.references.single.sourceCreatedAt,
          DateTime.utc(2024, 3, 2),
        );
        expect(reverse, forward);
      },
    );
  });

  group('reconcileCapture', () {
    // ── generative properties ────────────────────────────────────────────────

    glados.Glados(
      glados.any.distinctEntrySources,
      glados.ExploreConfig(numRuns: 250),
    ).test(
      'is empty against the frontier it would establish (convergence)',
      (
        sources,
      ) {
        final delta = reconcileCapture(
          currentSources: sources,
          activeDigestByEntry: frontierOf(sources),
        );
        expect(delta.isEmpty, isTrue);
      },
      tags: 'glados',
    );

    glados.Glados2(
      glados.any.renderedSources,
      glados.any.renderedSources,
      glados.ExploreConfig(numRuns: 250),
    ).test('every new reference is genuinely new or changed', (current, prior) {
      final active = frontierOf(prior);
      final delta = reconcileCapture(
        currentSources: current,
        activeDigestByEntry: active,
      );
      for (final reference in delta.newReferences) {
        expect(
          active[reference.contentEntryId],
          isNot(reference.contentDigest),
        );
      }
    }, tags: 'glados');

    glados.Glados2(
      glados.any.renderedSources,
      glados.any.renderedSources,
      glados.ExploreConfig(numRuns: 250),
    ).test('retracts exactly the frontier entries absent from current', (
      current,
      prior,
    ) {
      final active = frontierOf(prior);
      final delta = reconcileCapture(
        currentSources: current,
        activeDigestByEntry: active,
      );
      final currentIds = current.map((s) => s.contentEntryId).toSet();
      final expected = active.keys
          .where((entryId) => !currentIds.contains(entryId))
          .toSet();
      expect(delta.retractedEntryIds.toSet(), expected);
    }, tags: 'glados');

    glados.Glados2(
      glados.any.renderedSources,
      glados.any.renderedSources,
      glados.ExploreConfig(numRuns: 250),
    ).test('new payloads exactly cover the new references', (current, prior) {
      final delta = reconcileCapture(
        currentSources: current,
        activeDigestByEntry: frontierOf(prior),
      );
      expect(
        delta.newPayloads.map((p) => p.contentDigest).toSet(),
        delta.newReferences.map((r) => r.contentDigest).toSet(),
      );
    }, tags: 'glados');

    glados.Glados2(
      glados.any.renderedSources,
      glados.any.renderedSources,
      glados.ExploreConfig(numRuns: 250),
    ).test('an unchanged source contributes no reference', (current, prior) {
      final active = frontierOf(prior);
      final delta = reconcileCapture(
        currentSources: current,
        activeDigestByEntry: active,
      );
      final newRefKeys = delta.newReferences
          .map((r) => '${r.contentEntryId}|${r.contentDigest}')
          .toSet();
      for (final source in current) {
        final digest = ContentDigest.of(source.content);
        if (active[source.contentEntryId] == digest) {
          expect(
            newRefKeys,
            isNot(contains('${source.contentEntryId}|$digest')),
          );
        }
      }
    }, tags: 'glados');

    // ── examples ─────────────────────────────────────────────────────────────

    RenderedSource source(String entryId, String text, {int day = 10}) =>
        RenderedSource(
          contentEntryId: entryId,
          sourceCreatedAt: DateTime.utc(2024, 3, day),
          content: {'text': text},
        );

    test('a brand-new source yields one payload and one reference', () {
      final delta = reconcileCapture(
        currentSources: [source('e1', 'hello')],
        activeDigestByEntry: const {},
      );
      expect(delta.newPayloads, hasLength(1));
      expect(delta.newReferences.single.contentEntryId, 'e1');
      expect(delta.retractedEntryIds, isEmpty);
    });

    test('an edited source yields a fresh reference and payload', () {
      final priorDigest = ContentDigest.of({'text': 'v1'});
      final delta = reconcileCapture(
        currentSources: [source('e1', 'v2')],
        activeDigestByEntry: {'e1': priorDigest},
      );
      expect(delta.newReferences.single.contentDigest, isNot(priorDigest));
      expect(delta.newPayloads, hasLength(1));
    });

    test('a removed source is retracted and adds nothing', () {
      final delta = reconcileCapture(
        currentSources: const [],
        activeDigestByEntry: {
          'e1': ContentDigest.of({'text': 'gone'}),
        },
      );
      expect(delta.retractedEntryIds, ['e1']);
      expect(delta.newReferences, isEmpty);
      expect(delta.newPayloads, isEmpty);
    });

    test('value equality follows fields (RenderedSource, CaptureDelta)', () {
      RenderedSource make() => RenderedSource(
        contentEntryId: 'e1',
        sourceCreatedAt: DateTime.utc(2024, 3, 10),
        content: const {'text': 'a'},
      );
      // Distinct instances, equal by props.
      expect(make(), make());
      expect(
        make(),
        isNot(
          RenderedSource(
            contentEntryId: 'e2',
            sourceCreatedAt: DateTime.utc(2024, 3, 10),
            content: const {'text': 'a'},
          ),
        ),
      );

      CaptureDelta delta() => reconcileCapture(
        currentSources: [make()],
        activeDigestByEntry: const {},
      );
      expect(delta(), delta());
      expect(
        delta(),
        isNot(
          reconcileCapture(
            currentSources: const [],
            activeDigestByEntry: const {},
          ),
        ),
      );
    });

    test('re-adding a retracted source reappears as new', () {
      // After retraction the source is absent from the active frontier, so its
      // return — even with identical content — is captured as new again.
      final delta = reconcileCapture(
        currentSources: [source('e1', 'back')],
        activeDigestByEntry: const {},
      );
      expect(delta.newReferences.single.contentEntryId, 'e1');
      expect(delta.newPayloads, hasLength(1));
    });
  });
}
