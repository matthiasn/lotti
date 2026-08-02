import 'package:clock/clock.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart'
    show AgentTemplateKind, WakeReason;
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/service/agent_service.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:uuid/uuid.dart';

/// Event-agent-specific lifecycle management.
///
/// Mirrors `ProjectAgentService`'s lean service skeleton (no checklist /
/// time-entry / attention-claim machinery) but manages event-scoped agents and
/// — like `TaskAgentService` — holds the first run behind a **content gate**
/// (`awaitContent`). An event agent attaches on creation but does not narrate
/// until the event has real content (a photo/note), so a bare-title event does
/// not burn an inference run.
///
/// Rating and cover selection are **human-only**; this service never sets them.
class EventAgentService {
  EventAgentService({
    required this.agentService,
    required this.repository,
    required this.orchestrator,
    required this.syncService,
    this.domainLogger,
    this.onPersistedStateChanged,
  });

  final AgentService agentService;
  final AgentRepository repository;
  final WakeOrchestrator orchestrator;

  /// Sync-aware write service. All entity/link writes go through this so
  /// they are automatically enqueued for cross-device sync.
  final AgentSyncService syncService;

  /// Optional domain logger for structured, PII-safe logging.
  final DomainLogger? domainLogger;
  final void Function(String agentId)? onPersistedStateChanged;

  static const _uuid = Uuid();
  static const String _agentKind = AgentKinds.eventAgent;

  /// Create a new Event Agent for [eventId].
  ///
  /// Steps:
  /// 1. Create the agent via [AgentService.createAgent] with kind
  ///    `'event_agent'`.
  /// 2. Update the agent's state with `activeEventId = eventId` and the
  ///    `awaitingContent` flag (held until the event has real content).
  /// 3. Create an [AgentEventLink] from agentId → eventId.
  /// 4. Create a `templateAssignment` link from the template → agent.
  /// 5. Mirror `awaitingContent` in the orchestrator, register the direct-edit
  ///    subscription, and enqueue a creation wake.
  ///
  /// Returns the created [AgentIdentityEntity].
  ///
  /// Throws [StateError] if an Event Agent already exists for [eventId], or if
  /// [templateId] is not an active event-agent template.
  Future<AgentIdentityEntity> createEventAgent({
    required String eventId,
    required String templateId,
    required Set<String> allowedCategoryIds,
    String? displayName,
    String? profileId,
    bool awaitContent = true,
  }) async {
    final identity = await syncService.runInTransaction(() async {
      // Definitive duplicate check inside the transaction to prevent
      // concurrent createEventAgent calls from both committing.
      final linksForEvent = await repository.getLinksTo(
        eventId,
        type: AgentLinkTypes.agentEvent,
      );
      if (linksForEvent.isNotEmpty) {
        final primaryLink = linksForEvent.selectPrimary();
        throw StateError(
          'An event agent already exists for event $eventId '
          '(agent ${primaryLink.fromId})',
        );
      }

      // Validate the template.
      final templateEntity = await repository.getEntity(templateId);
      if (templateEntity is! AgentTemplateEntity ||
          templateEntity.deletedAt != null ||
          templateEntity.kind != AgentTemplateKind.eventAgent) {
        throw StateError(
          'Template $templateId is not an active event-agent template.',
        );
      }

      final identity = await agentService.createAgent(
        kind: _agentKind,
        displayName: displayName ?? 'Event Agent',
        config: AgentConfig(profileId: profileId),
        allowedCategoryIds: allowedCategoryIds,
      );

      // Update state with activeEventId and the content-gate flag.
      final state = await repository.getAgentState(identity.agentId);
      if (state == null) {
        throw StateError(
          'Agent ${identity.agentId} was just created but has no state entity',
        );
      }

      final now = clock.now();
      final updatedState = state.copyWith(
        slots: state.slots.copyWith(activeEventId: eventId),
        awaitingContent: awaitContent,
        updatedAt: now,
      );
      await syncService.upsertEntity(updatedState);

      // Create agent_event link: agent → event.
      final eventLinkId = _uuid.v4();
      await syncService.upsertLink(
        AgentLink.agentEvent(
          id: eventLinkId,
          fromId: identity.agentId,
          toId: eventId,
          createdAt: now,
          updatedAt: now,
          vectorClock: null,
        ),
      );

      // Create template_assignment link.
      final templateLinkId = _uuid.v4();
      await syncService.upsertLink(
        AgentLink.templateAssignment(
          id: templateLinkId,
          fromId: templateId,
          toId: identity.agentId,
          createdAt: now,
          updatedAt: now,
          vectorClock: null,
        ),
      );

      return identity;
    });

    onPersistedStateChanged
      ?..call(identity.agentId)
      // `eventAgentProvider` refreshes on the *event* id, and nothing in the
      // agent write path emits it — identity, state and links all go through
      // `AgentSyncService`, which does not notify. Without this the agent
      // stays invisible until something unrelated happens to ping the event,
      // in practice the creation wake completing an inference round-trip
      // later. Both ids coalesce into one `notifyUiOnly` batch.
      ..call(eventId);

    // Mirror the persisted awaitingContent flag in the orchestrator so the
    // content gate suppresses the creation wake until the event has content.
    orchestrator
      ..setAwaitingContent(identity.agentId, awaiting: awaitContent)
      ..enqueueManualWake(
        agentId: identity.agentId,
        reason: WakeReason.creation.name,
        triggerTokens: {eventId},
      );

    _registerEventSubscription(identity.agentId, eventId);

    domainLogger?.log(
      LogDomain.agentRuntime,
      'created event agent ${DomainLogger.sanitizeId(identity.agentId)} '
      'for event ${DomainLogger.sanitizeId(eventId)}'
      '${awaitContent ? ' (awaiting content)' : ''}',
      subDomain: 'lifecycle',
    );

    return identity;
  }

  /// Find the Event Agent for [eventId], or `null` if none exists.
  ///
  /// Looks up `AgentEventLink`s pointing to [eventId] and resolves the agent
  /// identity from the link's `fromId`.
  Future<AgentIdentityEntity?> getEventAgentForEvent(String eventId) async {
    final links = await repository.getLinksTo(
      eventId,
      type: AgentLinkTypes.agentEvent,
    );
    if (links.isEmpty) return null;

    final agentId = links.selectPrimary().fromId;
    return agentService.getAgent(agentId);
  }

  /// Trigger a manual re-analysis wake for [agentId].
  void triggerReanalysis(String agentId) {
    domainLogger?.log(
      LogDomain.agentRuntime,
      'manual reanalysis triggered for ${DomainLogger.sanitizeId(agentId)}',
      subDomain: 'lifecycle',
    );
    orchestrator.enqueueManualWake(
      agentId: agentId,
      reason: WakeReason.reanalysis.name,
    );
  }

  void _registerEventSubscription(String agentId, String eventId) {
    orchestrator.addSubscription(
      AgentSubscription(
        id: '${agentId}_event_direct_$eventId',
        agentId: agentId,
        // Match the bare event id, exactly like the task agent matches its bare
        // task id. `JournalEntity.affectedIds` always includes the entity id,
        // and linking a photo/note to the event emits the event id via the
        // link notification — so this wakes the agent on direct event edits AND
        // on content arrival (which clears the awaiting-content gate). Events
        // wake on direct content like tasks, not on aggregated activity like
        // projects, so they do not use a dedicated `*_ENTITY_UPDATE:` channel.
        matchEntityIds: {eventId},
      ),
    );
  }
}
