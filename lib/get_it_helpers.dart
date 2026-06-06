part of 'get_it.dart';

/// Helper function to lazily register services that might fail in sandboxed environments
/// Services are only created on first access, with safe error handling
void _registerLazyServiceSafely<T extends Object>(
  T Function() factory,
  String serviceName,
) {
  try {
    // Proactively prevent duplicate registration regardless of
    // GetIt's global allowReassignment flag, to keep semantics strict
    // and predictable across optimized test runners.
    if (getIt.isRegistered<T>()) {
      _safeLog(
        'Failed to register lazy $serviceName: already registered',
        isError: true,
      );
      return;
    }
    getIt.registerLazySingleton<T>(() {
      try {
        final instance = factory();
        _safeLog(
          'Successfully created lazy instance of $serviceName',
          isError: false,
        );
        return instance;
      } catch (e) {
        _safeLog(
          'Failed to create lazy instance of $serviceName: $e',
          isError: true,
        );
        rethrow; // Let GetIt handle the failure appropriately
      }
    });
    _safeLog('Successfully registered lazy $serviceName', isError: false);
  } catch (e) {
    _safeLog('Failed to register lazy $serviceName: $e', isError: true);
  }
}

/// Safe logging helper that falls back to DevLogger if LoggingService is unavailable
void _safeLog(String message, {required bool isError}) {
  try {
    if (getIt.isRegistered<DomainLogger>()) {
      final domainLogger = getIt<DomainLogger>();
      if (isError) {
        // error() is never gated on enabledDomains, so a registration failure
        // is always recorded even when the settings domain is toggled off.
        domainLogger.error(
          LogDomain.settings,
          message,
          subDomain: 'error',
        );
      } else {
        domainLogger.log(
          LogDomain.settings,
          message,
          subDomain: 'SERVICE_REGISTRATION',
        );
      }
    } else {
      // Fallback to DevLogger if LoggingService not available
      if (isError) {
        DevLogger.error(
          name: 'SERVICE_REGISTRATION',
          message: message,
        );
      } else {
        DevLogger.log(
          name: 'SERVICE_REGISTRATION',
          message: message,
        );
      }
    }
  } catch (e) {
    // Ultimate fallback if even the safe check fails
    DevLogger.error(
      name: 'SERVICE_REGISTRATION',
      message: '$message (logging failed: $e)',
    );
  }
}

@visibleForTesting
void registerLazyServiceForTesting<T extends Object>(
  T Function() factory,
  String serviceName,
) => _registerLazyServiceSafely(factory, serviceName);

@visibleForTesting
void safeLogForTesting(String message, {required bool isError}) =>
    _safeLog(message, isError: isError);
