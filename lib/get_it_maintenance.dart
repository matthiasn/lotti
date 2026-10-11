part of 'get_it.dart';

/// Automatically populate the sequence log if it's empty and the journal has
/// entries. This is a one-time migration for existing installations that
/// predates the sequence log feature.
///
/// This enables proper backfill responses - without the sequence log populated,
/// a device can't respond to backfill requests from other devices for historical
/// entries.
///
/// V2 adds agent entities and links to the population, which were missing in V1.
/// Devices that already ran V1 will re-run with the full set of data sources.
///
/// It runs once more after the sync database was restored from a backup
/// (`sync.sqlite.restored`, written by `restoreDatabaseFromBackup`): the
/// restored log lacks every row written after the snapshot, and an own
/// counter with no row is answered as burned, so a peer would give up on
/// payloads this device still holds (ADR 0135).
Future<void> _checkAndPopulateSequenceLog() async {
  // Bumped from 'maintenance_sequenceLogPopulated' to V2 so devices that
  // ran V1 (journal + links only) will re-run with agent data included.
  const settingsKey = 'maintenance_sequenceLogPopulatedV2';
  const restoreKey = 'maintenance_sequenceLogRestoreRepopulated';
  final settingsDb = getIt<SettingsDb>();
  final domainLogger = getIt<DomainLogger>();

  try {
    final restore = await _syncDbRestoreMarker();
    final hasRun = await settingsDb.itemByKey(settingsKey);
    if (hasRun == 'true' &&
        (restore == null ||
            restore == await settingsDb.itemByKey(restoreKey))) {
      return;
    }
    Future<void> markDone() async {
      await settingsDb.saveSettingsItem(settingsKey, 'true');
      if (restore != null) {
        await settingsDb.saveSettingsItem(restoreKey, restore);
      }
    }

    final syncDatabase = getIt<SyncDatabase>();
    final journalDb = getIt<JournalDb>();
    final agentDb = getIt<AgentDatabase>();
    final notificationsDb = getIt<NotificationsDb>();
    final consumptionDb = getIt<ConsumptionDatabase>();
    final aiConfigDb = getIt<AiConfigRepository>().configDb;

    // The payloads every other sequence-tracked family stores. A restore
    // loses their rows as much as the journal's.
    final recordSources = [
      (
        payloadType: SyncSequencePayloadType.notification,
        records: notificationsDb.streamNotificationsWithVectorClock,
        count: notificationsDb.countAllNotifications,
      ),
      (
        payloadType: SyncSequencePayloadType.consumptionEvent,
        records: consumptionDb.streamEventsWithVectorClock,
        count: consumptionDb.countAllEvents,
      ),
      (
        payloadType: SyncSequencePayloadType.entityDefinition,
        records: journalDb.streamDefinitionsWithVectorClock,
        count: journalDb.countAllDefinitions,
      ),
      (
        payloadType: SyncSequencePayloadType.aiConfig,
        records: aiConfigDb.streamVersionsWithVectorClock,
        count: aiConfigDb.countAllVersions,
      ),
    ];

    // Check current sequence log count
    final sequenceLogCount = await syncDatabase.getSequenceLogCount();

    // If already has significant entries, skip the threshold check — we still
    // need to populate agent data even if journal data is already present.
    // Only skip entirely if this V2 key has been set.

    // Check if there's any data that needs populating
    final journalCount = await journalDb.countAllJournalEntries();
    final linksCount = await journalDb.countAllEntryLinks();
    final agentEntityCount = await agentDb.countAllAgentEntities();
    final agentLinkCount = await agentDb.countAllAgentLinks();
    final recordCounts = [
      for (final source in recordSources) await source.count(),
    ];

    if (journalCount == 0 &&
        linksCount == 0 &&
        agentEntityCount == 0 &&
        agentLinkCount == 0 &&
        recordCounts.every((count) => count == 0)) {
      // Empty database, nothing to populate
      await markDone();
      return;
    }

    domainLogger.log(
      LogDomain.database,
      'Starting automatic sequence log population (V2): '
      'journal=$journalCount links=$linksCount '
      'agentEntities=$agentEntityCount agentLinks=$agentLinkCount '
      'other=$recordCounts sequenceLog=$sequenceLogCount',
      subDomain: 'sequenceLogPopulation',
    );

    final sequenceLogService = getIt<SyncSequenceLogService>();

    // Populate from journal entries
    final populatedJournal = await sequenceLogService.populateFromJournal(
      entryStream: journalDb.streamEntriesWithVectorClock(),
      getTotalCount: journalDb.countAllJournalEntries,
    );

    // Populate from entry links
    final populatedLinks = await sequenceLogService.populateFromEntryLinks(
      linkStream: journalDb.streamEntryLinksWithVectorClock(),
      getTotalCount: journalDb.countAllEntryLinks,
    );

    // Populate from agent entities
    final populatedAgentEntities = await sequenceLogService
        .populateFromAgentEntities(
          entityStream: agentDb.streamAgentEntitiesWithVectorClock(),
          getTotalCount: agentDb.countAllAgentEntities,
        );

    // Populate from agent links
    final populatedAgentLinks = await sequenceLogService.populateFromAgentLinks(
      linkStream: agentDb.streamAgentLinksWithVectorClock(),
      getTotalCount: agentDb.countAllAgentLinks,
    );

    final populatedRecords = [
      for (final source in recordSources)
        await sequenceLogService.populateFromRecords(
          payloadType: source.payloadType,
          records: source.records(),
          getTotalCount: source.count,
        ),
    ];

    // Mark as completed
    await markDone();

    domainLogger.log(
      LogDomain.database,
      'Automatic sequence log population (V2) completed: '
      'journal=$populatedJournal links=$populatedLinks '
      'agentEntities=$populatedAgentEntities agentLinks=$populatedAgentLinks '
      'other=$populatedRecords',
      subDomain: 'sequenceLogPopulation',
    );
  } catch (e, stackTrace) {
    domainLogger.error(
      LogDomain.database,
      e,
      stackTrace: stackTrace,
      subDomain: 'sequenceLogPopulation',
    );
    // Don't mark as completed on error - will retry on next startup
  }
}

/// The marker `restoreDatabaseFromBackup` leaves beside a restored sync
/// database — the time it restored it — or null when it never did.
Future<String?> _syncDbRestoreMarker() async {
  if (!getIt.isRegistered<Directory>()) return null;
  final marker = File('${getIt<Directory>().path}/$syncDbFileName.restored');
  return marker.existsSync() ? marker.readAsString() : null;
}

@visibleForTesting
Future<void> checkAndPopulateSequenceLogForTesting() =>
    _checkAndPopulateSequenceLog();

/// Stamps, once per device, the entity definitions and entry links saved
/// before they carried a vector clock, and sends them.
///
/// Until stamped, such a row stays outside clock comparison and backfill on
/// every device; the stamp was a manual action ("Repair vector clocks"),
/// so a device whose user never ran it kept them. Both repairs keep the
/// row's `updatedAt`, so two devices stamping the same row settle it the
/// same way and a stamp never outranks a genuine edit (ADR 0125). Agent
/// rows are left to the manual action: their stamp does not keep that
/// property. The flag ([clocklessRepairSettingsKey]) is set only after both
/// repairs succeed, so a failure retries at the next start. The inbound sync
/// path writes a fresh token under it whenever it stores a clockless row from
/// an older peer, and completion is recorded only if the token read before
/// the sweep is unchanged, so a row stored even mid-sweep leaves the next
/// start to sweep again.
Future<void> _repairClocklessRowsOnce() async {
  final settingsDb = getIt<SettingsDb>();
  final domainLogger = getIt<DomainLogger>();
  try {
    final token = await settingsDb.itemByKey(clocklessRepairSettingsKey);
    if (token == clocklessRepairDone) return;
    final vectorClockService = getIt<VectorClockService>();
    await vectorClockService.initialized;
    final repository = SyncMaintenanceRepository(
      journalDb: getIt<JournalDb>(),
      outboxService: getIt<OutboxService>(),
      loggingService: domainLogger,
      aiConfigRepository: getIt<AiConfigRepository>(),
      savedTaskFiltersRepository: getIt<SavedTaskFiltersRepository>(),
      agentRepository: AgentRepository(getIt<AgentDatabase>()),
      vectorClockService: vectorClockService,
      settingsDb: settingsDb,
    );
    await repository.backfillDefinitionClocks();
    await repository.backfillEntryLinkClocks();
    final recorded = await settingsDb.saveSettingsItemIfUnchanged(
      clocklessRepairSettingsKey,
      expected: token,
      value: clocklessRepairDone,
    );
    if (!recorded) {
      domainLogger.log(
        LogDomain.sync,
        'A clockless row arrived during the clock repair; '
        'the next start sweeps again',
        subDomain: 'clocklessRepair',
      );
    }
  } catch (error, stackTrace) {
    domainLogger.error(
      LogDomain.sync,
      error,
      stackTrace: stackTrace,
      subDomain: 'clocklessRepair',
    );
  }
}

@visibleForTesting
Future<void> repairClocklessRowsOnceForTesting() => _repairClocklessRowsOnce();

/// Settings key recording that [_resendOwnCounterZeroOnce] ran.
const counterZeroResentSettingsKey = 'maintenance_counterZeroResentV1';

/// Resends, once per device, this host's own write at counter 0, which a
/// host an older build created made first and no peer ever requests
/// ([BackfillResponseHandler.resendOwnCounterZero], ADR 0130). The flag is
/// set once the attempt returns, whether or not there was anything to send,
/// and not when it throws, so a failure retries at the next start.
Future<void> _resendOwnCounterZeroOnce() async {
  final settingsDb = getIt<SettingsDb>();
  final domainLogger = getIt<DomainLogger>();
  try {
    if (await settingsDb.itemByKey(counterZeroResentSettingsKey) == 'true') {
      return;
    }
    final sent = await getIt<BackfillResponseHandler>().resendOwnCounterZero();
    await settingsDb.saveSettingsItem(counterZeroResentSettingsKey, 'true');
    if (sent) {
      domainLogger.log(
        LogDomain.sync,
        "Resent this host's own counter 0 write",
        subDomain: 'counterZeroResend',
      );
    }
  } catch (error, stackTrace) {
    domainLogger.error(
      LogDomain.sync,
      error,
      stackTrace: stackTrace,
      subDomain: 'counterZeroResend',
    );
  }
}

/// Settings key recording that [_resendBurnedOwnCountersOnce] ran.
const burnedOwnCountersResentSettingsKey = 'maintenance_burnedOwnCountersV1';

/// Resends and rebinds, once per device, the own counters an older build
/// burned under the wrong id while a payload carried them
/// ([BackfillResponseHandler.resendBurnedOwnCountersCarried], ADR 0131). The
/// flag is set once the sweep returns and not when it throws, so a failure
/// retries at the next start.
Future<void> _resendBurnedOwnCountersOnce() async {
  final settingsDb = getIt<SettingsDb>();
  final domainLogger = getIt<DomainLogger>();
  try {
    if (await settingsDb.itemByKey(burnedOwnCountersResentSettingsKey) ==
        'true') {
      return;
    }
    final resent = await getIt<BackfillResponseHandler>()
        .resendBurnedOwnCountersCarried();
    await settingsDb.saveSettingsItem(
      burnedOwnCountersResentSettingsKey,
      'true',
    );
    if (resent > 0) {
      domainLogger.log(
        LogDomain.sync,
        'Resent $resent own counters burned under the wrong id',
        subDomain: 'burnedOwnCounters',
      );
    }
  } catch (error, stackTrace) {
    domainLogger.error(
      LogDomain.sync,
      error,
      stackTrace: stackTrace,
      subDomain: 'burnedOwnCounters',
    );
  }
}

@visibleForTesting
Future<void> resendBurnedOwnCountersOnceForTesting() =>
    _resendBurnedOwnCountersOnce();

@visibleForTesting
Future<void> resendOwnCounterZeroOnceForTesting() =>
    _resendOwnCounterZeroOnce();

/// The categories' legacy speech dictionaries into dictionary entries. Runs
/// at every start: it writes only terms this device holds no entry for, so
/// after the first run it changes nothing.
Future<void> _migrateSpeechDictionary() => SpeechDictionaryMigration(
  journalDb: getIt<JournalDb>(),
  persistenceLogic: getIt<PersistenceLogic>(),
  domainLogger: getIt<DomainLogger>(),
).run();

@visibleForTesting
Future<void> migrateSpeechDictionaryForTesting() => _migrateSpeechDictionary();
