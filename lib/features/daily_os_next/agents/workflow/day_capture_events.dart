import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/projection/input_events.dart';
import 'package:lotti/utils/string_utils.dart';

/// Lightweight ordering metadata for one capture — enough to fix its position
/// in the memory log without loading the transcript. A plain record so the
/// agents layer (which produces it) stays free of any Daily OS coupling.
typedef CaptureEventMeta = ({
  String id,
  DateTime createdAt,
  DateTime capturedAt,
});

/// Projects submitted Daily OS capture transcripts into **deferred** inline
/// [InputEvent]s so they share the day agent's memory substrate (ADR 0016/0017):
/// each capture is appended at its submission time, interleaves chronologically
/// with the agent's observations, and folds into summary checkpoints by the
/// same watermarks.
///
/// Deferred (no eager content) because the planner is one long-lived agent
/// whose capture history grows without bound: position + id are all the
/// substrate needs to order the log and prove checkpoint coverage, so the
/// transcript is resolved lazily ([captureInlineContent]) for only the
/// post-cutoff tail the compactor actually renders. Inline (no `messagePayload`
/// row) because [CaptureEntity] is *already* a synced log entity — re-capturing
/// it through payload links would duplicate synced data. Soft-deleted captures
/// are excluded upstream by the metadata query.
List<InputEvent> dayCaptureEvents(Iterable<CaptureEventMeta> captures) {
  return [
    for (final capture in captures)
      InputEvent.inlineDeferred(
        position: EventPosition(
          at: capture.createdAt,
          sourceAt: capture.capturedAt,
          key: 'capture|${capture.id}',
        ),
        contentEntryId: capture.id,
        sourceCreatedAt: capture.capturedAt,
      ),
  ];
}

/// The metadata record for an already-loaded [capture] — used where the full
/// entity is in hand (e.g. prompt reconstruction) so it can build the same
/// deferred events without a second query.
CaptureEventMeta captureEventMeta(CaptureEntity capture) => (
  id: capture.id,
  createdAt: capture.createdAt,
  capturedAt: capture.capturedAt,
);

/// The inline content a capture renders/folds as. The single source of truth
/// for capture content so the lazy resolver produces bytes identical to what a
/// fold digests — keeping checkpoint coverage convergent across devices and app
/// versions.
Map<String, Object?> captureInlineContent(String transcript) =>
    <String, Object?>{
      'entryType': 'capture',
      'text': normalizeWhitespace(transcript),
    };
