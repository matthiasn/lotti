import 'package:clock/clock.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/attention_negotiation.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:uuid/uuid.dart';

/// Authoring and lifecycle service for durable planner agreements.
///
/// Standing agreements are synced agent-domain records. This service is the
/// write boundary used by UI, agent tools, and maintenance code so callers do
/// not hand-roll entity construction or bypass [AgentSyncService]. Input
/// normalization and invariant validation apply to this local authoring path
/// only; inbound sync writes go straight to [AgentRepository] and are accepted
/// as-is to keep peers converging.
class StandingAgreementService {
  StandingAgreementService({
    required this.repository,
    required this.syncService,
  });

  final AgentRepository repository;
  final AgentSyncService syncService;

  static const _uuid = Uuid();

  /// Fetch a non-deleted standing agreement by id.
  Future<StandingAgreementEntity?> getAgreement(String agreementId) async {
    final entity = await repository.getEntity(agreementId);
    if (entity is StandingAgreementEntity && entity.deletedAt == null) {
      return entity;
    }
    return null;
  }

  /// Create a new active standing agreement.
  ///
  /// If [agreementId] is supplied it must not already exist; generated ids rely
  /// on UUID uniqueness and avoid a defensive source-table read.
  Future<StandingAgreementEntity> createAgreement({
    required String agentId,
    required String title,
    required StandingAgreementScope scope,
    required StandingAgreementCadence cadence,
    String? agreementId,
    StandingAgreementStatus status = StandingAgreementStatus.active,
    StandingAgreementEnforcement enforcement =
        StandingAgreementEnforcement.target,
    StandingAgreementApprovalMode approvalMode =
        StandingAgreementApprovalMode.ask,
    String? categoryId,
    String? targetId,
    String? targetKind,
    String? customScope,
    String? customCadence,
    int? minCount,
    int? maxCount,
    int? minMinutes,
    int? maxMinutes,
    int? preferredSessionMinutes,
    bool canPreempt = false,
    int priority = 0,
    List<String> preemptibleCategoryIds = const [],
    List<String> protectedCategoryIds = const [],
    List<AttentionEvidenceRef> evidenceRefs = const [],
    DateTime? activeFrom,
    DateTime? activeUntil,
    String? rationale,
  }) async {
    final id = agreementId == null
        ? _uuid.v4()
        : _requireNonBlank('agreementId', agreementId);
    final now = clock.now();
    final agreement =
        AgentDomainEntity.standingAgreement(
              id: id,
              agentId: _requireNonBlank('agentId', agentId),
              title: _requireNonBlank('title', title),
              scope: scope,
              cadence: cadence,
              status: status,
              enforcement: enforcement,
              approvalMode: approvalMode,
              categoryId: _trimOptional(categoryId),
              targetId: _trimOptional(targetId),
              targetKind: _trimOptional(targetKind),
              customScope: _trimOptional(customScope),
              customCadence: _trimOptional(customCadence),
              minCount: minCount,
              maxCount: maxCount,
              minMinutes: minMinutes,
              maxMinutes: maxMinutes,
              preferredSessionMinutes: preferredSessionMinutes,
              canPreempt: canPreempt,
              priority: priority,
              preemptibleCategoryIds: _normalizeIds(preemptibleCategoryIds),
              protectedCategoryIds: _normalizeIds(protectedCategoryIds),
              evidenceRefs: evidenceRefs,
              activeFrom: activeFrom,
              activeUntil: activeUntil,
              rationale: _trimOptional(rationale),
              createdAt: now,
              updatedAt: now,
              vectorClock: null,
            )
            as StandingAgreementEntity;
    _validateAgreement(agreement);

    // Generated ids rely on UUID uniqueness, so the common path is a single
    // write with no read to make atomic. Only the caller-supplied-id path
    // guards against collisions, and only it needs the read-then-write
    // wrapped in a transaction.
    if (agreementId == null) {
      await syncService.upsertEntity(agreement);
      return agreement;
    }

    return syncService.runInTransaction(() async {
      if (await repository.getEntity(id) != null) {
        throw StateError('Standing agreement $id already exists');
      }
      await syncService.upsertEntity(agreement);
      return agreement;
    });
  }

  /// Persist a caller-edited agreement through the synced write path.
  ///
  /// The returned entity is normalized, validated, and stamped with the current
  /// time as `updatedAt`. Callers that only need lifecycle transitions should
  /// prefer [activateAgreement], [pauseAgreement], or [retireAgreement].
  Future<StandingAgreementEntity> saveAgreement(
    StandingAgreementEntity agreement,
  ) async {
    final updated = agreement.copyWith(
      title: _requireNonBlank('title', agreement.title),
      categoryId: _trimOptional(agreement.categoryId),
      targetId: _trimOptional(agreement.targetId),
      targetKind: _trimOptional(agreement.targetKind),
      customScope: _trimOptional(agreement.customScope),
      customCadence: _trimOptional(agreement.customCadence),
      rationale: _trimOptional(agreement.rationale),
      preemptibleCategoryIds: _normalizeIds(
        agreement.preemptibleCategoryIds,
      ),
      protectedCategoryIds: _normalizeIds(agreement.protectedCategoryIds),
      updatedAt: clock.now(),
    );
    _validateAgreement(updated);
    await syncService.upsertEntity(updated);
    return updated;
  }

  /// Make a paused or retired agreement active again.
  Future<StandingAgreementEntity> activateAgreement({
    required String agreementId,
  }) {
    return _setStatus(agreementId, StandingAgreementStatus.active);
  }

  /// Pause an agreement without deleting its audit trail.
  Future<StandingAgreementEntity> pauseAgreement({
    required String agreementId,
  }) {
    return _setStatus(agreementId, StandingAgreementStatus.paused);
  }

  /// Retire an agreement so it remains historical but stops influencing plans.
  Future<StandingAgreementEntity> retireAgreement({
    required String agreementId,
  }) {
    return _setStatus(agreementId, StandingAgreementStatus.retired);
  }

  /// Soft-delete an agreement.
  Future<StandingAgreementEntity> deleteAgreement({
    required String agreementId,
  }) async {
    final agreement = await _loadAgreement(agreementId, includeDeleted: true);
    if (agreement.deletedAt != null) return agreement;

    final now = clock.now();
    final updated = agreement.copyWith(
      deletedAt: now,
      updatedAt: now,
    );
    await syncService.upsertEntity(updated);
    return updated;
  }

  Future<StandingAgreementEntity> _setStatus(
    String agreementId,
    StandingAgreementStatus status,
  ) async {
    final agreement = await _loadAgreement(agreementId);
    if (agreement.status == status) return agreement;

    final updated = agreement.copyWith(
      status: status,
      updatedAt: clock.now(),
    );
    await syncService.upsertEntity(updated);
    return updated;
  }

  Future<StandingAgreementEntity> _loadAgreement(
    String agreementId, {
    bool includeDeleted = false,
  }) async {
    final entity = await repository.getEntity(agreementId);
    if (entity is! StandingAgreementEntity) {
      throw StateError('Standing agreement $agreementId not found');
    }
    if (!includeDeleted && entity.deletedAt != null) {
      throw StateError('Standing agreement $agreementId not found');
    }
    return entity;
  }

  static String _requireNonBlank(String name, String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('$name must not be blank');
    }
    return trimmed;
  }

  static String? _trimOptional(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  static List<String> _normalizeIds(List<String> ids) {
    final seen = <String>{};
    final normalized = <String>[];
    for (final id in ids) {
      final trimmed = id.trim();
      if (trimmed.isNotEmpty && seen.add(trimmed)) {
        normalized.add(trimmed);
      }
    }
    return normalized;
  }

  static void _validateAgreement(StandingAgreementEntity agreement) {
    if (agreement.scope == StandingAgreementScope.custom &&
        agreement.customScope == null) {
      throw ArgumentError('customScope is required for custom scope');
    }
    if (agreement.cadence == StandingAgreementCadence.custom &&
        agreement.customCadence == null) {
      throw ArgumentError('customCadence is required for custom cadence');
    }

    _validateNonNegative('minCount', agreement.minCount);
    _validateNonNegative('maxCount', agreement.maxCount);
    _validateNonNegative('minMinutes', agreement.minMinutes);
    _validateNonNegative('maxMinutes', agreement.maxMinutes);
    _validatePositive(
      'preferredSessionMinutes',
      agreement.preferredSessionMinutes,
    );
    _validateMinMax('count', agreement.minCount, agreement.maxCount);
    _validateMinMax('minutes', agreement.minMinutes, agreement.maxMinutes);

    final preferredSessionMinutes = agreement.preferredSessionMinutes;
    final maxMinutes = agreement.maxMinutes;
    if (preferredSessionMinutes != null &&
        maxMinutes != null &&
        preferredSessionMinutes > maxMinutes) {
      throw ArgumentError('preferredSessionMinutes must be <= maxMinutes');
    }

    final activeFrom = agreement.activeFrom;
    final activeUntil = agreement.activeUntil;
    if (activeFrom != null &&
        activeUntil != null &&
        activeFrom.isAfter(activeUntil)) {
      throw ArgumentError('activeFrom must be before or equal to activeUntil');
    }
  }

  static void _validateNonNegative(String name, int? value) {
    if (value != null && value < 0) {
      throw ArgumentError('$name must not be negative');
    }
  }

  static void _validatePositive(String name, int? value) {
    if (value != null && value <= 0) {
      throw ArgumentError('$name must be positive');
    }
  }

  static void _validateMinMax(String name, int? min, int? max) {
    if (min != null && max != null && min > max) {
      throw ArgumentError('min$name must be <= max$name');
    }
  }
}
