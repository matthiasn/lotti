part of 'agent_repository.dart';

/// Attention-claim and standing-agreement projection queries and
/// rebuild/refresh machinery of [AgentRepository]. The class keeps thin
/// delegators for the public methods so mocktail mocks of the repository
/// keep intercepting them.
extension AgentAttentionProjection on AgentRepository {
  /// Fetch attention claims visible to a time range via the local indexed
  /// projection. This is the planner read path: it never scans
  /// `agent_entities` or filters deserialized JSON to discover claims.
  Future<List<AttentionRequestEntity>> getAttentionClaimsForWindowImpl({
    required DateTime start,
    required DateTime end,
    Set<AttentionClaimStatus> statuses = const {
      AttentionClaimStatus.open,
      AttentionClaimStatus.proposed,
      AttentionClaimStatus.partiallySatisfied,
      AttentionClaimStatus.deferred,
    },
    int limit = 200,
  }) async {
    if (end.isBefore(start) || statuses.isEmpty || limit <= 0) {
      return const [];
    }

    final statusPlaceholders = List.filled(statuses.length, '?').join(', ');
    final rows = await _db
        .customSelect(
          '''
            SELECT request_id,
              MIN(next_review_at) AS next_review_at,
              MIN(deadline) AS deadline
            FROM attention_claim_index
            WHERE visibility_start < ?
              AND visibility_end > ?
              AND status IN ($statusPlaceholders)
              AND deleted_at IS NULL
            GROUP BY request_id
            ORDER BY next_review_at IS NULL,
              next_review_at ASC,
              deadline IS NULL,
              deadline ASC,
              request_id ASC
            LIMIT ?
          ''',
          variables: [
            Variable.withDateTime(end),
            Variable.withDateTime(start),
            ...statuses.map((status) => Variable.withString(status.name)),
            Variable.withInt(limit),
          ],
        )
        .get();

    final requestIds = [
      for (final row in rows) row.read<String>('request_id'),
    ];
    final entitiesById = await getEntitiesByIds(requestIds);
    return [
      for (final requestId in requestIds)
        if (entitiesById[requestId] case final AttentionRequestEntity request)
          request,
    ];
  }

  /// Fetch active attention claims for a source target, e.g. a task agent
  /// checking whether it already requested focus time for its task.
  ///
  /// Uses `attention_claim_index(target_kind, target_id, status, ...)`; it does
  /// not scan `agent_entities` or deserialize source rows to discover matches.
  Future<List<AttentionRequestEntity>> getAttentionClaimsForTargetImpl({
    required String targetKind,
    required String targetId,
    Set<AttentionClaimStatus> statuses = const {
      AttentionClaimStatus.open,
      AttentionClaimStatus.proposed,
      AttentionClaimStatus.partiallySatisfied,
      AttentionClaimStatus.deferred,
    },
    int limit = 50,
  }) async {
    if (targetKind.trim().isEmpty ||
        targetId.trim().isEmpty ||
        statuses.isEmpty ||
        limit <= 0) {
      return const [];
    }

    final orderedStatuses = statuses.toList(growable: false)
      ..sort((a, b) => a.name.compareTo(b.name));
    final statusPlaceholders = List.filled(
      orderedStatuses.length,
      '?',
    ).join(', ');
    final rows = await _db
        .customSelect(
          '''
            SELECT request_id
            FROM attention_claim_index
            WHERE target_kind = ?
              AND target_id = ?
              AND status IN ($statusPlaceholders)
              AND deleted_at IS NULL
            ORDER BY next_review_at IS NULL,
              next_review_at ASC,
              deadline IS NULL,
              deadline ASC,
              updated_at DESC,
              request_id ASC
            LIMIT ?
          ''',
          variables: [
            Variable.withString(targetKind),
            Variable.withString(targetId),
            ...orderedStatuses.map(
              (status) => Variable.withString(status.name),
            ),
            Variable.withInt(limit),
          ],
          readsFrom: {_db.attentionClaimIndex},
        )
        .get();

    final requestIds = [
      for (final row in rows) row.read<String>('request_id'),
    ];
    final entitiesById = await getEntitiesByIds(requestIds);
    return [
      for (final requestId in requestIds)
        if (entitiesById[requestId] case final AttentionRequestEntity request)
          request,
    ];
  }

  /// Fetch the claim and standing-agreement inputs a day planner needs for a
  /// window. Both reads use projection indexes rather than source-table scans.
  Future<AttentionPlanningInputs> getAttentionPlanningInputsForWindowImpl({
    required DateTime start,
    required DateTime end,
    Set<AttentionClaimStatus> claimStatuses = const {
      AttentionClaimStatus.open,
      AttentionClaimStatus.proposed,
      AttentionClaimStatus.partiallySatisfied,
      AttentionClaimStatus.deferred,
    },
    Set<StandingAgreementStatus> agreementStatuses = const {
      StandingAgreementStatus.active,
    },
    Set<StandingAgreementScope>? agreementScopes,
    int claimLimit = 200,
    int agreementLimit = 200,
  }) async {
    final (claims, standingAgreements) = await (
      getAttentionClaimsForWindowImpl(
        start: start,
        end: end,
        statuses: claimStatuses,
        limit: claimLimit,
      ),
      getStandingAgreementsForWindowImpl(
        start: start,
        end: end,
        statuses: agreementStatuses,
        scopes: agreementScopes,
        limit: agreementLimit,
      ),
    ).wait;
    return AttentionPlanningInputs(
      claims: claims,
      standingAgreements: standingAgreements,
    );
  }

  /// Fetch standing agreements visible to a planning window via the local
  /// indexed projection.
  ///
  /// This is the planner read path for durable policies: it never scans
  /// `agent_entities` or filters deserialized JSON to discover agreements.
  /// The projection returns agreement ids, then the source rows are hydrated by
  /// primary-key batch lookup so the synced log remains the source of truth.
  Future<List<StandingAgreementEntity>> getStandingAgreementsForWindowImpl({
    required DateTime start,
    required DateTime end,
    Set<StandingAgreementStatus> statuses = const {
      StandingAgreementStatus.active,
    },
    Set<StandingAgreementScope>? scopes,
    int limit = 200,
  }) async {
    if (!end.isAfter(start) || statuses.isEmpty || limit <= 0) {
      return const [];
    }

    final orderedStatuses = statuses.toList(growable: false)
      ..sort((a, b) => a.name.compareTo(b.name));
    final orderedScopes = scopes == null
        ? null
        : (scopes.toList(growable: false)
            ..sort((a, b) => a.name.compareTo(b.name)));
    if (orderedScopes != null && orderedScopes.isEmpty) {
      return const [];
    }

    final statusPlaceholders = List.filled(
      orderedStatuses.length,
      '?',
    ).join(', ');
    final scopePlaceholders = orderedScopes == null
        ? null
        : List.filled(orderedScopes.length, '?').join(', ');
    final scopePredicate = scopePlaceholders == null
        ? ''
        : 'AND scope IN ($scopePlaceholders)';

    final rows = await _db
        .customSelect(
          '''
            SELECT agreement_id
            FROM standing_agreement_index
            WHERE active_from < ?
              AND active_until > ?
              AND status IN ($statusPlaceholders)
              $scopePredicate
              AND deleted_at IS NULL
            ORDER BY priority DESC,
              updated_at DESC,
              agreement_id ASC
            LIMIT ?
          ''',
          variables: [
            Variable.withDateTime(end),
            Variable.withDateTime(start),
            ...orderedStatuses.map(
              (status) => Variable.withString(status.name),
            ),
            if (orderedScopes != null)
              ...orderedScopes.map((scope) => Variable.withString(scope.name)),
            Variable.withInt(limit),
          ],
          readsFrom: {_db.standingAgreementIndex},
        )
        .get();

    final agreementIds = [
      for (final row in rows) row.read<String>('agreement_id'),
    ];
    final entitiesById = await getEntitiesByIds(agreementIds);
    return [
      for (final agreementId in agreementIds)
        if (entitiesById[agreementId] case final StandingAgreementEntity entity)
          entity,
    ];
  }

  /// Rebuild the local attention claim indexes from the synced source tables.
  ///
  /// This is for migrations, repair, and diagnostics. Planner reads must use
  /// [getAttentionClaimsForWindow], not a source-table scan.
  Future<void> rebuildAttentionClaimProjectionImpl() async {
    await _db.transaction(() async {
      await _db.customStatement('DELETE FROM attention_claim_index');
      final rows = await _db
          .customSelect(
            '''
              SELECT id
              FROM agent_entities
              WHERE type = ?
                AND deleted_at IS NULL
              ORDER BY created_at ASC, id ASC
            ''',
            variables: [
              Variable.withString(AgentEntityTypes.attentionRequest),
            ],
            readsFrom: {_db.agentEntities},
          )
          .get();
      for (final row in rows) {
        await _refreshAttentionClaimProjection(row.read<String>('id'));
      }
    });
  }

  /// Rebuild the local standing agreement index from synced source rows.
  ///
  /// This is for migrations, repair, and diagnostics. Planner reads must use
  /// [getStandingAgreementsForWindow], not a source-table scan.
  Future<void> rebuildStandingAgreementProjectionImpl() async {
    await _db.transaction(() async {
      await _db.customStatement('DELETE FROM standing_agreement_index');
      final rows = await _db
          .customSelect(
            '''
              SELECT id
              FROM agent_entities
              WHERE type = ?
                AND deleted_at IS NULL
              ORDER BY created_at ASC, id ASC
            ''',
            variables: [
              Variable.withString(AgentEntityTypes.standingAgreement),
            ],
            readsFrom: {_db.agentEntities},
          )
          .get();
      for (final row in rows) {
        await _refreshStandingAgreementProjection(row.read<String>('id'));
      }
    });
  }

  Future<void> _refreshAttentionClaimProjectionForEntity(
    AgentDomainEntity entity,
  ) async {
    final requestId = switch (entity) {
      AttentionRequestEntity() => entity.id,
      AttentionClaimDispositionEntity() => entity.requestId,
      _ => null,
    };
    if (requestId == null) return;
    await _refreshAttentionClaimProjection(requestId);
  }

  Future<void> _refreshStandingAgreementProjectionForEntity(
    AgentDomainEntity entity,
  ) async {
    if (entity is! StandingAgreementEntity) return;
    await _refreshStandingAgreementProjection(entity.id);
  }

  Future<void> _refreshAttentionClaimProjection(String requestId) async {
    final request = await _getAttentionRequestForProjection(requestId);
    if (request == null) {
      await _deleteAttentionClaimProjection(requestId);
      return;
    }

    final disposition = await _latestAttentionClaimDisposition(requestId);
    final status = _projectedAttentionClaimStatus(request, disposition);
    final visibility = _claimVisibilityWindow(request);
    final updatedAt = disposition?.createdAt ?? request.createdAt;
    final nextReviewAt = disposition?.nextReviewAt ?? request.nextReviewAt;

    await _db.customInsert(
      '''
        INSERT INTO attention_claim_index (
          request_id,
          agent_id,
          status,
          scope_kind,
          visibility_start,
          visibility_end,
          deadline,
          next_review_at,
          target_id,
          target_kind,
          updated_at,
          deleted_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(request_id) DO UPDATE SET
          agent_id = excluded.agent_id,
          status = excluded.status,
          scope_kind = excluded.scope_kind,
          visibility_start = excluded.visibility_start,
          visibility_end = excluded.visibility_end,
          deadline = excluded.deadline,
          next_review_at = excluded.next_review_at,
          target_id = excluded.target_id,
          target_kind = excluded.target_kind,
          updated_at = excluded.updated_at,
          deleted_at = excluded.deleted_at
      ''',
      variables: [
        Variable.withString(request.id),
        Variable.withString(request.agentId),
        Variable.withString(status.name),
        Variable.withString(request.scopeKind.name),
        Variable.withDateTime(visibility.start),
        Variable.withDateTime(visibility.end),
        _nullableDateTimeVariable(request.deadline),
        _nullableDateTimeVariable(nextReviewAt),
        _nullableStringVariable(request.targetId),
        _nullableStringVariable(request.targetKind),
        Variable.withDateTime(updatedAt),
        _nullableDateTimeVariable(request.deletedAt),
      ],
      updates: {_db.attentionClaimIndex},
    );
  }

  static Variable<DateTime> _nullableDateTimeVariable(DateTime? value) {
    if (value == null) return const Variable<DateTime>(null);
    return Variable.withDateTime(value);
  }

  static Variable<String> _nullableStringVariable(String? value) {
    if (value == null) return const Variable<String>(null);
    return Variable.withString(value);
  }

  Future<void> _deleteAttentionClaimProjection(String requestId) async {
    await _db.customStatement(
      'DELETE FROM attention_claim_index WHERE request_id = ?',
      [requestId],
    );
  }

  Future<void> _refreshStandingAgreementProjection(String agreementId) async {
    final rows = await _db.getAgentEntityById(agreementId).get();
    if (rows.isEmpty) {
      await _deleteStandingAgreementProjection(agreementId);
      return;
    }

    final entity = AgentDbConversions.fromEntityRow(rows.first);
    if (entity is! StandingAgreementEntity) {
      await _deleteStandingAgreementProjection(agreementId);
      return;
    }

    final activeWindow = _standingAgreementActiveWindow(entity);
    await _db.customInsert(
      '''
        INSERT INTO standing_agreement_index (
          agreement_id,
          agent_id,
          status,
          scope,
          cadence,
          approval_mode,
          enforcement,
          active_from,
          active_until,
          priority,
          target_id,
          target_kind,
          updated_at,
          deleted_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(agreement_id) DO UPDATE SET
          agent_id = excluded.agent_id,
          status = excluded.status,
          scope = excluded.scope,
          cadence = excluded.cadence,
          approval_mode = excluded.approval_mode,
          enforcement = excluded.enforcement,
          active_from = excluded.active_from,
          active_until = excluded.active_until,
          priority = excluded.priority,
          target_id = excluded.target_id,
          target_kind = excluded.target_kind,
          updated_at = excluded.updated_at,
          deleted_at = excluded.deleted_at
      ''',
      variables: [
        Variable.withString(entity.id),
        Variable.withString(entity.agentId),
        Variable.withString(entity.status.name),
        Variable.withString(entity.scope.name),
        Variable.withString(entity.cadence.name),
        Variable.withString(entity.approvalMode.name),
        Variable.withString(entity.enforcement.name),
        Variable.withDateTime(activeWindow.start),
        Variable.withDateTime(activeWindow.end),
        Variable.withInt(entity.priority),
        _nullableStringVariable(entity.targetId),
        _nullableStringVariable(entity.targetKind),
        Variable.withDateTime(entity.updatedAt),
        _nullableDateTimeVariable(entity.deletedAt),
      ],
      updates: {_db.standingAgreementIndex},
    );
  }

  Future<void> _deleteStandingAgreementProjection(String agreementId) async {
    await _db.customStatement(
      'DELETE FROM standing_agreement_index WHERE agreement_id = ?',
      [agreementId],
    );
  }

  static final DateTime _openEndedStandingAgreementUntil = DateTime(
    9999,
    12,
    31,
  );

  static ({DateTime start, DateTime end}) _standingAgreementActiveWindow(
    StandingAgreementEntity agreement,
  ) {
    final start = agreement.activeFrom ?? agreement.createdAt;
    final end = agreement.activeUntil ?? _openEndedStandingAgreementUntil;
    if (end.isAfter(start)) {
      return (start: start, end: end);
    }
    return (start: start, end: start.add(const Duration(minutes: 1)));
  }

  Future<AttentionRequestEntity?> _getAttentionRequestForProjection(
    String requestId,
  ) async {
    final rows = await _db.getAgentEntityById(requestId).get();
    if (rows.isEmpty) return null;
    final entity = AgentDbConversions.fromEntityRow(rows.first);
    return entity is AttentionRequestEntity ? entity : null;
  }

  Future<AttentionClaimDispositionEntity?> _latestAttentionClaimDisposition(
    String requestId,
  ) async {
    final rows = await _db
        .customSelect(
          '''
            SELECT *
            FROM agent_entities
            WHERE type = ?
              AND subtype = ?
              AND deleted_at IS NULL
            ORDER BY created_at DESC, id DESC
            LIMIT 1
          ''',
          variables: [
            Variable.withString(AgentEntityTypes.attentionClaimDisposition),
            Variable.withString(requestId),
          ],
          readsFrom: {_db.agentEntities},
        )
        .get();
    if (rows.isEmpty) return null;
    final row = await _db.agentEntities.mapFromRow(rows.first);
    final entity = AgentDbConversions.fromEntityRow(row);
    return entity is AttentionClaimDispositionEntity ? entity : null;
  }

  static AttentionClaimStatus _projectedAttentionClaimStatus(
    AttentionRequestEntity request,
    AttentionClaimDispositionEntity? disposition,
  ) {
    if (request.deletedAt != null) return AttentionClaimStatus.withdrawn;
    if (disposition != null) return disposition.status;
    return switch (request.status) {
      AttentionRequestStatus.pending => AttentionClaimStatus.open,
      AttentionRequestStatus.withdrawn => AttentionClaimStatus.withdrawn,
      AttentionRequestStatus.awarded => AttentionClaimStatus.proposed,
      AttentionRequestStatus.rejected => AttentionClaimStatus.declined,
    };
  }

  static ({DateTime start, DateTime end}) _claimVisibilityWindow(
    AttentionRequestEntity request,
  ) {
    final start =
        request.rangeStart ?? request.earliestStart ?? request.createdAt;
    final fallbackEnd = start.add(const Duration(days: 1));
    final end =
        request.rangeEnd ??
        request.latestEnd ??
        request.deadline ??
        fallbackEnd;
    if (end.isAfter(start)) {
      return (start: start, end: end);
    }
    return (start: start, end: start.add(const Duration(minutes: 1)));
  }
}
