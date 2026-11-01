import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/state/unified_suggestion_providers.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/tools/task_link_handler.dart';
import 'package:lotti/features/ai/backfill/inference_backfill_providers.dart';
import 'package:lotti/features/ai/backfill/inference_backfill_queue.dart';
import 'package:lotti/features/ai/link_suggestions/task_link_suggestion_providers.dart';
import 'package:lotti/providers/service_providers.dart';

/// Accepts a mechanical suggestion ([PendingSuggestion.isMechanical]), or
/// returns null for an agent proposal, which `ChangeSetConfirmationService`
/// decides.
Future<ToolExecutionResult>? confirmMechanicalSuggestion(
  WidgetRef ref,
  PendingSuggestion suggestion,
) {
  if (suggestion.backfill != null) {
    return Future.value(confirmBackfillSuggestion(ref, suggestion));
  }
  if (suggestion.link != null) return confirmLinkSuggestion(ref, suggestion);
  return null;
}

/// Dismisses a mechanical suggestion, or returns null for an agent proposal.
Future<bool>? dismissMechanicalSuggestion(
  WidgetRef ref,
  PendingSuggestion suggestion,
) {
  if (suggestion.backfill != null) {
    return dismissBackfillSuggestion(ref, suggestion);
  }
  if (suggestion.link != null) return dismissLinkSuggestion(ref, suggestion);
  return null;
}

/// Accepts a backfill suggestion: queues the inference it offers.
///
/// Succeeds as soon as the job is queued, which is what the row needs to
/// leave the list. The run itself is the queue's business — it reports
/// through the entry's own inference status like any other run, and a run
/// that fails puts the suggestion back as soon as the queue lets go of it,
/// since the entry still lacks what it offered.
ToolExecutionResult confirmBackfillSuggestion(
  WidgetRef ref,
  PendingSuggestion suggestion,
) {
  ref
      .read(inferenceBackfillQueueProvider.notifier)
      .enqueue(
        taskId: suggestion.changeSet.taskId,
        candidate: suggestion.backfill!,
      );
  return const ToolExecutionResult(success: true, output: 'queued');
}

/// Rejects a backfill suggestion: hides it on this device.
Future<bool> dismissBackfillSuggestion(
  WidgetRef ref,
  PendingSuggestion suggestion,
) async {
  await ref
      .read(inferenceBackfillDismissalsProvider.notifier)
      .dismiss(suggestion.backfill!);
  return true;
}

/// Accepts a link suggestion: writes the link, and only now.
///
/// It goes through [TaskLinkHandler], the handler a confirmed agent
/// `link_task` proposal is applied by, which checks again that the target is
/// a live task, treats a link the pair already holds as done, and refuses a
/// `blocks` link that would close a cycle. On success the pair is hidden at
/// once ([TaskLinkSuggestionAccepted]); the link itself keeps it away from
/// the next scan.
Future<ToolExecutionResult> confirmLinkSuggestion(
  WidgetRef ref,
  PendingSuggestion suggestion,
) async {
  final link = suggestion.link!;
  final result = await TaskLinkHandler(
    persistenceLogic: ref.read(persistenceLogicProvider),
    journalDb: ref.read(journalDbProvider),
    domainLogger: ref.read(domainLoggerProvider),
  ).handle(link.sourceTaskId, suggestion.item.args);
  if (result.success) {
    ref.read(taskLinkSuggestionAcceptedProvider.notifier).accept(link);
  }
  return result;
}

/// Rejects a link suggestion: hides the pair on this device, writing
/// nothing to the journal.
Future<bool> dismissLinkSuggestion(
  WidgetRef ref,
  PendingSuggestion suggestion,
) async {
  await ref
      .read(taskLinkSuggestionDismissalsProvider.notifier)
      .dismiss(suggestion.link!);
  return true;
}
