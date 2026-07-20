import 'package:clock/clock.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_event.dart';
import 'package:lotti/features/ai_consumption/repository/consumption_repository.dart';
import 'package:lotti/features/ai_consumption/sync/consumption_sync_service.dart';
import 'package:uuid/uuid.dart';

String agentWakeAttributionId(String wakeRunKey) => const Uuid().v5(
  Namespace.nil.value,
  'ai-attribution-agent-wake-v1|$wakeRunKey',
);

/// Values needed to attribute one logical AI operation.
class AiAttributionStart {
  const AiAttributionStart({
    required this.workType,
    required this.initiator,
    required this.trigger,
    this.intendedOutputs = const [],
    this.parentAttributionId,
    this.taskId,
    this.categoryId,
    this.attributionId,
  });

  final AiWorkType workType;
  final AiActorSnapshot initiator;
  final AiTriggerSnapshot trigger;
  final List<AiArtifactReference> intendedOutputs;
  final String? parentAttributionId;
  final String? taskId;
  final String? categoryId;
  final String? attributionId;
}

/// Connects logical work attribution to the existing consumption event store.
///
/// Running sessions are intentionally in memory only. Provider-call evidence
/// is written independently as an [AiConsumptionEvent], and completed output
/// carriers embed the authoritative [AiWorkAttribution]. No cross-database
/// transaction or crash-recovery state machine is required.
class AiAttributionService {
  AiAttributionService(
    this._repository,
    this._syncService, [
    this._uuid = const Uuid(),
  ]);

  final ConsumptionRepository _repository;
  final ConsumptionSyncService _syncService;
  final Uuid _uuid;
  final Map<String, AiAttributionSession> _sessions = {};

  Future<AiAttributionSession> begin(AiAttributionStart command) async {
    final id = command.attributionId ?? _uuid.v4();
    return _sessions.putIfAbsent(
      id,
      () => AiAttributionSession(
        id: id,
        workType: command.workType,
        initiator: command.initiator,
        trigger: command.trigger,
        startedAt: clock.now().toUtc(),
        intendedOutputs: command.intendedOutputs,
        parentAttributionId: command.parentAttributionId,
        taskId: command.taskId,
        categoryId: command.categoryId,
      ),
    );
  }

  /// Records one provider call. Sync enqueue is best-effort and never blocks
  /// persistence of an output.
  Future<void> recordInteraction({
    required String attributionId,
    required AiConsumptionEvent event,
  }) => _syncService.recordEvent(
    event.copyWith(
      attributionId: attributionId,
      completedAt: event.completedAt ?? clock.now().toUtc(),
    ),
  );

  /// Builds the record that a caller embeds in its output carrier.
  Future<AiWorkAttribution> prepareCompletion({
    required String attributionId,
    required List<AiArtifactReference> outputs,
    AiWorkStatus status = AiWorkStatus.succeeded,
    String? errorCode,
    String? errorSummary,
  }) async {
    final session = _sessions[attributionId];
    if (session == null) {
      throw StateError('AI attribution session $attributionId was not found');
    }
    final effectiveOutputs = outputs.isEmpty
        ? session.intendedOutputs
        : outputs;
    return AiWorkAttribution(
      id: session.id,
      workType: session.workType,
      status: status,
      initiator: session.initiator,
      trigger: session.trigger,
      startedAt: session.startedAt,
      completedAt: clock.now().toUtc(),
      vectorClock: null,
      parentAttributionId: session.parentAttributionId,
      taskId: session.taskId,
      categoryId: session.categoryId,
      primaryOutput: effectiveOutputs.isEmpty ? null : effectiveOutputs.first,
      errorCode: errorCode,
      errorSummary: errorSummary,
    );
  }

  /// Saves the local query projection after the caller persists the carrier.
  Future<void> finalize(AiWorkAttribution attribution) async {
    await _repository.upsertAttribution(attribution);
    _sessions.remove(attribution.id);
  }
}
