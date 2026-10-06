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

/// Logs a service-registration outcome to the [DomainLogger].
///
/// `registerSingletons` registers the logger before its first
/// [_registerLazyServiceSafely], so it is always available here. Errors are
/// never gated on the settings domain flag; successes are.
void _safeLog(String message, {required bool isError}) {
  final domainLogger = getIt<DomainLogger>();
  if (isError) {
    domainLogger.error(LogDomain.settings, message, subDomain: 'error');
  } else {
    domainLogger.log(
      LogDomain.settings,
      message,
      subDomain: 'SERVICE_REGISTRATION',
    );
  }
}

/// Registers late-loaded, sandbox-fragile and optional services (audio
/// waveform, the label pipeline, the local embedding pipeline) plus the
/// speech dictionary migration and the one-time sequence-log backfill. Split
/// from [registerSingletons] for file size; every dependency is resolved
/// through [getIt], so no state is threaded in from the caller.
Future<void> _registerLateAndOptionalServices({
  required ProfileContext profile,
}) async {
  // Register services that might fail in sandboxed environments using lazy loading
  _registerLazyServiceSafely<AudioWaveformService>(
    AudioWaveformService.new,
    'AudioWaveformService',
  );

  // Guest worlds have no MatrixService registered — the sync stack is
  // structurally absent, so there is nothing to init.
  if (profile.capabilities.syncEnabled) {
    getIt<StartupTasks>().track(getIt<MatrixService>().init());
  }

  getIt<StartupTasks>().track(_migrateSpeechDictionary());

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
      // One instance for every caller, so its per-endpoint availability
      // circuit is shared application-wide.
      ..registerSingleton<OllamaEmbeddingRepository>(
        OllamaEmbeddingRepository(domainLogger: getIt<DomainLogger>()),
        dispose: (repo) => repo.close(),
      )
      ..registerSingleton<EmbeddingService>(
        EmbeddingService(
          embeddingStore: embeddingStore,
          embeddingRepository: getIt<OllamaEmbeddingRepository>(),
          journalDb: getIt<JournalDb>(),
          updateNotifications: getIt<UpdateNotifications>(),
          aiConfigRepository: getIt<AiConfigRepository>(),
          domainLogger: getIt<DomainLogger>(),
        ),
        dispose: (svc) async => svc.stop(),
      )
      ..registerSingleton<VectorSearchRepository>(
        VectorSearchRepository(
          embeddingStore: embeddingStore,
          embeddingRepository: getIt<OllamaEmbeddingRepository>(),
          journalDb: getIt<JournalDb>(),
          aiConfigRepository: getIt<AiConfigRepository>(),
          domainLogger: getIt<DomainLogger>(),
        ),
      );

    getIt<EmbeddingService>().start();
    _safeLog('Embedding pipeline initialized successfully', isError: false);
  } catch (e, stackTrace) {
    getIt<DomainLogger>().error(
      LogDomain.ai,
      e,
      stackTrace: stackTrace,
      subDomain: 'embedding_pipeline_init',
    );
  }
  // coverage:ignore-end

  // Automatically populate sequence log if empty (one-time migration).
  // Skipped in guest worlds: their sequence log stays empty because nothing
  // ever enqueues.
  if (profile.capabilities.syncEnabled) {
    getIt<StartupTasks>().track(_checkAndPopulateSequenceLog());
  }
}

/// The [VectorClockService] wired from the locator: the [SettingsDb] now, the
/// [SyncDatabase] and [DomainLogger] on each use, since sync and logging may
/// be registered after it (or, in a test, not at all).
VectorClockService buildVectorClockService() => VectorClockService(
  settingsDb: getIt<SettingsDb>(),
  syncDatabase: () =>
      getIt.isRegistered<SyncDatabase>() ? getIt<SyncDatabase>() : null,
  domainLogger: () =>
      getIt.isRegistered<DomainLogger>() ? getIt<DomainLogger>() : null,
);

/// The [Maintenance] wired from the locator. The search index is resolved on
/// use because rebuilding it registers a fresh one, and the integrity check
/// covers whichever databases this build registered.
Maintenance buildMaintenance() {
  MaintainedStore? store<T extends GeneratedDatabase>(String name) =>
      getIt.isRegistered<T>() ? (name: name, database: getIt<T>()) : null;
  return Maintenance(
    journalDb: getIt<JournalDb>(),
    domainLogger: getIt<DomainLogger>(),
    editorDb: getIt.get<EditorDb>,
    syncDatabase: getIt.get<SyncDatabase>,
    fts5Db: getIt.get<Fts5Db>,
    replaceFts5Db: () {
      getIt
        ..unregister<Fts5Db>()
        ..registerSingleton<Fts5Db>(Fts5Db());
      return getIt<Fts5Db>();
    },
    integrityStores: () => [
      ?store<JournalDb>('journal'),
      ?store<SyncDatabase>('sync'),
      ?store<AgentDatabase>('agent'),
      ?store<EditorDb>('editor'),
      ?store<Fts5Db>('search'),
    ],
    agentDatabase: () =>
        getIt.isRegistered<AgentDatabase>() ? getIt<AgentDatabase>() : null,
    editorStateService: () => getIt.isRegistered<EditorStateService>()
        ? getIt<EditorStateService>()
        : null,
  );
}

/// The services the persistence collaborators reach, resolved from the
/// locator on each use.
PersistenceServices buildPersistenceServices() => PersistenceServices(
  journalDb: getIt.get<JournalDb>,
  metadataService: getIt.get<MetadataService>,
  vectorClockService: getIt.get<VectorClockService>,
  geolocationService: getIt.get<GeolocationService>,
  domainLogger: getIt.get<DomainLogger>,
  updateNotifications: getIt.get<UpdateNotifications>,
  outboxService: getIt.get<OutboxService>,
  fts5Db: getIt.get<Fts5Db>,
  notificationService: getIt.get<NotificationService>,
  configFlagEffects: getIt.get<ConfigFlagEffects>,
);

/// The services [JournalRepository] reaches, resolved from the locator on
/// each use.
JournalRepositoryServices buildJournalRepositoryServices() =>
    JournalRepositoryServices(
      journalDb: getIt.get<JournalDb>,
      persistenceLogic: getIt.get<PersistenceLogic>,
      domainLogger: getIt.get<DomainLogger>,
      timeService: getIt.get<TimeService>,
      notificationService: getIt.get<NotificationService>,
      vectorClockService: getIt.get<VectorClockService>,
      updateNotifications: getIt.get<UpdateNotifications>,
      outboxService: getIt.get<OutboxService>,
      relationshipCascade: getIt.get<RelationshipCascadeFactory>,
    );

/// A [JournalRepository] over [buildJournalRepositoryServices], for the
/// composition root's own wiring.
JournalRepository buildJournalRepository() =>
    JournalRepository(buildJournalRepositoryServices());

/// The [PersistenceLogic] facade over [buildPersistenceServices].
PersistenceLogic buildPersistenceLogic() =>
    PersistenceLogic(services: buildPersistenceServices());

/// [LiveWorldServices] over getIt, which always holds the generation that is
/// live right now — so each read follows a profile switch.
final class GetItLiveWorldServices implements LiveWorldServices {
  const GetItLiveWorldServices();

  @override
  ProfileContext? get profileContext =>
      getIt.isRegistered<ProfileContext>() ? getIt<ProfileContext>() : null;

  @override
  JournalDb get journalDb => getIt<JournalDb>();

  @override
  AiConfigRepository get aiConfigs => getIt<AiConfigRepository>();

  @override
  Directory get root => getIt<Directory>();

  @override
  PersistenceLogic get persistence => getIt<PersistenceLogic>();

  @override
  Fts5Db? get fts => getIt.isRegistered<Fts5Db>() ? getIt<Fts5Db>() : null;

  @override
  DomainLogger? get domainLogger =>
      getIt.isRegistered<DomainLogger>() ? getIt<DomainLogger>() : null;
}

/// The production notification tap handler: hands the payload to the
/// registered [NotificationTapHandler].
///
/// Resolved at tap time rather than bound at construction. The notification
/// service is registered lazily and ahead of the router, and
/// `registerSingletons` rebuilds the router for every profile generation, so a
/// tap has to find the router that is live *now*. A tap with nowhere to go is
/// logged, never thrown: this runs inside the plugin's channel handler. During
/// a profile switch the locator can be empty, logger included, and such a tap
/// is dropped silently.
void routeNotificationTap(String payload) {
  if (!getIt.isRegistered<NotificationTapHandler>()) {
    if (!getIt.isRegistered<DomainLogger>()) return;
    getIt<DomainLogger>().log(
      LogDomain.notifications,
      'a notification tap arrived before the tap router was registered',
      subDomain: 'tap',
      level: InsightLevel.warn,
    );
    return;
  }
  unawaited(getIt<NotificationTapHandler>().handleTap(payload));
}
