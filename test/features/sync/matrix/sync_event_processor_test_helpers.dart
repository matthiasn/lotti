// Shared setup for the SyncEventProcessor test files. The orchestrator's
// behaviour spans journal, agent, and outbox-bundle handlers (split across
// part files in `lib/`), so the test surface is split the same way to keep
// each file navigable. All four test files run in their own isolate per
// `package:test`'s default scheduler, so the top-level `late` mocks here are
// not shared across files — only across tests within a single file, where
// `setUp(setUpProcessorMocks)` produces a fresh set before each test.

import 'dart:convert';

import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/journal_update_result.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';

class MockJournalEntityLoader extends Mock implements SyncJournalEntityLoader {}

/// Shared mutable test state populated by [setUpProcessorMocks] before every
/// test. Within a single test file these are sequential, so the late globals
/// stay deterministic.
late MockEvent event;
late MockJournalDb journalDb;
late MockUpdateNotifications updateNotifications;
late MockDomainLogger loggingService;
late MockAiConfigRepository aiConfigRepository;
late MockJournalEntityLoader journalEntityLoader;
late MockSettingsDb settingsDb;
late SyncEventProcessor processor;

void registerSyncProcessorFallbacks() {
  registerAllFallbackValues();
  registerFallbackValue(
    EntryLink.basic(
      id: 'link-id',
      fromId: 'from',
      toId: 'to',
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
      vectorClock: null,
    ),
  );
  registerFallbackValue(measurableWater);
  registerFallbackValue(Uri.parse('mxc://placeholder'));
  registerFallbackValue(Exception('test'));
  registerFallbackValue(
    const SyncBackfillRequest(entries: [], requesterId: ''),
  );
  registerFallbackValue(
    const SyncBackfillResponse(hostId: '', counter: 0, deleted: false),
  );
  registerFallbackValue(const VectorClock({'fallback': 1}));
  registerFallbackValue(SyncSequencePayloadType.journalEntity);
}

void setUpProcessorMocks() {
  event = MockEvent();
  journalDb = MockJournalDb();
  updateNotifications = MockUpdateNotifications();
  loggingService = MockDomainLogger();
  aiConfigRepository = MockAiConfigRepository();
  journalEntityLoader = MockJournalEntityLoader();
  settingsDb = MockSettingsDb();

  when(
    () => journalDb.updateJournalEntity(any<JournalEntity>()),
  ).thenAnswer((_) async => JournalUpdateResult.applied());
  when(
    () => journalDb.entryLinkById(any<String>()),
  ).thenAnswer((_) async => null);
  when(
    () => journalDb.upsertEntryLink(any<EntryLink>()),
  ).thenAnswer((_) async => 1);
  when(
    () => journalDb.upsertEntityDefinition(any<EntityDefinition>()),
  ).thenAnswer((_) async => 1);
  when(
    () => journalDb.upsertConfigFlag(any<ConfigFlag>()),
  ).thenAnswer((_) async => 1);
  when(
    () => updateNotifications.notify(
      any<Set<String>>(),
      fromSync: any<bool>(named: 'fromSync'),
    ),
  ).thenAnswer((_) {});
  when(
    () => aiConfigRepository.saveConfig(
      any<AiConfig>(),
      fromSync: any<bool>(named: 'fromSync'),
    ),
  ).thenAnswer((_) async {});
  when(
    () => aiConfigRepository.deleteConfig(
      any<String>(),
      fromSync: any<bool>(named: 'fromSync'),
    ),
  ).thenAnswer((_) async {});

  when(() => event.eventId).thenReturn('event-id');
  when(() => event.originServerTs).thenReturn(DateTime(2024));

  when(
    () => settingsDb.itemByKey(any<String>()),
  ).thenAnswer((_) async => null);
  when(
    () => settingsDb.saveSettingsItem(any<String>(), any<String>()),
  ).thenAnswer((_) async => 1);

  processor = SyncEventProcessor(
    loggingService: loggingService,
    updateNotifications: updateNotifications,
    aiConfigRepository: aiConfigRepository,
    settingsDb: settingsDb,
    journalEntityLoader: journalEntityLoader,
  );
}

String encodeMessage(SyncMessage message) =>
    base64.encode(utf8.encode(json.encode(message.toJson())));

String stripLeadingSlashes(String s) => s.replaceFirst(RegExp(r'^[\\/]+'), '');
