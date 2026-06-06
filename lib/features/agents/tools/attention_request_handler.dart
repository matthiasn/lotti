import 'package:clock/clock.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/attention_negotiation.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:uuid/uuid.dart';

/// Handles task-agent requests for planner attention/time.
class AttentionRequestHandler {
  AttentionRequestHandler({
    required this.agentRepository,
    required this.syncService,
    required this.requestingAgentId,
  });

  final AgentRepository agentRepository;
  final AgentSyncService syncService;
  final String requestingAgentId;

  static const _uuid = Uuid();
  static const _taskTargetKind = 'task';

  Future<ToolExecutionResult> handle(
    Task task,
    Map<String, dynamic> args,
  ) async {
    if (requestingAgentId.trim().isEmpty) {
      return const ToolExecutionResult(
        success: false,
        output: 'Error: request_attention is missing the requesting agent id.',
        errorMessage: 'Missing requesting agent id',
      );
    }

    final categoryId = task.categoryId;
    if (categoryId == null || categoryId.trim().isEmpty) {
      return const ToolExecutionResult(
        success: false,
        output: 'Error: task has no category for an attention request.',
        errorMessage: 'Task has no category',
      );
    }

    final requestedMinutes = _requiredInt(
      args,
      'requestedMinutes',
      min: 1,
      max: 1440,
    );
    final impact = _requiredInt(args, 'impact', min: 1, max: 5);
    final urgency = _requiredInt(args, 'urgency', min: 1, max: 5);
    final energyFit = _requiredEnum(
      args,
      'energyFit',
      AttentionEnergyFit.values,
    );
    final rationale = _requiredString(args, 'rationale');

    final validationErrors = [
      requestedMinutes.error,
      impact.error,
      urgency.error,
      energyFit.error,
      rationale.error,
    ].whereType<String>();
    if (validationErrors.isNotEmpty) {
      return ToolExecutionResult(
        success: false,
        output: 'Error: ${validationErrors.first}',
        errorMessage: validationErrors.first,
      );
    }

    final title = _optionalString(args, 'title') ?? _defaultTitle(task);
    final earliestStart = _optionalDateTime(args, 'earliestStart');
    final latestEnd = _optionalDateTime(args, 'latestEnd');
    final deadline = _optionalDateTime(args, 'deadline');
    final nextReviewAt = _optionalDateTime(args, 'nextReviewAt');
    final optionalDateErrors = [
      earliestStart.error,
      latestEnd.error,
      deadline.error,
      nextReviewAt.error,
    ].whereType<String>();
    if (optionalDateErrors.isNotEmpty) {
      return ToolExecutionResult(
        success: false,
        output: 'Error: ${optionalDateErrors.first}',
        errorMessage: optionalDateErrors.first,
      );
    }

    final start = earliestStart.value;
    final latest = latestEnd.value;
    final due = deadline.value;
    if (start != null && latest != null && !latest.isAfter(start)) {
      return const ToolExecutionResult(
        success: false,
        output: 'Error: latestEnd must be after earliestStart.',
        errorMessage: 'Invalid attention request window',
      );
    }
    if (start != null && due != null && !due.isAfter(start)) {
      return const ToolExecutionResult(
        success: false,
        output: 'Error: deadline must be after earliestStart.',
        errorMessage: 'Invalid attention request deadline',
      );
    }
    if (latest != null && due != null && latest.isAfter(due)) {
      return const ToolExecutionResult(
        success: false,
        output: 'Error: latestEnd cannot be after the deadline.',
        errorMessage: 'Invalid attention request window and deadline',
      );
    }

    final explicitScopeKind = _optionalEnum(
      args,
      'scopeKind',
      AttentionClaimScopeKind.values,
    );
    if (explicitScopeKind.error != null) {
      return ToolExecutionResult(
        success: false,
        output: 'Error: ${explicitScopeKind.error}',
        errorMessage: explicitScopeKind.error,
      );
    }
    final scopeKind =
        explicitScopeKind.value ??
        _inferScopeKind(latestEnd: latest, deadline: due);
    final now = clock.now();
    final existing = await agentRepository.getAttentionClaimsForTarget(
      targetKind: _taskTargetKind,
      targetId: task.id,
    );
    final matching = existing
        .where(
          (claim) => _matchesRequest(
            claim,
            title: title,
            categoryId: categoryId,
            requestedMinutes: requestedMinutes.value!,
            impact: impact.value!,
            urgency: urgency.value!,
            energyFit: energyFit.value!,
            scopeKind: scopeKind,
            earliestStart: start,
            latestEnd: latest,
            deadline: due,
            nextReviewAt: nextReviewAt.value,
            rationale: rationale.value!,
          ),
        )
        .toList(growable: false);
    // Keep at most one canonical active claim per task. When the incoming
    // request matches an existing claim, retain the first match and supersede
    // every other claim — both stale variants and any pre-existing duplicate
    // equivalent claims, so duplicates can't accumulate.
    final canonical = matching.isEmpty ? null : matching.first;
    final claimsToSupersede = [
      for (final claim in existing)
        if (canonical == null || claim.id != canonical.id) claim,
    ];

    if (canonical != null) {
      if (claimsToSupersede.isNotEmpty) {
        await syncService.runInTransaction(() async {
          for (final claim in claimsToSupersede) {
            await _supersede(claim.id, now);
          }
        });
      }
      return ToolExecutionResult(
        success: true,
        output:
            'Attention request already active for this task: ${canonical.id}',
      );
    }

    final requestId = _uuid.v4();
    final request = AgentDomainEntity.attentionRequest(
      id: requestId,
      agentId: requestingAgentId,
      kind: AttentionRequestKind.task,
      title: title,
      categoryId: categoryId,
      requestedMinutes: requestedMinutes.value!,
      impact: impact.value!,
      urgency: urgency.value!,
      energyFit: energyFit.value!,
      evidenceRefs: [
        AttentionEvidenceRef(
          kind: AttentionEvidenceKind.task,
          id: task.id,
          label: task.data.title.trim().isEmpty ? task.id : task.data.title,
        ),
      ],
      scopeKind: scopeKind,
      earliestStart: start,
      latestEnd: latest,
      deadline: due,
      nextReviewAt: nextReviewAt.value,
      targetId: task.id,
      targetKind: _taskTargetKind,
      rationale: rationale.value,
      createdAt: now,
      vectorClock: null,
    );

    await syncService.runInTransaction(() async {
      for (final claim in claimsToSupersede) {
        await _supersede(claim.id, now);
      }
      await syncService.upsertEntity(request);
    });

    return ToolExecutionResult(
      success: true,
      output: 'Attention request created: $requestId',
    );
  }

  Future<void> _supersede(String requestId, DateTime now) {
    return syncService.upsertEntity(
      AgentDomainEntity.attentionClaimDisposition(
        id: _uuid.v4(),
        agentId: requestingAgentId,
        requestId: requestId,
        status: AttentionClaimStatus.superseded,
        reason: 'Superseded by a newer task attention request.',
        createdAt: now,
        vectorClock: null,
      ),
    );
  }

  static AttentionClaimScopeKind _inferScopeKind({
    required DateTime? latestEnd,
    required DateTime? deadline,
  }) {
    if (latestEnd != null) return AttentionClaimScopeKind.dateRange;
    if (deadline != null) return AttentionClaimScopeKind.deadline;
    return AttentionClaimScopeKind.day;
  }

  static String _defaultTitle(Task task) {
    final title = task.data.title.trim();
    if (title.isEmpty) return 'Schedule task work';
    return 'Schedule: $title';
  }

  static bool _matchesRequest(
    AttentionRequestEntity claim, {
    required String title,
    required String categoryId,
    required int requestedMinutes,
    required int impact,
    required int urgency,
    required AttentionEnergyFit energyFit,
    required AttentionClaimScopeKind scopeKind,
    required DateTime? earliestStart,
    required DateTime? latestEnd,
    required DateTime? deadline,
    required DateTime? nextReviewAt,
    required String rationale,
  }) {
    return claim.title == title &&
        claim.categoryId == categoryId &&
        claim.requestedMinutes == requestedMinutes &&
        claim.impact == impact &&
        claim.urgency == urgency &&
        claim.energyFit == energyFit &&
        claim.scopeKind == scopeKind &&
        _isSameMoment(claim.earliestStart, earliestStart) &&
        _isSameMoment(claim.latestEnd, latestEnd) &&
        _isSameMoment(claim.deadline, deadline) &&
        _isSameMoment(claim.nextReviewAt, nextReviewAt) &&
        claim.rationale == rationale;
  }

  /// Compares two optional [DateTime] values by the instant they represent.
  ///
  /// Uses [DateTime.isAtSameMomentAs] rather than `==` because the stored
  /// claim is typically read back as UTC while a freshly parsed request value
  /// may be local; `==` also compares the `isUtc` flag and would report a
  /// false mismatch for the same moment, causing duplicate requests.
  static bool _isSameMoment(DateTime? a, DateTime? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a.isAtSameMomentAs(b);
  }

  static _Parsed<int> _requiredInt(
    Map<String, dynamic> args,
    String key, {
    required int min,
    required int max,
  }) {
    final value = args[key];
    if (value is! int) {
      return _Parsed(error: '"$key" must be an integer.');
    }
    if (value < min || value > max) {
      return _Parsed(error: '"$key" must be between $min and $max.');
    }
    return _Parsed(value: value);
  }

  static _Parsed<T> _requiredEnum<T extends Enum>(
    Map<String, dynamic> args,
    String key,
    List<T> values,
  ) {
    final parsed = _optionalEnum(args, key, values);
    if (parsed.error != null) return parsed;
    if (parsed.value == null) {
      return _Parsed(error: '"$key" is required.');
    }
    return parsed;
  }

  static _Parsed<T> _optionalEnum<T extends Enum>(
    Map<String, dynamic> args,
    String key,
    List<T> values,
  ) {
    final value = args[key];
    if (value == null) return const _Parsed();
    if (value is! String || value.trim().isEmpty) {
      return _Parsed(error: '"$key" must be a non-empty string.');
    }
    for (final candidate in values) {
      if (candidate.name == value.trim()) {
        return _Parsed(value: candidate);
      }
    }
    return _Parsed(
      error:
          '"$key" must be one of: '
          '${values.map((value) => value.name).join(", ")}.',
    );
  }

  static _Parsed<String> _requiredString(
    Map<String, dynamic> args,
    String key,
  ) {
    final value = _optionalString(args, key);
    if (value == null) return _Parsed(error: '"$key" is required.');
    return _Parsed(value: value);
  }

  static String? _optionalString(Map<String, dynamic> args, String key) {
    final value = args[key];
    if (value == null) return null;
    if (value is! String || value.trim().isEmpty) return null;
    return value.trim();
  }

  static _Parsed<DateTime?> _optionalDateTime(
    Map<String, dynamic> args,
    String key,
  ) {
    final value = args[key];
    if (value == null) return const _Parsed();
    if (value is! String || value.trim().isEmpty) {
      return _Parsed(error: '"$key" must be an ISO-8601 string.');
    }
    final parsed = DateTime.tryParse(value.trim());
    if (parsed == null) {
      return _Parsed(error: '"$key" must be a valid ISO-8601 date/time.');
    }
    return _Parsed(value: parsed);
  }
}

class _Parsed<T> {
  const _Parsed({this.value, this.error});

  final T? value;
  final String? error;
}
