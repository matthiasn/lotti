import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/proposal_ledger.dart';
import 'package:lotti/features/agents/projection/input_events.dart';

/// Renders one resolved [LedgerEntry] as the single line both the prompt's
/// proposal ledger (legacy mode) and the event tail's `(decision)` events
/// use, e.g.:
///
/// `[fp=set_task_title:179…] ✓ \`set_task_title\`: Set title to "X" —
/// confirmed by user (reason: "…")`
///
/// Pure function of the entry, so two devices render byte-identical lines.
String formatResolvedLedgerLine(LedgerEntry entry) {
  final icon = switch (entry.verdict) {
    ChangeDecisionVerdict.confirmed => '✓',
    ChangeDecisionVerdict.rejected => '✗',
    ChangeDecisionVerdict.deferred => '⏸',
    ChangeDecisionVerdict.retracted => '↺',
    null => '○',
  };
  final verdictLabel = entry.verdict?.name ?? entry.status.name;
  final actorLabel = switch (entry.resolvedBy) {
    DecisionActor.user => ' by user',
    DecisionActor.agent => ' by agent',
    null => '',
  };
  final summary = entry.humanSummary.trim();
  final trimmedReason = entry.reason?.trim();
  final reasonSuffix = (trimmedReason != null && trimmedReason.isNotEmpty)
      ? ' (reason: "$trimmedReason")'
      : '';
  return '[fp=${entry.fingerprint}] $icon `${entry.toolName}`: $summary '
      '— $verdictLabel$actorLabel$reasonSuffix';
}

/// Projects resolved proposal verdicts into inline [InputEvent]s so they
/// share the agent's memory substrate (ADR 0016/0017): a verdict is appended
/// at its resolution time, interleaves chronologically with the content that
/// motivated it, and folds into summary checkpoints by the same watermarks —
/// instead of being re-rendered (and eventually capped away) in a separate
/// prompt section every wake.
///
/// Verdict events only: while a proposal is open it is current *state*
/// (the ledger's Open section, where the agent reads fingerprints for
/// `retract_suggestions`); once resolved, the verdict event records both
/// what was proposed and how it ended, so a creation event would be
/// redundant tail noise.
///
/// Positioned at `resolvedAt` (falling back to the proposal's `createdAt`)
/// with the `(changeSetId, itemIndex)` pair as the unique key — all synced
/// data, so devices converge. The rare re-resolution of an item (e.g.
/// deferred → confirmed) re-positions its event: one deliberate line
/// mutation, mirroring how the ledger itself keeps only the newest verdict.
List<InputEvent> decisionEventsFromLedger(Iterable<LedgerEntry> resolved) {
  return [
    for (final entry in resolved)
      InputEvent.inline(
        position: EventPosition(
          at: entry.resolvedAt ?? entry.createdAt,
          sourceAt: entry.resolvedAt ?? entry.createdAt,
          key: 'decision|${entry.changeSetId}:${entry.itemIndex}',
        ),
        contentEntryId: '${entry.changeSetId}:${entry.itemIndex}',
        sourceCreatedAt: entry.resolvedAt ?? entry.createdAt,
        inlineContent: <String, Object?>{
          'entryType': 'decision',
          'text': formatResolvedLedgerLine(entry),
        },
      ),
  ];
}
