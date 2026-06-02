import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/projection/input_capture.dart';

/// Projects the agent's **active input frontier** (ADR 0020): the latest,
/// not-retracted captured content per source (`contentEntryId`), folded from
/// the append-only log of `messagePayload` references and retraction events.
///
/// Pure function of the message/link *set* for one agent — it never re-reads
/// the journal — so two devices holding the same log derive the same frontier.
/// Operations are ordered by **capture time** (`createdAt`), then id as a
/// deterministic tiebreak (ADR 0020 rule 4 fixes ordering on captured metadata,
/// not a live read), and folded latest-wins per source:
/// - an active `messagePayload` link captures/changes its `contentEntryId` to
///   the referenced payload digest (its `toId`);
/// - an active message tagged `metadata.retractsContentEntryId` removes that
///   source;
/// - so a re-capture after a retraction (a later `createdAt`) restores the
///   source.
///
/// Soft-deleted links/messages are ignored, and pre-ADR-0020 payload references
/// (which carry no `contentEntryId`/`sourceCreatedAt`) are not input captures
/// and are skipped. Returns a map from `contentEntryId` to the winning
/// [CaptureReference]; use [inputFrontierDigests] for the `activeDigestByEntry`
/// shape `reconcileCapture` expects.
Map<String, CaptureReference> projectInputFrontier({
  required Iterable<AgentMessageEntity> messages,
  required Iterable<AgentLink> links,
}) {
  final ops = <_FrontierOp>[];

  for (final link in links) {
    if (link is! MessagePayloadLink || link.deletedAt != null) continue;
    final entryId = link.contentEntryId;
    final sourceCreatedAt = link.sourceCreatedAt;
    if (entryId == null || sourceCreatedAt == null) continue;
    ops.add(
      _FrontierOp(
        at: link.createdAt,
        tiebreak: link.id,
        entryId: entryId,
        reference: CaptureReference(
          contentDigest: link.toId,
          contentEntryId: entryId,
          sourceCreatedAt: sourceCreatedAt,
        ),
      ),
    );
  }

  for (final message in messages) {
    if (message.deletedAt != null) continue;
    final retracted = message.metadata.retractsContentEntryId;
    if (retracted == null) continue;
    ops.add(
      _FrontierOp(
        at: message.createdAt,
        tiebreak: message.id,
        entryId: retracted,
        reference: null,
      ),
    );
  }

  ops.sort((a, b) {
    final byTime = a.at.compareTo(b.at);
    if (byTime != 0) return byTime;
    return a.tiebreak.compareTo(b.tiebreak);
  });

  final frontier = <String, CaptureReference>{};
  for (final op in ops) {
    if (op.reference == null) {
      frontier.remove(op.entryId);
    } else {
      frontier[op.entryId] = op.reference!;
    }
  }
  return frontier;
}

/// The `activeDigestByEntry` view of a [projectInputFrontier] result — each
/// source's `contentEntryId` mapped to its active content digest — as accepted
/// by `reconcileCapture`.
Map<String, String> inputFrontierDigests(
  Map<String, CaptureReference> frontier,
) => {
  for (final entry in frontier.entries) entry.key: entry.value.contentDigest,
};

/// One capture (non-null [reference]) or retraction (null [reference]) folded
/// by [projectInputFrontier], ordered by ([at], [tiebreak]).
class _FrontierOp {
  const _FrontierOp({
    required this.at,
    required this.tiebreak,
    required this.entryId,
    required this.reference,
  });

  final DateTime at;
  final String tiebreak;
  final String entryId;
  final CaptureReference? reference;
}
