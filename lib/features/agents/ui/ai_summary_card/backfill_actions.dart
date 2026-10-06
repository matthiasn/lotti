import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/state/unified_suggestion_providers.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/ai/backfill/inference_backfill_providers.dart';
import 'package:lotti/features/ai/backfill/inference_backfill_queue.dart';

/// Accepts a backfill suggestion: queues the inference it offers.
///
/// Succeeds as soon as the job is queued, which is what the row needs to
/// leave the list. The run itself is the queue's business — it reports
/// through the entry's own inference status like any other run, and a run
/// that fails puts the suggestion back on the next scan.
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
