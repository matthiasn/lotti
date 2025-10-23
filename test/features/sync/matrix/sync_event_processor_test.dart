import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/journal_update_result.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/sync/matrix/pipeline_v2/attachment_index.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/image_utils.dart';
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

class MockMatrixRoom extends Mock implements Room {}

class MockMatrixClient extends Mock implements Client {}

class MockMatrixDatabase extends Mock implements DatabaseApi {}

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
  });
  // Helper to normalize leading separators across platforms so that
  // path.join(docDir, rel) never treats rel as absolute.
  String stripLeadingSlashes(String s) =>
      s.replaceFirst(RegExp(r'^[\\/]+'), '');

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

    processor = SyncEventProcessor(
      loggingService: loggingService,
      updateNotifications: updateNotifications,
      aiConfigRepository: aiConfigRepository,
      journalEntityLoader: journalEntityLoader,
    );
  });

  String encodeMessage(SyncMessage message) =>
      base64.encode(utf8.encode(json.encode(message.toJson())));

  group('VectorClockValidator', () {
    late MockLoggingService logging;
    late VectorClockValidator validator;

    setUp(() {
      logging = MockLoggingService();
      when(() => logging.captureEvent(
            any<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          )).thenAnswer((_) {});
      when(() => logging.captureException(
            any<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
          )).thenAnswer((_) {});
      validator = VectorClockValidator(loggingService: logging);
    });

    JournalEntry buildEntry(VectorClock? vc) => JournalEntry(
          meta: Metadata(
            id: 'entry',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
            vectorClock: vc,
          ),
          entryText: const EntryText(plainText: 'text'),
        );

    test('returns retryAfterPurge for stale first attempt', () {
      final decision = validator.evaluate(
        jsonPath: '/path.json',
        incomingVectorClock: const VectorClock({'n': 2}),
        candidate: buildEntry(const VectorClock({'n': 1})),
        attempt: 0,
      );
      expect(decision, VectorClockDecision.retryAfterPurge);
      verify(
        () => logging.captureEvent(
          contains('smart.fetch.stale_vc path=/path.json'),
          domain: 'MATRIX_SERVICE',
          subDomain: 'SmartLoader.fetch',
        ),
      ).called(1);
    });

    test('returns staleAfterRefresh on subsequent attempt', () {
      validator.evaluate(
        jsonPath: '/path.json',
        incomingVectorClock: const VectorClock({'n': 3}),
        candidate: buildEntry(const VectorClock({'n': 1})),
        attempt: 0,
      );
      final decision = validator.evaluate(
        jsonPath: '/path.json',
        incomingVectorClock: const VectorClock({'n': 3}),
        candidate: buildEntry(const VectorClock({'n': 1})),
        attempt: 1,
      );
      expect(decision, VectorClockDecision.staleAfterRefresh);
      verify(
        () => logging.captureEvent(
          contains('smart.fetch.stale_vc.pending path=/path.json'),
          domain: 'MATRIX_SERVICE',
          subDomain: 'SmartLoader.fetch',
        ),
      ).called(1);
    });

    test('trips circuit breaker after repeated stale descriptors', () {
      for (var i = 0;
          i < VectorClockValidator.maxStaleDescriptorFailures - 1;
          i++) {
        expect(
          validator.evaluate(
            jsonPath: '/path.json',
            incomingVectorClock: const VectorClock({'n': 5}),
            candidate: buildEntry(const VectorClock({'n': 1})),
            attempt: 0,
          ),
          VectorClockDecision.retryAfterPurge,
        );
      }
      final decision = validator.evaluate(
        jsonPath: '/path.json',
        incomingVectorClock: const VectorClock({'n': 5}),
        candidate: buildEntry(const VectorClock({'n': 1})),
        attempt: 0,
      );
      expect(decision, VectorClockDecision.circuitBreaker);
      verify(
        () => logging.captureEvent(
          contains('smart.fetch.stale_vc.breaker path=/path.json'),
          domain: 'MATRIX_SERVICE',
          subDomain: 'SmartLoader.fetch',
        ),
      ).called(1);
    });

    test('returns missingVectorClock when descriptor lacks vector clock', () {
      final decision = validator.evaluate(
        jsonPath: '/missing.json',
        incomingVectorClock: const VectorClock({'n': 1}),
        candidate: buildEntry(null),
        attempt: 0,
      );
      expect(decision, VectorClockDecision.missingVectorClock);
      verify(
        () => logging.captureEvent(
          contains('smart.fetch.missing_vc path=/missing.json'),
          domain: 'MATRIX_SERVICE',
          subDomain: 'SmartLoader.fetch',
        ),
      ).called(1);
    });

    test('resets failure count when descriptor becomes fresh', () {
      validator.evaluate(
        jsonPath: '/path.json',
        incomingVectorClock: const VectorClock({'n': 3}),
        candidate: buildEntry(const VectorClock({'n': 1})),
        attempt: 0,
      );
      final acceptDecision = validator.evaluate(
        jsonPath: '/path.json',
        incomingVectorClock: const VectorClock({'n': 3}),
        candidate: buildEntry(const VectorClock({'n': 4})),
        attempt: 0,
      );
      expect(acceptDecision, VectorClockDecision.accept);

      final retryDecision = validator.evaluate(
        jsonPath: '/path.json',
        incomingVectorClock: const VectorClock({'n': 3}),
        candidate: buildEntry(const VectorClock({'n': 2})),
        attempt: 0,
      );
      expect(retryDecision, VectorClockDecision.retryAfterPurge);
    });
  });

  group('DescriptorDownloader', () {
    late MockLoggingService logging;
    late VectorClockValidator validator;
    late DescriptorDownloader downloader;
    late MockEvent descriptorEvent;
    late MockMatrixRoom room;
    late MockMatrixClient client;
    late MockMatrixDatabase database;

    setUp(() {
      logging = MockLoggingService();
      when(() => logging.captureEvent(
            any<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          )).thenAnswer((_) {});
      when(() => logging.captureException(
            any<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
          )).thenAnswer((_) {});
      validator = VectorClockValidator(loggingService: logging);
      downloader = DescriptorDownloader(
        loggingService: logging,
        validator: validator,
      );

      descriptorEvent = MockEvent();
      room = MockMatrixRoom();
      client = MockMatrixClient();
      database = MockMatrixDatabase();

      when(() => descriptorEvent.room).thenReturn(room);
      when(() => room.client).thenReturn(client);
      when(() => client.database).thenReturn(database);
      when(() => descriptorEvent.attachmentMimetype)
          .thenReturn('application/json');
      when(() => descriptorEvent.content).thenReturn({'relativePath': '/path'});
      when(() => descriptorEvent.attachmentOrThumbnailMxcUrl())
          .thenReturn(Uri.parse('mxc://server/file'));
    });

    JournalEntry buildEntry(VectorClock? vc) => JournalEntry(
          meta: Metadata(
            id: 'entry',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
            vectorClock: vc,
          ),
          entryText: const EntryText(plainText: 'text'),
        );

    Future<DescriptorDownloadResult> download({
      required VectorClock incoming,
      required List<JournalEntry> responses,
      void Function()? onCachePurge,
    }) async {
      if (onCachePurge != null) {
        downloader.onCachePurge = onCachePurge;
      }
      var index = 0;
      when(descriptorEvent.downloadAndDecryptAttachment).thenAnswer((_) async {
        final entry = responses[index.clamp(0, responses.length - 1)];
        index++;
        final bytes = Uint8List.fromList(jsonEncode(entry.toJson()).codeUnits);
        return MatrixFile(bytes: bytes, name: 'entry.json');
      });
      when(() => database.deleteFile(any<Uri>())).thenAnswer((_) async => true);
      return downloader.download(
        descriptorEvent: descriptorEvent,
        incomingVectorClock: incoming,
        jsonPath: '/path.json',
      );
    }

    test('returns fresh descriptor payload when vector clock is current',
        () async {
      final entry = buildEntry(const VectorClock({'n': 2}));
      final result = await download(
        incoming: const VectorClock({'n': 1}),
        responses: [entry],
      );
      final decoded = JournalEntity.fromJson(
        json.decode(result.json) as Map<String, dynamic>,
      );
      expect(decoded, isA<JournalEntry>());
      final journal = decoded as JournalEntry;
      expect(journal.entryText?.plainText, 'text');
      expect(journal.meta.vectorClock, const VectorClock({'n': 2}));
      expect(result.bytesLength, isPositive);
      verifyNever(() => database.deleteFile(any<Uri>()));
    });

    test('purges cache and retries stale descriptor once', () async {
      var purges = 0;
      final stale = buildEntry(const VectorClock({'n': 1}));
      final fresh = buildEntry(const VectorClock({'n': 3}));
      final result = await download(
        incoming: const VectorClock({'n': 3}),
        responses: [stale, fresh],
        onCachePurge: () => purges++,
      );
      final decoded = JournalEntity.fromJson(
        json.decode(result.json) as Map<String, dynamic>,
      );
      expect(decoded, isA<JournalEntry>());
      final journal = decoded as JournalEntry;
      expect(journal.entryText?.plainText, 'text');
      expect(journal.meta.vectorClock, const VectorClock({'n': 3}));
      expect(purges, 1);
      verify(() => database.deleteFile(any<Uri>())).called(1);
      verify(
        () => logging.captureEvent(
          contains('smart.fetch.stale_vc.refresh path=/path.json'),
          domain: 'MATRIX_SERVICE',
          subDomain: 'SmartLoader.fetch',
        ),
      ).called(1);
    });

    test('throws when descriptor remains stale after refresh', () async {
      final stale = buildEntry(const VectorClock({'n': 1}));
      await expectLater(
        () => download(
          incoming: const VectorClock({'n': 3}),
          responses: [stale, stale],
        ),
        throwsA(
          isA<FileSystemException>().having(
            (error) => error.message,
            'message',
            contains('after refresh'),
          ),
        ),
      );
      verify(() => database.deleteFile(any<Uri>())).called(1);
    });

    test('throws circuit breaker after repeated stale downloads', () async {
      final stale = buildEntry(const VectorClock({'n': 1}));
      Future<void> attempt() => download(
            incoming: const VectorClock({'n': 5}),
            responses: [stale, stale],
          ).then((_) {});

      await expectLater(
        attempt(),
        throwsA(isA<FileSystemException>()),
      );
      await expectLater(
        attempt(),
        throwsA(isA<FileSystemException>()),
      );
      await expectLater(
        attempt(),
        throwsA(
          isA<FileSystemException>().having(
            (error) => error.message,
            'message',
            contains('circuit breaker'),
          ),
        ),
      );
      verify(
        () => logging.captureEvent(
          contains('smart.fetch.stale_vc.breaker path=/path.json'),
          domain: 'MATRIX_SERVICE',
          subDomain: 'SmartLoader.fetch',
        ),
      ).called(1);
    });

    test('throws when descriptor lacks vector clock metadata', () async {
      final missing = buildEntry(null);
      await expectLater(
        () => download(
          incoming: const VectorClock({'n': 2}),
          responses: [missing],
        ),
        throwsA(
          isA<FileSystemException>().having(
            (error) => error.message,
            'message',
            contains('missing attachment vector clock'),
          ),
        ),
      );
      verifyNever(() => database.deleteFile(any<Uri>()));
    });
  });

  test('processes journal entities via loader and updates notifications',
      () async {
    const message = SyncMessage.journalEntity(
      id: 'entity-id',
      jsonPath: '/entity.json',
      vectorClock: null,
      status: SyncEntryStatus.initial,
    );
    when(() => journalEntityLoader.load(
          jsonPath: '/entity.json',
        )).thenAnswer((_) async => fallbackJournalEntity);
    when(() => event.text).thenReturn(encodeMessage(message));

    await processor.process(event: event, journalDb: journalDb);

    verify(() => journalEntityLoader.load(
          jsonPath: '/entity.json',
        )).called(1);
    verify(() => journalDb.updateJournalEntity(fallbackJournalEntity))
        .called(1);
    verify(
      () => updateNotifications.notify(
        fallbackJournalEntity.affectedIds,
        fromSync: true,
      ),
    ).called(1);
  });

  test(
      'invokes applyObserver with diagnostics and logs vclock prediction failure',
      () async {
    // Arrange a journal entity message
    const message = SyncMessage.journalEntity(
      id: 'entity-id',
      jsonPath: '/entity.json',
      vectorClock: null,
      status: SyncEntryStatus.initial,
    );
    when(() => event.text).thenReturn(encodeMessage(message));

    // Loader returns the canonical fallback entity
    when(() => journalEntityLoader.load(
          jsonPath: '/entity.json',
        )).thenAnswer((_) async => fallbackJournalEntity);

    // DB lookup for prediction throws to exercise logging + default status
    when(() => journalDb.journalEntityById(fallbackJournalEntity.meta.id))
        .thenThrow(Exception('db unavailable'));

    SyncApplyDiagnostics? capturedDiag;
    processor.applyObserver = (diag) => capturedDiag = diag;

    await processor.process(event: event, journalDb: journalDb);

    // Observer called with a complete diagnostics payload
    expect(capturedDiag, isNotNull);
    expect(capturedDiag!.eventId, 'event-id');
    expect(capturedDiag!.payloadType, 'journalEntity');
    expect(capturedDiag!.entityId, fallbackJournalEntity.meta.id);
    expect(capturedDiag!.conflictStatus, contains('VclockStatus'));
    expect(capturedDiag!.applied, isTrue);
    expect(capturedDiag!.skipReason, isNull);

    // Prediction failure is logged with specific subDomain
    verify(() => loggingService.captureException(
          any<Object>(),
          domain: 'MATRIX_SERVICE',
          subDomain: 'apply.predictVectorClock',
          stackTrace: any<StackTrace>(named: 'stackTrace'),
        )).called(1);
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

  test('EntryLink diag reports applied when rows > 0', () async {
    final link = EntryLink.basic(
      id: 'diag-link',
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

    SyncApplyDiagnostics? diag;
    processor.applyObserver = (value) => diag = value;

    await processor.process(event: event, journalDb: journalDb);

    expect(diag, isNotNull);
    expect(diag!.payloadType, 'entryLink');
    expect(diag!.applied, isTrue);
    expect(diag!.entityId, '${link.fromId}->${link.toId}');
  });

  test('EntryLink observer exceptions are swallowed', () async {
    final link = EntryLink.basic(
      id: 'diag-link-throw',
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

    processor.applyObserver = (_) {
      throw StateError('observer failure');
    };

    await processor.process(event: event, journalDb: journalDb);
    verify(() => journalDb.upsertEntryLink(link)).called(1);
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

  test('SyncTagEntity does not emit diagnostics', () async {
    final message = SyncMessage.tagEntity(
      tagEntity: testTag1,
      status: SyncEntryStatus.initial,
    );
    when(() => event.text).thenReturn(encodeMessage(message));

    var observerCalled = false;
    processor.applyObserver = (_) => observerCalled = true;

    await processor.process(event: event, journalDb: journalDb);

    expect(observerCalled, isFalse);
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

  test('SyncAiConfig payload does not emit diagnostics', () async {
    final message = SyncMessage.aiConfig(
      aiConfig: fallbackAiConfig,
      status: SyncEntryStatus.initial,
    );
    when(() => event.text).thenReturn(encodeMessage(message));

    var observerCalled = false;
    processor.applyObserver = (_) => observerCalled = true;

    await processor.process(event: event, journalDb: journalDb);

    expect(observerCalled, isFalse);
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

    await expectLater(
      () => processor.process(event: event, journalDb: journalDb),
      throwsA(isA<FormatException>()),
    );

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
    when(() => journalEntityLoader.load(
          jsonPath: '/entity.json',
        )).thenThrow(Exception('load failed'));

    await expectLater(
      () => processor.process(event: event, journalDb: journalDb),
      throwsA(isA<Exception>()),
    );

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

  group('SmartJournalEntityLoader media ensure', () {
    late Directory tempDir;

    setUp(() async {
      await getIt.reset();
      getIt.allowReassignment = true;
      tempDir = await Directory.systemTemp.createTemp('smart_loader_test');
      getIt.registerSingleton<Directory>(tempDir);
    });

    test('fetches JSON when no VC and file missing via AttachmentIndex',
        () async {
      // Build a simple text entry JSON path and index descriptor
      const relJson = '/text_entries/2024-01-01/abc.text.json';
      final index = AttachmentIndex();
      final ev = MockEvent();
      when(() => ev.attachmentMimetype).thenReturn('application/json');
      when(() => ev.content).thenReturn({'relativePath': relJson});
      final entity = JournalEntry(
        meta: Metadata(
          id: 'abc',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
        ),
        entryText: const EntryText(plainText: 'hello'),
      );
      final jsonBytes = utf8.encode(jsonEncode(entity.toJson()));
      when(ev.downloadAndDecryptAttachment).thenAnswer((_) async => MatrixFile(
            bytes: Uint8List.fromList(jsonBytes),
            name: 'abc.text.json',
          ));
      index.record(ev);

      final loader = SmartJournalEntityLoader(
        attachmentIndex: index,
        loggingService: loggingService,
      );

      final loaded = await loader.load(jsonPath: relJson);
      expect(
        loaded.maybeMap(
          journalEntry: (j) => j.entryText?.plainText,
          orElse: () => null,
        ),
        'hello',
      );

      // File exists under temp doc dir
      final docDir = getIt<Directory>().path;
      final normalized = stripLeadingSlashes(relJson);
      final f = File(path.join(docDir, normalized));
      expect(f.existsSync(), isTrue);
      expect(f.lengthSync(), greaterThan(0));
    });

    tearDown(() async {
      await getIt.reset();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    // (SmartJournalEntityLoader local-read logging tests deferred)

    test('ensures missing image media via AttachmentIndex', () async {
      // Arrange: JSON for an image entity exists, media file does not.
      final image = JournalImage(
        meta: Metadata(
          id: 'img-1',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
        ),
        data: ImageData(
          imageId: 'img-1',
          imageDirectory: '/images/2024-01-01/',
          imageFile: 'picture.jpg',
          capturedAt: DateTime.now(),
        ),
      );
      final relJson = '${getRelativeImagePath(image)}.json';
      final jsonPathImg = path.join(tempDir.path, stripLeadingSlashes(relJson));
      final jsonFile = File(jsonPathImg);
      await jsonFile.create(recursive: true);
      await jsonFile.writeAsString(jsonEncode(image.toJson()));

      final relMedia = getRelativeImagePath(image);
      final mediaPathImg =
          path.join(tempDir.path, stripLeadingSlashes(relMedia));
      final mediaFile = File(mediaPathImg);
      expect(mediaFile.existsSync(), isFalse);

      // Index contains a descriptor for the media path.
      final index = AttachmentIndex();
      final ev = MockEvent();
      when(() => ev.eventId).thenReturn('evt-img-empty');
      when(() => ev.attachmentMimetype).thenReturn('image/jpeg');
      when(() => ev.content).thenReturn({'relativePath': relMedia});
      when(ev.downloadAndDecryptAttachment).thenAnswer((_) async => MatrixFile(
            bytes: Uint8List.fromList([1, 2, 3]),
            name: 'picture.jpg',
          ));
      index.record(ev);

      // Act: Load via smart loader (no incoming VC needed for media ensure).
      final loader = SmartJournalEntityLoader(
        attachmentIndex: index,
        loggingService: loggingService,
      );
      final loaded = await loader.load(jsonPath: relJson);

      // Assert entity and media written.
      expect(loaded.meta.id, 'img-1');
      expect(mediaFile.existsSync(), isTrue);
      expect(mediaFile.lengthSync(), greaterThan(0));
      verify(ev.downloadAndDecryptAttachment).called(1);
    });

    test('image media ensure logs and throws on empty bytes', () async {
      final image = JournalImage(
        meta: Metadata(
          id: 'img-empty',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
        ),
        data: ImageData(
          imageId: 'img-empty',
          imageDirectory: '/images/2024-01-01/',
          imageFile: 'empty.jpg',
          capturedAt: DateTime.now(),
        ),
      );
      final relJson = '${getRelativeImagePath(image)}.json';
      final jsonPathImg = path.join(tempDir.path, stripLeadingSlashes(relJson));
      File(jsonPathImg)
        ..createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(image.toJson()));

      final relMedia = getRelativeImagePath(image);
      final index = AttachmentIndex();
      final ev = MockEvent();
      when(() => ev.attachmentMimetype).thenReturn('image/jpeg');
      when(() => ev.content).thenReturn({'relativePath': relMedia});
      when(ev.downloadAndDecryptAttachment)
          .thenAnswer((_) async => MatrixFile(bytes: Uint8List(0), name: 'x'));
      index.record(ev);

      final loader = SmartJournalEntityLoader(
        attachmentIndex: index,
        loggingService: loggingService,
      );
      await expectLater(
        () => loader.load(jsonPath: relJson),
        throwsA(isA<FileSystemException>()),
      );
      verify(
        () => loggingService.captureException(
          any<Object>(),
          domain: 'MATRIX_SERVICE',
          subDomain: 'SmartLoader.fetchMedia',
          stackTrace: any<StackTrace>(named: 'stackTrace'),
        ),
      ).called(1);
    });

    test('no-VC JSON fetch logs and throws on empty bytes', () async {
      const relJson = '/text_entries/2024-02-01/empty.text.json';
      final index = AttachmentIndex();
      final ev = MockEvent();
      when(() => ev.eventId).thenReturn('evt-json-empty');
      when(() => ev.attachmentMimetype).thenReturn('application/json');
      when(() => ev.content).thenReturn({'relativePath': relJson});
      when(ev.downloadAndDecryptAttachment)
          .thenAnswer((_) async => MatrixFile(bytes: Uint8List(0), name: 'x'));
      index.record(ev);

      final loader = SmartJournalEntityLoader(
        attachmentIndex: index,
        loggingService: loggingService,
      );
      await expectLater(
        () => loader.load(jsonPath: relJson),
        throwsA(isA<FileSystemException>()),
      );
      verify(
        () => loggingService.captureException(
          any<Object>(),
          domain: 'MATRIX_SERVICE',
          subDomain: 'SmartLoader.fetchJson.noVc',
          stackTrace: any<StackTrace>(named: 'stackTrace'),
        ),
      ).called(1);
    });

    test('throws and logs when image media missing and descriptor not indexed',
        () async {
      final image = JournalImage(
        meta: Metadata(
          id: 'img-2',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
        ),
        data: ImageData(
          imageId: 'img-2',
          imageDirectory: '/images/2024-01-01/',
          imageFile: 'missing.jpg',
          capturedAt: DateTime.now(),
        ),
      );
      final relJson = '${getRelativeImagePath(image)}.json';
      final jsonPathMissing =
          path.join(tempDir.path, stripLeadingSlashes(relJson));
      final createdJson = File(jsonPathMissing)
        ..createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(image.toJson()));
      expect(createdJson.existsSync(), isTrue);

      final index = AttachmentIndex(logging: loggingService);
      final loader = SmartJournalEntityLoader(
        attachmentIndex: index,
        loggingService: loggingService,
      );
      await expectLater(
        () => loader.load(jsonPath: relJson),
        throwsA(isA<FileSystemException>()),
      );
      verify(
        () => loggingService.captureEvent(
          contains('smart.media.miss path=${getRelativeImagePath(image)}'),
          domain: 'MATRIX_SERVICE',
          subDomain: 'SmartLoader.fetchMedia',
        ),
      ).called(1);
    });

    test('ensures missing audio media via AttachmentIndex', () async {
      final audio = JournalAudio(
        meta: Metadata(
          id: 'aud-1',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
        ),
        data: AudioData(
          audioDirectory: '/audio/2024-01-01/',
          audioFile: 'clip.aac',
          duration: const Duration(seconds: 1),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
        ),
      );
      final relJson = '${AudioUtils.getRelativeAudioPath(audio)}.json';
      final jsonPathAud = path.join(tempDir.path, stripLeadingSlashes(relJson));
      File(jsonPathAud)
        ..createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(audio.toJson()));

      final relMedia = AudioUtils.getRelativeAudioPath(audio);
      final mediaPathAud =
          path.join(tempDir.path, stripLeadingSlashes(relMedia));
      final mediaFile = File(mediaPathAud);
      expect(mediaFile.existsSync(), isFalse);

      final index = AttachmentIndex();
      final ev = MockEvent();
      when(() => ev.attachmentMimetype).thenReturn('audio/aac');
      when(() => ev.content).thenReturn({'relativePath': relMedia});
      when(ev.downloadAndDecryptAttachment).thenAnswer((_) async => MatrixFile(
            bytes: Uint8List.fromList([9, 9, 9]),
            name: 'clip.aac',
          ));
      index.record(ev);

      final loader = SmartJournalEntityLoader(
        attachmentIndex: index,
        loggingService: loggingService,
      );
      final loaded = await loader.load(jsonPath: relJson);

      expect(loaded.meta.id, 'aud-1');
      expect(mediaFile.existsSync(), isTrue);
      expect(mediaFile.lengthSync(), greaterThan(0));
      verify(ev.downloadAndDecryptAttachment).called(1);
    });

    test('returns local entity when incoming VC is equal or older', () async {
      // Arrange a local entity JSON with a particular vector clock
      const localVc = VectorClock({'a': 2});
      final entity = JournalEntry(
        meta: Metadata(
          id: 'vc-1',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
          vectorClock: localVc,
        ),
        entryText: const EntryText(plainText: 'local'),
      );
      const relJson = '/text_entries/2024-01-01/vc-1.text.json';
      final jsonPath = path.join(tempDir.path, stripLeadingSlashes(relJson));
      File(jsonPath)
        ..createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(entity.toJson()));

      final index = AttachmentIndex();
      final loader = SmartJournalEntityLoader(
        attachmentIndex: index,
        loggingService: loggingService,
      );

      // Incoming VC is equal -> loader must return local without fetching
      final loaded = await loader.load(
        jsonPath: relJson,
        incomingVectorClock: const VectorClock({'a': 2}),
      );
      expect(
        loaded.maybeMap(
          journalEntry: (j) => j.entryText?.plainText,
          orElse: () => null,
        ),
        'local',
      );
    });

    test('VC path: index miss throws and logs fetch.miss', () async {
      const relJson = '/text_entries/2024-01-01/missing.text.json';
      final index = AttachmentIndex(logging: loggingService);
      final loader = SmartJournalEntityLoader(
        attachmentIndex: index,
        loggingService: loggingService,
      );
      when(() => loggingService.captureEvent(
            any<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          )).thenAnswer((_) {});
      await expectLater(
        () => loader.load(
          jsonPath: relJson,
          incomingVectorClock: const VectorClock({'n': 1}),
        ),
        throwsA(isA<FileSystemException>()),
      );
      verify(
        () => loggingService.captureEvent(
          contains('smart.fetch.miss path=$relJson'),
          domain: 'MATRIX_SERVICE',
          subDomain: 'SmartLoader.fetch',
        ),
      ).called(1);
    });

    test('purges cached descriptor and refreshes stale download', () async {
      const relJson = '/text_entries/2024-01-01/stale.text.json';
      final index = AttachmentIndex(logging: loggingService);
      final ev = MockEvent();
      when(() => ev.eventId).thenReturn('evt-stale');
      when(() => ev.attachmentMimetype).thenReturn('application/json');
      when(() => ev.content).thenReturn({'relativePath': relJson});
      final room = MockMatrixRoom();
      final client = MockMatrixClient();
      final database = MockMatrixDatabase();
      when(() => ev.room).thenReturn(room);
      when(() => room.client).thenReturn(client);
      when(() => client.database).thenReturn(database);
      final descriptorUri = Uri.parse('mxc://server/file');
      when(ev.attachmentOrThumbnailMxcUrl).thenReturn(descriptorUri);
      when(() => database.deleteFile(descriptorUri))
          .thenAnswer((_) async => true);

      final stale = JournalEntry(
        meta: Metadata(
          id: 'stale-1',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
          vectorClock: const VectorClock({'n': 1}),
        ),
        entryText: const EntryText(plainText: 'old'),
      );
      final fresh = JournalEntry(
        meta: Metadata(
          id: stale.meta.id,
          createdAt: stale.meta.createdAt,
          updatedAt: DateTime.now(),
          dateFrom: stale.meta.dateFrom,
          dateTo: stale.meta.dateTo,
          vectorClock: const VectorClock({'n': 2}),
        ),
        entryText: const EntryText(plainText: 'fresh'),
      );
      final staleBytes =
          Uint8List.fromList(jsonEncode(stale.toJson()).codeUnits);
      final freshBytes =
          Uint8List.fromList(jsonEncode(fresh.toJson()).codeUnits);
      var calls = 0;
      when(ev.downloadAndDecryptAttachment).thenAnswer((_) async {
        calls++;
        return MatrixFile(
          bytes: calls == 1 ? staleBytes : freshBytes,
          name: 'entry.json',
        );
      });
      index.record(ev);

      final loader = SmartJournalEntityLoader(
        attachmentIndex: index,
        loggingService: loggingService,
      );
      var purges = 0;
      loader.onCachePurge = () => purges++;

      final loaded = await loader.load(
        jsonPath: relJson,
        incomingVectorClock: const VectorClock({'n': 2}),
      );

      expect(loaded.meta.id, fresh.meta.id);
      expect(calls, 2);
      verify(() => database.deleteFile(descriptorUri)).called(1);
      expect(purges, 1);
      verify(
        () => loggingService.captureEvent(
          contains('smart.fetch.stale_vc path=$relJson'),
          domain: 'MATRIX_SERVICE',
          subDomain: 'SmartLoader.fetch',
        ),
      ).called(1);
      verify(
        () => loggingService.captureEvent(
          contains('smart.fetch.stale_vc.refresh path=$relJson'),
          domain: 'MATRIX_SERVICE',
          subDomain: 'SmartLoader.fetch',
        ),
      ).called(1);
      final saved = File(path.join(
        getIt<Directory>().path,
        stripLeadingSlashes(relJson),
      ));
      expect(saved.existsSync(), isTrue);
    });

    test('throws when descriptor remains stale after refresh', () async {
      const relJson = '/text_entries/2024-01-01/staler.text.json';
      final index = AttachmentIndex(logging: loggingService);
      final ev = MockEvent();
      when(() => ev.eventId).thenReturn('evt-staler');
      when(() => ev.attachmentMimetype).thenReturn('application/json');
      when(() => ev.content).thenReturn({'relativePath': relJson});
      final room = MockMatrixRoom();
      final client = MockMatrixClient();
      final database = MockMatrixDatabase();
      when(() => ev.room).thenReturn(room);
      when(() => room.client).thenReturn(client);
      when(() => client.database).thenReturn(database);
      final descriptorUri = Uri.parse('mxc://server/old');
      when(ev.attachmentOrThumbnailMxcUrl).thenReturn(descriptorUri);
      when(() => database.deleteFile(descriptorUri))
          .thenAnswer((_) async => true);

      final stale = JournalEntry(
        meta: Metadata(
          id: 'stale-2',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
          vectorClock: const VectorClock({'n': 1}),
        ),
        entryText: const EntryText(plainText: 'older'),
      );
      final staleBytes =
          Uint8List.fromList(jsonEncode(stale.toJson()).codeUnits);
      var calls = 0;
      when(ev.downloadAndDecryptAttachment).thenAnswer((_) async {
        calls++;
        return MatrixFile(bytes: staleBytes, name: 'entry.json');
      });
      index.record(ev);

      final loader = SmartJournalEntityLoader(
        attachmentIndex: index,
        loggingService: loggingService,
      );
      var purges = 0;
      loader.onCachePurge = () => purges++;

      await expectLater(
        () => loader.load(
          jsonPath: relJson,
          incomingVectorClock: const VectorClock({'n': 3}),
        ),
        throwsA(
          isA<FileSystemException>().having(
            (e) => e.message,
            'message',
            contains('after refresh'),
          ),
        ),
      );
      expect(calls, 2);
      expect(purges, 1);
      verify(
        () => loggingService.captureEvent(
          contains('smart.fetch.stale_vc.pending path=$relJson'),
          domain: 'MATRIX_SERVICE',
          subDomain: 'SmartLoader.fetch',
        ),
      ).called(1);
    });

    test('trips circuit breaker after repeated stale descriptors', () async {
      const relJson = '/text_entries/2024-01-01/always_stale.text.json';
      final index = AttachmentIndex(logging: loggingService);
      final ev = MockEvent();
      when(() => ev.eventId).thenReturn('evt-stale-loop');
      when(() => ev.attachmentMimetype).thenReturn('application/json');
      when(() => ev.content).thenReturn({'relativePath': relJson});
      final room = MockMatrixRoom();
      final client = MockMatrixClient();
      final database = MockMatrixDatabase();
      when(() => ev.room).thenReturn(room);
      when(() => room.client).thenReturn(client);
      when(() => client.database).thenReturn(database);
      final descriptorUri = Uri.parse('mxc://server/always-stale');
      when(ev.attachmentOrThumbnailMxcUrl).thenReturn(descriptorUri);
      when(() => database.deleteFile(descriptorUri))
          .thenAnswer((_) async => true);
      when(() => loggingService.captureEvent(
            any<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          )).thenAnswer((_) {});

      final stale = JournalEntry(
        meta: Metadata(
          id: 'stale-loop',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
          vectorClock: const VectorClock({'n': 1}),
        ),
        entryText: const EntryText(plainText: 'stale'),
      );
      final staleBytes =
          Uint8List.fromList(jsonEncode(stale.toJson()).codeUnits);
      var downloads = 0;
      when(ev.downloadAndDecryptAttachment).thenAnswer((_) async {
        downloads++;
        return MatrixFile(
          bytes: staleBytes,
          name: 'entry.json',
        );
      });
      index.record(ev);

      final loader = SmartJournalEntityLoader(
        attachmentIndex: index,
        loggingService: loggingService,
      );
      var purges = 0;
      loader.onCachePurge = () => purges++;

      Future<void> attemptLoad() => loader.load(
            jsonPath: relJson,
            incomingVectorClock: const VectorClock({'n': 3}),
          );

      await expectLater(attemptLoad, throwsA(isA<FileSystemException>()));
      await expectLater(attemptLoad, throwsA(isA<FileSystemException>()));
      await expectLater(
        attemptLoad,
        throwsA(
          isA<FileSystemException>().having(
            (error) => error.message,
            'message',
            contains('circuit breaker'),
          ),
        ),
      );

      expect(downloads, 5);
      expect(purges, 2);
      verify(() => database.deleteFile(descriptorUri)).called(2);
      verify(
        () => loggingService.captureEvent(
          contains('smart.fetch.stale_vc.breaker path=$relJson'),
          domain: 'MATRIX_SERVICE',
          subDomain: 'SmartLoader.fetch',
        ),
      ).called(1);
    });

    group('SmartLoader circuit breaker cleanup -', () {
      test('clears failure count on success after prior stale retries',
          () async {
        const relJson = '/text_entries/2024-01-01/reset.text.json';
        final index = AttachmentIndex(logging: loggingService);
        final ev = MockEvent();
        when(() => ev.eventId).thenReturn('evt-reset');
        when(() => ev.attachmentMimetype).thenReturn('application/json');
        when(() => ev.content).thenReturn({'relativePath': relJson});
        final room = MockMatrixRoom();
        final client = MockMatrixClient();
        final database = MockMatrixDatabase();
        when(() => ev.room).thenReturn(room);
        when(() => room.client).thenReturn(client);
        when(() => client.database).thenReturn(database);
        final descriptorUri = Uri.parse('mxc://server/reset');
        when(ev.attachmentOrThumbnailMxcUrl).thenReturn(descriptorUri);
        when(() => database.deleteFile(descriptorUri))
            .thenAnswer((_) async => true);
        when(() => loggingService.captureEvent(
              any<Object>(),
              domain: any(named: 'domain'),
              subDomain: any(named: 'subDomain'),
            )).thenAnswer((_) {});

        final staleOne = JournalEntry(
          meta: Metadata(
            id: 'reset',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
            vectorClock: const VectorClock({'n': 1}),
          ),
          entryText: const EntryText(plainText: 'stale-1'),
        );
        final freshOne = staleOne.copyWith(
          entryText: const EntryText(plainText: 'fresh-1'),
          meta: staleOne.meta.copyWith(
            vectorClock: const VectorClock({'n': 2}),
            updatedAt: DateTime.now(),
          ),
        );
        final staleTwo = staleOne.copyWith(
          entryText: const EntryText(plainText: 'stale-2'),
          meta: staleOne.meta.copyWith(
            vectorClock: const VectorClock({'n': 2}),
            updatedAt: DateTime.now(),
          ),
        );
        final freshTwo = staleOne.copyWith(
          entryText: const EntryText(plainText: 'fresh-2'),
          meta: staleOne.meta.copyWith(
            vectorClock: const VectorClock({'n': 3}),
            updatedAt: DateTime.now(),
          ),
        );

        var downloads = 0;
        when(ev.downloadAndDecryptAttachment).thenAnswer((_) async {
          downloads++;
          final entry = switch (downloads) {
            1 => staleOne,
            2 => freshOne,
            3 => staleTwo,
            _ => freshTwo,
          };
          return MatrixFile(
            bytes: Uint8List.fromList(jsonEncode(entry.toJson()).codeUnits),
            name: 'entry.json',
          );
        });
        index.record(ev);

        final loader = SmartJournalEntityLoader(
          attachmentIndex: index,
          loggingService: loggingService,
        );
        var purges = 0;
        loader.onCachePurge = () => purges++;

        final first = await loader.load(
          jsonPath: relJson,
          incomingVectorClock: const VectorClock({'n': 2}),
        );
        expect(first.entryText?.plainText, 'fresh-1');

        final second = await loader.load(
          jsonPath: relJson,
          incomingVectorClock: const VectorClock({'n': 3}),
        );
        expect(second.entryText?.plainText, 'fresh-2');

        expect(downloads, 4);
        expect(purges, 2);
        verify(() => database.deleteFile(descriptorUri)).called(2);
      });

      test('maintains separate failure counts by jsonPath', () async {
        const relJsonA = '/text_entries/2024-01-01/a.text.json';
        const relJsonB = '/text_entries/2024-01-01/b.text.json';
        final index = AttachmentIndex(logging: loggingService);
        final evA = MockEvent();
        final evB = MockEvent();
        when(() => evA.eventId).thenReturn('evt-a');
        when(() => evB.eventId).thenReturn('evt-b');
        when(() => evA.attachmentMimetype).thenReturn('application/json');
        when(() => evB.attachmentMimetype).thenReturn('application/json');
        when(() => evA.content).thenReturn({'relativePath': relJsonA});
        when(() => evB.content).thenReturn({'relativePath': relJsonB});
        final roomA = MockMatrixRoom();
        final roomB = MockMatrixRoom();
        final clientA = MockMatrixClient();
        final clientB = MockMatrixClient();
        final database = MockMatrixDatabase();
        when(() => evA.room).thenReturn(roomA);
        when(() => roomA.client).thenReturn(clientA);
        when(() => clientA.database).thenReturn(database);
        when(() => evB.room).thenReturn(roomB);
        when(() => roomB.client).thenReturn(clientB);
        when(() => clientB.database).thenReturn(database);
        final uriA = Uri.parse('mxc://server/a');
        final uriB = Uri.parse('mxc://server/b');
        when(evA.attachmentOrThumbnailMxcUrl).thenReturn(uriA);
        when(evB.attachmentOrThumbnailMxcUrl).thenReturn(uriB);
        when(() => database.deleteFile(uriA)).thenAnswer((_) async => true);
        when(() => database.deleteFile(uriB)).thenAnswer((_) async => true);
        when(() => loggingService.captureEvent(
              any<Object>(),
              domain: any(named: 'domain'),
              subDomain: any(named: 'subDomain'),
            )).thenAnswer((_) {});

        JournalEntry buildEntry(String id, int clock, String text) {
          return JournalEntry(
            meta: Metadata(
              id: id,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              dateFrom: DateTime.now(),
              dateTo: DateTime.now(),
              vectorClock: VectorClock({'n': clock}),
            ),
            entryText: EntryText(plainText: text),
          );
        }

        var downloadsA = 0;
        when(evA.downloadAndDecryptAttachment).thenAnswer((_) async {
          downloadsA++;
          final entry = downloadsA == 1
              ? buildEntry('a', 1, 'stale-a')
              : buildEntry('a', 2, 'fresh-a');
          return MatrixFile(
            bytes: Uint8List.fromList(jsonEncode(entry.toJson()).codeUnits),
            name: 'a.json',
          );
        });

        var downloadsB = 0;
        when(evB.downloadAndDecryptAttachment).thenAnswer((_) async {
          downloadsB++;
          final entry = downloadsB == 1
              ? buildEntry('b', 1, 'stale-b')
              : buildEntry('b', 2, 'fresh-b');
          return MatrixFile(
            bytes: Uint8List.fromList(jsonEncode(entry.toJson()).codeUnits),
            name: 'b.json',
          );
        });

        index
          ..record(evA)
          ..record(evB);

        final loader = SmartJournalEntityLoader(
          attachmentIndex: index,
          loggingService: loggingService,
        );
        var purges = 0;
        loader.onCachePurge = () => purges++;

        final loadedA = await loader.load(
          jsonPath: relJsonA,
          incomingVectorClock: const VectorClock({'n': 2}),
        );
        final loadedB = await loader.load(
          jsonPath: relJsonB,
          incomingVectorClock: const VectorClock({'n': 2}),
        );

        expect(loadedA.entryText?.plainText, 'fresh-a');
        expect(loadedB.entryText?.plainText, 'fresh-b');
        expect(purges, 2);
        verify(() => database.deleteFile(uriA)).called(1);
        verify(() => database.deleteFile(uriB)).called(1);
      });
    });

    group('SmartLoader cache purge edge cases -', () {
      test('onCachePurge not invoked when descriptor lacks MXC', () async {
        const relJson = '/text_entries/2024-01-01/no_mxc.text.json';
        final index = AttachmentIndex(logging: loggingService);
        final ev = MockEvent();
        when(() => ev.eventId).thenReturn('evt-no-mxc');
        when(() => ev.attachmentMimetype).thenReturn('application/json');
        when(() => ev.content).thenReturn({'relativePath': relJson});
        final room = MockMatrixRoom();
        final client = MockMatrixClient();
        final database = MockMatrixDatabase();
        when(() => ev.room).thenReturn(room);
        when(() => room.client).thenReturn(client);
        when(() => client.database).thenReturn(database);
        when(ev.attachmentOrThumbnailMxcUrl).thenReturn(null);
        when(() => loggingService.captureEvent(
              any<Object>(),
              domain: any(named: 'domain'),
              subDomain: any(named: 'subDomain'),
            )).thenAnswer((_) {});

        final stale = JournalEntry(
          meta: Metadata(
            id: 'no-mxc',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
            vectorClock: const VectorClock({'n': 1}),
          ),
          entryText: const EntryText(plainText: 'stale'),
        );
        final fresh = stale.copyWith(
          entryText: const EntryText(plainText: 'fresh'),
          meta: stale.meta.copyWith(
            vectorClock: const VectorClock({'n': 2}),
            updatedAt: DateTime.now(),
          ),
        );
        var downloads = 0;
        when(ev.downloadAndDecryptAttachment).thenAnswer((_) async {
          downloads++;
          final entry = downloads == 1 ? stale : fresh;
          return MatrixFile(
            bytes: Uint8List.fromList(jsonEncode(entry.toJson()).codeUnits),
            name: 'entry.json',
          );
        });
        index.record(ev);

        final loader = SmartJournalEntityLoader(
          attachmentIndex: index,
          loggingService: loggingService,
        );
        var purges = 0;
        loader.onCachePurge = () => purges++;

        final loaded = await loader.load(
          jsonPath: relJson,
          incomingVectorClock: const VectorClock({'n': 2}),
        );

        expect(loaded.entryText?.plainText, 'fresh');
        expect(purges, 0);
        verifyNever(() => database.deleteFile(any<Uri>()));
      });

      test('onCachePurge not invoked when deleteFile throws', () async {
        const relJson = '/text_entries/2024-01-01/delete_error.text.json';
        final index = AttachmentIndex(logging: loggingService);
        final ev = MockEvent();
        when(() => ev.eventId).thenReturn('evt-delete-error');
        when(() => ev.attachmentMimetype).thenReturn('application/json');
        when(() => ev.content).thenReturn({'relativePath': relJson});
        final room = MockMatrixRoom();
        final client = MockMatrixClient();
        final database = MockMatrixDatabase();
        when(() => ev.room).thenReturn(room);
        when(() => room.client).thenReturn(client);
        when(() => client.database).thenReturn(database);
        final descriptorUri = Uri.parse('mxc://server/delete-error');
        when(ev.attachmentOrThumbnailMxcUrl).thenReturn(descriptorUri);
        when(() => database.deleteFile(descriptorUri))
            .thenThrow(Exception('db failure'));
        when(() => loggingService.captureEvent(
              any<Object>(),
              domain: any(named: 'domain'),
              subDomain: any(named: 'subDomain'),
            )).thenAnswer((_) {});
        when(() => loggingService.captureException(
              any<Object>(),
              domain: any(named: 'domain'),
              subDomain: any(named: 'subDomain'),
              stackTrace: any<StackTrace>(named: 'stackTrace'),
            )).thenAnswer((_) {});

        final stale = JournalEntry(
          meta: Metadata(
            id: 'delete-error',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
            vectorClock: const VectorClock({'n': 1}),
          ),
          entryText: const EntryText(plainText: 'stale'),
        );
        final fresh = stale.copyWith(
          entryText: const EntryText(plainText: 'fresh'),
          meta: stale.meta.copyWith(
            vectorClock: const VectorClock({'n': 2}),
            updatedAt: DateTime.now(),
          ),
        );
        var downloads = 0;
        when(ev.downloadAndDecryptAttachment).thenAnswer((_) async {
          downloads++;
          final entry = downloads == 1 ? stale : fresh;
          return MatrixFile(
            bytes: Uint8List.fromList(jsonEncode(entry.toJson()).codeUnits),
            name: 'entry.json',
          );
        });
        index.record(ev);

        final loader = SmartJournalEntityLoader(
          attachmentIndex: index,
          loggingService: loggingService,
        );
        var purges = 0;
        loader.onCachePurge = () => purges++;

        final loaded = await loader.load(
          jsonPath: relJson,
          incomingVectorClock: const VectorClock({'n': 2}),
        );

        expect(loaded.entryText?.plainText, 'fresh');
        expect(purges, 0);
        verify(() => database.deleteFile(descriptorUri)).called(1);
        verify(
          () => loggingService.captureException(
            any<Object>(),
            domain: 'MATRIX_SERVICE',
            subDomain: 'SmartLoader.purge',
            stackTrace: any<StackTrace>(named: 'stackTrace'),
          ),
        ).called(1);
      });
    });

    group('SmartLoader vector clock edge cases -', () {
      test('succeeds when incoming VC is null but descriptor VC is present',
          () async {
        const relJson = '/text_entries/2024-01-02/vc_present.text.json';
        final index = AttachmentIndex(logging: loggingService);
        final ev = MockEvent();
        when(() => ev.eventId).thenReturn('evt-vc-present');
        when(() => ev.attachmentMimetype).thenReturn('application/json');
        when(() => ev.content).thenReturn({'relativePath': relJson});
        final entry = JournalEntry(
          meta: Metadata(
            id: 'vc-present',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
            vectorClock: const VectorClock({'n': 5}),
          ),
          entryText: const EntryText(plainText: 'descriptor with vc'),
        );
        when(ev.downloadAndDecryptAttachment)
            .thenAnswer((_) async => MatrixFile(
                  bytes:
                      Uint8List.fromList(jsonEncode(entry.toJson()).codeUnits),
                  name: 'entry.json',
                ));
        index.record(ev);

        final loader = SmartJournalEntityLoader(
          attachmentIndex: index,
          loggingService: loggingService,
        );

        final loaded = await loader.load(jsonPath: relJson);
        expect(loaded.meta.vectorClock, const VectorClock({'n': 5}));
        expect(loaded.entryText?.plainText, 'descriptor with vc');
      });

      test('throws when descriptor lacks VC but incoming VC provided',
          () async {
        const relJson = '/text_entries/2024-01-03/missing_vc.text.json';
        final index = AttachmentIndex(logging: loggingService);
        final ev = MockEvent();
        when(() => ev.eventId).thenReturn('evt-missing-vc');
        when(() => ev.attachmentMimetype).thenReturn('application/json');
        when(() => ev.content).thenReturn({'relativePath': relJson});
        final entry = JournalEntry(
          meta: Metadata(
            id: 'missing-vc',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
          ),
          entryText: const EntryText(plainText: 'descriptor missing vc'),
        );
        when(ev.downloadAndDecryptAttachment)
            .thenAnswer((_) async => MatrixFile(
                  bytes:
                      Uint8List.fromList(jsonEncode(entry.toJson()).codeUnits),
                  name: 'entry.json',
                ));
        index.record(ev);

        final loader = SmartJournalEntityLoader(
          attachmentIndex: index,
          loggingService: loggingService,
        );

        await expectLater(
          () => loader.load(
            jsonPath: relJson,
            incomingVectorClock: const VectorClock({'n': 1}),
          ),
          throwsA(
            isA<FileSystemException>().having(
              (error) => error.message,
              'message',
              contains('missing attachment vector clock'),
            ),
          ),
        );
      });

      test('succeeds when both incoming and descriptor VCs are null', () async {
        const relJson = '/text_entries/2024-01-04/both_null.text.json';
        final index = AttachmentIndex(logging: loggingService);
        final ev = MockEvent();
        when(() => ev.eventId).thenReturn('evt-both-null');
        when(() => ev.attachmentMimetype).thenReturn('application/json');
        when(() => ev.content).thenReturn({'relativePath': relJson});
        final entry = JournalEntry(
          meta: Metadata(
            id: 'both-null',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
          ),
          entryText: const EntryText(plainText: 'both null'),
        );
        when(ev.downloadAndDecryptAttachment)
            .thenAnswer((_) async => MatrixFile(
                  bytes:
                      Uint8List.fromList(jsonEncode(entry.toJson()).codeUnits),
                  name: 'entry.json',
                ));
        index.record(ev);

        final loader = SmartJournalEntityLoader(
          attachmentIndex: index,
          loggingService: loggingService,
        );

        final loaded = await loader.load(jsonPath: relJson);
        expect(loaded.meta.vectorClock, isNull);
        expect(loaded.entryText?.plainText, 'both null');
      });
    });

    group('SmartLoader error handling -', () {
      test('throws when refreshed descriptor returns empty bytes', () async {
        const relJson = '/text_entries/2024-01-05/empty_second.text.json';
        final index = AttachmentIndex(logging: loggingService);
        final ev = MockEvent();
        when(() => ev.eventId).thenReturn('evt-empty-second');
        when(() => ev.attachmentMimetype).thenReturn('application/json');
        when(() => ev.content).thenReturn({'relativePath': relJson});
        final room = MockMatrixRoom();
        final client = MockMatrixClient();
        final database = MockMatrixDatabase();
        when(() => ev.room).thenReturn(room);
        when(() => room.client).thenReturn(client);
        when(() => client.database).thenReturn(database);
        final descriptorUri = Uri.parse('mxc://server/empty-second');
        when(ev.attachmentOrThumbnailMxcUrl).thenReturn(descriptorUri);
        when(() => database.deleteFile(descriptorUri))
            .thenAnswer((_) async => true);

        final stale = JournalEntry(
          meta: Metadata(
            id: 'empty-second',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
            vectorClock: const VectorClock({'n': 1}),
          ),
          entryText: const EntryText(plainText: 'stale'),
        );

        var calls = 0;
        when(ev.downloadAndDecryptAttachment).thenAnswer((_) async {
          calls++;
          if (calls == 1) {
            return MatrixFile(
              bytes: Uint8List.fromList(jsonEncode(stale.toJson()).codeUnits),
              name: 'entry.json',
            );
          }
          return MatrixFile(bytes: Uint8List(0), name: 'entry.json');
        });
        index.record(ev);

        final loader = SmartJournalEntityLoader(
          attachmentIndex: index,
          loggingService: loggingService,
        );

        await expectLater(
          () => loader.load(
            jsonPath: relJson,
            incomingVectorClock: const VectorClock({'n': 2}),
          ),
          throwsA(
            isA<FileSystemException>().having(
              (error) => error.message,
              'message',
              contains('empty attachment bytes'),
            ),
          ),
        );
        verify(() => database.deleteFile(descriptorUri)).called(1);
        verify(
          () => loggingService.captureException(
            any<Object>(),
            domain: 'MATRIX_SERVICE',
            subDomain: 'SmartLoader.fetchJson',
            stackTrace: any<StackTrace>(named: 'stackTrace'),
          ),
        ).called(1);
      });

      test('logs and rethrows when descriptor JSON is invalid', () async {
        const relJson = '/text_entries/2024-01-06/invalid_json.text.json';
        final index = AttachmentIndex(logging: loggingService);
        final ev = MockEvent();
        when(() => ev.eventId).thenReturn('evt-invalid-json');
        when(() => ev.attachmentMimetype).thenReturn('application/json');
        when(() => ev.content).thenReturn({'relativePath': relJson});
        final room = MockMatrixRoom();
        final client = MockMatrixClient();
        final database = MockMatrixDatabase();
        when(() => ev.room).thenReturn(room);
        when(() => room.client).thenReturn(client);
        when(() => client.database).thenReturn(database);
        when(ev.attachmentOrThumbnailMxcUrl)
            .thenReturn(Uri.parse('mxc://server/invalid-json'));
        when(() => database.deleteFile(any())).thenAnswer((_) async => true);

        when(ev.downloadAndDecryptAttachment).thenAnswer(
          (_) async => MatrixFile(
            bytes: Uint8List.fromList('{not-json'.codeUnits),
            name: 'entry.json',
          ),
        );
        index.record(ev);

        final loader = SmartJournalEntityLoader(
          attachmentIndex: index,
          loggingService: loggingService,
        );

        await expectLater(
          () => loader.load(
            jsonPath: relJson,
            incomingVectorClock: const VectorClock({'n': 1}),
          ),
          throwsA(isA<FormatException>()),
        );
        verify(
          () => loggingService.captureException(
            any<Object>(),
            domain: 'MATRIX_SERVICE',
            subDomain: 'SmartLoader.fetchJson',
            stackTrace: any<StackTrace>(named: 'stackTrace'),
          ),
        ).called(1);
      });
    });

    test('no-VC path: does not fetch when file exists and non-empty', () async {
      const relJson = '/text_entries/2024-01-01/present.text.json';
      final entity = JournalEntry(
        meta: Metadata(
          id: 'present-1',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
        ),
        entryText: const EntryText(plainText: 'present'),
      );
      final jsonPath = path.join(tempDir.path, stripLeadingSlashes(relJson));
      File(jsonPath)
        ..createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(entity.toJson()));

      var downloads = 0;
      final index = AttachmentIndex();
      final ev = MockEvent();
      when(() => ev.eventId).thenReturn('evt-present');
      when(ev.downloadAndDecryptAttachment).thenAnswer((_) async {
        downloads++;
        return MatrixFile(bytes: Uint8List.fromList(const []), name: 'x');
      });
      when(() => ev.attachmentMimetype).thenReturn('application/json');
      when(() => ev.content).thenReturn({'relativePath': relJson});
      index.record(ev);

      final loader = SmartJournalEntityLoader(
        attachmentIndex: index,
        loggingService: loggingService,
      );
      final loaded = await loader.load(jsonPath: relJson);
      expect(
          loaded.maybeMap(
              journalEntry: (j) => j.entryText?.plainText, orElse: () => null),
          'present');
      expect(downloads, 0);
    });
  });

  group('SyncEventProcessor listener -', () {
    test('cachePurgeListener with non-smart loader does not crash', () {
      final processorWithFileLoader = SyncEventProcessor(
        loggingService: loggingService,
        updateNotifications: updateNotifications,
        aiConfigRepository: aiConfigRepository,
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
    when(() => journalDb.upsertEntryLink(link)).thenAnswer((_) async => 1);

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
    when(() => journalDb.upsertEntryLink(link)).thenAnswer((_) async => 0);

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
    when(() => journalDb.upsertEntryLink(link)).thenAnswer((_) async => 1);
    when(() => loggingService.captureEvent(
          any<Object>(),
          domain: 'MATRIX_SERVICE',
          subDomain: 'apply.entryLink',
        )).thenThrow(Exception('logging failed'));

    // Should not throw - logging is best-effort
    await processor.process(event: event, journalDb: journalDb);

    verify(() => journalDb.upsertEntryLink(link)).called(1);
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
}
