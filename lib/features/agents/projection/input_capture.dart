import 'package:equatable/equatable.dart';
import 'package:lotti/features/agents/projection/content_digest.dart';

/// A single user-content source the agent rendered into its prompt during a
/// wake, *before* it is captured into the log (ADR 0020).
///
/// [content] is the rendered text/structure the model actually saw — never a
/// raw artifact (audio becomes its transcript, an image its analysis result).
/// [contentEntryId] is the originating journal entity (provenance) and
/// [sourceCreatedAt] is that source's chronological position; both are
/// snapshotted so capture *and* replay are pure functions of the log and never
/// re-read the mutable journal.
class RenderedSource extends Equatable {
  /// Creates a rendered source. [content] must be JSON-able (it is hashed by
  /// [ContentDigest]).
  const RenderedSource({
    required this.contentEntryId,
    required this.sourceCreatedAt,
    required this.content,
  });

  /// The originating journal entity id — provenance and the id-tiebreak in the
  /// canonical assembly order.
  final String contentEntryId;

  /// The source's chronological position, snapshotted at capture time.
  final DateTime sourceCreatedAt;

  /// The rendered content the model saw (e.g. `{'text': ...}`). Hashed to form
  /// the content-addressed payload id.
  final Map<String, Object?> content;

  @override
  List<Object?> get props => [contentEntryId, sourceCreatedAt, content];
}

/// A content-addressed payload produced by [captureSources]: stored once per
/// distinct content version, keyed purely by [contentDigest] (no originating
/// identity — provenance lives on the [CaptureReference]).
class CapturedPayload extends Equatable {
  /// Creates a payload. [contentDigest] is both its id and its address.
  const CapturedPayload({required this.contentDigest, required this.content});

  /// The content-addressed digest — also the payload's id (ADR 0020 rule 2).
  final String contentDigest;

  /// The rendered content this payload holds.
  final Map<String, Object?> content;

  @override
  List<Object?> get props => [contentDigest, content];
}

/// A reference from the consuming wake to one [CapturedPayload], carrying the
/// provenance and ordering metadata (ADR 0020 rules 2/4). Many references can
/// point at one shared payload, each with its own provenance.
class CaptureReference extends Equatable {
  /// Creates a reference to the payload addressed by [contentDigest].
  const CaptureReference({
    required this.contentDigest,
    required this.contentEntryId,
    required this.sourceCreatedAt,
  });

  /// The payload this reference points at.
  final String contentDigest;

  /// The originating journal entity (provenance).
  final String contentEntryId;

  /// The source's snapshotted chronological position (primary sort key).
  final DateTime sourceCreatedAt;

  @override
  List<Object?> get props => [contentDigest, contentEntryId, sourceCreatedAt];
}

/// The deduplicated result of capturing a wake's rendered sources:
/// [payloads] unique by content digest, [references] one per distinct
/// (source, content) pair in **canonical assembly order**.
class CaptureResult extends Equatable {
  /// Wraps the capture output. Callers obtain instances from [captureSources].
  const CaptureResult({required this.payloads, required this.references});

  /// Distinct content payloads, ordered by [CapturedPayload.contentDigest] for
  /// determinism. Storage grows with distinct content versions, not wakes.
  final List<CapturedPayload> payloads;

  /// The per-wake input frontier: one reference per source, sorted in canonical
  /// assembly order so the rebuilt prompt is byte-identical across devices and
  /// replays (and the on-device prefix cache keeps hitting).
  final List<CaptureReference> references;

  /// True when nothing was captured.
  bool get isEmpty => payloads.isEmpty && references.isEmpty;

  @override
  List<Object?> get props => [payloads, references];
}

/// Folds the [sources] a wake rendered into a deduplicated [CaptureResult]
/// (ADR 0020). Pure function of the input set:
///
/// - **Payloads** dedupe by `ContentDigest.of(content)` — identical content
///   yields a single payload, so re-waking with unchanged content emits no new
///   payload.
/// - **References** dedupe by `(contentEntryId, contentDigest)` — capturing the
///   same set twice is idempotent — and are returned in canonical assembly
///   order (`sourceCreatedAt`, then `contentEntryId`, then `contentDigest`),
///   which is a total order over captured (never live-read) metadata.
///
/// Callers are expected to pass one source per `contentEntryId`; if a single
/// entry legitimately appears with two different contents, both references are
/// kept (distinct digests) and ordered deterministically.
CaptureResult captureSources(Iterable<RenderedSource> sources) {
  final payloadsByDigest = <String, CapturedPayload>{};
  final referencesByKey = <String, CaptureReference>{};

  for (final source in sources) {
    final digest = ContentDigest.of(source.content);
    payloadsByDigest.putIfAbsent(
      digest,
      () => CapturedPayload(contentDigest: digest, content: source.content),
    );
    // `|` cannot occur in a journal-entity id (UUID) or in a digest
    // (`sha256-v1:` + base64url), so it is a safe composite-key separator that
    // cannot alias two distinct (entry, digest) pairs.
    final key = '${source.contentEntryId}|$digest';
    final existing = referencesByKey[key];
    // On a key collision (the same entry rendered twice with identical
    // content) keep the earliest `sourceCreatedAt`, so the fold is independent
    // of the iteration order of [sources].
    if (existing == null ||
        source.sourceCreatedAt.isBefore(existing.sourceCreatedAt)) {
      referencesByKey[key] = CaptureReference(
        contentDigest: digest,
        contentEntryId: source.contentEntryId,
        sourceCreatedAt: source.sourceCreatedAt,
      );
    }
  }

  final payloads = payloadsByDigest.values.toList()
    ..sort((a, b) => a.contentDigest.compareTo(b.contentDigest));
  final references = referencesByKey.values.toList()..sort(_canonicalOrder);

  return CaptureResult(payloads: payloads, references: references);
}

/// Canonical assembly order (ADR 0020 rule 4): source chronological position,
/// then originating-entity id, then content digest. A strict total order that
/// is a pure function of captured metadata, so two devices and a replay emit
/// byte-identical prompts.
int _canonicalOrder(CaptureReference a, CaptureReference b) {
  final byTime = a.sourceCreatedAt.compareTo(b.sourceCreatedAt);
  if (byTime != 0) return byTime;
  final byEntry = a.contentEntryId.compareTo(b.contentEntryId);
  if (byEntry != 0) return byEntry;
  return a.contentDigest.compareTo(b.contentDigest);
}

/// What a wake must append to bring the captured log in line with the sources
/// it just rendered, relative to the agent's currently-active input frontier
/// (ADR 0020). Produced by [reconcileCapture].
class CaptureDelta extends Equatable {
  /// Wraps the delta. Callers obtain instances from [reconcileCapture].
  const CaptureDelta({
    required this.newPayloads,
    required this.newReferences,
    required this.retractedEntryIds,
  });

  /// Payloads whose content is not already covered by the active frontier and
  /// must be ensured-present (content-addressed, so a write is a no-op when the
  /// row already exists from an earlier wake/agent). Ordered by digest.
  final List<CapturedPayload> newPayloads;

  /// New `messagePayload` references to append for sources that are new or
  /// whose content changed since the active frontier. Canonical order.
  final List<CaptureReference> newReferences;

  /// Sources present in the active frontier but absent from the current render
  /// — deleted or unlinked — to be soft-retracted from consideration (kept
  /// auditable in the log). Sorted.
  final List<String> retractedEntryIds;

  /// True when the captured log already matches the rendered sources — the
  /// "re-wake with no content change emits nothing" case.
  bool get isEmpty =>
      newPayloads.isEmpty && newReferences.isEmpty && retractedEntryIds.isEmpty;

  @override
  List<Object?> get props => [newPayloads, newReferences, retractedEntryIds];
}

/// Diffs the [currentSources] a wake rendered against the agent's active input
/// frontier — [activeDigestByEntry], mapping each non-retracted source's
/// `contentEntryId` to its currently-captured `contentDigest` — and returns the
/// [CaptureDelta] to append (ADR 0020).
///
/// Pure function of its inputs:
/// - a source whose digest already equals `activeDigestByEntry[entryId]` is
///   **unchanged** → contributes nothing;
/// - a source that is new (`entryId` absent) or changed (different digest)
///   contributes a reference, and its payload if not otherwise present;
/// - an `entryId` in the frontier but absent from [currentSources] is
///   **retracted**.
///
/// Convergence/idempotence: applying the delta makes the frontier equal the
/// current sources' digests, after which a re-reconcile yields an empty delta.
/// A previously-retracted source that reappears is simply "new" again (the
/// re-added reference post-dates the retraction in the log).
CaptureDelta reconcileCapture({
  required Iterable<RenderedSource> currentSources,
  required Map<String, String> activeDigestByEntry,
}) {
  final captured = captureSources(currentSources);

  final changedReferences = [
    for (final reference in captured.references)
      if (activeDigestByEntry[reference.contentEntryId] !=
          reference.contentDigest)
        reference,
  ];
  final neededDigests = {
    for (final reference in changedReferences) reference.contentDigest,
  };
  final newPayloads = [
    for (final payload in captured.payloads)
      if (neededDigests.contains(payload.contentDigest)) payload,
  ];

  final currentEntryIds = {
    for (final source in currentSources) source.contentEntryId,
  };
  final retractedEntryIds = [
    for (final entryId in activeDigestByEntry.keys)
      if (!currentEntryIds.contains(entryId)) entryId,
  ]..sort();

  return CaptureDelta(
    newPayloads: newPayloads,
    newReferences: changedReferences,
    retractedEntryIds: retractedEntryIds,
  );
}
