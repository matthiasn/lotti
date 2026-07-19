import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_enums.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_event.dart';
import 'package:lotti/features/ai_consumption/model/consumption_aggregation_models.dart';
import 'package:lotti/features/ai_consumption/service/ai_attribution_identity_resolver.dart';
import 'package:lotti/features/ai_consumption/service/ai_attribution_service.dart';
import 'package:lotti/features/ai_consumption/service/ai_interaction_capture.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mocks.dart';

/// Shared test bench for funnels that use the concrete pre-call capture
/// boundary with mocked persistence and identity services.
class AiInteractionCaptureTestBench {
  AiInteractionCaptureTestBench._(
    this._pendingById, {
    required this.service,
    required this.identity,
    required this.capture,
  });

  factory AiInteractionCaptureTestBench.create() {
    final service = MockAiAttributionService();
    final identity = MockAiAttributionIdentityResolver();
    const human = AiActorSnapshot(
      type: AiActorType.human,
      id: 'human-1',
      displayName: 'Test User',
      humanPrincipalId: 'human-1',
    );
    const executor = AiExecutorSnapshot(
      hostId: 'host-1',
      displayName: 'Test Host',
    );
    final pendingById = <String, AiAttributionPendingSession>{};

    when(identity.humanInitiator).thenAnswer((_) async => human);
    when(identity.executor).thenAnswer((_) async => executor);
    when(
      () => identity.automationInitiator(
        id: any(named: 'id'),
        displayName: any(named: 'displayName'),
      ),
    ).thenAnswer((invocation) async {
      return AiActorSnapshot(
        type: AiActorType.automation,
        id: invocation.namedArguments[#id] as String,
        displayName: invocation.namedArguments[#displayName] as String,
        humanPrincipalId: human.id,
      );
    });
    when(
      () => identity.agentInitiator(
        id: any(named: 'id'),
        displayName: any(named: 'displayName'),
      ),
    ).thenAnswer((invocation) async {
      return AiActorSnapshot(
        type: AiActorType.agent,
        id: invocation.namedArguments[#id] as String,
        displayName: invocation.namedArguments[#displayName] as String,
        humanPrincipalId: human.id,
      );
    });
    when(() => service.begin(any())).thenAnswer((invocation) async {
      final command =
          invocation.positionalArguments.first as AiAttributionStart;
      final id =
          command.attributionId ?? 'attribution-${pendingById.length + 1}';
      final now = DateTime.utc(2024, 3, 15, 10, 30);
      final pending = AiAttributionPendingSession(
        id: id,
        attributionId: id,
        workType: command.workType,
        initiator: command.initiator,
        trigger: command.trigger,
        executor: command.executor,
        privacyClassification: command.privacyClassification,
        phase: AiAttributionPendingPhase.prepared,
        startedAt: now,
        lastUpdatedAt: now,
        intendedOutputs: command.intendedOutputs,
        sourceArtifacts: command.sources,
        contextArtifacts: command.context,
        taskId: command.taskId,
        categoryId: command.categoryId,
      );
      pendingById[id] = pending;
      return pending;
    });
    when(
      () => service.recordInteraction(
        attributionId: any(named: 'attributionId'),
        event: any(named: 'event'),
      ),
    ).thenAnswer((invocation) async {
      final attributionId = invocation.namedArguments[#attributionId] as String;
      final event = invocation.namedArguments[#event] as AiConsumptionEvent;
      final pending = pendingById[attributionId]!;
      final updated = pending.copyWith(
        phase: AiAttributionPendingPhase.evidencePublished,
        lastUpdatedAt: event.completedAt ?? event.createdAt,
        interactionIds: [...pending.interactionIds, event.id],
      );
      pendingById[attributionId] = updated;
      return AiAttributedInteractionResult(
        session: updated,
        event: event.copyWith(attributionId: attributionId),
        published: true,
      );
    });
    when(
      () => service.prepareCompletion(
        attributionId: any(named: 'attributionId'),
        outputs: any(named: 'outputs'),
        status: any(named: 'status'),
        errorCode: any(named: 'errorCode'),
        errorSummary: any(named: 'errorSummary'),
      ),
    ).thenAnswer((invocation) async {
      final attributionId = invocation.namedArguments[#attributionId] as String;
      final outputs =
          invocation.namedArguments[#outputs] as List<AiArtifactReference>;
      final status = invocation.namedArguments[#status] as AiWorkStatus;
      final pending = pendingById[attributionId]!;
      final effectiveOutputs = outputs.isEmpty
          ? pending.intendedOutputs
          : outputs;
      return AiTerminalAttributionEnvelope(
        id: 'terminal-$attributionId',
        attribution: AiWorkAttribution(
          id: attributionId,
          workType: pending.workType,
          status: status,
          initiator: pending.initiator,
          trigger: pending.trigger,
          executor: pending.executor,
          privacyClassification: pending.privacyClassification,
          startedAt: pending.startedAt,
          completedAt: DateTime.utc(2024, 3, 15, 10, 31),
          vectorClock: null,
          links: [
            for (final output in effectiveOutputs)
              AiAttributionLink(
                id: 'link-$attributionId-${output.id}',
                attributionId: attributionId,
                role: AiAttributionLinkRole.output,
                artifact: output,
              ),
          ],
          primaryOutput: effectiveOutputs.isEmpty
              ? null
              : effectiveOutputs.first,
          taskId: pending.taskId,
          categoryId: pending.categoryId,
          errorCode: invocation.namedArguments[#errorCode] as String?,
          errorSummary: invocation.namedArguments[#errorSummary] as String?,
        ),
      );
    });
    when(() => service.finalize(any())).thenAnswer((_) async {});

    return AiInteractionCaptureTestBench._(
      pendingById,
      service: service,
      identity: identity,
      capture: AiInteractionCapture(service, identity),
    );
  }

  final MockAiAttributionService service;
  final MockAiAttributionIdentityResolver identity;
  final AiInteractionCapture capture;
  final Map<String, AiAttributionPendingSession> _pendingById;

  /// Seeds the deterministic owner normally created inside a real agent
  /// conversation. Workflow tests use mocked conversation repositories, so
  /// they need this pending state before exercising carrier publication.
  void seedAgentWake({
    required String wakeRunKey,
    required String agentId,
    String? taskId,
    String? categoryId,
  }) {
    final attributionId = agentWakeAttributionId(wakeRunKey);
    final now = DateTime.utc(2024, 3, 15, 10, 30);
    _pendingById[attributionId] = AiAttributionPendingSession(
      id: attributionId,
      attributionId: attributionId,
      workType: AiWorkType.agentReport,
      initiator: AiActorSnapshot(
        type: AiActorType.agent,
        id: agentId,
        displayName: agentId,
        humanPrincipalId: 'human-1',
      ),
      trigger: AiTriggerSnapshot(
        type: AiTriggerType.agentTool,
        agentId: agentId,
        wakeRunKey: wakeRunKey,
      ),
      executor: const AiExecutorSnapshot(
        hostId: 'host-1',
        displayName: 'Test Host',
      ),
      privacyClassification: AiPrivacyClassification.mixed,
      phase: AiAttributionPendingPhase.evidencePublished,
      startedAt: now,
      lastUpdatedAt: now,
      intendedOutputs: const [],
      interactionIds: const ['interaction-1'],
      taskId: taskId,
      categoryId: categoryId,
    );
  }

  void register() {
    if (getIt.isRegistered<AiAttributionService>()) {
      getIt.unregister<AiAttributionService>();
    }
    if (getIt.isRegistered<AiInteractionCapture>()) {
      getIt.unregister<AiInteractionCapture>();
    }
    if (getIt.isRegistered<AiAttributionIdentityResolver>()) {
      getIt.unregister<AiAttributionIdentityResolver>();
    }
    getIt
      ..registerSingleton<AiAttributionService>(service)
      ..registerSingleton<AiAttributionIdentityResolver>(identity)
      ..registerSingleton<AiInteractionCapture>(capture);
  }

  /// Removes the capture services registered by [register].
  void unregister() {
    if (getIt.isRegistered<AiInteractionCapture>()) {
      getIt.unregister<AiInteractionCapture>();
    }
    if (getIt.isRegistered<AiAttributionService>()) {
      getIt.unregister<AiAttributionService>();
    }
    if (getIt.isRegistered<AiAttributionIdentityResolver>()) {
      getIt.unregister<AiAttributionIdentityResolver>();
    }
  }
}

/// Deterministic factory for [AiConsumptionEvent]s in tests. Every field is
/// overridable; the defaults model a Melious agent turn with full impact data
/// so tests only pass the parts that matter to them.
AiConsumptionEvent makeConsumptionEvent({
  String id = 'evt-1',
  DateTime? createdAt,
  InferenceProviderType providerType = InferenceProviderType.melious,
  AiConsumptionResponseType responseType = AiConsumptionResponseType.agentTurn,
  VectorClock? vectorClock,
  String? attributionId,
  String? parentId,
  String? taskId = 'task-1',
  String? categoryId = 'cat-1',
  String? entryId,
  String? agentId,
  String? wakeRunKey,
  String? threadId,
  int? turnIndex,
  String? promptId,
  String? skillId,
  String? configId,
  String? modelId = 'glm-5.2',
  String? providerModelId,
  int? durationMs = 1200,
  int? inputTokens = 1000,
  int? outputTokens = 500,
  int? cachedInputTokens,
  int? thoughtsTokens,
  int? totalTokens = 1500,
  double? credits = 0.002,
  double? energyKwh = 0.0003,
  double? carbonGCo2 = 0.12,
  double? waterLiters = 0.01,
  double? renewablePercent = 100,
  double? pue = 1.1,
  String? dataCenter = 'FI',
  String? upstreamProviderId,
}) {
  return AiConsumptionEvent(
    id: id,
    createdAt: createdAt ?? DateTime(2026, 3, 15, 12),
    providerType: providerType,
    responseType: responseType,
    vectorClock: vectorClock,
    attributionId: attributionId,
    parentId: parentId,
    taskId: taskId,
    categoryId: categoryId,
    entryId: entryId,
    agentId: agentId,
    wakeRunKey: wakeRunKey,
    threadId: threadId,
    turnIndex: turnIndex,
    promptId: promptId,
    skillId: skillId,
    configId: configId,
    modelId: modelId,
    providerModelId: providerModelId,
    durationMs: durationMs,
    inputTokens: inputTokens,
    outputTokens: outputTokens,
    cachedInputTokens: cachedInputTokens,
    thoughtsTokens: thoughtsTokens,
    totalTokens: totalTokens,
    credits: credits,
    energyKwh: energyKwh,
    carbonGCo2: carbonGCo2,
    waterLiters: waterLiters,
    renewablePercent: renewablePercent,
    pue: pue,
    dataCenter: dataCenter,
    upstreamProviderId: upstreamProviderId,
  );
}

AiActorSnapshot makeAiActor({
  AiActorType type = AiActorType.human,
  String id = 'user-1',
  String displayName = 'Ada',
}) => AiActorSnapshot(
  type: type,
  id: id,
  displayName: displayName,
  humanPrincipalId: type == AiActorType.human ? id : null,
);

AiExecutorSnapshot makeAiExecutor({
  String hostId = 'host-a',
  String displayName = 'Ada’s Mac',
}) => AiExecutorSnapshot(hostId: hostId, displayName: displayName);

AiArtifactReference makeAiArtifact({
  AiArtifactType type = AiArtifactType.journalAiResponse,
  String id = 'output-1',
  String? subId,
}) => AiArtifactReference(type: type, id: id, subId: subId);

AiAttributionStart makeAiAttributionStart({
  AiWorkType workType = AiWorkType.codingPrompt,
  List<AiArtifactReference>? intendedOutputs,
  List<AiArtifactReference> sources = const [],
  List<AiArtifactReference> context = const [],
}) => AiAttributionStart(
  workType: workType,
  initiator: makeAiActor(),
  trigger: const AiTriggerSnapshot(
    type: AiTriggerType.manual,
    skillId: 'skill-1',
  ),
  executor: makeAiExecutor(),
  privacyClassification: AiPrivacyClassification.standard,
  intendedOutputs: intendedOutputs ?? [makeAiArtifact()],
  sources: sources,
  context: context,
  taskId: 'task-1',
  categoryId: 'cat-1',
);

AiTerminalAttributionEnvelope makeAiTerminalEnvelope({
  String attributionId = 'attribution-1',
  AiArtifactReference? output,
}) {
  final artifact = output ?? makeAiArtifact();
  return AiTerminalAttributionEnvelope(
    id: 'terminal-$attributionId',
    attribution: AiWorkAttribution(
      id: attributionId,
      workType: AiWorkType.codingPrompt,
      status: AiWorkStatus.succeeded,
      initiator: makeAiActor(),
      trigger: const AiTriggerSnapshot(type: AiTriggerType.manual),
      executor: makeAiExecutor(),
      privacyClassification: AiPrivacyClassification.standard,
      startedAt: DateTime(2026, 3, 15, 12),
      completedAt: DateTime(2026, 3, 15, 12, 0, 1),
      vectorClock: const VectorClock({'host-a': 1}),
      links: [
        AiAttributionLink(
          id: 'link-$attributionId',
          attributionId: attributionId,
          role: AiAttributionLinkRole.output,
          artifact: artifact,
        ),
      ],
      primaryOutput: artifact,
    ),
  );
}

/// Deterministic factory for [ConsumptionTotals] fixtures. Defaults to the
/// all-zero totals so tests only set the fields they assert on.
ConsumptionTotals makeConsumptionTotals({
  int callCount = 0,
  int impactCallCount = 0,
  int inputTokens = 0,
  int outputTokens = 0,
  int cachedInputTokens = 0,
  int thoughtsTokens = 0,
  int totalTokens = 0,
  double credits = 0,
  double energyKwh = 0,
  double carbonGCo2 = 0,
  double waterLiters = 0,
}) {
  return ConsumptionTotals(
    callCount: callCount,
    impactCallCount: impactCallCount,
    inputTokens: inputTokens,
    outputTokens: outputTokens,
    cachedInputTokens: cachedInputTokens,
    thoughtsTokens: thoughtsTokens,
    totalTokens: totalTokens,
    credits: credits,
    energyKwh: energyKwh,
    carbonGCo2: carbonGCo2,
    waterLiters: waterLiters,
  );
}

/// Deterministic factory for [ConsumptionMetricRow] fixtures — one call with
/// binary-exact double defaults so summed cells compare exactly.
ConsumptionMetricRow makeMetricRow({
  DateTime? createdAt,
  String? categoryId = 'work',
  int callCount = 1,
  int totalTokens = 100,
  double credits = 0.25,
  double energyKwh = 0,
  double carbonGCo2 = 0,
  String? modelId,
  String? providerModelId,
  String? dataCenter,
  double? renewablePercent,
}) {
  return ConsumptionMetricRow(
    createdAt: createdAt ?? DateTime(2026, 6, 7, 9),
    categoryId: categoryId,
    modelId: modelId,
    providerModelId: providerModelId,
    metrics: ConsumptionMetrics(
      callCount: callCount,
      totalTokens: totalTokens,
      credits: credits,
      energyKwh: energyKwh,
      carbonGCo2: carbonGCo2,
    ),
    dataCenter: dataCenter,
    renewablePercent: renewablePercent,
  );
}
