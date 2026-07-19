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

/// Registers late-loaded, sandbox-fragile and optional services (audio
/// waveform, the label pipeline, the local embedding pipeline) plus the
/// one-time sequence-log backfill. Split from [registerSingletons] for file
/// size; every dependency is resolved through [getIt], so no state is
/// threaded in from the caller.
Future<void> _registerLateAndOptionalServices() async {
  // Register services that might fail in sandboxed environments using lazy loading
  _registerLazyServiceSafely<AudioWaveformService>(
    AudioWaveformService.new,
    'AudioWaveformService',
  );

  unawaited(getIt<MatrixService>().init());

  // Label validator used by the assignment processor
  _registerLazyServiceSafely<LabelValidator>(
    LabelValidator.new,
    'LabelValidator',
  );

  // Label assignment processor
  _registerLazyServiceSafely<LabelAssignmentProcessor>(
    LabelAssignmentProcessor.new,
    'LabelAssignmentProcessor',
  );

  // Label assignment event service for UI notifications
  _registerLazyServiceSafely<LabelAssignmentEventService>(
    LabelAssignmentEventService.new,
    'LabelAssignmentEventService',
  );

  // Embedding generation pipeline (Ollama-based, local).
  // If the backend fails to initialize, the pipeline is non-essential
  // and the app should still start.
  // coverage:ignore-start
  try {
    final embeddingStore = await openShardedEmbeddingStore(
      documentsPath: getIt<Directory>().path,
    );
    getIt
      ..registerSingleton<EmbeddingStore>(
        embeddingStore,
        dispose: (store) => store.close(),
      )
      ..registerSingleton<OllamaEmbeddingRepository>(
        OllamaEmbeddingRepository(),
        dispose: (repo) => repo.close(),
      )
      ..registerSingleton<EmbeddingService>(
        EmbeddingService(
          embeddingStore: embeddingStore,
          embeddingRepository: getIt<OllamaEmbeddingRepository>(),
          journalDb: getIt<JournalDb>(),
          updateNotifications: getIt<UpdateNotifications>(),
          aiConfigRepository: getIt<AiConfigRepository>(),
        ),
        dispose: (svc) async => svc.stop(),
      )
      ..registerSingleton<VectorSearchRepository>(
        VectorSearchRepository(
          embeddingStore: embeddingStore,
          embeddingRepository: getIt<OllamaEmbeddingRepository>(),
          journalDb: getIt<JournalDb>(),
          aiConfigRepository: getIt<AiConfigRepository>(),
        ),
      );

    getIt<EmbeddingService>().start();
    _safeLog('Embedding pipeline initialized successfully', isError: false);
  } catch (e, stackTrace) {
    if (getIt.isRegistered<DomainLogger>()) {
      getIt<DomainLogger>().error(
        LogDomain.ai,
        e,
        stackTrace: stackTrace,
        subDomain: 'embedding_pipeline_init',
      );
    }
    _safeLog(
      'Embedding pipeline unavailable: $e',
      isError: true,
    );
  }
  // coverage:ignore-end

  // Automatically populate sequence log if empty (one-time migration)
  unawaited(_checkAndPopulateSequenceLog());
}
