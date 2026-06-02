import 'package:glados/glados.dart';
import 'package:lotti/features/agents/projection/content_digest.dart';
import 'package:lotti/features/agents/projection/input_capture.dart';

/// A deterministic shuffle of [items] keyed by [seed] — models the same logical
/// content being constructed/arriving in a different order.
List<T> shuffledBySeed<T>(List<T> items, int seed) =>
    [...items]..shuffle(Random(seed));

/// The active input frontier that capturing [sources] would establish: the
/// content digest per `contentEntryId` (last occurrence wins). A convenient
/// stand-in for a prior frontier in `reconcileCapture` property tests.
Map<String, String> frontierOf(Iterable<RenderedSource> sources) {
  final byEntry = <String, String>{};
  for (final source in sources) {
    byEntry[source.contentEntryId] = ContentDigest.of(source.content);
  }
  return byEntry;
}

/// Glados generators for the content-capture property tests (C1). Shared by
/// `content_digest_test.dart` and `input_capture_test.dart`.
extension AnyCaptureFixtures on Any {
  /// A JSON scalar of mixed type, deliberately including the cases
  /// canonicalization must normalize: integral vs non-integral doubles,
  /// empty/unicode/whitespace strings, bool, and null.
  // NB: glados `choose` requires distinct pool entries, and `1 == 1.0` in a
  // Set — so the pool carries `1000000.0` (an integral double) for the
  // double-normalization path but not a `1.0` that would collide with `1`.
  Generator<Object?> get jsonScalar => AnyUtils(this).choose(<Object?>[
    0,
    1,
    -1,
    42,
    2.5,
    -3.5,
    1000000.0,
    true,
    false,
    null,
    '',
    'a',
    'b',
    'status',
    'naïve',
    '日本語',
    'x y',
  ]);

  /// 0..6 scalars; callers build maps/lists from these so they can reorder the
  /// *same* logical content and assert digest stability.
  Generator<List<Object?>> get jsonScalars =>
      ListAnys(this).listWithLengthInRange(0, 6, jsonScalar);

  /// A flat content map `{k0: v, k1: v, ...}` with distinct keys and 0..5
  /// mixed-type scalar values.
  Generator<Map<String, Object?>> get contentMap => jsonScalars.map(
    (values) => <String, Object?>{
      for (var i = 0; i < values.length; i++) 'k$i': values[i],
    },
  );

  /// 0..6 rendered sources drawn from small pools, so entry-id collisions,
  /// content collisions, and identical-timestamp ties all arise naturally —
  /// exercising dedup and the canonical-order tiebreaks.
  Generator<List<RenderedSource>> get renderedSources =>
      ListAnys(this).listWithLengthInRange(0, 6, _renderedSource);

  Generator<RenderedSource> get _renderedSource => CombinableAny(this).combine3(
    AnyUtils(this).choose(<String>['t1', 't2', 't3']),
    IntAnys(this).intInRange(0, 4),
    contentMap,
    (entryId, dayOffset, content) => RenderedSource(
      contentEntryId: entryId,
      sourceCreatedAt: DateTime.utc(2024, 3, 10).add(Duration(days: dayOffset)),
      content: content,
    ),
  );

  /// 0..6 sources with **distinct** entry ids (`e0`, `e1`, …) — so their
  /// frontier is unambiguous (one digest per entry), which the convergence
  /// property of `reconcileCapture` relies on.
  Generator<List<RenderedSource>> get distinctEntrySources => ListAnys(this)
      .listWithLengthInRange(0, 6, _contentAndDay)
      .map(
        (specs) => [
          for (var i = 0; i < specs.length; i++)
            RenderedSource(
              contentEntryId: 'e$i',
              sourceCreatedAt: DateTime.utc(
                2024,
                3,
                10,
              ).add(Duration(days: specs[i].$2)),
              content: specs[i].$1,
            ),
        ],
      );

  Generator<(Map<String, Object?>, int)> get _contentAndDay =>
      CombinableAny(this).combine2(
        contentMap,
        IntAnys(this).intInRange(0, 4),
        (content, dayOffset) => (content, dayOffset),
      );

  /// A non-negative seed for deterministic shuffles.
  Generator<int> get shuffleSeed => IntAnys(this).intInRange(0, 1 << 30);
}
