import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai_consumption/model/consumption_aggregation_models.dart';
import 'package:lotti/features/ai_consumption/state/consumption_providers.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/state/front_chat_thread_provider.dart';
import 'package:lotti/features/front_agent/state/front_inbox_filter.dart';

/// What the open conversation has cost so far: the routing calls of every
/// wake that wrote one of her turns in it, summed from each run's own
/// recorded totals ([agentRunConsumptionTotalsProvider]), never recomputed.
/// Her owners' answers are theirs and count on their own agents.
///
/// Null in the inbox, which gathers every conversation and so is no one
/// conversation's cost — nor a reason to read the totals of every run she
/// ever made. Null until the thread is known; read through `.value`, so a reload keeps
/// the shown total. A run whose totals are still loading is counted once
/// they arrive: the total grows in place rather than blanking on every new
/// turn.
final Provider<ConsumptionTotals?> frontConversationCostProvider =
    Provider.autoDispose<ConsumptionTotals?>((ref) {
      if (ref.watch(frontInboxFilterProvider)) return null;
      final thread = ref.watch(frontChatThreadProvider).value;
      if (thread == null) return null;
      var total = ConsumptionTotals.empty;
      // Every run of the conversation, not only those the window shows.
      for (final runKey in thread.runKeys) {
        final run = ref
            .watch(
              agentRunConsumptionTotalsProvider((
                agentId: frontAgentId,
                runKey: runKey,
              )),
            )
            .value;
        if (run != null) total += run;
      }
      return total;
    }, name: 'frontConversationCostProvider');
