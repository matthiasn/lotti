import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/projection/input_events.dart';
import 'package:lotti/utils/string_utils.dart';

/// Projects submitted Daily OS capture transcripts into inline [InputEvent]s
/// so they share the day agent's memory substrate (ADR 0016/0017): each
/// capture is appended at its submission time, interleaves chronologically
/// with the agent's observations, and folds into summary checkpoints by the
/// same watermarks.
///
/// Inline (no `messagePayload` row) because [CaptureEntity] is *already* a
/// synced log entity — re-capturing it through payload links would duplicate
/// synced data. Soft-deleted captures are excluded.
List<InputEvent> dayCaptureEvents(Iterable<CaptureEntity> captures) {
  return [
    for (final capture in captures)
      if (capture.deletedAt == null)
        InputEvent.inline(
          position: EventPosition(
            at: capture.createdAt,
            sourceAt: capture.capturedAt,
            key: 'capture|${capture.id}',
          ),
          contentEntryId: capture.id,
          sourceCreatedAt: capture.capturedAt,
          inlineContent: <String, Object?>{
            'entryType': 'capture',
            'text': normalizeWhitespace(capture.transcript),
          },
        ),
  ];
}
