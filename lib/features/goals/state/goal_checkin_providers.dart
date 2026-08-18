import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/state/consumption_providers.dart';
import 'package:lotti/features/goals/logic/goal_timeline_projection.dart';
import 'package:lotti/features/goals/model/goal_timeline_item.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/state/goal_assessment_state.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';

/// Whether the latest durable transcription attempt for `entryId` failed.
///
/// The live inference controller is intentionally short-lived. This lookup is
/// the restart-safe half of the timeline state: failed logical work retains
/// the audio entry as its intended output even though no transcript carrier
/// was produced.
final FutureProviderFamily<bool, String> goalAudioTranscriptionFailedProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, entryId) async {
      final attribution = await ref
          .watch(consumptionRepositoryProvider)
          .getLatestAttributionForArtifact(
            type: AiArtifactType.journalAudio,
            id: entryId,
          );
      return attribution?.workType == AiWorkType.audioTranscription &&
          attribution?.status == AiWorkStatus.failed;
    }, name: 'goalAudioTranscriptionFailedProvider');

/// The journal id of the goal coached by an agent, or null while the journal
/// stack is unavailable.
///
/// Derived, not looked up, so it resolves synchronously. Safe for READS — a
/// goal row that does not exist yet simply has no linked entries — but never
/// use it as a capture target: see [goalCaptureTargetProvider].
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

/// The goal row a new check-in may be linked to, or null when there is none.
///
/// **Capture must go through this, never through [goalEntryIdProvider].**
/// `createDbEntity` only creates the link when the parent id actually
/// resolves, so linking to a derived id whose row has not been written yet
/// produces an entry that saves successfully, is silently unlinked, and never
/// appears on the timeline — with no later repair, because the mirror writes
/// the goal and knows nothing about the orphan.
///
/// Repairs as it checks: a goal whose mirror has not run yet (freshly synced,
/// or a write that failed) gets one here rather than refusing the user's
/// recording.
final FutureProviderFamily<String?, String> goalCaptureTargetProvider =
    FutureProvider.autoDispose.family<String?, String>((ref, agentId) async {
      final repository = ref.watch(goalRepositoryProvider);
      if (repository == null) return null;
      final existing = await repository.getGoalForAgent(agentId);
      if (existing != null) return existing.meta.id;
      final mirrored = await ref
          .watch(goalMirrorServiceProvider)
          ?.mirrorHead(agentId);
      return mirrored?.meta.id;
    }, name: 'goalCaptureTargetProvider');
