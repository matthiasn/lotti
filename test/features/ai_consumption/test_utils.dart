import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_enums.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_event.dart';
import 'package:lotti/features/ai_consumption/model/consumption_aggregation_models.dart';
import 'package:lotti/features/sync/vector_clock.dart';

/// Deterministic factory for [AiConsumptionEvent]s in tests. Every field is
/// overridable; the defaults model a Melious agent turn with full impact data
/// so tests only pass the parts that matter to them.
AiConsumptionEvent makeConsumptionEvent({
  String id = 'evt-1',
  DateTime? createdAt,
  InferenceProviderType providerType = InferenceProviderType.melious,
  AiConsumptionResponseType responseType = AiConsumptionResponseType.agentTurn,
  VectorClock? vectorClock,
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
  String? dataCenter,
  double? renewablePercent,
}) {
  return ConsumptionMetricRow(
    createdAt: createdAt ?? DateTime(2026, 6, 7, 9),
    categoryId: categoryId,
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
