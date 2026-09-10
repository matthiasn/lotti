/// Keeps the project agent's "Proposed changes" band from accumulating the
/// same suggestion once per wake.
///
/// A project wake used to write a fresh pending `ChangeSetEntity` and never
/// look at the ones already on screen, so an agent that thought the project
/// should be Active proposed exactly that on every wake — thirteen identical
/// rows, none of which the previous wake could withdraw. Two rules fix that,
/// and they are deliberately separate:
///
///  * **Redundant against the project**: a status the project already has
///    changes nothing when applied, so it is never worth proposing. Caught by
///    [projectStatusProposalIsRedundant] the moment the tool is called, so the
///    model gets told inside the wake rather than silently losing the call.
///  * **Redundant against the band**: a proposal the user is already looking
///    at — or has already turned down — must not be written a second time.
///    Caught by [reconcileProjectProposals] at persist time, against the
///    ledger the wake was handed.
///
/// Retraction is the third leg and lives in `SuggestionRetractionService`:
/// the guard in the prompt lists open proposals by fingerprint so the agent
/// can withdraw the ones that went stale.
library;

import 'package:lotti/classes/project_data.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/model/proposal_ledger.dart';
import 'package:lotti/features/agents/tools/project_tool_definitions.dart';
import 'package:lotti/features/agents/workflow/change_item_dedup.dart';

/// The args to persist for a deferred [toolName] call, with an
/// `update_project_status` status word replaced by its canonical value.
///
/// The tool accepts aliases — `on_track` and `in_progress` both mean `active`,
/// `blocked` means `on_hold` — and the apply path and the row the user reads
/// both collapse them. The *stored* args did not, so two proposals that read
/// identically ("Update project status to Active") carried different
/// fingerprints and different summaries, and every duplicate check downstream
/// missed them: the band accumulated rows that were the same suggestion
/// spelled differently.
///
/// Normalizing here, at the boundary where the model's word enters, makes
/// fingerprint *and* display-key comparison correct everywhere at once
/// instead of teaching each comparison about status aliases. A word outside
/// the vocabulary is left verbatim, so the apply path can still report what
/// the vocabulary is.
Map<String, dynamic> normalizeProjectProposalArgs(
  String toolName,
  Map<String, dynamic> args,
) {
  if (toolName != ProjectAgentToolNames.updateProjectStatus) return args;
  final raw = args['status'];
  if (raw is! String) return args;
  final canonical = canonicalProjectStatus(raw);
  if (canonical == null || canonical == raw) return args;
  return {...args, 'status': canonical};
}

/// Whether an `update_project_status` call would leave the project exactly as
/// it is.
///
/// [args] are the raw tool arguments. A status word outside the vocabulary is
/// **not** redundant — it is invalid, and the apply path reports that far more
/// usefully than a silent drop here would.
///
/// `on_hold` carries a reason the user reads, so re-proposing it with a
/// different reason is a real change and stays proposable; the same reason
/// (whitespace aside) is not.
bool projectStatusProposalIsRedundant({
  required ProjectStatus current,
  required Map<String, dynamic> args,
}) {
  final raw = args['status'];
  if (raw is! String) return false;
  final proposed = canonicalProjectStatus(raw);
  if (proposed == null) return false;
  if (proposed != canonicalProjectStatusOf(current)) return false;

  if (current case ProjectOnHold(:final reason)) {
    final proposedReason = args['reason'];
    final next = proposedReason is String ? proposedReason.trim() : '';
    return next.isEmpty || next == reason.trim();
  }
  return true;
}

/// The subset of [proposed] worth persisting, given what the band already
/// holds.
///
/// Drops anything whose structural fingerprint or user-facing summary matches
/// a still-open proposal in [ledger], and anything matching a proposal the
/// user has already rejected — the sticky-rejection rule the task agent's
/// change-set builder applies, reused here rather than restated.
///
/// Order is preserved and the first occurrence of a fingerprint wins, so a
/// wake that proposes the same change twice in one conversation writes it
/// once.
List<ChangeItem> reconcileProjectProposals({
  required List<ChangeItem> proposed,
  required ProposalLedger ledger,
}) {
  if (proposed.isEmpty) return proposed;
  final open = [
    for (final entry in ledger.open)
      ChangeItem(
        toolName: entry.toolName,
        args: entry.args,
        humanSummary: entry.humanSummary,
      ),
  ];
  final deduped = deduplicateItems(
    proposed,
    open,
    rejectedFingerprints: ledger.rejectedFingerprints,
    rejectedDisplayKeys: ledger.rejectedDisplayKeys,
  );
  // `deduplicateItems` compares each proposal against [open] only, so two
  // items that duplicate each other *inside* one wake both survive it.
  // Collapse those on the same two keys the cross-wake pass uses: two
  // `create_task` calls with one title but different descriptions carry
  // different fingerprints and render the same row, and confirming both
  // would create the task twice.
  final seenFingerprints = <String>{};
  final seenDisplayKeys = <String>{};
  final collapsed = <ChangeItem>[];
  for (final item in deduped) {
    if (!seenFingerprints.add(ChangeItem.fingerprint(item))) continue;
    final displayKey = ChangeItem.displayDuplicateKey(item);
    if (displayKey != null && !seenDisplayKeys.add(displayKey)) continue;
    collapsed.add(item);
  }
  return collapsed;
}
