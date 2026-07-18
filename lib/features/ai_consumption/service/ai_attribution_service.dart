import 'dart:convert';
import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_event.dart';
import 'package:lotti/features/ai_consumption/repository/consumption_repository.dart';
import 'package:lotti/features/ai_consumption/sync/consumption_sync_service.dart';
import 'package:uuid/uuid.dart';

const kAiAttributionDigestAlgorithm = 'sha256-v1';
const int kAiAttributionInlineEvidenceMaxBytes = 64 * 1024;

String agentWakeAttributionId(String wakeRunKey) => const Uuid().v5(
  Namespace.nil.value,
  'ai-attribution-agent-wake-v1|$wakeRunKey',
);

/// Immutable command used to start a durable attribution publication saga.
class AiAttributionStart {
  const AiAttributionStart({
    required this.workType,
    required this.initiator,
    required this.trigger,
    required this.executor,
    required this.privacyClassification,
    this.intendedOutputs = const [],
    this.sources = const [],
    this.context = const [],
    this.parentAttributionId,
    this.taskId,
    this.categoryId,
    this.attributionId,
  });

  final AiWorkType workType;
  final AiActorSnapshot initiator;
  final AiTriggerSnapshot trigger;
  final AiExecutorSnapshot executor;
  final AiPrivacyClassification privacyClassification;
  final List<AiArtifactReference> intendedOutputs;
  final List<AiArtifactReference> sources;
  final List<AiArtifactReference> context;
  final String? parentAttributionId;
  final String? taskId;
  final String? categoryId;
  final String? attributionId;
}

/// Returned when a terminal interaction was committed and publication tried.
class AiAttributedInteractionResult {
  const AiAttributedInteractionResult({
    required this.session,
    required this.event,
    required this.published,
  });

  final AiAttributionPendingSession session;
  final AiConsumptionEvent event;
  final bool published;
}

class AiAttributionPublicationException implements Exception {
  const AiAttributionPublicationException(this.message);

  final String message;

  @override
  String toString() => 'AiAttributionPublicationException: $message';
}

/// Coordinates the cross-database AI attribution publication saga.
///
/// Pending state is durable before inference. Terminal interaction/cost
/// evidence is committed and queued through the existing consumption envelope
/// before callers may persist an output carrier. Completion then projects the
/// terminal carrier envelope and clears pending state idempotently.
class AiAttributionService {
  AiAttributionService(
    this._repository,
    this._syncService, [
    this._uuid = const Uuid(),
  ]);

  final ConsumptionRepository _repository;
  final ConsumptionSyncService _syncService;
  final Uuid _uuid;

  /// Persists the saga before any provider/native inference starts.
  Future<AiAttributionPendingSession> begin(AiAttributionStart command) async {
    final now = clock.now().toUtc();
    final attributionId = command.attributionId ?? _uuid.v4();
    final existing = await _repository.getPendingAttribution(attributionId);
    if (existing != null) return existing;
    final pending = AiAttributionPendingSession(
      id: attributionId,
      attributionId: attributionId,
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
      parentAttributionId: command.parentAttributionId,
      taskId: command.taskId,
      categoryId: command.categoryId,
    );
    await _repository.upsertPendingAttribution(pending);
    return pending;
  }

  /// Commits terminal interaction evidence and attempts the publication barrier.
  Future<AiAttributedInteractionResult> recordInteraction({
    required String attributionId,
    required AiConsumptionEvent event,
  }) async {
    final pending = await _requirePending(attributionId);
    final sequenceIndex = pending.interactionIds.length;
    final now = clock.now().toUtc();
    final calling = pending.copyWith(
      phase: AiAttributionPendingPhase.calling,
      lastUpdatedAt: now,
    );
    await _repository.upsertPendingAttribution(calling);

    _validateInteractionEvidence(event);
    final attributed = _boundInlineEvidence(
      event.copyWith(
        attributionId: attributionId,
        sequenceIndex: sequenceIndex,
        completedAt: event.completedAt ?? now,
        recoveryCapsule: _recoveryCapsule(calling),
      ),
    );
    final publication = await _syncService.recordEventForPublication(
      attributed,
    );
    final updated = calling.copyWith(
      phase: publication.published
          ? AiAttributionPendingPhase.evidencePublished
          : AiAttributionPendingPhase.evidenceDurable,
      lastUpdatedAt: clock.now().toUtc(),
      interactionIds: [...calling.interactionIds, publication.event.id],
    );
    await _repository.upsertPendingAttribution(updated);
    return AiAttributedInteractionResult(
      session: updated,
      event: publication.event,
      published: publication.published,
    );
  }

  /// Retries the exact stamped evidence envelope after an enqueue failure.
  Future<AiAttributionPendingSession> retryPublication({
    required String attributionId,
    required String interactionId,
  }) async {
    final pending = await _requirePending(attributionId);
    final event = await _repository.getEvent(interactionId);
    if (event == null || event.attributionId != attributionId) {
      throw AiAttributionPublicationException(
        'interaction $interactionId is unavailable for $attributionId',
      );
    }
    final published = await _syncService.retryEventPublication(event);
    if (!published) return pending;
    final updated = pending.copyWith(
      phase: AiAttributionPendingPhase.evidencePublished,
      lastUpdatedAt: clock.now().toUtc(),
    );
    await _repository.upsertPendingAttribution(updated);
    return updated;
  }

  /// Builds the terminal envelope that must be stored on the output carrier.
  Future<AiTerminalAttributionEnvelope> prepareCompletion({
    required String attributionId,
    required List<AiArtifactReference> outputs,
    AiWorkStatus status = AiWorkStatus.succeeded,
    String? errorCode,
    String? errorSummary,
  }) async {
    final pending = await _requirePending(attributionId);
    if (pending.interactionIds.isNotEmpty &&
        pending.phase != AiAttributionPendingPhase.evidencePublished) {
      throw const AiAttributionPublicationException(
        'interaction evidence has not crossed the publication barrier',
      );
    }
    final effectiveOutputs = outputs.isEmpty
        ? pending.intendedOutputs
        : outputs;
    final links = <AiAttributionLink>[
      for (final output in effectiveOutputs)
        _link(attributionId, AiAttributionLinkRole.output, output),
      for (final source in pending.sourceArtifacts)
        _link(attributionId, AiAttributionLinkRole.source, source),
      for (final context in pending.contextArtifacts)
        _link(attributionId, AiAttributionLinkRole.context, context),
    ];
    final attribution = AiWorkAttribution(
      id: attributionId,
      workType: pending.workType,
      status: status,
      initiator: pending.initiator,
      trigger: pending.trigger,
      executor: pending.executor,
      privacyClassification: pending.privacyClassification,
      startedAt: pending.startedAt,
      completedAt: clock.now().toUtc(),
      vectorClock: null,
      links: links,
      parentAttributionId: pending.parentAttributionId,
      taskId: pending.taskId,
      categoryId: pending.categoryId,
      primaryOutput: effectiveOutputs.firstOrNull,
      errorCode: errorCode,
      errorSummary: errorSummary,
    );
    return AiTerminalAttributionEnvelope(
      id: _derivedId(attributionId, 'terminal-v1'),
      attribution: attribution,
    );
  }

  /// Projects the carrier envelope and clears its local pending saga.
  Future<void> finalize(AiTerminalAttributionEnvelope envelope) async {
    await _repository.projectTerminalEnvelope(envelope);
    await _repository.deletePendingAttribution(envelope.attribution.id);
  }

  /// Converts stale local pending state into terminal audit records.
  Future<List<AiWorkAttribution>> recoverStale({
    required Duration threshold,
  }) async {
    final cutoff = clock.now().toUtc().subtract(threshold);
    final recovered = <AiWorkAttribution>[];
    for (final pending in await _repository.pendingAttributions()) {
      if (pending.lastUpdatedAt.isAfter(cutoff)) continue;
      try {
        var recoverable = pending;
        if (pending.phase == AiAttributionPendingPhase.evidenceDurable &&
            pending.interactionIds.isNotEmpty) {
          recoverable = await retryPublication(
            attributionId: pending.id,
            interactionId: pending.interactionIds.last,
          );
          if (recoverable.phase !=
              AiAttributionPendingPhase.evidencePublished) {
            continue;
          }
        }
        final hasEvidence = recoverable.interactionIds.isNotEmpty;
        final envelope = await prepareCompletion(
          attributionId: recoverable.id,
          outputs: recoverable.intendedOutputs,
          status: hasEvidence ? AiWorkStatus.partial : AiWorkStatus.abandoned,
          errorCode: hasEvidence ? 'output_missing' : 'execution_interrupted',
        );
        await finalize(envelope);
        recovered.add(envelope.attribution);
      } on Object catch (error, stackTrace) {
        developer.log(
          'Failed to recover stale AI attribution ${pending.id}',
          name: 'ai_attribution.recovery',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    return recovered;
  }

  Future<AiAttributionPendingSession> _requirePending(String id) async {
    final pending = await _repository.getPendingAttribution(id);
    if (pending == null) {
      throw AiAttributionPublicationException(
        'pending attribution $id was not found',
      );
    }
    return pending;
  }

  AiAttributionRecoveryCapsule _recoveryCapsule(
    AiAttributionPendingSession pending,
  ) => AiAttributionRecoveryCapsule(
    id: _derivedId(pending.attributionId, 'recovery-v1'),
    attributionId: pending.attributionId,
    workType: pending.workType,
    initiator: pending.initiator,
    trigger: pending.trigger,
    executor: pending.executor,
    privacyClassification: pending.privacyClassification,
    startedAt: pending.startedAt,
    intendedOutputs: pending.intendedOutputs,
    parentAttributionId: pending.parentAttributionId,
    taskId: pending.taskId,
    categoryId: pending.categoryId,
  );

  AiAttributionLink _link(
    String attributionId,
    AiAttributionLinkRole role,
    AiArtifactReference artifact,
  ) => AiAttributionLink(
    id: _derivedId(
      attributionId,
      '${role.name}|${artifact.type.name}|${artifact.id}|'
      '${artifact.subId ?? ''}',
    ),
    attributionId: attributionId,
    role: role,
    artifact: artifact,
  );

  String _derivedId(String attributionId, String name) =>
      _uuid.v5(Namespace.nil.value, '$attributionId|$name');

  void _validateInteractionEvidence(AiConsumptionEvent event) {
    final payload = event.payload;
    if (payload != null && payload.interactionId != event.id) {
      throw ArgumentError.value(
        payload.interactionId,
        'event.payload.interactionId',
        'must match event ${event.id}',
      );
    }
    final cost = event.cost;
    if (cost != null && cost.interactionId != event.id) {
      throw ArgumentError.value(
        cost.interactionId,
        'event.cost.interactionId',
        'must match event ${event.id}',
      );
    }
    if (payload?.capturePolicy == AiPayloadCapturePolicy.fullText) {
      throw const AiAttributionPublicationException(
        'full-text payloads are local-only and cannot enter sync evidence',
      );
    }
  }

  AiConsumptionEvent _boundInlineEvidence(AiConsumptionEvent event) {
    final encoded = utf8.encode(jsonEncode(event.toJson()));
    if (encoded.length <= kAiAttributionInlineEvidenceMaxBytes) return event;
    final payload = event.payload;
    if (payload == null) {
      throw const AiAttributionPublicationException(
        'interaction evidence exceeds the 64 KiB wire limit',
      );
    }
    final reduced = event.copyWith(
      payload: payload.copyWith(
        request: const [],
        response: const [],
        parameters: {
          'inlineEvidenceOverflow': true,
          'originalByteLength': encoded.length,
          'originalSha256': sha256.convert(encoded).toString(),
        },
        providerMetadata: null,
        capturePolicy: AiPayloadCapturePolicy.metadataOnly,
      ),
    );
    if (utf8.encode(jsonEncode(reduced.toJson())).length >
        kAiAttributionInlineEvidenceMaxBytes) {
      throw const AiAttributionPublicationException(
        'reduced interaction evidence exceeds the 64 KiB wire limit',
      );
    }
    return reduced;
  }
}
