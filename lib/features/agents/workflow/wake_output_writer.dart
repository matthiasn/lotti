import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_report_provenance.dart';
import 'package:lotti/features/agents/model/proposal_ledger.dart';
import 'package:lotti/features/agents/service/suggestion_retraction_service.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/util/text_utils.dart';
import 'package:lotti/features/agents/workflow/change_set_builder.dart';
import 'package:lotti/features/agents/workflow/task_agent_strategy.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/service/ai_attribution_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:uuid/uuid.dart';

/// Report details captured inside the wake transaction and returned to the
/// caller for post-commit embedding. Carries the freshly written report's id
/// and content, the task it belongs to, and the report this one supersedes (if
/// any) so the embedding pipeline can replace the prior vector.
typedef WakeReportToEmbed = ({
  String reportId,
  String reportContent,
  String taskId,
  String? previousReportId,
});

/// Transactional persistence of a wake cycle's outputs (thought, report,
/// observations, staged retractions, deferred change set, agent state and the
/// wake-completed milestone).
///
/// Extracted from the Task Agent workflow into a standalone, independently
/// testable collaborator. It depends on an [AgentSyncService] for all
/// sync-aware writes, an [AgentRepository] for the single report-head read,
/// and the registered [UpdateNotifications] service for a post-commit UI
/// refresh when one is available.
/// Everything else a wake produced — the strategy, report fields,
/// observations, retraction/change-set collaborators, the proposal ledger,
/// the agent state, and the run identity — is passed in as data to [persist].
class WakeOutputWriter {
  /// Creates a writer bound to the sync write service and agent repository.
  ///
  /// [uuid] is injectable so tests can pin generated ids; production passes the
  /// default `const Uuid()`.
  WakeOutputWriter({
    required AgentSyncService syncService,
    required AgentRepository agentRepository,
    Uuid uuid = const Uuid(),
  }) : _sync = syncService,
       _repo = agentRepository,
       _idGen = uuid;

  final AgentSyncService _sync;
  final AgentRepository _repo;
  final Uuid _idGen;

  /// Persists all of a single wake's outputs atomically.
  ///
  /// Runs inside [AgentSyncService.runInTransaction] so the agent state
  /// revision is only bumped if every output (thought, report, observations,
  /// retractions, deferred change set, milestone) is written successfully.
  ///
  /// Returns the report details to embed post-commit, or `null` if no report
  /// was written this wake (an empty [reportContent]).
  Future<WakeReportToEmbed?> persist({
    required TaskAgentStrategy strategy,
    required String reportContent,
    required String? reportTldr,
    required String? reportOneLiner,
    required List<ObservationRecord> observations,
    required SuggestionRetractionService retractionService,
    required ChangeSetBuilder changeSetBuilder,
    required ProposalLedger ledger,
    required List<ChangeSetEntity> pendingSets,
    required AgentStateEntity state,
    required String taskId,
    required String agentId,
    required String threadId,
    required String runKey,
    required DateTime now,
    ReportInferenceProvenance? reportProvenance,
  }) async {
    // Collects report details inside the transaction for post-commit
    // embedding. Declared outside so it survives the transaction scope.
    WakeReportToEmbed? reportToEmbed;

    final sanitizedContent = sanitizeAgentReportText(reportContent);
    final sanitizedTldr = reportTldr == null
        ? null
        : sanitizeAgentReportText(reportTldr);
    final sanitizedOneLiner = reportOneLiner == null
        ? null
        : sanitizeAgentReportText(reportOneLiner);
    final reportId = sanitizedContent.isEmpty ? null : _idGen.v4();
    AiWorkAttribution? attributionEnvelope;
    if (reportId != null && getIt.isRegistered<AiAttributionService>()) {
      attributionEnvelope = await getIt<AiAttributionService>()
          .prepareCompletion(
            attributionId: agentWakeAttributionId(runKey),
            outputs: [
              AiArtifactReference(
                type: AiArtifactType.agentReport,
                id: reportId,
              ),
            ],
          );
    }

    final persistence = _sync.runInTransaction(() async {
      // 8. Persist the final assistant response as a thought message.
      final thoughtText = strategy.finalResponse;
      if (thoughtText != null) {
        final thoughtPayloadId = _idGen.v4();
        await _sync.upsertEntity(
          AgentDomainEntity.agentMessagePayload(
            id: thoughtPayloadId,
            agentId: agentId,
            createdAt: now,
            vectorClock: null,
            content: <String, Object?>{'text': thoughtText},
          ),
        );
        await _sync.upsertEntity(
          AgentDomainEntity.agentMessage(
            id: _idGen.v4(),
            agentId: agentId,
            threadId: threadId,
            kind: AgentMessageKind.thought,
            createdAt: now,
            vectorClock: null,
            contentEntryId: thoughtPayloadId,
            metadata: AgentMessageMetadata(runKey: runKey),
          ),
        );
      }

      // 9. Extract and persist updated report (from update_report tool call).
      // Strip any internal entity ids the model echoed into the user-facing
      // report — the task context hands it each checklist item's real id (for
      // tool calls), and weaker models copy those into the prose. Applies to
      // every wake regardless of the agent's baked directive, so already
      // created agents are cleaned too.
      if (sanitizedContent.isNotEmpty) {
        final persistedReportId = reportId!;

        await _sync.upsertEntity(
          AgentDomainEntity.agentReport(
            id: persistedReportId,
            agentId: agentId,
            scope: AgentReportScopes.current,
            createdAt: now,
            vectorClock: null,
            content: sanitizedContent,
            tldr: sanitizedTldr,
            oneLiner: sanitizedOneLiner,
            provenance: <String, Object?>{
              ...?reportProvenance?.toReportMap(),
              if (attributionEnvelope != null)
                aiAttributionProvenanceKey: attributionEnvelope.toJson(),
            },
            threadId: threadId,
          ),
        );

        // Update the report head pointer.
        final existingHead = await _repo.getReportHead(
          agentId,
          AgentReportScopes.current,
        );
        final headId = existingHead?.id ?? _idGen.v4();

        await _sync.upsertEntity(
          AgentDomainEntity.agentReportHead(
            id: headId,
            agentId: agentId,
            scope: AgentReportScopes.current,
            reportId: persistedReportId,
            updatedAt: now,
            vectorClock: null,
          ),
        );

        // Capture report details for post-transaction embedding. Embeds the
        // sanitized text so the vector matches what the user actually reads.
        reportToEmbed = (
          reportId: persistedReportId,
          reportContent: sanitizedContent,
          taskId: taskId,
          previousReportId: existingHead?.reportId,
        );
      }

      // 10. Persist new observation notes (agentJournal entries).
      for (final observation in observations) {
        final payloadId = _idGen.v4();
        await _sync.upsertEntity(
          AgentDomainEntity.agentMessagePayload(
            id: payloadId,
            agentId: agentId,
            createdAt: now,
            vectorClock: null,
            content: <String, Object?>{
              'text': observation.text,
              'priority': observation.priority.name,
              'category': observation.category.name,
            },
          ),
        );

        await _sync.upsertEntity(
          AgentDomainEntity.agentMessage(
            id: _idGen.v4(),
            agentId: agentId,
            threadId: threadId,
            kind: AgentMessageKind.observation,
            createdAt: now,
            vectorClock: null,
            contentEntryId: payloadId,
            metadata: AgentMessageMetadata(runKey: runKey),
          ),
        );
      }

      // 10a. Apply any retractions the agent staged during the conversation.
      // Deferred to here so the suggestion list never reads empty: proposals
      // flush at each turn boundary during the conversation, so by the time a
      // retraction lands its replacement is already on screen. Persisting
      // retractions mid-conversation (their original behavior) emptied the
      // list for the seconds until the proposals arrived. Running before the
      // build below also lets the final flush's dedup see the freshly
      // retracted statuses — which is what gives an item suppressed by an
      // earlier flush its second chance.
      //
      // Churn guard: weaker models routinely retract an open proposal AND
      // re-propose an identical one in the same wake. That retract-then-re-add
      // makes a stable suggestion vanish and reappear under the user's finger
      // (and, when the user has just confirmed a sibling, looks like accepting
      // one wipes the rest). Suppress retractions of anything being
      // re-proposed this wake; the matching new proposal is then dropped by
      // the builder's dedup against the still-open original, leaving it
      // untouched.
      await retractionService.applyStaged(
        strategy.extractStagedRetractions(),
        skipFingerprints: changeSetBuilder.proposedFingerprints,
      );

      // 10b. Final flush of the deferred change set. Turn-boundary flushes
      // during the conversation have usually written most of these items
      // already; this call picks up whatever the last turn staged, and is a
      // no-op when the builder has nothing new. Pass the full pending sets so
      // a builder that never flushed can still merge into an existing set
      // rather than creating a duplicate entity.
      //
      // Reuse the proposal ledger we already fetched at step 5 for the sticky
      // rejection keys — avoids a second round-trip for the same data.
      await changeSetBuilder.build(
        _sync,
        existingPendingSets: pendingSets,
        rejectedFingerprints: ledger.rejectedFingerprints,
        rejectedDisplayKeys: ledger.rejectedDisplayKeys,
      );

      // 11. Persist state.
      final hostId = await _sync.localHost();
      await _sync.upsertEntity(
        state.copyWith(
          lastWakeAt: now,
          updatedAt: now,
          consecutiveFailureCount: 0,
          wakeCounter: state.wakeCounter.increment(hostId),
        ),
      );

      // 12. Event-source the `lastWakeAt` watermark: emit a milestone marker
      // whose createdAt the projection folds as the watermark (PR 4, B2). The
      // cached row above stays the read source until the cutover (B6).
      await _sync.appendMilestone(
        agentId: agentId,
        milestone: AgentMilestone.wakeCompleted,
        createdAt: now,
        threadId: threadId,
        runKey: runKey,
      );
    });
    try {
      await persistence;
    } catch (error, stackTrace) {
      // Outbox flushing happens after the database transaction commits and
      // can still surface an error. Confirm the report is durable before
      // refreshing the UI, while preserving the original sync failure.
      if (reportId != null && await _reportWasCommitted(reportId: reportId)) {
        _notifyReportPublished(agentId: agentId, taskId: taskId);
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
    if (reportToEmbed != null) {
      _notifyReportPublished(agentId: agentId, taskId: taskId);
    }
    if (reportToEmbed != null && attributionEnvelope != null) {
      await getIt<AiAttributionService>().finalize(attributionEnvelope);
    }
    return reportToEmbed;
  }

  Future<bool> _reportWasCommitted({required String reportId}) async {
    try {
      return await _repo.getEntity(reportId) is AgentReportEntity;
    } catch (_) {
      return false;
    }
  }

  void _notifyReportPublished({
    required String agentId,
    required String taskId,
  }) {
    if (!getIt.isRegistered<UpdateNotifications>()) return;
    getIt<UpdateNotifications>().notifyUiOnly({
      agentId,
      taskId,
      agentNotification,
    });
  }
}
