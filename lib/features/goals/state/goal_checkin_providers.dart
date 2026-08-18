import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/goals/logic/goal_timeline_projection.dart';
import 'package:lotti/features/goals/model/goal_timeline_item.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/state/goal_assessment_state.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';

/// The journal id of the goal coached by an agent, or null while the journal
/// stack is unavailable.
///
/// Derived, not looked up, so it resolves synchronously and a surface can
/// address a goal's check-ins before the goal row itself has been written.
final ProviderFamily<String?, String> goalEntryIdProvider = Provider.autoDispose
    .family<String?, String>(
      (ref, agentId) =>
          ref.watch(goalRepositoryProvider)?.goalIdForAgent(agentId),
      name: 'goalEntryIdProvider',
    );

/// The entries linked to a goal — its check-ins.
///
/// Rides the shared linked-entries projection, so a recording added anywhere
/// appears here without this feature owning a query or a refresh path.
final ProviderFamily<List<JournalEntity>, String> goalCheckInEntriesProvider =
    Provider.autoDispose.family<List<JournalEntity>, String>((ref, agentId) {
      final goalId = ref.watch(goalEntryIdProvider(agentId));
      if (goalId == null) return const [];
      return ref.watch(resolvedOutgoingLinkedEntriesProvider(goalId));
    }, name: 'goalCheckInEntriesProvider');

/// Everything the user has said about a goal, newest first: free-form
/// check-ins merged with the standing daily reflections.
final ProviderFamily<List<GoalTimelineItem>, String> goalTimelineItemsProvider =
    Provider.autoDispose.family<List<GoalTimelineItem>, String>((ref, agentId) {
      final health = ref.watch(goalAgentHealthProvider(agentId)).value;
      return goalTimelineItems(
        entries: ref.watch(goalCheckInEntriesProvider(agentId)),
        assessments:
            ref.watch(goalAssessmentHistoryProvider(agentId)).value ?? const [],
        // Reflections are judgements against a spec version, so only those
        // passed on the CURRENT one belong on the rail.
        specVersionId: health?.spec?.id,
      );
    }, name: 'goalTimelineItemsProvider');
