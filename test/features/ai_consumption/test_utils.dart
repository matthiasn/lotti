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

class AiInteractionCaptureTestBench {
  AiInteractionCaptureTestBench._(
    this._sessions, {
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
    final sessions = <String, AiAttributionSession>{};

    when(identity.humanInitiator).thenAnswer((_) async => human);
    when(
      () => identity.automationInitiator(
        id: any(named: 'id'),
        displayName: any(named: 'displayName'),
      ),
    ).thenAnswer(
      (invocation) async => AiActorSnapshot(
        type: AiActorType.automation,
        id: invocation.namedArguments[#id] as String,
        displayName: invocation.namedArguments[#displayName] as String,
        humanPrincipalId: human.id,
      ),
    );
    when(
      () => identity.agentInitiator(
        id: any(named: 'id'),
        displayName: any(named: 'displayName'),
      ),
    ).thenAnswer(
      (invocation) async => AiActorSnapshot(
        type: AiActorType.agent,
        id: invocation.namedArguments[#id] as String,
        displayName: invocation.namedArguments[#displayName] as String,
        humanPrincipalId: human.id,
      ),
    );
    when(() => service.begin(any())).thenAnswer((invocation) async {
      final command =
          invocation.positionalArguments.first as AiAttributionStart;
      final id = command.attributionId ?? 'attribution-${sessions.length + 1}';
      return sessions.putIfAbsent(
        id,
        () => AiAttributionSession(
          id: id,
          workType: command.workType,
          initiator: command.initiator,
          trigger: command.trigger,
          startedAt: DateTime.utc(2024, 3, 15, 10, 30),
          intendedOutputs: command.intendedOutputs,
          parentAttributionId: command.parentAttributionId,
          taskId: command.taskId,
          categoryId: command.categoryId,
        ),
      );
    });
    when(
      () => service.recordInteraction(
        attributionId: any(named: 'attributionId'),
        event: any(named: 'event'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => service.prepareCompletion(
        attributionId: any(named: 'attributionId'),
        outputs: any(named: 'outputs'),
        status: any(named: 'status'),
        errorCode: any(named: 'errorCode'),
        errorSummary: any(named: 'errorSummary'),
      ),
    ).thenAnswer((invocation) async {
      final id = invocation.namedArguments[#attributionId] as String;
      final session = sessions[id]!;
      final outputs =
          invocation.namedArguments[#outputs] as List<AiArtifactReference>;
      final effectiveOutputs = outputs.isEmpty
          ? session.intendedOutputs
          : outputs;
      return AiWorkAttribution(
        id: id,
        workType: session.workType,
        status: invocation.namedArguments[#status] as AiWorkStatus,
        initiator: session.initiator,
        trigger: session.trigger,
        startedAt: session.startedAt,
        completedAt: DateTime.utc(2024, 3, 15, 10, 31),
        vectorClock: null,
        parentAttributionId: session.parentAttributionId,
        taskId: session.taskId,
        categoryId: session.categoryId,
        primaryOutput: effectiveOutputs.isEmpty ? null : effectiveOutputs.first,
        errorCode: invocation.namedArguments[#errorCode] as String?,
        errorSummary: invocation.namedArguments[#errorSummary] as String?,
      );
    });
    when(() => service.finalize(any())).thenAnswer((_) async {});

    return AiInteractionCaptureTestBench._(
      sessions,
      service: service,
      identity: identity,
      capture: AiInteractionCapture(service, identity),
    );
  }

  final MockAiAttributionService service;
  final MockAiAttributionIdentityResolver identity;
  final AiInteractionCapture capture;
  final Map<String, AiAttributionSession> _sessions;

  void seedAgentWake({
    required String wakeRunKey,
    required String agentId,
    String? taskId,
    String? categoryId,
  }) {
    final id = agentWakeAttributionId(wakeRunKey);
    _sessions[id] = AiAttributionSession(
      id: id,
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
      startedAt: DateTime.utc(2024, 3, 15, 10, 30),
      taskId: taskId,
      categoryId: categoryId,
    );
  }

  void register() {
    unregister();
    getIt
      ..registerSingleton<AiAttributionService>(service)
      ..registerSingleton<AiAttributionIdentityResolver>(identity)
      ..registerSingleton<AiInteractionCapture>(capture);
  }

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

AiConsumptionEvent makeConsumptionEvent({
  String id = 'evt-1',
  DateTime? createdAt,
  InferenceProviderType providerType = InferenceProviderType.melious,
  AiConsumptionResponseType responseType = AiConsumptionResponseType.agentTurn,
  VectorClock? vectorClock,
  String? attributionId,
  AiInteractionKind? interactionKind,
  AiInteractionStatus interactionStatus = AiInteractionStatus.succeeded,
  DateTime? completedAt,
  String? requestDigest,
  String? responseDigest,
  Map<String, dynamic>? interactionParameters,
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
  String? costCreditsDecimal = '0.002',
  double? energyKwh = 0.0003,
  double? carbonGCo2 = 0.12,
  double? waterLiters = 0.01,
  double? renewablePercent = 100,
  double? pue = 1.1,
  String? dataCenter = 'FI',
  String? upstreamProviderId,
}) => AiConsumptionEvent(
  id: id,
  createdAt: createdAt ?? DateTime(2026, 3, 15, 12),
  providerType: providerType,
  responseType: responseType,
  vectorClock: vectorClock,
  attributionId: attributionId,
  interactionKind: interactionKind,
  interactionStatus: interactionStatus,
  completedAt: completedAt,
  requestDigest: requestDigest,
  responseDigest: responseDigest,
  interactionParameters: interactionParameters,
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
  costCreditsDecimal: costCreditsDecimal,
  energyKwh: energyKwh,
  carbonGCo2: carbonGCo2,
  waterLiters: waterLiters,
  renewablePercent: renewablePercent,
  pue: pue,
  dataCenter: dataCenter,
  upstreamProviderId: upstreamProviderId,
);

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

AiArtifactReference makeAiArtifact({
  AiArtifactType type = AiArtifactType.journalAiResponse,
  String id = 'output-1',
  String? subId,
}) => AiArtifactReference(type: type, id: id, subId: subId);

AiAttributionStart makeAiAttributionStart({
  AiWorkType workType = AiWorkType.codingPrompt,
  List<AiArtifactReference>? intendedOutputs,
}) => AiAttributionStart(
  workType: workType,
  initiator: makeAiActor(),
  trigger: const AiTriggerSnapshot(
    type: AiTriggerType.manual,
    skillId: 'skill-1',
  ),
  intendedOutputs: intendedOutputs ?? [makeAiArtifact()],
  taskId: 'task-1',
  categoryId: 'cat-1',
);

AiWorkAttribution makeAiWorkAttribution({
  String attributionId = 'attribution-1',
  AiArtifactReference? output,
}) => AiWorkAttribution(
  id: attributionId,
  workType: AiWorkType.codingPrompt,
  status: AiWorkStatus.succeeded,
  initiator: makeAiActor(),
  trigger: const AiTriggerSnapshot(type: AiTriggerType.manual),
  startedAt: DateTime(2026, 3, 15, 12),
  completedAt: DateTime(2026, 3, 15, 12, 0, 1),
  vectorClock: const VectorClock({'host-a': 1}),
  primaryOutput: output ?? makeAiArtifact(),
);

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
}) => ConsumptionTotals(
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
}) => ConsumptionMetricRow(
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
