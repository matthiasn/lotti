import 'dart:developer' as developer;

import 'package:lotti/database/database.dart';

/// Simple conflict detection for AI operations to prevent multiple concurrent
/// AI processes from interfering with each other.
///
/// This uses an in-memory tracking approach that's lightweight and sufficient
/// for detecting most concurrent AI operations on the same task.
class AiConflictDetector {
  AiConflictDetector(this._db);
  final JournalDb _db;

  /// Check if a task was modified recently after a given timestamp.
  ///
  /// This is useful for detecting if another process (user or AI) modified
  /// the task while our AI operation was running.
  ///
  /// [taskId] - The task to check
  /// [since] - Check if modified after this timestamp
  ///
  /// Returns true if the task was modified after the timestamp, or if the task was deleted.
  Future<bool> hasRecentModification(
    String taskId,
    DateTime since,
  ) async {
    try {
      final entity = await _db.entityById(taskId);
      if (entity == null) {
        developer.log(
          'Task $taskId was deleted during AI operation',
          name: 'AiConflictDetector',
        );
        return true; // Task was deleted
      }

      final wasModified = entity.updatedAt.isAfter(since);
      if (wasModified) {
        developer.log(
          'Task $taskId was modified during AI operation: '
          'expected before ${since.toIso8601String()}, '
          'but updated at ${entity.updatedAt.toIso8601String()}',
          name: 'AiConflictDetector',
        );
      }

      return wasModified;
    } catch (e) {
      developer.log(
        'Error checking recent modification for task $taskId: $e',
        name: 'AiConflictDetector',
        error: e,
      );
      return true; // Assume conflict on error
    }
  }

  // In-memory tracking of active AI operations
  // Format: taskId -> {startTime, operationType}
  static final Map<String, ActiveOperation> _activeOperations = {};

  /// Mark an AI operation as starting on a specific task.
  ///
  /// This helps detect when multiple AI operations are trying to work
  /// on the same task simultaneously.
  ///
  /// [taskId] - The task being operated on
  /// [operationType] - Type of operation (e.g., 'task_summary', 'action_items')
  ///
  /// Returns false if another operation is already active, true if successfully marked.
  static bool markOperationStart(String taskId, String operationType) {
    // Clean up any stale operations first
    _cleanupStaleOperations();

    // Check if another operation is already active
    final existing = _activeOperations[taskId];
    if (existing != null) {
      developer.log(
        'AI operation conflict: $operationType on $taskId blocked by existing ${existing.operationType} '
        '(started ${DateTime.now().difference(existing.startTime).inSeconds}s ago)',
        name: 'AiConflictDetector',
      );
      return false;
    }

    // Mark this operation as active
    _activeOperations[taskId] = ActiveOperation(
      startTime: DateTime.now(),
      operationType: operationType,
    );

    developer.log(
      'Marked AI operation as active: $operationType on $taskId',
      name: 'AiConflictDetector',
    );

    return true;
  }

  /// Mark an AI operation as complete.
  ///
  /// This should always be called when an AI operation finishes,
  /// whether it succeeded or failed.
  ///
  /// [taskId] - The task that was being operated on
  static void markOperationComplete(String taskId) {
    final removed = _activeOperations.remove(taskId);
    if (removed != null) {
      final duration = DateTime.now().difference(removed.startTime);
      developer.log(
        'Marked AI operation as complete: ${removed.operationType} on $taskId '
        '(duration: ${duration.inMilliseconds}ms)',
        name: 'AiConflictDetector',
      );
    }
  }

  /// Check if an AI operation is currently active on a task.
  ///
  /// [taskId] - The task to check
  ///
  /// Returns true if another AI operation is active, false otherwise.
  static bool hasActiveOperation(String taskId) {
    _cleanupStaleOperations();

    final operation = _activeOperations[taskId];
    return operation != null;
  }

  /// Get information about the currently active operation on a task.
  ///
  /// [taskId] - The task to check
  ///
  /// Returns operation info if active, null otherwise.
  static ActiveOperation? getActiveOperation(String taskId) {
    _cleanupStaleOperations();
    return _activeOperations[taskId];
  }

  /// Clean up operations that have been running for too long.
  ///
  /// This prevents memory leaks and handles cases where operations
  /// crash without calling markOperationComplete().
  static void _cleanupStaleOperations() {
    final now = DateTime.now();
    const staleThreshold =
        Duration(minutes: 10); // Consider operations stale after 10 minutes

    final staleEntries = _activeOperations.entries.where((entry) {
      return now.difference(entry.value.startTime) > staleThreshold;
    }).toList();

    for (final entry in staleEntries) {
      developer.log(
        'Cleaning up stale AI operation: ${entry.value.operationType} on ${entry.key} '
        '(started ${now.difference(entry.value.startTime).inMinutes} minutes ago)',
        name: 'AiConflictDetector',
      );
      _activeOperations.remove(entry.key);
    }
  }

  /// Get statistics about currently active operations.
  ///
  /// Useful for monitoring and debugging.
  static Map<String, dynamic> getStats() {
    _cleanupStaleOperations();

    final now = DateTime.now();
    final operations = _activeOperations.entries.map((entry) {
      return {
        'taskId': entry.key,
        'operationType': entry.value.operationType,
        'durationSeconds': now.difference(entry.value.startTime).inSeconds,
      };
    }).toList();

    return {
      'activeOperations': operations.length,
      'operations': operations,
    };
  }

  /// Clear all active operations.
  ///
  /// This should only be used for testing or emergency cleanup.
  static void clearAll() {
    developer.log(
      'Clearing all active AI operations (${_activeOperations.length} operations)',
      name: 'AiConflictDetector',
    );
    _activeOperations.clear();
  }
}

/// Internal class to track active AI operations.
class ActiveOperation {
  const ActiveOperation({
    required this.startTime,
    required this.operationType,
  });

  final DateTime startTime;
  final String operationType;
}
