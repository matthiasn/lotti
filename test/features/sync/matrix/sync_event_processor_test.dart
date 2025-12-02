// ignore_for_file: avoid_redundant_argument_values

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/journal_update_result.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;

import '../../../helpers/fallbacks.dart';
import '../../../test_data/test_data.dart';

class MockEvent extends Mock implements Event {}

class MockJournalDb extends Mock implements JournalDb {}

class MockUpdateNotifications extends Mock implements UpdateNotifications {}

class MockLoggingService extends Mock implements LoggingService {}

class MockAiConfigRepository extends Mock implements AiConfigRepository {}

class MockJournalEntityLoader extends Mock implements SyncJournalEntityLoader {}

class MockSettingsDb extends Mock implements SettingsDb {}

//

void main() {
  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
    registerFallbackValue(fallbackJournalEntity);
    registerFallbackValue(fallbackTagEntity);
    registerFallbackValue(EntryLink.basic(
      id: 'link-id',
      fromId: 'from',
      toId: 'to',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      vectorClock: null,
    ));
    registerFallbackValue(testTag1);
    registerFallbackValue(measurableWater);
    registerFallbackValue(fallbackAiConfig);
    registerFallbackValue(Uri.parse('mxc://placeholder'));
    registerFallbackValue(Exception('test'));
  });

  late MockEvent event;
  late MockJournalDb journalDb;
  late MockUpdateNotifications updateNotifications;
  late MockLoggingService loggingService;
  late MockAiConfigRepository aiConfigRepository;
  late MockJournalEntityLoader journalEntityLoader;
  late MockSettingsDb settingsDb;
  late SyncEventProcessor processor;

  setUp(() {
    event = MockEvent();
    journalDb = MockJournalDb();
    updateNotifications = MockUpdateNotifications();
    loggingService = MockLoggingService();
    aiConfigRepository = MockAiConfigRepository();
    journalEntityLoader = MockJournalEntityLoader();
    settingsDb = MockSettingsDb();

    when(() => journalDb.updateJournalEntity(any<JournalEntity>()))
        .thenAnswer((_) async => JournalUpdateResult.applied());
    when(() => journalDb.upsertEntryLink(any<EntryLink>()))
        .thenAnswer((_) async => 1);
    when(() => journalDb.upsertEntityDefinition(any<EntityDefinition>()))
        .thenAnswer((_) async => 1);
    when(() => journalDb.upsertTagEntity(any<TagEntity>()))
        .thenAnswer((_) async => 1);
    when(() => updateNotifications.notify(any<Set<String>>(),
        fromSync: any<bool>(named: 'fromSync'))).thenAnswer((_) {});
    when(() => loggingService.captureEvent(
          any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
        )).thenAnswer((_) {});
    when(() => loggingService.captureException(
          any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
        )).thenAnswer((_) {});
    when(() => aiConfigRepository.saveConfig(
          any<AiConfig>(),
          fromSync: any<bool>(named: 'fromSync'),
        )).thenAnswer((_) async {});
    when(() => aiConfigRepository.deleteConfig(
          any<String>(),
          fromSync: any<bool>(named: 'fromSync'),
        )).thenAnswer((_) async {});

    when(() => event.eventId).thenReturn('event-id');
    when(() => event.originServerTs).thenReturn(DateTime(2024));

    when(() => settingsDb.itemByKey(any<String>()))
        .thenAnswer((_) async => null);
    when(() => settingsDb.saveSettingsItem(any<String>(), any<String>()))
        .thenAnswer((_) async => 1);

    processor = SyncEventProcessor(
      loggingService: loggingService,
      updateNotifications: updateNotifications,
      aiConfigRepository: aiConfigRepository,
      settingsDb: settingsDb,
      journalEntityLoader: journalEntityLoader,
    );
  });

  String encodeMessage(SyncMessage message) =>
      base64.encode(utf8.encode(json.encode(message.toJson())));

  group('FileSyncJournalEntityLoader', () {
    late Directory tempDir;

    setUp(() async {
      await getIt.reset();
      getIt.allowReassignment = true;
      tempDir = await Directory.systemTemp.createTemp('sync_loader_test');
      getIt.registerSingleton<Directory>(tempDir);
    });

    tearDown(() async {
      await getIt.reset();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    Future<void> writeEntity(String relativePath) async {
      final file = File(path.join(tempDir.path, relativePath));
      await file.create(recursive: true);
      await file.writeAsString(jsonEncode(fallbackJournalEntity.toJson()));
    }

    test('loads entity when jsonPath starts with leading slash', () async {
      await writeEntity('entity.json');

      const loader = FileSyncJournalEntityLoader();
      final entity = await loader.load(jsonPath: '/entity.json');

      expect(entity.meta.id, fallbackJournalEntity.meta.id);
    });

    test('loads entity when jsonPath is relative', () async {
      await writeEntity('nested/entity.json');

      const loader = FileSyncJournalEntityLoader();
      final entity = await loader.load(jsonPath: 'nested/entity.json');

      expect(entity.meta.id, fallbackJournalEntity.meta.id);
    });

    test('rejects path traversal attempts', () async {
      // Create a file outside the documents directory to ensure it's not read.
      final externalDir =
          await Directory.systemTemp.createTemp('sync_loader_ext');
      final externalFile = File(path.join(externalDir.path, 'escape.json'))
        ..createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(fallbackJournalEntity.toJson()));

      const loader = FileSyncJournalEntityLoader();

      expect(
        () => loader.load(jsonPath: '../${path.basename(externalFile.path)}'),
        throwsA(isA<FileSystemException>()),
      );

      externalDir.deleteSync(recursive: true);
    });
  });

  group('SyncEventProcessor listener -', () {
    test('cachePurgeListener with non-smart loader does not crash', () {
      final processorWithFileLoader = SyncEventProcessor(
        loggingService: loggingService,
        updateNotifications: updateNotifications,
        aiConfigRepository: aiConfigRepository,
        settingsDb: settingsDb,
        journalEntityLoader: const FileSyncJournalEntityLoader(),
      );

      expect(() {
        processorWithFileLoader.cachePurgeListener = () {};
      }, returnsNormally);
    });
  });

  test('EntryLink apply logs from/to IDs and rows affected', () async {
    final link = EntryLink.basic(
      id: 'link-log',
      fromId: 'from-id',
      toId: 'to-id',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      vectorClock: null,
    );
    final message = SyncMessage.entryLink(
      entryLink: link,
      status: SyncEntryStatus.initial,
    );
    when(() => event.text).thenReturn(encodeMessage(message));
    when(() => journalDb.upsertEntryLink(any())).thenAnswer((_) async => 1);

    await processor.process(event: event, journalDb: journalDb);

    verify(() => loggingService.captureEvent(
          contains('apply entryLink from=from-id to=to-id rows=1'),
          domain: 'MATRIX_SERVICE',
          subDomain: 'apply.entryLink',
        )).called(1);
  });

  test('EntryLink no-op (rows=0) suppresses apply log and emits diag',
      () async {
    final link = EntryLink.basic(
      id: 'link-noop',
      fromId: 'from-id',
      toId: 'to-id',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      vectorClock: null,
    );
    final message = SyncMessage.entryLink(
      entryLink: link,
      status: SyncEntryStatus.initial,
    );
    when(() => event.text).thenReturn(encodeMessage(message));
    when(() => journalDb.upsertEntryLink(any())).thenAnswer((_) async => 0);

    SyncApplyDiagnostics? seen;
    processor.applyObserver = (d) => seen = d;

    await processor.process(event: event, journalDb: journalDb);

    // No apply.entryLink log on rows=0
    verifyNever(() => loggingService.captureEvent(
          any<Object>(),
          domain: 'MATRIX_SERVICE',
          subDomain: 'apply.entryLink',
        ));

    // Diagnostics captured for pipeline
    expect(seen, isNotNull);
    expect(seen!.payloadType, 'entryLink');
    expect(seen!.conflictStatus, 'entryLink.noop');
    expect(seen!.applied, isFalse);
    expect(seen!.skipReason, JournalUpdateSkipReason.olderOrEqual);

    // Restore default behavior for subsequent tests
    when(() => journalDb.upsertEntryLink(any())).thenAnswer((_) async => 1);
  });

  test('EntryLink apply continues when logging throws', () async {
    final link = EntryLink.basic(
      id: 'link-fail',
      fromId: 'from',
      toId: 'to',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      vectorClock: null,
    );
    final message = SyncMessage.entryLink(
      entryLink: link,
      status: SyncEntryStatus.initial,
    );
    when(() => event.text).thenReturn(encodeMessage(message));
    when(() => journalDb.upsertEntryLink(any())).thenAnswer((_) async => 1);
    when(() => loggingService.captureEvent(
          any<Object>(),
          domain: 'MATRIX_SERVICE',
          subDomain: 'apply.entryLink',
        )).thenThrow(Exception('logging failed'));

    // Should not throw - logging is best-effort
    await processor.process(event: event, journalDb: journalDb);

    verify(() => journalDb.upsertEntryLink(any())).called(1);
    verify(() => updateNotifications.notify(any(), fromSync: true)).called(1);
  });

  test('journal entity loader exception logs missingAttachment subdomain',
      () async {
    const message = SyncMessage.journalEntity(
      id: 'entity-id',
      jsonPath: '/entity.json',
      vectorClock: null,
      status: SyncEntryStatus.initial,
    );
    when(() => event.text).thenReturn(encodeMessage(message));
    when(() => journalEntityLoader.load(jsonPath: '/entity.json'))
        .thenThrow(const FileSystemException('missing'));

    await processor.process(event: event, journalDb: journalDb);
    verify(
      () => loggingService.captureException(
        any<Object>(),
        domain: 'MATRIX_SERVICE',
        subDomain: 'SyncEventProcessor.missingAttachment',
        stackTrace: any<StackTrace>(named: 'stackTrace'),
      ),
    ).called(1);
    verifyNever(() => journalDb.updateJournalEntity(any()));
  });

  group('SyncEventProcessor - SyncThemingSelection', () {
    String encodeThemingMessage(SyncMessage message) =>
        base64.encode(utf8.encode(json.encode(message.toJson())));

    // Helper to create event with theming message
    Event createThemingEvent(SyncMessage message) {
      final themingEvent = MockEvent();
      final encoded = encodeThemingMessage(message);
      when(() => themingEvent.eventId).thenReturn('event-id');
      when(() => themingEvent.originServerTs).thenReturn(DateTime(2024));
      when(() => themingEvent.content).thenReturn({
        'msgtype': 'com.lotti.sync.message',
        'body': 'sync',
        'data': encoded,
      });
      when(() => themingEvent.text).thenReturn(encoded);
      return themingEvent;
    }

    test('applies incoming theme selection', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final message = SyncMessage.themingSelection(
        lightThemeName: 'Indigo',
        darkThemeName: 'Shark',
        themeMode: 'dark',
        updatedAt: now,
        status: SyncEntryStatus.update,
      );
      final themingEvent = createThemingEvent(message);

      await processor.process(event: themingEvent, journalDb: journalDb);

      // Verify all settings saved
      verify(() => settingsDb.saveSettingsItem('LIGHT_SCHEME', 'Indigo'))
          .called(1);
      verify(() => settingsDb.saveSettingsItem('DARK_SCHEMA', 'Shark'))
          .called(1);
      verify(() => settingsDb.saveSettingsItem('THEME_MODE', 'dark')).called(1);
      verify(() =>
              settingsDb.saveSettingsItem('THEME_PREFS_UPDATED_AT', '$now'))
          .called(1);
    });

    test('rejects stale message based on timestamp', () async {
      // Mock local timestamp to future
      when(() => settingsDb.itemByKey('THEME_PREFS_UPDATED_AT'))
          .thenAnswer((_) async => '9999999999999');

      const message = SyncMessage.themingSelection(
        lightThemeName: 'Indigo',
        darkThemeName: 'Shark',
        themeMode: 'dark',
        updatedAt: 1000000000000,
        status: SyncEntryStatus.update,
      );
      final themingEvent = createThemingEvent(message);

      await processor.process(event: themingEvent, journalDb: journalDb);

      // Verify settings not saved for theme keys
      verifyNever(() => settingsDb.saveSettingsItem('LIGHT_SCHEME', any()));
      verifyNever(() => settingsDb.saveSettingsItem('DARK_SCHEMA', any()));
      verifyNever(() => settingsDb.saveSettingsItem('THEME_MODE', any()));

      // Verify log contains stale message
      verify(() => loggingService.captureEvent(
            contains('themingSync.ignored.stale'),
            domain: 'THEMING_SYNC',
            subDomain: 'apply',
          )).called(1);
    });

    test('accepts message when no local timestamp exists', () async {
      // Mock no local timestamp
      when(() => settingsDb.itemByKey('THEME_PREFS_UPDATED_AT'))
          .thenAnswer((_) async => null);

      final now = DateTime.now().millisecondsSinceEpoch;
      final message = SyncMessage.themingSelection(
        lightThemeName: 'Indigo',
        darkThemeName: 'Shark',
        themeMode: 'dark',
        updatedAt: now,
        status: SyncEntryStatus.update,
      );
      final themingEvent = createThemingEvent(message);

      await processor.process(event: themingEvent, journalDb: journalDb);

      // Verify all settings saved
      verify(() => settingsDb.saveSettingsItem('LIGHT_SCHEME', 'Indigo'))
          .called(1);
      verify(() => settingsDb.saveSettingsItem('DARK_SCHEMA', 'Shark'))
          .called(1);
      verify(() => settingsDb.saveSettingsItem('THEME_MODE', 'dark')).called(1);
      verify(() =>
              settingsDb.saveSettingsItem('THEME_PREFS_UPDATED_AT', '$now'))
          .called(1);
    });

    test('accepts newer message', () async {
      // Mock old local timestamp
      when(() => settingsDb.itemByKey('THEME_PREFS_UPDATED_AT'))
          .thenAnswer((_) async => '1000000000000');

      final now = DateTime.now().millisecondsSinceEpoch;
      final message = SyncMessage.themingSelection(
        lightThemeName: 'Indigo',
        darkThemeName: 'Shark',
        themeMode: 'dark',
        updatedAt: now,
        status: SyncEntryStatus.update,
      );
      final themingEvent = createThemingEvent(message);

      await processor.process(event: themingEvent, journalDb: journalDb);

      // Verify all settings saved
      verify(() => settingsDb.saveSettingsItem('LIGHT_SCHEME', 'Indigo'))
          .called(1);
      verify(() => settingsDb.saveSettingsItem('DARK_SCHEMA', 'Shark'))
          .called(1);
      verify(() => settingsDb.saveSettingsItem('THEME_MODE', 'dark')).called(1);
      verify(() =>
              settingsDb.saveSettingsItem('THEME_PREFS_UPDATED_AT', '$now'))
          .called(1);
    });

    test('normalizes invalid ThemeMode to system', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final message = SyncMessage.themingSelection(
        lightThemeName: 'Indigo',
        darkThemeName: 'Shark',
        themeMode: 'invalid_mode',
        updatedAt: now,
        status: SyncEntryStatus.update,
      );
      final themingEvent = createThemingEvent(message);

      await processor.process(event: themingEvent, journalDb: journalDb);

      // Verify themeMode normalized to 'system'
      verify(() => settingsDb.saveSettingsItem('THEME_MODE', 'system'))
          .called(1);
    });

    test('handles exception during apply', () async {
      // Mock saveSettingsItem to throw
      when(() => settingsDb.saveSettingsItem(any(), any()))
          .thenThrow(Exception('DB error'));

      final message = SyncMessage.themingSelection(
        lightThemeName: 'Indigo',
        darkThemeName: 'Shark',
        themeMode: 'dark',
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        status: SyncEntryStatus.update,
      );
      final themingEvent = createThemingEvent(message);

      // Should not throw
      await processor.process(event: themingEvent, journalDb: journalDb);

      // Verify exception logged
      verify(() => loggingService.captureException(
            any<Object>(),
            domain: 'THEMING_SYNC',
            subDomain: 'apply',
            stackTrace: any<StackTrace>(named: 'stackTrace'),
          )).called(1);
    });

    test('logs success on apply', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final message = SyncMessage.themingSelection(
        lightThemeName: 'Indigo',
        darkThemeName: 'Shark',
        themeMode: 'dark',
        updatedAt: now,
        status: SyncEntryStatus.update,
      );
      final themingEvent = createThemingEvent(message);

      await processor.process(event: themingEvent, journalDb: journalDb);

      // Verify success logged
      verify(() => loggingService.captureEvent(
            contains('apply themingSelection'),
            domain: 'THEMING_SYNC',
            subDomain: 'apply',
          )).called(1);
    });

    test('saves updatedAt as string', () async {
      const timestamp = 1234567890;
      const message = SyncMessage.themingSelection(
        lightThemeName: 'Indigo',
        darkThemeName: 'Shark',
        themeMode: 'dark',
        updatedAt: timestamp,
        status: SyncEntryStatus.update,
      );
      final themingEvent = createThemingEvent(message);

      await processor.process(event: themingEvent, journalDb: journalDb);

      // Verify updatedAt saved as string
      verify(() => settingsDb.saveSettingsItem(
          'THEME_PREFS_UPDATED_AT', '$timestamp')).called(1);
    });
  });

  group('SyncEventProcessor - Embedded Entry Links', () {
    test('processes embedded links after successful journal entity update',
        () async {
      final link1 = EntryLink.basic(
        id: 'link-1',
        fromId: 'entry-id',
        toId: 'category-1',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
        vectorClock: null,
      );
      final link2 = EntryLink.basic(
        id: 'link-2',
        fromId: 'entry-id',
        toId: 'category-2',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
        vectorClock: null,
      );

      final message = SyncMessage.journalEntity(
        id: 'entry-id',
        jsonPath: '/entry.json',
        vectorClock: null,
        status: SyncEntryStatus.initial,
        entryLinks: [link1, link2],
      );

      when(() => journalEntityLoader.load(jsonPath: '/entry.json'))
          .thenAnswer((_) async => fallbackJournalEntity);
      when(() => event.text).thenReturn(encodeMessage(message));
      when(() => journalDb.upsertEntryLink(link1)).thenAnswer((_) async => 1);
      when(() => journalDb.upsertEntryLink(link2)).thenAnswer((_) async => 1);

      await processor.process(event: event, journalDb: journalDb);

      // Verify both links were upserted
      verify(() => journalDb.upsertEntryLink(link1)).called(1);
      verify(() => journalDb.upsertEntryLink(link2)).called(1);

      // Verify logging for each embedded link
      verify(() => loggingService.captureEvent(
            contains(
                'apply entryLink.embedded from=${link1.fromId} to=${link1.toId}'),
            domain: 'MATRIX_SERVICE',
            subDomain: 'apply.entryLink.embedded',
          )).called(1);

      verify(() => loggingService.captureEvent(
            contains(
                'apply entryLink.embedded from=${link2.fromId} to=${link2.toId}'),
            domain: 'MATRIX_SERVICE',
            subDomain: 'apply.entryLink.embedded',
          )).called(1);

      // Verify summary log includes embedded links count
      verify(() => loggingService.captureEvent(
            contains('embeddedLinks=2/2'),
            domain: 'MATRIX_SERVICE',
            subDomain: 'apply',
          )).called(1);

      // Verify notifications sent for all affected IDs from both links
      verify(() => updateNotifications.notify(
            {link1.fromId, link1.toId, link2.toId},
            fromSync: true,
          )).called(1);
    });

    test('does not process embedded links when update is skipped', () async {
      final link = EntryLink.basic(
        id: 'link-1',
        fromId: 'entry-id',
        toId: 'category-1',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
        vectorClock: null,
      );

      final message = SyncMessage.journalEntity(
        id: 'entry-id',
        jsonPath: '/entry.json',
        vectorClock: const VectorClock({'old': 1}),
        status: SyncEntryStatus.initial,
        entryLinks: [link],
      );

      // Create an entry with newer vector clock so update is skipped
      final newerEntry = JournalEntry(
        meta: Metadata(
          id: 'entry-id',
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 1),
          dateFrom: DateTime(2025, 1, 1),
          dateTo: DateTime(2025, 1, 1),
          vectorClock: const VectorClock({'new': 2}),
        ),
        entryText: const EntryText(plainText: 'newer'),
      );

      when(() => journalEntityLoader.load(
            jsonPath: '/entry.json',
            incomingVectorClock: const VectorClock({'old': 1}),
          )).thenAnswer((_) async => fallbackJournalEntity);
      when(() => event.text).thenReturn(encodeMessage(message));
      when(() => journalDb.journalEntityById('entry-id'))
          .thenAnswer((_) async => newerEntry);
      when(() => journalDb.updateJournalEntity(any<JournalEntity>()))
          .thenAnswer((_) async => JournalUpdateResult.skipped(
                reason: JournalUpdateSkipReason.olderOrEqual,
              ));

      await processor.process(event: event, journalDb: journalDb);

      // Verify link was NOT upserted because update was skipped
      verifyNever(() => journalDb.upsertEntryLink(any()));

      // Verify summary shows 0 embedded links processed
      verify(() => loggingService.captureEvent(
            contains('embeddedLinks=0/1'),
            domain: 'MATRIX_SERVICE',
            subDomain: 'apply',
          )).called(1);
    });

    test('handles errors when processing individual embedded links', () async {
      final link1 = EntryLink.basic(
        id: 'link-1',
        fromId: 'entry-id',
        toId: 'category-1',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
        vectorClock: null,
      );
      final link2 = EntryLink.basic(
        id: 'link-2',
        fromId: 'entry-id',
        toId: 'category-2',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
        vectorClock: null,
      );

      final message = SyncMessage.journalEntity(
        id: 'entry-id',
        jsonPath: '/entry.json',
        vectorClock: null,
        status: SyncEntryStatus.initial,
        entryLinks: [link1, link2],
      );

      when(() => journalEntityLoader.load(jsonPath: '/entry.json'))
          .thenAnswer((_) async => fallbackJournalEntity);
      when(() => event.text).thenReturn(encodeMessage(message));

      // First link fails, second succeeds
      when(() => journalDb.upsertEntryLink(link1))
          .thenThrow(Exception('Database error'));
      when(() => journalDb.upsertEntryLink(link2)).thenAnswer((_) async => 1);

      // Should not throw - errors are handled gracefully
      await processor.process(event: event, journalDb: journalDb);

      // Verify both links were attempted
      verify(() => journalDb.upsertEntryLink(link1)).called(1);
      verify(() => journalDb.upsertEntryLink(link2)).called(1);

      // Verify exception was logged for link1
      verify(() => loggingService.captureException(
            any<Exception>(),
            domain: 'MATRIX_SERVICE',
            subDomain: 'apply.entryLink.embedded',
            stackTrace: any<StackTrace>(named: 'stackTrace'),
          )).called(1);

      // Verify link2 was logged successfully
      verify(() => loggingService.captureEvent(
            contains(
                'apply entryLink.embedded from=${link2.fromId} to=${link2.toId}'),
            domain: 'MATRIX_SERVICE',
            subDomain: 'apply.entryLink.embedded',
          )).called(1);

      // Verify only one link was processed successfully
      verify(() => loggingService.captureEvent(
            contains('embeddedLinks=1/2'),
            domain: 'MATRIX_SERVICE',
            subDomain: 'apply',
          )).called(1);
    });

    test('processes empty embedded links list', () async {
      const message = SyncMessage.journalEntity(
        id: 'entry-id',
        jsonPath: '/entry.json',
        vectorClock: null,
        status: SyncEntryStatus.initial,
        entryLinks: [],
      );

      when(() => journalEntityLoader.load(jsonPath: '/entry.json'))
          .thenAnswer((_) async => fallbackJournalEntity);
      when(() => event.text).thenReturn(encodeMessage(message));

      await processor.process(event: event, journalDb: journalDb);

      // Verify no links were upserted
      verifyNever(() => journalDb.upsertEntryLink(any()));

      // Verify summary shows 0/0 embedded links
      verify(() => loggingService.captureEvent(
            contains('embeddedLinks=0/0'),
            domain: 'MATRIX_SERVICE',
            subDomain: 'apply',
          )).called(1);
    });

    test('skips link processing when linkRows is 0 (no-op upsert)', () async {
      final link = EntryLink.basic(
        id: 'link-1',
        fromId: 'entry-id',
        toId: 'category-1',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
        vectorClock: null,
      );

      final message = SyncMessage.journalEntity(
        id: 'entry-id',
        jsonPath: '/entry.json',
        vectorClock: null,
        status: SyncEntryStatus.initial,
        entryLinks: [link],
      );

      when(() => journalEntityLoader.load(jsonPath: '/entry.json'))
          .thenAnswer((_) async => fallbackJournalEntity);
      when(() => event.text).thenReturn(encodeMessage(message));
      when(() => journalDb.upsertEntryLink(link)).thenAnswer((_) async => 0);

      await processor.process(event: event, journalDb: journalDb);

      // Verify link upsert was attempted
      verify(() => journalDb.upsertEntryLink(link)).called(1);

      // Verify no log for link application (rows was 0)
      verifyNever(() => loggingService.captureEvent(
            contains('apply entryLink.embedded'),
            domain: any(named: 'domain'),
            subDomain: 'apply.entryLink.embedded',
          ));

      // Verify summary shows 0 processed (since linkRows was 0)
      verify(() => loggingService.captureEvent(
            contains('embeddedLinks=0/1'),
            domain: 'MATRIX_SERVICE',
            subDomain: 'apply',
          )).called(1);

      // Verify notifications were still sent for affected IDs
      verify(() => updateNotifications.notify(
            {link.fromId, link.toId},
            fromSync: true,
          )).called(1);
    });
  });
}
