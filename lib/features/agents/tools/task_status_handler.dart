import 'package:clock/clock.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/logging_types.dart';
import 'package:lotti/logic/repositories/journal_repository.dart';
import 'package:lotti/logic/repositories/task_field_write.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:uuid/uuid.dart';

/// Result of processing a task status transition.
class TaskStatusResult {
  const TaskStatusResult({
    required this.success,
    required this.message,
    this.error,
    this.didWrite = false,
  });

  final bool success;
  final String message;
  final String? error;
  final bool didWrite;
}

/// Handler for transitioning the status of a task.
///
/// Validates the requested status string, enforces agent-accessible statuses
/// (DONE and REJECTED are user-only), requires a reason for BLOCKED and
/// ON HOLD, detects no-op transitions, and persists the update via
/// [JournalRepository].
///
/// Uses [clock.now()] from the `clock` package for testability instead of
/// `DateTime.now()`.
class TaskStatusHandler {
  TaskStatusHandler({
    required this.task,
    required this.journalRepository,
    required this._domainLogger,
  });

  /// Receives the handler's traces and failures.
  final DomainLogger _domainLogger;

  Task task;
  final JournalRepository journalRepository;

  static const _uuid = Uuid();

  /// Status strings the agent is allowed to set.
  static const allowedStatuses = {
    'OPEN',
    'IN PROGRESS',
    'GROOMED',
    'BLOCKED',
    'ON HOLD',
  };

  /// Status strings reserved for user-only transitions.
  static const terminalStatuses = {'DONE', 'REJECTED'};

  /// Transitions the task to [statusString].
  ///
  /// [reason] is required for BLOCKED and ON HOLD statuses.
  Future<TaskStatusResult> handle(
    String statusString, {
    String? reason,
  }) async {
    final normalized = statusString.trim().toUpperCase();

    _domainLogger.log(
      LogDomain.agentWorkflow,
      'Processing set_task_status: chars=${normalized.length}',
      subDomain: 'TaskStatusHandler',
    );

    // Reject terminal statuses.
    if (terminalStatuses.contains(normalized)) {
      final message =
          'Cannot set status to "$normalized": '
          'DONE and REJECTED are user-only statuses.';
      _domainLogger.log(
        LogDomain.agentWorkflow,
        'Rejected terminal status',
        subDomain: 'TaskStatusHandler',
        level: InsightLevel.warn,
      );
      return TaskStatusResult(
        success: false,
        message: message,
        error: message,
      );
    }

    // Validate against allowed statuses.
    if (!allowedStatuses.contains(normalized)) {
      final message =
          'Unknown status: "$normalized". '
          'Valid statuses: ${allowedStatuses.join(", ")}';
      _domainLogger.log(
        LogDomain.agentWorkflow,
        'Rejected unsupported status',
        subDomain: 'TaskStatusHandler',
        level: InsightLevel.warn,
      );
      return TaskStatusResult(
        success: false,
        message: message,
        error: message,
      );
    }

    // Require reason for BLOCKED and ON HOLD.
    if ((normalized == 'BLOCKED' || normalized == 'ON HOLD') &&
        (reason == null || reason.trim().isEmpty)) {
      final message =
          'Status "$normalized" requires a reason. Please provide one.';
      _domainLogger.log(
        LogDomain.agentWorkflow,
        'Rejected status transition with missing reason',
        subDomain: 'TaskStatusHandler',
        level: InsightLevel.warn,
      );
      return TaskStatusResult(
        success: false,
        message: message,
        error: message,
      );
    }

    // No-op if already in target status.
    final currentDbString = task.data.status.toDbString;
    if (currentDbString == normalized) {
      final message = 'Task is already "$normalized". No change needed.';
      _domainLogger.log(
        LogDomain.agentWorkflow,
        'Status unchanged — skipping write',
        subDomain: 'TaskStatusHandler',
      );
      return TaskStatusResult(
        success: true,
        message: message,
      );
    }

    // Build the new TaskStatus using clock.now() for testability.
    final now = clock.now();
    final newStatus = _buildStatus(
      normalized,
      now: now,
      reason: reason?.trim(),
    );

    try {
      final write = await writeTaskField(
        journalRepository: journalRepository,
        task: task,
        field: (data) => data.status.toDbString,
        set: (stored) => stored.withStatus(newStatus),
      );

      switch (write) {
        case TaskFieldWriteFailed():
          const message = 'Failed to update status: repository returned false.';
          _domainLogger.log(
            LogDomain.agentWorkflow,
            message,
            subDomain: 'TaskStatusHandler',
            level: InsightLevel.warn,
          );
          return const TaskStatusResult(
            success: false,
            message: message,
            error: message,
          );
        case TaskFieldMoved(task: final stored):
          task = stored;
          final message =
              "Nothing applied: the task's status changed to "
              '${stored.data.status.toDbString} since this call read it, '
              'so it stays as it is.';
          _domainLogger.log(
            LogDomain.agentWorkflow,
            message,
            subDomain: 'TaskStatusHandler',
          );
          return TaskStatusResult(success: true, message: message);
        case TaskFieldWritten(task: final stored):
          task = stored;
      }

      final message =
          'Task status changed from "$currentDbString" to "$normalized".';
      _domainLogger.log(
        LogDomain.agentWorkflow,
        'Successfully transitioned task status',
        subDomain: 'TaskStatusHandler',
      );

      return TaskStatusResult(
        success: true,
        message: message,
        didWrite: true,
      );
    } catch (e, s) {
      const message =
          'Failed to update status. Continuing without status change.';
      _domainLogger.error(
        LogDomain.agentWorkflow,
        e,
        stackTrace: s,
        subDomain: 'TaskStatusHandler',
        message: 'Failed to update task status',
      );

      return TaskStatusResult(
        success: false,
        message: message,
        error: e.toString(),
      );
    }
  }

  /// Builds a [TaskStatus] from a validated status string.
  ///
  /// Uses [clock.now()] instead of [DateTime.now()] for testability.
  static TaskStatus _buildStatus(
    String status, {
    required DateTime now,
    String? reason,
  }) {
    final id = _uuid.v1();
    final utcOffset = now.timeZoneOffset.inMinutes;

    return switch (status) {
      'IN PROGRESS' => TaskStatus.inProgress(
        id: id,
        createdAt: now,
        utcOffset: utcOffset,
      ),
      'GROOMED' => TaskStatus.groomed(
        id: id,
        createdAt: now,
        utcOffset: utcOffset,
      ),
      'BLOCKED' => TaskStatus.blocked(
        id: id,
        createdAt: now,
        utcOffset: utcOffset,
        reason: reason ?? 'No reason provided',
      ),
      'ON HOLD' => TaskStatus.onHold(
        id: id,
        createdAt: now,
        utcOffset: utcOffset,
        reason: reason ?? 'No reason provided',
      ),
      _ => TaskStatus.open(
        id: id,
        createdAt: now,
        utcOffset: utcOffset,
      ),
    };
  }
}
