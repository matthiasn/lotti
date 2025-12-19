// ignore_for_file: avoid_redundant_argument_values, cascade_invocations

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
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/sync/backfill/backfill_response_handler.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_index.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
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

class MockSettingsDb extends Mock implements SettingsDb {}

class MockMatrixRoom extends Mock implements Room {}

class MockMatrixClient extends Mock implements Client {}

class MockMatrixDatabase extends Mock implements DatabaseApi {}

class MockBackfillResponseHandler extends Mock
    implements BackfillResponseHandler {}

class MockSyncSequenceLogService extends Mock
    implements SyncSequenceLogService {}

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
    registerFallbackValue(
      const SyncBackfillRequest(entries: [], requesterId: ''),
    );
    registerFallbackValue(
      const SyncBackfillResponse(hostId: '', counter: 0, deleted: false),
    );
    registerFallbackValue(const VectorClock({'fallback': 1}));
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
        download(
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
      Future<DescriptorDownloadResult> attempt() => download(
            incoming: const VectorClock({'n': 5}),
            responses: [stale, stale],
          );

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
        download(
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

    final capturedLink = verify(
      () => journalDb.upsertEntryLink(captureAny<EntryLink>()),
    ).captured.single as EntryLink;
    expect(capturedLink.id, link.id);
    expect(capturedLink.fromId, link.fromId);
    expect(capturedLink.toId, link.toId);
    verify(
      () => updateNotifications.notify(const {'from', 'to'}, fromSync: true),
    ).called(1);
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
      processor.process(event: event, journalDb: journalDb),
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
      processor.process(event: event, journalDb: journalDb),
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
        loader.load(jsonPath: relJson),
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
        loader.load(jsonPath: relJson),
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
        loader.load(jsonPath: relJson),
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
        loader.load(
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

      await expectLater(attemptLoad(), throwsA(isA<FileSystemException>()));
      await expectLater(attemptLoad(), throwsA(isA<FileSystemException>()));
      await expectLater(
        attemptLoad(),
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
          loader.load(
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
          loader.load(
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
          loader.load(
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

    await expectLater(
      processor.process(event: event, journalDb: journalDb),
      throwsA(isA<FileSystemException>()),
    );
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

  test('stale descriptor is skipped when local entry is newer', () async {
    final entryId = fallbackJournalEntity.meta.id;
    final message = SyncMessage.journalEntity(
      id: entryId,
      jsonPath: '/entity.json',
      vectorClock: const VectorClock({'a': 10}),
      status: SyncEntryStatus.initial,
    );
    when(() => event.text).thenReturn(encodeMessage(message));
    when(() => journalEntityLoader.load(
          jsonPath: '/entity.json',
          incomingVectorClock: any(named: 'incomingVectorClock'),
        )).thenThrow(
      const FileSystemException('stale attachment json after refresh'),
    );
    when(() => journalDb.journalEntityById(entryId))
        .thenAnswer((_) async => fallbackJournalEntity);

    SyncApplyDiagnostics? captured;
    processor.applyObserver = (diag) => captured = diag;

    await processor.process(event: event, journalDb: journalDb);

    expect(captured, isNotNull);
    expect(captured!.skipReason, JournalUpdateSkipReason.olderOrEqual);
    expect(captured!.conflictStatus, contains('a_gt_b'));
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

    test('processes embedded links even when entity update is skipped',
        () async {
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
      when(() => journalDb.upsertEntryLink(link)).thenAnswer((_) async => 1);

      await processor.process(event: event, journalDb: journalDb);

      // Verify link WAS upserted even though entity update was skipped.
      // EntryLinks have their own vector clock for conflict resolution,
      // so they should be processed regardless of journal entity status.
      // This prevents gray calendar entries that rely on links for color lookup.
      verify(() => journalDb.upsertEntryLink(link)).called(1);

      // Verify logging for embedded link processing
      verify(() => loggingService.captureEvent(
            contains(
                'apply entryLink.embedded from=${link.fromId} to=${link.toId}'),
            domain: 'MATRIX_SERVICE',
            subDomain: 'apply.entryLink.embedded',
          )).called(1);

      // Verify summary shows 1 embedded link processed
      verify(() => loggingService.captureEvent(
            contains('embeddedLinks=1/1'),
            domain: 'MATRIX_SERVICE',
            subDomain: 'apply',
          )).called(1);

      // Verify notification sent for affected IDs from link
      verify(() => updateNotifications.notify(
            {link.fromId, link.toId},
            fromSync: true,
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

  group('SyncEventProcessor - Backfill Messages', () {
    test('SyncBackfillRequest is ignored when no handler configured', () async {
      const message = SyncBackfillRequest(
        entries: [
          BackfillRequestEntry(hostId: 'host-1', counter: 5),
        ],
        requesterId: 'requester-1',
      );

      when(() => event.text).thenReturn(encodeMessage(message));

      await processor.process(event: event, journalDb: journalDb);

      // Should log that request was ignored
      verify(
        () => loggingService.captureEvent(
          any<Object>(),
          domain: 'SYNC_BACKFILL',
          subDomain: 'apply',
        ),
      ).called(1);
    });

    test('SyncBackfillResponse is ignored when no handler configured',
        () async {
      const message = SyncBackfillResponse(
        hostId: 'host-1',
        counter: 5,
        deleted: false,
        entryId: 'entry-1',
      );

      when(() => event.text).thenReturn(encodeMessage(message));

      await processor.process(event: event, journalDb: journalDb);

      // Should log that response was ignored
      verify(
        () => loggingService.captureEvent(
          any<Object>(),
          domain: 'SYNC_BACKFILL',
          subDomain: 'apply',
        ),
      ).called(1);
    });

    test('SyncBackfillRequest is delegated to handler when configured',
        () async {
      const message = SyncBackfillRequest(
        entries: [
          BackfillRequestEntry(hostId: 'host-1', counter: 5),
        ],
        requesterId: 'requester-1',
      );

      final mockHandler = MockBackfillResponseHandler();
      when(() => mockHandler.handleBackfillRequest(any()))
          .thenAnswer((_) async {});

      processor.backfillResponseHandler = mockHandler;

      when(() => event.text).thenReturn(encodeMessage(message));

      await processor.process(event: event, journalDb: journalDb);

      verify(() => mockHandler.handleBackfillRequest(message)).called(1);
    });

    test('SyncBackfillResponse is delegated to handler when configured',
        () async {
      const message = SyncBackfillResponse(
        hostId: 'host-1',
        counter: 5,
        deleted: true,
      );

      final mockHandler = MockBackfillResponseHandler();
      when(() => mockHandler.handleBackfillResponse(any()))
          .thenAnswer((_) async {});

      processor.backfillResponseHandler = mockHandler;

      when(() => event.text).thenReturn(encodeMessage(message));

      await processor.process(event: event, journalDb: journalDb);

      verify(() => mockHandler.handleBackfillResponse(message)).called(1);
    });

    test('skips old SyncBackfillRequest when startupTimestamp is set',
        () async {
      const message = SyncBackfillRequest(
        entries: [BackfillRequestEntry(hostId: 'host-1', counter: 5)],
        requesterId: 'requester-1',
      );

      final mockHandler = MockBackfillResponseHandler();
      when(() => mockHandler.handleBackfillRequest(any()))
          .thenAnswer((_) async {});

      // Create processor with startupTimestamp set
      final processorWithStartup = SyncEventProcessor(
        loggingService: loggingService,
        updateNotifications: updateNotifications,
        aiConfigRepository: aiConfigRepository,
        settingsDb: settingsDb,
        journalEntityLoader: journalEntityLoader,
      );
      processorWithStartup.backfillResponseHandler = mockHandler;
      // Set startup timestamp to a point in the future relative to the event
      processorWithStartup.startupTimestamp = 2000000000000; // Far future

      // Event timestamp is in the past (before startup)
      when(() => event.originServerTs).thenReturn(DateTime(2024));
      when(() => event.text).thenReturn(encodeMessage(message));
      when(() => event.eventId).thenReturn('old-backfill-event');

      await processorWithStartup.process(event: event, journalDb: journalDb);

      // Handler should NOT be called - event is older than startup
      verifyNever(() => mockHandler.handleBackfillRequest(any()));

      // Should log the skip
      verify(
        () => loggingService.captureEvent(
          any<String>(that: contains('skipping old backfill')),
          domain: 'SYNC_BACKFILL',
          subDomain: 'skipOld',
        ),
      ).called(1);
    });

    test('skips old SyncBackfillResponse when startupTimestamp is set',
        () async {
      const message = SyncBackfillResponse(
        hostId: 'host-1',
        counter: 5,
        deleted: false,
      );

      final mockHandler = MockBackfillResponseHandler();
      when(() => mockHandler.handleBackfillResponse(any()))
          .thenAnswer((_) async {});

      final processorWithStartup = SyncEventProcessor(
        loggingService: loggingService,
        updateNotifications: updateNotifications,
        aiConfigRepository: aiConfigRepository,
        settingsDb: settingsDb,
        journalEntityLoader: journalEntityLoader,
      );
      processorWithStartup.backfillResponseHandler = mockHandler;
      processorWithStartup.startupTimestamp = 2000000000000;

      when(() => event.originServerTs).thenReturn(DateTime(2024));
      when(() => event.text).thenReturn(encodeMessage(message));
      when(() => event.eventId).thenReturn('old-response-event');

      await processorWithStartup.process(event: event, journalDb: journalDb);

      verifyNever(() => mockHandler.handleBackfillResponse(any()));
    });

    test('processes SyncBackfillRequest when newer than startupTimestamp',
        () async {
      const message = SyncBackfillRequest(
        entries: [BackfillRequestEntry(hostId: 'host-1', counter: 5)],
        requesterId: 'requester-1',
      );

      final mockHandler = MockBackfillResponseHandler();
      when(() => mockHandler.handleBackfillRequest(any()))
          .thenAnswer((_) async {});

      final processorWithStartup = SyncEventProcessor(
        loggingService: loggingService,
        updateNotifications: updateNotifications,
        aiConfigRepository: aiConfigRepository,
        settingsDb: settingsDb,
        journalEntityLoader: journalEntityLoader,
      );
      processorWithStartup.backfillResponseHandler = mockHandler;
      // Startup was in the past
      processorWithStartup.startupTimestamp = 1000000000000;

      // Event is newer than startup
      when(() => event.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(1500000000000));
      when(() => event.text).thenReturn(encodeMessage(message));
      when(() => event.eventId).thenReturn('new-backfill-event');

      await processorWithStartup.process(event: event, journalDb: journalDb);

      // Handler SHOULD be called - event is newer than startup
      verify(() => mockHandler.handleBackfillRequest(message)).called(1);
    });
  });

  group('EntryLink sequence log recording -', () {
    late MockSyncSequenceLogService mockSequenceService;

    setUp(() {
      mockSequenceService = MockSyncSequenceLogService();
    });

    test(
        'records entry link in sequence log when vectorClock and originatingHostId present',
        () async {
      const vc = VectorClock({'host-A': 5});
      final link = EntryLink.basic(
        id: 'seq-link-1',
        fromId: 'from-1',
        toId: 'to-1',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        vectorClock: vc,
      );
      final message = SyncMessage.entryLink(
        entryLink: link,
        status: SyncEntryStatus.update,
        originatingHostId: 'host-A',
      );

      when(() => mockSequenceService.recordReceivedEntryLink(
            linkId: any(named: 'linkId'),
            vectorClock: any(named: 'vectorClock'),
            originatingHostId: any(named: 'originatingHostId'),
          )).thenAnswer((_) async => []);

      final processorWithSeq = SyncEventProcessor(
        loggingService: loggingService,
        updateNotifications: updateNotifications,
        aiConfigRepository: aiConfigRepository,
        settingsDb: settingsDb,
        journalEntityLoader: journalEntityLoader,
        sequenceLogService: mockSequenceService,
      );

      when(() => event.text).thenReturn(encodeMessage(message));
      when(() => journalDb.upsertEntryLink(any())).thenAnswer((_) async => 1);

      await processorWithSeq.process(event: event, journalDb: journalDb);

      verify(() => mockSequenceService.recordReceivedEntryLink(
            linkId: 'seq-link-1',
            vectorClock: vc,
            originatingHostId: 'host-A',
          )).called(1);
    });

    test('logs gap detection when recordReceivedEntryLink returns gaps',
        () async {
      const vc = VectorClock({'host-B': 10});
      final link = EntryLink.basic(
        id: 'seq-link-gaps',
        fromId: 'from-gap',
        toId: 'to-gap',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        vectorClock: vc,
      );
      final message = SyncMessage.entryLink(
        entryLink: link,
        status: SyncEntryStatus.update,
        originatingHostId: 'host-B',
      );

      when(() => mockSequenceService.recordReceivedEntryLink(
            linkId: any(named: 'linkId'),
            vectorClock: any(named: 'vectorClock'),
            originatingHostId: any(named: 'originatingHostId'),
          )).thenAnswer((_) async => [
            (hostId: 'host-B', counter: 8),
            (hostId: 'host-B', counter: 9),
          ]);

      final processorWithSeq = SyncEventProcessor(
        loggingService: loggingService,
        updateNotifications: updateNotifications,
        aiConfigRepository: aiConfigRepository,
        settingsDb: settingsDb,
        journalEntityLoader: journalEntityLoader,
        sequenceLogService: mockSequenceService,
      );

      when(() => event.text).thenReturn(encodeMessage(message));
      when(() => journalDb.upsertEntryLink(any())).thenAnswer((_) async => 1);

      await processorWithSeq.process(event: event, journalDb: journalDb);

      verify(() => loggingService.captureEvent(
            contains('apply.entryLink.gapsDetected count=2'),
            domain: 'SYNC_SEQUENCE',
            subDomain: 'gapDetection',
          )).called(1);
    });

    test('handles recordReceivedEntryLink exceptions gracefully', () async {
      const vc = VectorClock({'host-C': 3});
      final link = EntryLink.basic(
        id: 'seq-link-error',
        fromId: 'from-err',
        toId: 'to-err',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        vectorClock: vc,
      );
      final message = SyncMessage.entryLink(
        entryLink: link,
        status: SyncEntryStatus.update,
        originatingHostId: 'host-C',
      );

      when(() => mockSequenceService.recordReceivedEntryLink(
            linkId: any(named: 'linkId'),
            vectorClock: any(named: 'vectorClock'),
            originatingHostId: any(named: 'originatingHostId'),
          )).thenThrow(Exception('sequence log error'));

      final processorWithSeq = SyncEventProcessor(
        loggingService: loggingService,
        updateNotifications: updateNotifications,
        aiConfigRepository: aiConfigRepository,
        settingsDb: settingsDb,
        journalEntityLoader: journalEntityLoader,
        sequenceLogService: mockSequenceService,
      );

      when(() => event.text).thenReturn(encodeMessage(message));
      when(() => journalDb.upsertEntryLink(any())).thenAnswer((_) async => 1);

      // Should not throw - errors are caught and logged
      await processorWithSeq.process(event: event, journalDb: journalDb);

      // Verify exception was logged
      verify(() => loggingService.captureException(
            any<Object>(),
            domain: 'SYNC_SEQUENCE',
            subDomain: 'recordReceived',
            stackTrace: any<StackTrace>(named: 'stackTrace'),
          )).called(1);
    });

    test('skips sequence log when vectorClock is null', () async {
      final link = EntryLink.basic(
        id: 'seq-link-no-vc',
        fromId: 'from-novc',
        toId: 'to-novc',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        vectorClock: null,
      );
      final message = SyncMessage.entryLink(
        entryLink: link,
        status: SyncEntryStatus.update,
        originatingHostId: 'host-D',
      );

      final processorWithSeq = SyncEventProcessor(
        loggingService: loggingService,
        updateNotifications: updateNotifications,
        aiConfigRepository: aiConfigRepository,
        settingsDb: settingsDb,
        journalEntityLoader: journalEntityLoader,
        sequenceLogService: mockSequenceService,
      );

      when(() => event.text).thenReturn(encodeMessage(message));
      when(() => journalDb.upsertEntryLink(any())).thenAnswer((_) async => 1);

      await processorWithSeq.process(event: event, journalDb: journalDb);

      // Sequence log should NOT be called
      verifyNever(() => mockSequenceService.recordReceivedEntryLink(
            linkId: any(named: 'linkId'),
            vectorClock: any(named: 'vectorClock'),
            originatingHostId: any(named: 'originatingHostId'),
          ));
    });

    test('skips sequence log when originatingHostId is null', () async {
      const vc = VectorClock({'host-E': 1});
      final link = EntryLink.basic(
        id: 'seq-link-no-origin',
        fromId: 'from-noorig',
        toId: 'to-noorig',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        vectorClock: vc,
      );
      final message = SyncMessage.entryLink(
        entryLink: link,
        status: SyncEntryStatus.update,
        // No originatingHostId
      );

      final processorWithSeq = SyncEventProcessor(
        loggingService: loggingService,
        updateNotifications: updateNotifications,
        aiConfigRepository: aiConfigRepository,
        settingsDb: settingsDb,
        journalEntityLoader: journalEntityLoader,
        sequenceLogService: mockSequenceService,
      );

      when(() => event.text).thenReturn(encodeMessage(message));
      when(() => journalDb.upsertEntryLink(any())).thenAnswer((_) async => 1);

      await processorWithSeq.process(event: event, journalDb: journalDb);

      // Sequence log should NOT be called
      verifyNever(() => mockSequenceService.recordReceivedEntryLink(
            linkId: any(named: 'linkId'),
            vectorClock: any(named: 'vectorClock'),
            originatingHostId: any(named: 'originatingHostId'),
          ));
    });

    test('records when rows=0 but link exists locally', () async {
      const vc = VectorClock({'host-F': 7});
      final link = EntryLink.basic(
        id: 'seq-link-exists',
        fromId: 'from-exists',
        toId: 'to-exists',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        vectorClock: vc,
      );
      final message = SyncMessage.entryLink(
        entryLink: link,
        status: SyncEntryStatus.update,
        originatingHostId: 'host-F',
      );

      when(() => mockSequenceService.recordReceivedEntryLink(
            linkId: any(named: 'linkId'),
            vectorClock: any(named: 'vectorClock'),
            originatingHostId: any(named: 'originatingHostId'),
          )).thenAnswer((_) async => []);

      final processorWithSeq = SyncEventProcessor(
        loggingService: loggingService,
        updateNotifications: updateNotifications,
        aiConfigRepository: aiConfigRepository,
        settingsDb: settingsDb,
        journalEntityLoader: journalEntityLoader,
        sequenceLogService: mockSequenceService,
      );

      when(() => event.text).thenReturn(encodeMessage(message));
      // rows=0 (no-op upsert)
      when(() => journalDb.upsertEntryLink(any())).thenAnswer((_) async => 0);
      // But link exists locally
      when(() => journalDb.entryLinkById('seq-link-exists'))
          .thenAnswer((_) async => link);

      await processorWithSeq.process(event: event, journalDb: journalDb);

      // Sequence log SHOULD be called because link exists
      verify(() => mockSequenceService.recordReceivedEntryLink(
            linkId: 'seq-link-exists',
            vectorClock: vc,
            originatingHostId: 'host-F',
          )).called(1);
    });

    test('skips recording when rows=0 and link does not exist locally',
        () async {
      const vc = VectorClock({'host-G': 2});
      final link = EntryLink.basic(
        id: 'seq-link-missing',
        fromId: 'from-missing',
        toId: 'to-missing',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        vectorClock: vc,
      );
      final message = SyncMessage.entryLink(
        entryLink: link,
        status: SyncEntryStatus.update,
        originatingHostId: 'host-G',
      );

      final processorWithSeq = SyncEventProcessor(
        loggingService: loggingService,
        updateNotifications: updateNotifications,
        aiConfigRepository: aiConfigRepository,
        settingsDb: settingsDb,
        journalEntityLoader: journalEntityLoader,
        sequenceLogService: mockSequenceService,
      );

      when(() => event.text).thenReturn(encodeMessage(message));
      // rows=0 (no-op upsert)
      when(() => journalDb.upsertEntryLink(any())).thenAnswer((_) async => 0);
      // Link does NOT exist locally
      when(() => journalDb.entryLinkById('seq-link-missing'))
          .thenAnswer((_) async => null);

      await processorWithSeq.process(event: event, journalDb: journalDb);

      // Sequence log should NOT be called
      verifyNever(() => mockSequenceService.recordReceivedEntryLink(
            linkId: any(named: 'linkId'),
            vectorClock: any(named: 'vectorClock'),
            originatingHostId: any(named: 'originatingHostId'),
          ));
    });

    test('passes coveredVectorClocks to recordReceivedEntryLink', () async {
      const vc = VectorClock({'host-A': 5});
      const coveredClock1 = VectorClock({'host-A': 3});
      const coveredClock2 = VectorClock({'host-A': 4});
      final link = EntryLink.basic(
        id: 'seq-link-covered',
        fromId: 'from-covered',
        toId: 'to-covered',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        vectorClock: vc,
      );
      final message = SyncMessage.entryLink(
        entryLink: link,
        status: SyncEntryStatus.update,
        originatingHostId: 'host-A',
        coveredVectorClocks: [coveredClock1, coveredClock2],
      );

      when(() => mockSequenceService.recordReceivedEntryLink(
            linkId: any(named: 'linkId'),
            vectorClock: any(named: 'vectorClock'),
            originatingHostId: any(named: 'originatingHostId'),
            coveredVectorClocks: any(named: 'coveredVectorClocks'),
          )).thenAnswer((_) async => []);

      final processorWithSeq = SyncEventProcessor(
        loggingService: loggingService,
        updateNotifications: updateNotifications,
        aiConfigRepository: aiConfigRepository,
        settingsDb: settingsDb,
        journalEntityLoader: journalEntityLoader,
        sequenceLogService: mockSequenceService,
      );

      when(() => event.text).thenReturn(encodeMessage(message));
      when(() => journalDb.upsertEntryLink(any())).thenAnswer((_) async => 1);

      await processorWithSeq.process(event: event, journalDb: journalDb);

      verify(() => mockSequenceService.recordReceivedEntryLink(
            linkId: 'seq-link-covered',
            vectorClock: vc,
            originatingHostId: 'host-A',
            coveredVectorClocks: [coveredClock1, coveredClock2],
          )).called(1);
    });
  });

  // Note: Sequence log integration tests for the sync processor are covered
  // by sync_sequence_log_service_test.dart which tests recordReceivedEntry
  // behavior including gap detection and status transitions.
}
