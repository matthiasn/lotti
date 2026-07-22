import 'package:clock/clock.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_identity.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_slots.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_directive_models.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_service.dart'
    show DayAgentCaptureException, DayAgentDirectToolResult;
import 'package:lotti/features/daily_os_next/agents/service/day_agent_plan_parser.dart';
import 'package:lotti/features/daily_os_next/agents/tools/day_agent_tool_names.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:uuid/uuid.dart';

/// Raised by the directive service for an invalid tool call or argument.
class DayAgentDirectiveException implements Exception {
  /// Creates the exception with a tool-facing [message].
  const DayAgentDirectiveException(this.message);

  /// Tool-facing error message.
  final String message;

  @override
  String toString() => message;
}

/// Backend for the coordinator-issued day directive (ADR 0032 §2, phase 3).
///
/// The coordinator distills the commitments ledger, capacity budget,
/// carry-over, and cross-day attention notes into one revisable
/// `DayDirectiveEntity` per day (`day_directive:<dayId>`). Only the
/// coordinator may issue: a per-day agent calling `issue_day_directive` gets
/// a tool failure — directives flow downward. Revisions upsert the same
/// deterministic id with a fresh [Uuid] revision marker; `createdAt` is
/// preserved so LWW picks the newest revision without resurrecting history.
class DayAgentDirectiveService {
  /// Creates the directive service.
  DayAgentDirectiveService({
    required this.agentRepository,
    required this.syncService,
    required this.domainLogger,
    this.onPersistedStateChanged,
  });

  /// Agent entity repository.
  final AgentRepository agentRepository;

  /// Sync-aware writer.
  final AgentSyncService syncService;

  /// Structured logger.
  final DomainLogger domainLogger;

  /// Callback fired when persisted state changes.
  final void Function(String id)? onPersistedStateChanged;

  static const _uuid = Uuid();

  /// Run keys that already raised a status event — at most one per wake, so
  /// a looping model cannot spam the coordinator's digest. In-memory only:
  /// a process restart resets the guard, which is harmless (the wake it
  /// guarded is gone too).
  final _statusRaisedRunKeys = <String>{};

  /// Bounded-list caps: a directive is distilled facts, not a dump. The
  /// coordinator must prioritize before issuing.
  static const int maxCommitments = 12;

  /// Cap for carry-over items.
  static const int maxCarryOverItems = 12;

  /// Cap for freeform constraints and attention notes (each).
  static const int maxNotes = 8;

  /// Character bound for each freeform constraint/note/reason string.
  static const int maxNoteLength = 280;

  /// Character bound for a status event's note (mirrors day summaries).
  static const int maxStatusNoteLength = 500;

  /// Executes a directive-protocol tool emitted by the agent.
  ///
  /// [wakeDayId] is the wake's workspace day — `raise_day_status` may only
  /// target it (an agent cannot speak for another day). [runKey] scopes the
  /// one-status-event-per-wake cap.
  Future<DayAgentDirectToolResult> executeTool({
    required String agentId,
    required String toolName,
    required Map<String, dynamic> args,
    String? wakeDayId,
    String? runKey,
  }) async {
    try {
      final data = switch (toolName) {
        DayAgentToolNames.issueDayDirective => await _issueTool(agentId, args),
        DayAgentToolNames.raiseDayStatus => await _raiseTool(
          agentId,
          args,
          wakeDayId: wakeDayId,
          runKey: runKey,
        ),
        _ => throw DayAgentDirectiveException('unknown tool "$toolName"'),
      };
      return DayAgentDirectToolResult.success(data);
    } on DayAgentDirectiveException catch (e) {
      return DayAgentDirectToolResult.failure(e.message);
    } on DayAgentCaptureException catch (e) {
      // The shared arg/energy-band parsers throw this; surface its message
      // to the model instead of an opaque toString.
      return DayAgentDirectToolResult.failure(e.message);
    } catch (e, s) {
      domainLogger.error(
        LogDomain.agentWorkflow,
        e,
        message: 'day-directive tool failed',
        stackTrace: s,
      );
      return DayAgentDirectToolResult.failure(e.toString());
    }
  }

  /// The current directive for [dayId], or null when none was issued or it
  /// was deleted.
  Future<DayDirectiveEntity?> directiveForDay(String dayId) async {
    final entity = await agentRepository.getEntity(dayDirectiveEntityId(dayId));
    if (entity is! DayDirectiveEntity || entity.deletedAt != null) return null;
    return entity;
  }

  Future<Map<String, Object?>> _issueTool(
    String agentId,
    Map<String, dynamic> args,
  ) async {
    // Directives flow downward only (ADR 0032 §2): the coordinator owns the
    // cross-day ledger a directive distills. A per-day agent pushes back via
    // `raise_day_status`, never by rewriting its own orders.
    if (agentId != dailyOsPlannerAgentId) {
      throw const DayAgentDirectiveException(
        'only the coordinator may issue day directives',
      );
    }

    final dayId = requiredStringArg(args, 'dayId');
    final planDate = dateFromDayId(dayId);
    if (planDate == null) {
      throw const DayAgentDirectiveException(
        'dayId must be of the form dayplan-YYYY-MM-DD',
      );
    }

    final commitments = _parseCommitments(args['commitments'], planDate);
    final capacityBudget = _parseCapacityBudget(
      args['capacityBudget'],
      planDate,
    );
    final carryOver = _parseCarryOver(args['carryOver']);
    final constraints = _boundedNotes(args['constraints'], 'constraints');
    final attentionNotes = _boundedNotes(
      args['attentionNotes'],
      'attentionNotes',
    );

    final directive = await issue(
      dayId: dayId,
      planDate: planDate,
      commitments: commitments,
      capacityBudget: capacityBudget,
      carryOver: carryOver,
      constraints: constraints,
      attentionNotes: attentionNotes,
    );
    return {
      'id': directive.id,
      'directiveRevisionId': directive.directiveRevisionId,
      'commitments': directive.commitments.length,
    };
  }

  /// Issues (or revises) the directive for [dayId].
  ///
  /// Upserts the deterministic `day_directive:<dayId>` register with a fresh
  /// revision id; a prior revision's `createdAt` is preserved so the entity
  /// stays one register rather than a re-created row.
  Future<DayDirectiveEntity> issue({
    required String dayId,
    required DateTime planDate,
    List<DayDirectiveCommitment> commitments = const [],
    DayCapacityBudget? capacityBudget,
    List<DayCarryOverItem> carryOver = const [],
    List<String> constraints = const [],
    List<String> attentionNotes = const [],
  }) async {
    final now = clock.now();
    final id = dayDirectiveEntityId(dayId);
    final existing = await agentRepository.getEntity(id);
    final createdAt = existing is DayDirectiveEntity ? existing.createdAt : now;

    final directive =
        AgentDomainEntity.dayDirective(
              id: id,
              agentId: dailyOsPlannerAgentId,
              dayId: dayId,
              planDate: planDate,
              directiveRevisionId: _uuid.v4(),
              issuedAt: now,
              commitments: commitments,
              capacityBudget: capacityBudget,
              carryOver: carryOver,
              constraints: constraints,
              attentionNotes: attentionNotes,
              createdAt: createdAt,
              updatedAt: now,
              vectorClock: null,
            )
            as DayDirectiveEntity;

    await syncService.runInTransaction(() async {
      await syncService.upsertEntity(directive);
    });
    onPersistedStateChanged
      ?..call(dayId)
      ..call(directive.id);
    return directive;
  }

  Future<Map<String, Object?>> _raiseTool(
    String agentId,
    Map<String, dynamic> args, {
    String? wakeDayId,
    String? runKey,
  }) async {
    final dayId = requiredStringArg(args, 'dayId');
    if (dateFromDayId(dayId) == null) {
      throw const DayAgentDirectiveException(
        'dayId must be of the form dayplan-YYYY-MM-DD',
      );
    }
    // Status speaks for the wake's own day only: unlike issue_day_directive
    // (deliberately exempt from the workspace guard so a digest can write
    // tomorrow's directive), an agent cannot report on another day's state.
    if (wakeDayId != null && dayId != wakeDayId) {
      throw DayAgentDirectiveException(
        'raise_day_status may only target the wake\'s own day "$wakeDayId"',
      );
    }

    final statusName = requiredStringArg(args, 'status');
    final status = optionalEnumArg(DayStatusKind.values, statusName);
    if (status == null) {
      throw const DayAgentDirectiveException(
        'status must be onTrack, attentionNeeded, or dayClosed',
      );
    }
    final reasons = _parseReasons(args['reasons'], status);
    final note = optionalStringArg(args['note']) ?? '';
    if (note.length > maxStatusNoteLength) {
      throw const DayAgentDirectiveException(
        'note must be at most $maxStatusNoteLength characters',
      );
    }

    if (runKey != null && !_statusRaisedRunKeys.add(runKey)) {
      throw const DayAgentDirectiveException(
        'already raised a status event this wake — one per wake',
      );
    }

    final event = await raise(
      agentId: agentId,
      dayId: dayId,
      status: status,
      reasons: reasons,
      note: note,
    );
    return {
      'id': event.id,
      'status': event.status.name,
    };
  }

  /// Persists one append-only status event under the raising agent's id.
  Future<DayStatusEventEntity> raise({
    required String agentId,
    required String dayId,
    required DayStatusKind status,
    List<DayStatusReason> reasons = const [],
    String note = '',
  }) async {
    final now = clock.now();
    final event =
        AgentDomainEntity.dayStatusEvent(
              id: dayStatusEventId(dayId, _uuid.v4()),
              agentId: agentId,
              dayId: dayId,
              status: status,
              reasons: reasons,
              note: note,
              raisedAt: now,
              createdAt: now,
              vectorClock: null,
            )
            as DayStatusEventEntity;
    await syncService.runInTransaction(() async {
      await syncService.upsertEntity(event);
    });
    onPersistedStateChanged
      ?..call(dayId)
      ..call(event.id);
    return event;
  }

  List<DayStatusReason> _parseReasons(Object? raw, DayStatusKind status) {
    final names = stringListArg(raw);
    final reasons = <DayStatusReason>[];
    for (final name in names) {
      final reason = optionalEnumArg(DayStatusReason.values, name);
      if (reason == null) {
        throw const DayAgentDirectiveException(
          'reasons must be overCommitted, directiveUnsatisfiable, '
          'userDivergence, or processingBlocked',
        );
      }
      reasons.add(reason);
    }
    if (status == DayStatusKind.attentionNeeded && reasons.isEmpty) {
      throw const DayAgentDirectiveException(
        'attentionNeeded requires at least one typed reason',
      );
    }
    if (status != DayStatusKind.attentionNeeded && reasons.isNotEmpty) {
      throw const DayAgentDirectiveException(
        'reasons are only valid with attentionNeeded',
      );
    }
    return reasons;
  }

  List<DayDirectiveCommitment> _parseCommitments(
    Object? raw,
    DateTime planDate,
  ) {
    final entries = objectListArg(raw, 'commitments');
    if (entries.length > maxCommitments) {
      throw const DayAgentDirectiveException(
        'commitments must contain at most $maxCommitments entries — '
        'distill, do not dump',
      );
    }
    return [
      for (final entry in entries) _parseCommitment(entry, planDate),
    ];
  }

  DayDirectiveCommitment _parseCommitment(Object? raw, DateTime planDate) {
    if (raw is! Map) {
      throw const DayAgentDirectiveException('commitment must be an object');
    }
    final data = raw.cast<String, dynamic>();
    final sourceName = requiredStringArg(data, 'source');
    final source = optionalEnumArg(DayCommitmentSource.values, sourceName);
    if (source == null) {
      throw const DayAgentDirectiveException(
        'commitment source must be attentionAward, standingAgreement, '
        'userCommitment, or carryOver',
      );
    }
    final windowStart = optionalDateTimeArg(data['windowStart']);
    final windowEnd = optionalDateTimeArg(data['windowEnd']);
    if ((windowStart == null) != (windowEnd == null)) {
      throw const DayAgentDirectiveException(
        'commitment windowStart and windowEnd must be set together',
      );
    }
    if (windowStart != null && windowEnd != null) {
      if (!windowEnd.isAfter(windowStart)) {
        throw const DayAgentDirectiveException(
          'commitment windowEnd must be after windowStart',
        );
      }
      final dayStart = localDay(planDate);
      final dayEnd = dayStart.add(const Duration(days: 1));
      if (windowStart.isBefore(dayStart) || windowEnd.isAfter(dayEnd)) {
        throw const DayAgentDirectiveException(
          'commitment windows must stay within the directive day',
        );
      }
    }
    final minutes = optionalIntArg(data['minutes']);
    if (minutes != null && (minutes <= 0 || minutes > 24 * 60)) {
      throw const DayAgentDirectiveException(
        'commitment minutes must be between 1 and 1440',
      );
    }
    return DayDirectiveCommitment(
      id: requiredStringArg(data, 'id'),
      source: source,
      title: requiredStringArg(data, 'title'),
      windowStart: windowStart,
      windowEnd: windowEnd,
      minutes: minutes,
      evidenceRefs: stringListArg(data['evidenceRefs']),
    );
  }

  DayCapacityBudget? _parseCapacityBudget(Object? raw, DateTime planDate) {
    if (raw == null) return null;
    if (raw is! Map) {
      throw const DayAgentDirectiveException(
        'capacityBudget must be an object',
      );
    }
    final data = raw.cast<String, dynamic>();
    final availableMinutes = optionalIntArg(data['availableMinutes']);
    if (availableMinutes == null ||
        availableMinutes <= 0 ||
        availableMinutes > 24 * 60) {
      throw const DayAgentDirectiveException(
        'capacityBudget.availableMinutes must be between 1 and 1440',
      );
    }
    final alreadyScheduled = optionalIntArg(data['alreadyScheduledMinutes']);
    if (alreadyScheduled != null && alreadyScheduled < 0) {
      throw const DayAgentDirectiveException(
        'capacityBudget.alreadyScheduledMinutes must not be negative',
      );
    }
    return DayCapacityBudget(
      availableMinutes: availableMinutes,
      alreadyScheduledMinutes: alreadyScheduled ?? 0,
      energyBands: [
        for (final band in objectListArg(data['energyBands'], 'energyBands'))
          parseEnergyBand(raw: band, day: planDate),
      ],
    );
  }

  List<DayCarryOverItem> _parseCarryOver(Object? raw) {
    final entries = objectListArg(raw, 'carryOver');
    if (entries.length > maxCarryOverItems) {
      throw const DayAgentDirectiveException(
        'carryOver must contain at most $maxCarryOverItems entries',
      );
    }
    return [
      for (final entry in entries) _parseCarryOverItem(entry),
    ];
  }

  DayCarryOverItem _parseCarryOverItem(Object? raw) {
    if (raw is! Map) {
      throw const DayAgentDirectiveException(
        'carryOver entry must be an object',
      );
    }
    final data = raw.cast<String, dynamic>();
    final reason = requiredStringArg(data, 'reason');
    if (reason.length > maxNoteLength) {
      throw const DayAgentDirectiveException(
        'carryOver reason must be at most $maxNoteLength characters',
      );
    }
    return DayCarryOverItem(
      title: requiredStringArg(data, 'title'),
      reason: reason,
      taskId: optionalStringArg(data['taskId']),
      itemId: optionalStringArg(data['itemId']),
    );
  }

  List<String> _boundedNotes(Object? raw, String name) {
    final notes = stringListArg(raw);
    if (notes.length > maxNotes) {
      throw DayAgentDirectiveException(
        '$name must contain at most $maxNotes entries',
      );
    }
    for (final note in notes) {
      if (note.length > maxNoteLength) {
        throw DayAgentDirectiveException(
          '$name entries must be at most $maxNoteLength characters',
        );
      }
    }
    return notes;
  }
}
