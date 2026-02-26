import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:uuid/uuid.dart';

/// Result of processing a task status transition.
class TaskStatusResult {
  const TaskStatusResult({
    required this.success,
    required this.message,
    this.updatedTask,
    this.error,
    this.didWrite = false,
  });

  final bool success;
  final String message;
  final Task? updatedTask;
  final String? error;
  final bool didWrite;
  bool get wasNoOp => success && !didWrite;
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
  });

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

    developer.log(
      'Processing set_task_status: "$normalized"',
      name: 'TaskStatusHandler',
    );

    // Reject terminal statuses.
    if (terminalStatuses.contains(normalized)) {
      final message = 'Cannot set status to "$normalized": '
          'DONE and REJECTED are user-only statuses.';
      developer.log(message, name: 'TaskStatusHandler');
      return TaskStatusResult(
        success: false,
        message: message,
        error: message,
      );
    }

    // Validate against allowed statuses.
    if (!allowedStatuses.contains(normalized)) {
      final message = 'Unknown status: "$normalized". '
          'Valid statuses: ${allowedStatuses.join(", ")}';
      developer.log(message, name: 'TaskStatusHandler');
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
      developer.log(message, name: 'TaskStatusHandler');
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
      developer.log(
        'Status unchanged — skipping write',
        name: 'TaskStatusHandler',
      );
      return TaskStatusResult(
        success: true,
        message: message,
        updatedTask: task,
      );
    }

    // Build the new TaskStatus using clock.now() for testability.
    final now = clock.now();
    final newStatus = _buildStatus(
      normalized,
      now: now,
      reason: reason?.trim(),
    );

    final updatedTask = task.copyWith(
      data: task.data.copyWith(
        status: newStatus,
        statusHistory: [...task.data.statusHistory, newStatus],
      ),
    );

    try {
      final success = await journalRepository.updateJournalEntity(updatedTask);

      if (!success) {
        const message = 'Failed to update status: repository returned false.';
        developer.log(message, name: 'TaskStatusHandler');
        return const TaskStatusResult(
          success: false,
          message: message,
          error: message,
        );
      }

      task = updatedTask;

      final message =
          'Task status changed from "$currentDbString" to "$normalized".';
      developer.log(
        'Successfully transitioned task status to "$normalized"',
        name: 'TaskStatusHandler',
      );

      return TaskStatusResult(
        success: true,
        message: message,
        updatedTask: updatedTask,
        didWrite: true,
      );
    } catch (e, s) {
      const message =
          'Failed to update status. Continuing without status change.';
      developer.log(
        'Failed to update task status',
        name: 'TaskStatusHandler',
        error: e,
        stackTrace: s,
      );

      return TaskStatusResult(
        success: false,
        message: message,
        error: e.toString(),
      );
    }
  }

  /// Converts a [TaskStatusResult] to a [ToolExecutionResult].
  static ToolExecutionResult toToolExecutionResult(
    TaskStatusResult result, {
    String? entityId,
  }) {
    return ToolExecutionResult(
      success: result.success,
      output: result.message,
      mutatedEntityId: result.didWrite ? entityId : null,
      errorMessage: result.error,
    );
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
