import 'package:lotti/services/domain_logging.dart';

/// Coarse classification of a sync failure, used to pick a user-facing
/// message and to group errors in diagnostics.
enum SyncErrorType {
  database,
  network,
  outbox,
  unknown,
}

/// A sync failure paired with a user-friendly [message] and its [type].
///
/// Retains the [originalError]/[stackTrace] for diagnostics while exposing a
/// localised-intent message via [toString]. Build instances through
/// [SyncError.fromException], which classifies the error and logs the raw
/// detail before discarding it from the UI surface.
class SyncError {
  SyncError({
    required this.type,
    required this.message,
    this.originalError,
    this.stackTrace,
  });

  /// Classifies [error] into a [SyncErrorType] (by inspecting its string form),
  /// logs the full error + [stackTrace] via [loggingService], and returns a
  /// [SyncError] carrying a user-friendly message for that type.
  factory SyncError.fromException(
    Object error,
    StackTrace? stackTrace,
    DomainLogger loggingService,
  ) {
    // Log the full error and stack trace for debugging
    loggingService.error(
      LogDomain.sync,
      error,
      stackTrace: stackTrace,
      subDomain: 'SYNC_CONTROLLER',
    );

    // Determine error type based on the error object
    final type = _determineErrorType(error);

    // Create a user-friendly message
    final message = _createUserFriendlyMessage(error, type);

    return SyncError(
      type: type,
      message: message,
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  final SyncErrorType type;
  final String message;
  final Object? originalError;
  final StackTrace? stackTrace;

  static SyncErrorType _determineErrorType(Object error) {
    if (error.toString().contains('database')) {
      return SyncErrorType.database;
    } else if (error.toString().contains('network') ||
        error.toString().contains('connection')) {
      return SyncErrorType.network;
    } else if (error.toString().contains('outbox')) {
      return SyncErrorType.outbox;
    }
    return SyncErrorType.unknown;
  }

  static String _createUserFriendlyMessage(Object error, SyncErrorType type) {
    switch (type) {
      case SyncErrorType.database:
        return 'Failed to access local data. Please try again.';
      case SyncErrorType.network:
        return 'Network connection issue. Please check your internet connection.';
      case SyncErrorType.outbox:
        return 'Failed to queue sync items. Please try again.';
      case SyncErrorType.unknown:
        return 'An unexpected error occurred. Please try again.';
    }
  }

  @override
  String toString() => message;
}
