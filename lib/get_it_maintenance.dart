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
Future<void> _checkAndPopulateSequenceLog() async {
  // Bumped from 'maintenance_sequenceLogPopulated' to V2 so devices that
  // ran V1 (journal + links only) will re-run with agent data included.
  const settingsKey = 'maintenance_sequenceLogPopulatedV2';
  final settingsDb = getIt<SettingsDb>();
  final domainLogger = getIt<DomainLogger>();

  try {
    // Check if we've already run this migration
    final hasRun = await settingsDb.itemByKey(settingsKey);
    if (hasRun == 'true') {
      return;
    }

    final syncDatabase = getIt<SyncDatabase>();
    final journalDb = getIt<JournalDb>();
    final agentDb = getIt<AgentDatabase>();

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

    if (journalCount == 0 &&
        linksCount == 0 &&
        agentEntityCount == 0 &&
        agentLinkCount == 0) {
      // Empty database, nothing to populate
      await settingsDb.saveSettingsItem(settingsKey, 'true');
      return;
    }

    domainLogger.log(
      LogDomain.database,
      'Starting automatic sequence log population (V2): '
      'journal=$journalCount links=$linksCount '
      'agentEntities=$agentEntityCount agentLinks=$agentLinkCount '
      'sequenceLog=$sequenceLogCount',
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

    // Mark as completed
    await settingsDb.saveSettingsItem(settingsKey, 'true');

    domainLogger.log(
      LogDomain.database,
      'Automatic sequence log population (V2) completed: '
      'journal=$populatedJournal links=$populatedLinks '
      'agentEntities=$populatedAgentEntities agentLinks=$populatedAgentLinks',
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

@visibleForTesting
Future<void> checkAndPopulateSequenceLogForTesting() =>
    _checkAndPopulateSequenceLog();

/// Projects conservative, deterministic attribution for pre-attribution data.
Future<void> _backfillAiAttribution() async {
  const settingsKey = 'maintenance_aiAttributionBackfillV1';
  final settingsDb = getIt<SettingsDb>();
  final logger = getIt<DomainLogger>();
  try {
    if (await settingsDb.itemByKey(settingsKey) == 'true') return;
    final service = getIt<AiAttributionBackfillService>();
    final journalDb = getIt<JournalDb>();
    const pageSize = 250;
    var offset = 0;
    while (true) {
      final entities = await journalDb.getJournalEntities(
        types: const ['AiResponse', 'JournalAudio'],
        starredStatuses: const [true, false],
        privateStatuses: const [true, false],
        flaggedStatuses: const [0, 1],
        ids: null,
        limit: pageSize,
        offset: offset,
      );
      if (entities.isEmpty) break;
      await service.backfill(journalEntities: entities);
      offset += entities.length;
      if (entities.length < pageSize) break;
    }

    final agentRepository = AgentRepository(getIt<AgentDatabase>());
    String? lastAgentId;
    while (true) {
      final entities = await agentRepository.getEntitiesPage(
        limit: pageSize,
        afterId: lastAgentId,
      );
      if (entities.isEmpty) break;
      await service.backfill(agentEntities: entities);
      lastAgentId = entities.last.id;
      if (entities.length < pageSize) break;
    }

    final consumptionRepository = getIt<ConsumptionRepository>();
    String? lastConsumptionEventId;
    while (true) {
      final events = await consumptionRepository.eventsWithoutAttribution(
        limit: pageSize,
        afterId: lastConsumptionEventId,
      );
      if (events.isEmpty) break;
      await service.backfill(consumptionEvents: events);
      lastConsumptionEventId = events.last.id;
      if (events.length < pageSize) break;
    }
    await settingsDb.saveSettingsItem(settingsKey, 'true');
  } catch (error, stackTrace) {
    logger.error(
      LogDomain.ai,
      error,
      stackTrace: stackTrace,
      subDomain: 'aiAttributionBackfill',
    );
  }
}

@visibleForTesting
Future<void> backfillAiAttributionForTesting() => _backfillAiAttribution();

/// Recovers interrupted attribution sagas after startup initialization.
Future<void> _recoverAiAttribution() async {
  try {
    await getIt<AiAttributionService>().recoverStale(
      threshold: const Duration(minutes: 15),
    );
  } catch (error, stackTrace) {
    getIt<DomainLogger>().error(
      LogDomain.ai,
      error,
      stackTrace: stackTrace,
      subDomain: 'aiAttributionRecovery',
    );
  }
}

@visibleForTesting
Future<void> recoverAiAttributionForTesting() => _recoverAiAttribution();

Future<void> _maintainAiAttribution() async {
  await _backfillAiAttribution();
  await _recoverAiAttribution();
}

@visibleForTesting
Future<void> maintainAiAttributionForTesting() => _maintainAiAttribution();
