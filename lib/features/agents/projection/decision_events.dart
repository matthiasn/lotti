import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/proposal_ledger.dart';
import 'package:lotti/features/agents/projection/input_events.dart';
import 'package:lotti/utils/string_utils.dart';

/// Renders one resolved [LedgerEntry] as the single line both the prompt's
/// proposal ledger (legacy mode) and the event tail's decision-tagged events
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
  // Collapse whitespace runs (incl. embedded newlines) so one decision is
  // always exactly one line in the event tail.
  final summary = normalizeWhitespace(entry.humanSummary);
  final trimmedReason = entry.reason == null
      ? null
      : normalizeWhitespace(entry.reason!);
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
/// data, so devices converge. Two acknowledged edges:
/// - re-resolution of an item (e.g. deferred → confirmed) re-positions its
///   event: one deliberate line mutation, mirroring how the ledger itself
///   keeps only the newest verdict;
/// - [resolved] is a bounded recent window
///   (`TaskAgentWorkflow.resolvedDecisionWindow`, 500): once more verdicts
///   than that exist, the oldest leave the projected set. Folded verdicts
///   stay provably covered (they are in the checkpoint's `coveredSources`,
///   so checkpoint completeness does not misfire on their absence); only a
///   never-folding agent with >window UNFOLDED verdicts would see its oldest
///   decision lines drop — the workflow logs loudly when the window
///   saturates instead of truncating silently.
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
