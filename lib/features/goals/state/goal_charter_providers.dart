import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/goals/logic/goal_charter.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/providers/update_notifications_providers.dart';
import 'package:lotti/services/db_notification.dart';

/// The charter of the goal coached by `agentId` (ADR 0140), in the order it
/// was written — what the goal page's *About this goal* lists.
///
/// Re-read whenever the goal row is notified. Every charter write names it:
/// a new entry through its link, an edit or a delete through the repository's
/// `linkedId`. Private entries being hidden or shown re-read it too.
final FutureProviderFamily<List<JournalEntry>, String>
goalCharterEntriesProvider = FutureProvider.autoDispose
    .family<List<JournalEntry>, String>((ref, agentId) async {
      final repository = ref.watch(goalRepositoryProvider);
      if (repository == null) return const [];
      final goalId = repository.goalIdForAgent(agentId);
      final subscription = ref
          .read(updateNotificationsProvider)
          .updateStream
          .listen((affectedIds) {
            if (affectedIds.contains(goalId) ||
                affectedIds.contains(privateToggleNotification)) {
              ref.invalidateSelf();
            }
          });
      ref.onDispose(subscription.cancel);
      return repository.charterEntries(agentId);
    }, name: 'goalCharterEntriesProvider');

/// Whether the agent can read the whole charter in one wake — the same
/// selection the wake makes, so the page warns exactly when FACTS cut it.
bool goalCharterFitsBudget(List<JournalEntry> entries) {
  final selection = goalCharterSelection([
    for (final entry in entries) GoalCharterEntry.of(entry),
  ]);
  return selection.omitted == 0 && !selection.truncated;
}
