import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/classes/agents/change_set.dart';
import 'package:lotti/classes/agents/proposal_ledger.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/workflow/change_item_dedup.dart';
import 'package:lotti/features/ai/backfill/inference_backfill.dart';
import 'package:lotti/features/ai/backfill/inference_backfill_providers.dart';
import 'package:lotti/features/ai/link_suggestions/task_link_suggestion.dart';
import 'package:lotti/features/ai/link_suggestions/task_link_suggestion_providers.dart';
import 'package:lotti/providers/agent_repository_providers.dart';

/// One pending proposal in the unified suggestion list.
///
/// Carries the full owning [ChangeSetEntity] and the item's zero-based
/// index within its items list, plus the item itself for convenience.
/// This shape is what the UI widget needs to hand directly to
/// `ChangeSetConfirmationService.confirmItem(changeSet, itemIndex)` or
/// `rejectItem(...)` — the service itself re-reads a fresh snapshot
/// before mutating, so stale fields are harmless.
///
/// A [backfill] suggestion is the exception: it is not the agent's proposal
/// but a mechanical one — an entry of the task whose image analysis,
/// transcription or summary never ran. Its [changeSet] is a stand-in that is
/// never persisted, never synced and never shown to the agent; it exists so
/// the row renders and animates like every other proposal. Confirming or
/// rejecting it goes to the backfill queue and dismissals instead of
/// `ChangeSetConfirmationService`.
///
/// A [link] suggestion is the other mechanical kind: a task the task's own
/// notes or log speak of, found by meaning. It is an ordinary `link_task`
/// row — the sentence it reads, the "Add" kind — on the same kind of
/// stand-in set; confirming it writes the link through the same handler a
/// confirmed agent `link_task` proposal uses, and rejecting it hides the
/// pair on this device.
class PendingSuggestion {
  const PendingSuggestion({
    required this.changeSet,
    required this.itemIndex,
    required this.item,
    required this.fingerprint,
    this.backfill,
    this.link,
  });

  /// A suggestion to run the inference [candidate] is missing.
  factory PendingSuggestion.backfill({
    required InferenceBackfillCandidate candidate,
    required String agentId,
    required String taskId,
  }) {
    final item = ChangeItem(
      toolName: candidate.kind.toolName,
      args: {
        'entryId': candidate.entryId,
        'capturedAt': candidate.capturedAt.toIso8601String(),
      },
      // Fallback text only: the row re-derives the localized sentence from
      // the tool name and args.
      humanSummary: candidate.kind.toolName,
    );
    return PendingSuggestion(
      changeSet: ChangeSetEntity(
        id: 'inference-backfill:${candidate.key}',
        agentId: agentId,
        taskId: taskId,
        threadId: 'inference-backfill',
        runKey: 'inference-backfill',
        status: ChangeSetStatus.pending,
        items: [item],
        createdAt: candidate.capturedAt,
        vectorClock: null,
      ),
      itemIndex: 0,
      item: item,
      fingerprint: ChangeItem.fingerprint(item),
      backfill: candidate,
    );
  }

  /// A suggestion to link the task to the one [suggestion] found.
  ///
  /// Its args are a `link_task` proposal's, plus the target's title so the
  /// row reads the relation in the reader's language. The title also keeps
  /// its fingerprint apart from an agent proposal of the same link, which
  /// [unifiedSuggestionList] hides it behind anyway.
  factory PendingSuggestion.link({
    required TaskLinkSuggestion suggestion,
    required String agentId,
  }) {
    final item = ChangeItem(
      toolName: TaskAgentToolNames.linkTask,
      args: {
        'relation': suggestion.relation.wireName,
        'targetTaskId': suggestion.targetTaskId,
        'targetTitle': suggestion.targetTitle,
      },
      // Fallback text only: the row re-derives the localized sentence from
      // the relation and the title.
      humanSummary:
          'Link: this task ${suggestion.relation.englishPhrase} '
          '"${suggestion.targetTitle}"',
    );
    return PendingSuggestion(
      changeSet: ChangeSetEntity(
        id: 'link-suggestion:${suggestion.key}',
        agentId: agentId,
        taskId: suggestion.sourceTaskId,
        threadId: 'link-suggestion',
        runKey: 'link-suggestion',
        status: ChangeSetStatus.pending,
        items: [item],
        createdAt: suggestion.mentionedAt,
        vectorClock: null,
      ),
      itemIndex: 0,
      item: item,
      fingerprint: ChangeItem.fingerprint(item),
      link: suggestion,
    );
  }

  final ChangeSetEntity changeSet;
  final int itemIndex;
  final ChangeItem item;
  final String fingerprint;

  /// The missing inference this suggestion runs; null for an agent proposal.
  final InferenceBackfillCandidate? backfill;

  /// The link this suggestion writes; null for an agent proposal.
  final TaskLinkSuggestion? link;

  /// Whether this is a mechanical suggestion — [backfill] or [link] — rather
  /// than a proposal persisted in the agent's change set. A mechanical one
  /// is decided outside `ChangeSetConfirmationService`.
  bool get isMechanical => backfill != null || link != null;
}

/// What the consolidated `AiSummaryCard` renders for a single task.
///
/// [open] feeds the active suggestion list the user can act on. [activity]
/// feeds the collapsed "recent activity" strip so the user can see what
/// the agent has already confirmed, rejected, or autonomously retracted.
class UnifiedSuggestionList {
  const UnifiedSuggestionList({
    required this.open,
    required this.activity,
    this.agentName,
  });

  const UnifiedSuggestionList.empty()
    : open = const [],
      activity = const [],
      agentName = null;

  final List<PendingSuggestion> open;
  final List<LedgerEntry> activity;

  /// The task agent's display name. Surfaced in the activity strip so
  /// the retracted-verdict tooltip can name the agent that withdrew a
  /// proposal instead of a generic "by agent". `null` when no agent is
  /// attached to the task.
  final String? agentName;
}

/// Builds a [UnifiedSuggestionList] for a task.
///
/// Resolves the task agent, watches its update stream for reactive
/// invalidation, and queries both the pending change sets (so the UI can
/// dispatch confirm/reject through the existing
/// `ChangeSetConfirmationService` contract) and the proposal ledger (so
/// the activity strip can show recently-resolved / retracted items).
///
/// After the agent's own proposals come the task's link suggestions
/// ([taskLinkSuggestionsProvider]) — except one for a task an open agent
/// proposal already links, which would be the same decision twice — and
/// then its backfill suggestions ([inferenceBackfillSuggestionsProvider]),
/// one per entry missing inference.
final FutureProviderFamily<UnifiedSuggestionList, String>
unifiedSuggestionListProvider = FutureProvider.autoDispose
    .family<UnifiedSuggestionList, String>(
      unifiedSuggestionList,
      name: 'unifiedSuggestionListProvider',
    );
Future<UnifiedSuggestionList> unifiedSuggestionList(
  Ref ref,
  String taskId,
) async {
  final agent = ref
      .watch(taskAgentProvider(taskId))
      .value
      ?.mapOrNull(agent: (a) => a);
  if (agent == null) return const UnifiedSuggestionList.empty();

  ref.watch(agentUpdateStreamProvider(agent.agentId));
  final backfill = ref.watch(inferenceBackfillSuggestionsProvider(taskId));
  final links = ref.watch(taskLinkSuggestionsProvider(taskId));

  final repo = ref.watch(agentRepositoryProvider);
  final ledger = await repo.getProposalLedger(agent.agentId, taskId: taskId);

  final open = <PendingSuggestion>[];
  final seenFingerprints = <String>{};
  final seenDisplayKeys = <String>{};
  for (final cs in ledger.pendingSets) {
    for (var i = 0; i < cs.items.length; i++) {
      final item = cs.items[i];
      if (item.status != ChangeItemStatus.pending) continue;
      final fingerprint = ChangeItem.fingerprint(item);
      // Race-condition dedup: two wakes may have produced sets with the
      // exact same fingerprint before persistence-time dedup kicks in.
      if (!seenFingerprints.add(fingerprint)) continue;
      final displayKey = ChangeItem.displayDuplicateKey(item);
      if (displayKey != null && !seenDisplayKeys.add(displayKey)) continue;
      open.add(
        PendingSuggestion(
          changeSet: cs,
          itemIndex: i,
          item: item,
          fingerprint: fingerprint,
        ),
      );
    }
  }
  open.sort((a, b) => b.changeSet.createdAt.compareTo(a.changeSet.createdAt));
  final visibleOpen = hideSupersededTimeEntryEdits(open);
  final proposedLinkTargets = {
    for (final s in visibleOpen)
      if (s.item.toolName == TaskAgentToolNames.linkTask)
        if (s.item.args['targetTaskId'] case final String target) target,
  };

  // Dedupe the activity strip by fingerprint — the repository ledger
  // deliberately emits one entry per decision event so the LLM prompt
  // can see the full decision history, but the UI should show each
  // unique proposal at most once. `ledger.resolved` is already sorted
  // newest-first, so the first occurrence of each fingerprint is the
  // most recent decision for that proposal.
  final seenActivityFingerprints = <String>{};
  final activity = <LedgerEntry>[];
  for (final entry in ledger.resolved) {
    if (!seenActivityFingerprints.add(entry.fingerprint)) continue;
    activity.add(entry);
  }

  return UnifiedSuggestionList(
    open: [
      ...visibleOpen,
      for (final link in links)
        if (!proposedLinkTargets.contains(link.targetTaskId))
          PendingSuggestion.link(suggestion: link, agentId: agent.agentId),
      for (final candidate in backfill)
        PendingSuggestion.backfill(
          candidate: candidate,
          agentId: agent.agentId,
          taskId: taskId,
        ),
    ],
    activity: activity,
    agentName: agent.displayName,
  );
}

/// Drops every time-entry edit that a newer open one supersedes (see
/// [supersedesTimeEntryEdit]), keeping the order of what remains.
///
/// Persistence retracts a superseded edit at the end of the wake that
/// replaced it; until then — and for edits from two concurrent wakes — this
/// keeps the stale wording from standing beside its replacement. "Newer" is
/// the later change set, or the later item within one set.
List<PendingSuggestion> hideSupersededTimeEntryEdits(
  List<PendingSuggestion> open,
) {
  bool isNewer(PendingSuggestion a, PendingSuggestion b) =>
      a.changeSet.createdAt.isAfter(b.changeSet.createdAt) ||
      (a.changeSet.createdAt == b.changeSet.createdAt &&
          a.itemIndex > b.itemIndex);

  return [
    for (final suggestion in open)
      if (!open.any(
        (other) =>
            isNewer(other, suggestion) &&
            supersedesTimeEntryEdit(other.item, suggestion.item),
      ))
        suggestion,
  ];
}
