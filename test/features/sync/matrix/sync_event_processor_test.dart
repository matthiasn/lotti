import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
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
  });

  late MockEvent event;
  late MockJournalDb journalDb;
  late MockUpdateNotifications updateNotifications;
  late MockLoggingService loggingService;
  late MockAiConfigRepository aiConfigRepository;
  late MockJournalEntityLoader journalEntityLoader;
  late SyncEventProcessor processor;

  setUp(() {
    event = MockEvent();
    journalDb = MockJournalDb();
    updateNotifications = MockUpdateNotifications();
    loggingService = MockLoggingService();
    aiConfigRepository = MockAiConfigRepository();
    journalEntityLoader = MockJournalEntityLoader();

    when(() => journalDb.updateJournalEntity(any<JournalEntity>()))
        .thenAnswer((_) async => 1);
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

    processor = SyncEventProcessor(
      loggingService: loggingService,
      updateNotifications: updateNotifications,
      aiConfigRepository: aiConfigRepository,
      journalEntityLoader: journalEntityLoader,
    );
  });

  String encodeMessage(SyncMessage message) =>
      base64.encode(utf8.encode(json.encode(message.toJson())));

  test('processes journal entities via loader and updates notifications',
      () async {
    const message = SyncMessage.journalEntity(
      id: 'entity-id',
      jsonPath: '/entity.json',
      vectorClock: null,
      status: SyncEntryStatus.initial,
    );
    when(() => journalEntityLoader.load('/entity.json'))
        .thenAnswer((_) async => fallbackJournalEntity);
    when(() => event.text).thenReturn(encodeMessage(message));

    await processor.process(event: event, journalDb: journalDb);

    verify(() => journalEntityLoader.load('/entity.json')).called(1);
    verify(() => journalDb.updateJournalEntity(fallbackJournalEntity))
        .called(1);
    verify(
      () => updateNotifications.notify(
        fallbackJournalEntity.affectedIds,
        fromSync: true,
      ),
    ).called(1);
  });

  test('processes entry link messages', () async {
    final link = EntryLink.basic(
      id: 'link',
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

    await processor.process(event: event, journalDb: journalDb);

    verify(() => journalDb.upsertEntryLink(link)).called(1);
    verify(() =>
            updateNotifications.notify(const {'from', 'to'}, fromSync: true))
        .called(1);
  });

  test('processes entity definitions', () async {
    final message = SyncMessage.entityDefinition(
      entityDefinition: measurableWater,
      status: SyncEntryStatus.initial,
    );
    when(() => event.text).thenReturn(encodeMessage(message));

    await processor.process(event: event, journalDb: journalDb);

    verify(() => journalDb.upsertEntityDefinition(measurableWater)).called(1);
  });

  test('processes tag entities', () async {
    final message = SyncMessage.tagEntity(
      tagEntity: testTag1,
      status: SyncEntryStatus.initial,
    );
    when(() => event.text).thenReturn(encodeMessage(message));

    await processor.process(event: event, journalDb: journalDb);

    verify(() => journalDb.upsertTagEntity(testTag1)).called(1);
  });

  test('processes ai config messages', () async {
    final message = SyncMessage.aiConfig(
      aiConfig: fallbackAiConfig,
      status: SyncEntryStatus.initial,
    );
    when(() => event.text).thenReturn(encodeMessage(message));

    await processor.process(event: event, journalDb: journalDb);

    verify(
      () => aiConfigRepository.saveConfig(
        fallbackAiConfig,
        fromSync: true,
      ),
    ).called(1);
  });

  test('processes ai config delete messages', () async {
    const id = 'config-id';
    const message = SyncMessage.aiConfigDelete(id: id);
    when(() => event.text).thenReturn(encodeMessage(message));

    await processor.process(event: event, journalDb: journalDb);

    verify(() => aiConfigRepository.deleteConfig(id, fromSync: true)).called(1);
  });

  test('logs exceptions for invalid base64 payloads', () async {
    when(() => event.text).thenReturn('not-base64');

    await processor.process(event: event, journalDb: journalDb);

    verify(() => loggingService.captureException(
          any<Object>(),
          domain: 'MATRIX_SERVICE',
          subDomain: 'SyncEventProcessor',
          stackTrace: any<StackTrace>(named: 'stackTrace'),
        )).called(1);
  });

  test('logs exceptions thrown by handlers', () async {
    const message = SyncMessage.journalEntity(
      id: 'entity-id',
      jsonPath: '/entity.json',
      vectorClock: null,
      status: SyncEntryStatus.initial,
    );
    when(() => event.text).thenReturn(encodeMessage(message));
    when(() => journalEntityLoader.load('/entity.json'))
        .thenThrow(Exception('load failed'));

    await processor.process(event: event, journalDb: journalDb);

    verify(() => loggingService.captureException(
          any<Object>(),
          domain: 'MATRIX_SERVICE',
          subDomain: 'SyncEventProcessor',
          stackTrace: any<StackTrace>(named: 'stackTrace'),
        )).called(1);
  });

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
      final entity = await loader.load('/entity.json');

      expect(entity.meta.id, fallbackJournalEntity.meta.id);
    });

    test('loads entity when jsonPath is relative', () async {
      await writeEntity('nested/entity.json');

      const loader = FileSyncJournalEntityLoader();
      final entity = await loader.load('nested/entity.json');

      expect(entity.meta.id, fallbackJournalEntity.meta.id);
    });
  });
}
