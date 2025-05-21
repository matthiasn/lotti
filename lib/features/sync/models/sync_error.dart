import 'package:lotti/services/logging_service.dart';

enum SyncErrorType {
  database,
  network,
  outbox,
  unknown,
}

class SyncError {
  SyncError({
    required this.type,
    required this.message,
    this.originalError,
    this.stackTrace,
  });

  factory SyncError.fromException(
    Object error,
    StackTrace? stackTrace,
    LoggingService loggingService, {
    String domain = 'SYNC_CONTROLLER',
  }) {
    // Log the full error and stack trace for debugging
    loggingService.captureException(
      error,
      domain: domain,
      stackTrace: stackTrace,
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
