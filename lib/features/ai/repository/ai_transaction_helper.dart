import 'dart:developer' as developer;

import 'package:lotti/database/database.dart';

/// Helper class for executing AI operations with transaction safety and retry logic.
///
/// This provides a simple way to handle concurrent modifications by:
/// 1. Wrapping operations in database transactions for atomic rollback
/// 2. Detecting conflicts (vector clock conflicts, database locks, etc.)
/// 3. Retrying failed operations with exponential backoff
/// 4. Logging detailed information for debugging
class AiTransactionHelper {
  AiTransactionHelper(this._db);
  final JournalDb _db;

  /// Execute AI operation with transaction safety and automatic retry on conflicts.
  ///
  /// This method wraps the operation in a database transaction and automatically
  /// retries if conflicts are detected (vector clock conflicts, database locks, etc.).
  ///
  /// [operation] - The operation to execute (should read current state and update)
  /// [maxRetries] - Maximum number of retry attempts (default: 3)
  /// [baseDelay] - Base delay between retries, doubles each attempt (default: 100ms)
  /// [operationName] - Name for logging purposes (e.g., 'task_summary_abc123')
  ///
  /// Returns the result of the operation or throws the final error if all retries fail.
  Future<T> executeWithRetry<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
    Duration baseDelay = const Duration(milliseconds: 100),
    String? operationName,
  }) async {
    var attempt = 0;
    var delay = baseDelay;

    while (attempt < maxRetries) {
      try {
        // Execute operation within database transaction for atomic rollback
        return await _db.transaction(() async {
          developer.log(
            'Executing AI operation (attempt ${attempt + 1}/$maxRetries): $operationName',
            name: 'AiTransactionHelper',
          );

          return operation();
        });
      } catch (e) {
        attempt++;

        // Check if this is a conflict we should retry
        if (_shouldRetry(e) && attempt < maxRetries) {
          developer.log(
            'AI operation conflict on attempt $attempt/$maxRetries for $operationName. '
            'Retrying in ${delay.inMilliseconds}ms... Error: $e',
            name: 'AiTransactionHelper',
          );

          // Wait before retrying with exponential backoff
          await Future<void>.delayed(delay);
          delay = Duration(milliseconds: (delay.inMilliseconds * 1.5).round());
          continue;
        }

        // Max retries reached or non-retryable error
        developer.log(
          'AI operation failed after $attempt attempts for $operationName: $e',
          name: 'AiTransactionHelper',
          error: e,
        );
        rethrow;
      }
    }

    throw StateError('Should not reach here - retry loop ended unexpectedly');
  }

  /// Check if an error indicates a conflict that's worth retrying.
  ///
  /// Returns true for:
  /// - Vector clock conflicts
  /// - Database lock conflicts
  /// - SQLite busy errors
  /// - General conflict-related errors
  bool _shouldRetry(Object error) {
    if (error is AiUpdateConflictException) {
      return true; // Always retry our custom conflict exceptions
    }

    // Check error message for common conflict indicators
    final message = error.toString().toLowerCase();
    return message.contains('conflict') ||
        message.contains('database is locked') ||
        message.contains('database is busy') ||
        message.contains('vector clock') ||
        message.contains('busy') ||
        message.contains('locked') ||
        message.contains('concurrent');
  }
}

/// Custom exception for AI update conflicts that should trigger retries.
///
/// Throw this exception when:
/// - Vector clock conflicts are detected
/// - Current task state differs from expected state
/// - Update operations fail due to concurrent modifications
class AiUpdateConflictException implements Exception {
  const AiUpdateConflictException(
    this.message, {
    this.taskId,
    this.operationType,
  });
  final String message;
  final String? taskId;
  final String? operationType;

  @override
  String toString() {
    final parts = ['AiUpdateConflictException: $message'];
    if (taskId != null) parts.add('taskId: $taskId');
    if (operationType != null) parts.add('operation: $operationType');
    return parts.join(', ');
  }
}
