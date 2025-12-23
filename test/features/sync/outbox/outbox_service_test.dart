// ignore_for_file: avoid_redundant_argument_values, unnecessary_lambdas, cascade_invocations

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/sync/outbox_state.dart';
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_processor.dart';
import 'package:lotti/features/sync/outbox/outbox_repository.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/features/user_activity/state/user_activity_gate.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/cached_stream_controller.dart' as matrix_utils;
import 'package:mocktail/mocktail.dart';

class MockSyncDatabase extends Mock implements SyncDatabase {}

class MockLoggingService extends Mock implements LoggingService {}

class MockUserActivityGate extends Mock implements UserActivityGate {}

class MockJournalDb extends Mock implements JournalDb {}

class MockUserActivityService extends Mock implements UserActivityService {}

class MockOutboxRepository extends Mock implements OutboxRepository {}

class MockOutboxMessageSender extends Mock implements OutboxMessageSender {}

class MockOutboxProcessor extends Mock implements OutboxProcessor {}

class MockVectorClockService extends Mock implements VectorClockService {}

class MockMatrixService extends Mock implements MatrixService {}

class MockMatrixClient extends Mock implements Client {}

class MockCachedLoginController extends Mock
    implements matrix_utils.CachedStreamController<LoginState> {}

class MockSyncSequenceLogService extends Mock
    implements SyncSequenceLogService {}

class TestableOutboxService extends OutboxService {
  TestableOutboxService({
    required super.syncDatabase,
    required super.loggingService,
    required super.vectorClockService,
    required super.journalDb,
    required super.documentsDirectory,
    required super.userActivityService,
    super.repository,
    super.messageSender,
    super.processor,
    super.activityGate,
    super.ownsActivityGate,
    super.saveJsonHandler,
    super.sequenceLogService,
  });

  int enqueueCalls = 0;
  Duration? lastDelay;

  @override
  Future<void> enqueueNextSendRequest({
    Duration delay = const Duration(milliseconds: 1),
  }) async {
    final adjustedDelay = computeEnqueueDelay(delay);
    enqueueCalls++;
    lastDelay = adjustedDelay;
  }
}

MockUserActivityGate createGate({
  bool canProcess = true,
  Stream<bool>? canProcessStream,
}) {
  final gate = MockUserActivityGate();
  when(gate.waitUntilIdle).thenAnswer((_) async {});
  when(gate.dispose).thenAnswer((_) async {});
  when(() => gate.canProcess).thenReturn(canProcess);
  when(() => gate.canProcessStream)
      .thenAnswer((_) => canProcessStream ?? Stream<bool>.value(canProcess));
  return gate;
}

void expectDelayCloseTo(
  Duration? actual,
  Duration expected, {
  Duration tolerance = const Duration(milliseconds: 50),
}) {
  expect(actual, isNotNull);
  final deltaMs = (actual!.inMilliseconds - expected.inMilliseconds).abs();
  expect(deltaMs, lessThanOrEqualTo(tolerance.inMilliseconds));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const connectivityMethodChannel =
      MethodChannel('dev.fluttercommunity.plus/connectivity');

  setUpAll(() {
    registerFallbackValue(const SyncMessage.aiConfigDelete(id: 'fallback'));
    registerFallbackValue(Exception('fallback'));
    // Mocktail fallback for any<OutboxCompanion>() matchers
    registerFallbackValue(OutboxCompanion.insert(message: 'm', subject: 's'));
    registerFallbackValue(StackTrace.empty);
    registerFallbackValue(const VectorClock({'fallback': 1}));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(connectivityMethodChannel,
            (MethodCall call) async {
      if (call.method == 'check') {
        return 'wifi';
      }
      return 'wifi';
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
      'dev.fluttercommunity.plus/connectivity_status',
      (ByteData? message) async => null,
    );
  });

  late MockSyncDatabase syncDatabase;
  late MockLoggingService loggingService;
  late MockOutboxRepository repository;
  late MockOutboxMessageSender messageSender;
  late MockOutboxProcessor processor;
  late MockJournalDb journalDb;
  late MockVectorClockService vectorClockService;
  late MockUserActivityService userActivityService;
  late Directory documentsDirectory;
  late OutboxService service;
  late bool hadDirectoryRegistered;
  Directory? previousDirectory;

  setUp(() {
    syncDatabase = MockSyncDatabase();
    loggingService = MockLoggingService();
    repository = MockOutboxRepository();
    messageSender = MockOutboxMessageSender();
    processor = MockOutboxProcessor();
    journalDb = MockJournalDb();
    vectorClockService = MockVectorClockService();
    userActivityService = MockUserActivityService();
    documentsDirectory =
        Directory.systemTemp.createTempSync('outbox_service_test_');
    hadDirectoryRegistered = getIt.isRegistered<Directory>();
    if (hadDirectoryRegistered) {
      previousDirectory = getIt<Directory>();
      getIt.unregister<Directory>();
    } else {
      previousDirectory = null;
    }
    getIt.allowReassignment = true;
    getIt.registerSingleton<Directory>(documentsDirectory);

    when(() => processor.processQueue())
        .thenAnswer((_) async => OutboxProcessingResult.none);
    when(() => loggingService.captureEvent(
          any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
        )).thenAnswer((_) {});
    when(() => loggingService.captureException(
          any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        )).thenAnswer((_) async {});
    when(() => vectorClockService.getHostHash())
        .thenAnswer((_) async => 'hhash');
    when(() => vectorClockService.getHost()).thenAnswer((_) async => 'hostA');
    when(() => syncDatabase.addOutboxItem(any<OutboxCompanion>()))
        .thenAnswer((_) async => 1);
    // Avoid null stream issues from db-driven nudge subscription in service ctor
    when(() => syncDatabase.watchOutboxCount())
        .thenAnswer((_) => const Stream<int>.empty());
    // Default stub for findPendingByEntryId - no existing pending item
    when(() => syncDatabase.findPendingByEntryId(any()))
        .thenAnswer((_) async => null);
    when(() => journalDb.linksForEntryIdsBidirectional(any()))
        .thenAnswer((_) async => <EntryLink>[]);
    // Ensure activity gate can construct if needed
    when(() => userActivityService.lastActivity).thenReturn(DateTime.now());
    when(() => userActivityService.activityStream)
        .thenAnswer((_) => const Stream<DateTime>.empty());

    service = TestableOutboxService(
      syncDatabase: syncDatabase,
      loggingService: loggingService,
      vectorClockService: vectorClockService,
      journalDb: journalDb,
      documentsDirectory: documentsDirectory,
      userActivityService: userActivityService,
      repository: repository,
      messageSender: messageSender,
      processor: processor,
      activityGate: createGate(),
      ownsActivityGate: false,
    );
  });

  tearDown(() async {
    await service.dispose();
    if (documentsDirectory.existsSync()) {
      documentsDirectory.deleteSync(recursive: true);
    }
    if (getIt.isRegistered<Directory>()) {
      getIt.unregister<Directory>();
    }
    if (hadDirectoryRegistered && previousDirectory != null) {
      getIt.registerSingleton<Directory>(previousDirectory!);
    }
  });

  test('enqueueMessage logs SyncEntityDefinition', () async {
    final def = SyncMessage.entityDefinition(
      entityDefinition: EntityDefinition.measurableDataType(
        id: 'def-1',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        displayName: 'Water',
        description: 'H2O',
        unitName: 'ml',
        version: 1,
        vectorClock: null,
      ),
      status: SyncEntryStatus.initial,
    );

    await service.enqueueMessage(def);

    verify(() => loggingService.captureEvent(
          contains('type=SyncEntityDefinition'),
          domain: 'OUTBOX',
          subDomain: 'enqueueMessage',
        )).called(1);
  });

  test('enqueueMessage logs SyncEntryLink with from/to', () async {
    final link = SyncMessage.entryLink(
      entryLink: EntryLink.basic(
        id: 'l1',
        fromId: 'A',
        toId: 'B',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vectorClock: null,
      ),
      status: SyncEntryStatus.initial,
    );

    await service.enqueueMessage(link);

    verify(() => loggingService.captureEvent(
          allOf([
            contains('type=SyncEntryLink'),
            contains('from=A'),
            contains('to=B'),
          ]),
          domain: 'OUTBOX',
          subDomain: 'enqueueMessage',
        )).called(1);
  });

  test('enqueueMessage refreshes JSON before reading descriptor', () async {
    const id = 'checklist-refresh';
    final staleMeta = Metadata(
      id: id,
      createdAt: DateTime(2025, 10, 22, 23, 18, 48, 935417),
      updatedAt: DateTime(2025, 10, 22, 23, 18, 49, 201352),
      dateFrom: DateTime(2025, 10, 22, 23, 18, 48, 935417),
      dateTo: DateTime(2025, 10, 22, 23, 18, 48, 935417),
      categoryId: 'category-1',
      utcOffset: 60,
      timezone: 'WEST',
      vectorClock: const VectorClock({'hostA': 402}),
    );
    final staleChecklist = JournalEntity.checklist(
      meta: staleMeta,
      data: const ChecklistData(
        title: 'TODOs',
        linkedChecklistItems: <String>[],
        linkedTasks: <String>['task-1'],
      ),
    );
    final freshChecklist = staleChecklist.copyWith(
      meta: staleChecklist.meta.copyWith(
        vectorClock: const VectorClock({'hostA': 425}),
      ),
    );
    final jsonPath = relativeEntityPath(staleChecklist);
    final file = File('${documentsDirectory.path}$jsonPath')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(jsonEncode(staleChecklist));

    when(() => journalDb.journalEntityById(id))
        .thenAnswer((_) async => freshChecklist);

    final message = SyncMessage.journalEntity(
      id: id,
      vectorClock: freshChecklist.meta.vectorClock,
      jsonPath: jsonPath,
      status: SyncEntryStatus.update,
    );

    await service.enqueueMessage(message);

    final stored =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    expect(
      // ignore: avoid_dynamic_calls
      stored['meta']['vectorClock'],
      equals({'hostA': 425}),
    );
  });

  test('enqueueMessage logs missing entity when DB lookup returns null',
      () async {
    const id = 'missing-entity';
    final entity = JournalEntity.journalEntry(
      meta: Metadata(
        id: id,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        dateFrom: DateTime.now(),
        dateTo: DateTime.now(),
        vectorClock: const VectorClock({'host': 1}),
      ),
      entryText: const EntryText(plainText: 'draft'),
    );
    final jsonPath = relativeEntityPath(entity);
    File('${documentsDirectory.path}$jsonPath')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(jsonEncode(entity.toJson()));

    when(() => journalDb.journalEntityById(id)).thenAnswer((_) async => null);

    final message = SyncMessage.journalEntity(
      id: id,
      jsonPath: jsonPath,
      vectorClock: entity.meta.vectorClock,
      status: SyncEntryStatus.initial,
    );

    await service.enqueueMessage(message);

    verify(
      () => loggingService.captureEvent(
        contains('enqueueMessage.missingEntity id=$id'),
        domain: 'MATRIX_SERVICE',
        subDomain: 'enqueueMessage',
      ),
    ).called(1);
    verify(() => syncDatabase.addOutboxItem(any())).called(1);
  });

  test('continues when saveJson throws during refresh', () async {
    const id = 'save-fails';
    final entity = JournalEntity.journalEntry(
      meta: Metadata(
        id: id,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        dateFrom: DateTime.now(),
        dateTo: DateTime.now(),
        vectorClock: const VectorClock({'host': 1}),
      ),
      entryText: const EntryText(plainText: 'draft'),
    );
    final jsonPath = relativeEntityPath(entity);
    File('${documentsDirectory.path}$jsonPath')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(jsonEncode(entity.toJson()));

    when(() => journalDb.journalEntityById(id)).thenAnswer((_) async => entity);

    final failingGate = MockUserActivityGate();
    when(failingGate.waitUntilIdle).thenAnswer((_) async {});
    when(failingGate.dispose).thenAnswer((_) async {});

    final failingService = TestableOutboxService(
      syncDatabase: syncDatabase,
      loggingService: loggingService,
      vectorClockService: vectorClockService,
      journalDb: journalDb,
      documentsDirectory: documentsDirectory,
      userActivityService: userActivityService,
      repository: repository,
      messageSender: messageSender,
      processor: processor,
      activityGate: failingGate,
      ownsActivityGate: false,
      saveJsonHandler: (_, __) => Future.error(Exception('disk full')),
    );

    final message = SyncMessage.journalEntity(
      id: id,
      jsonPath: jsonPath,
      vectorClock: entity.meta.vectorClock,
      status: SyncEntryStatus.initial,
    );

    await failingService.enqueueMessage(message);

    verify(
      () => loggingService.captureException(
        any<Object>(),
        domain: 'MATRIX_SERVICE',
        subDomain: 'enqueueMessage.refreshJson',
        stackTrace: any<StackTrace?>(
          named: 'stackTrace',
        ),
      ),
    ).called(1);
    verify(() => syncDatabase.addOutboxItem(any())).called(1);
    await failingService.dispose();
  });

  test('non-journal messages skip JSON refresh lookup', () async {
    clearInteractions(journalDb);

    await service.enqueueMessage(
      const SyncMessage.aiConfigDelete(id: 'cfg'),
    );

    verifyNever(() => journalDb.journalEntityById(any()));
  });

  test('enqueueMessage logs SyncAiConfig', () async {
    final cfg = SyncMessage.aiConfig(
      aiConfig: AiConfig.inferenceProvider(
        id: 'cfg1',
        baseUrl: 'https://example.org',
        apiKey: 'k',
        name: 'p',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.openAi,
      ),
      status: SyncEntryStatus.initial,
    );

    await service.enqueueMessage(cfg);

    verify(() => loggingService.captureEvent(
          contains('type=SyncAiConfig'),
          domain: 'OUTBOX',
          subDomain: 'enqueueMessage',
        )).called(1);
  });

  test('enqueueMessage logs SyncAiConfigDelete', () async {
    const del = SyncMessage.aiConfigDelete(id: 'cfg1');

    await service.enqueueMessage(del);

    verify(() => loggingService.captureEvent(
          contains('type=SyncAiConfigDelete'),
          domain: 'OUTBOX',
          subDomain: 'enqueueMessage',
        )).called(1);
  });

  test('enqueueMessage logs SyncTagEntity', () async {
    final tag = SyncMessage.tagEntity(
      tagEntity: TagEntity.genericTag(
        id: 't1',
        tag: 'alpha',
        private: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vectorClock: null,
      ),
      status: SyncEntryStatus.initial,
    );

    await service.enqueueMessage(tag);

    verify(() => loggingService.captureEvent(
          contains('type=SyncTagEntity'),
          domain: 'OUTBOX',
          subDomain: 'enqueueMessage',
        )).called(1);
  });

  test('dispose closes owned activity gate', () async {
    final ownedGate = MockUserActivityGate();
    when(ownedGate.waitUntilIdle).thenAnswer((_) async {});
    when(ownedGate.dispose).thenAnswer((_) async {});

    final serviceOwned = OutboxService(
      syncDatabase: syncDatabase,
      loggingService: loggingService,
      vectorClockService: vectorClockService,
      journalDb: journalDb,
      documentsDirectory: documentsDirectory,
      userActivityService: userActivityService,
      repository: repository,
      messageSender: messageSender,
      processor: processor,
      activityGate: ownedGate,
      ownsActivityGate: true,
    );

    await serviceOwned.dispose();

    verify(ownedGate.dispose).called(1);
  });

  test('dispose does not close externally provided activity gate', () async {
    final externalGate = MockUserActivityGate();
    when(externalGate.waitUntilIdle).thenAnswer((_) async {});
    when(externalGate.dispose).thenAnswer((_) async {});

    final serviceExternal = OutboxService(
      syncDatabase: syncDatabase,
      loggingService: loggingService,
      vectorClockService: vectorClockService,
      journalDb: journalDb,
      documentsDirectory: documentsDirectory,
      userActivityService: userActivityService,
      repository: repository,
      messageSender: messageSender,
      processor: processor,
      activityGate: externalGate,
    );

    await serviceExternal.dispose();

    verifyNever(externalGate.dispose);
  });

  group('enqueueMessage', () {
    test(
        'stores relative attachment path for initial journal entry and schedules',
        () async {
      final capturedCompanions = <OutboxCompanion>[];
      when(() => syncDatabase.addOutboxItem(any<OutboxCompanion>()))
          .thenAnswer((invocation) async {
        capturedCompanions
            .add(invocation.positionalArguments.first as OutboxCompanion);
        return 1;
      });

      final testService = TestableOutboxService(
        syncDatabase: syncDatabase,
        loggingService: loggingService,
        vectorClockService: vectorClockService,
        journalDb: journalDb,
        documentsDirectory: documentsDirectory,
        userActivityService: userActivityService,
        repository: repository,
        messageSender: messageSender,
        processor: processor,
      );

      final sampleDate = DateTime.utc(2024);
      final metadata = Metadata(
        id: 'entry',
        createdAt: sampleDate,
        updatedAt: sampleDate,
        dateFrom: sampleDate,
        dateTo: sampleDate,
        vectorClock: const VectorClock({'hostA': 1}),
      );
      final imageData = ImageData(
        capturedAt: sampleDate,
        imageId: 'image-id',
        imageFile: 'image.jpg',
        imageDirectory: '/images/',
      );
      final journalEntity = JournalEntity.journalImage(
        meta: metadata,
        data: imageData,
        entryText: const EntryText(plainText: 'Test'),
      );

      const jsonPath = '/entries/test.json';
      File('${documentsDirectory.path}$jsonPath')
        ..createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(journalEntity.toJson()));

      final imagePath =
          '${documentsDirectory.path}${imageData.imageDirectory}${imageData.imageFile}';
      File(imagePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(List<int>.filled(10, 42));

      await testService.enqueueMessage(
        const SyncMessage.journalEntity(
          id: 'entry',
          jsonPath: jsonPath,
          vectorClock: VectorClock({'device': 1}),
          status: SyncEntryStatus.initial,
        ),
      );

      expect(capturedCompanions, hasLength(1));
      final companion = capturedCompanions.single;
      expect(companion.filePath.value, getRelativeAssetPath(imagePath));
      expect(companion.subject.value, 'hhash:1');
      expect(companion.status.value, OutboxStatus.pending.index);
      final decodedMessage = SyncMessage.fromJson(
        jsonDecode(companion.message.value) as Map<String, dynamic>,
      );
      final journalMsg = decodedMessage as SyncJournalEntity;
      expect(journalMsg.coveredVectorClocks, isNotNull);
      final coveredCounters = journalMsg.coveredVectorClocks!
          .map((vc) => vc.vclock['device'])
          .whereType<int>()
          .toSet();
      expect(coveredCounters, contains(1));

      // Ensure scheduling happens after enqueue
      expect(testService.enqueueCalls, 1);
      expect(testService.lastDelay, const Duration(seconds: 1));
    });

    test('enqueues entry link with coveredVectorClocks populated', () async {
      final capturedCompanions = <OutboxCompanion>[];
      when(() => syncDatabase.addOutboxItem(any<OutboxCompanion>()))
          .thenAnswer((invocation) async {
        capturedCompanions
            .add(invocation.positionalArguments.first as OutboxCompanion);
        return 1;
      });

      final testService = TestableOutboxService(
        syncDatabase: syncDatabase,
        loggingService: loggingService,
        vectorClockService: vectorClockService,
        journalDb: journalDb,
        documentsDirectory: documentsDirectory,
        userActivityService: userActivityService,
        repository: repository,
        messageSender: messageSender,
        processor: processor,
      );

      final now = DateTime.utc(2024);
      const linkVc = VectorClock({'hostA': 3});
      final link = EntryLink.basic(
        id: 'link-id',
        fromId: 'from-entry',
        toId: 'to-entry',
        createdAt: now,
        updatedAt: now,
        vectorClock: linkVc,
      );

      await testService.enqueueMessage(
        SyncMessage.entryLink(
          entryLink: link,
          status: SyncEntryStatus.initial,
        ),
      );

      expect(capturedCompanions, hasLength(1));
      final companion = capturedCompanions.single;
      final decodedMessage = SyncMessage.fromJson(
        jsonDecode(companion.message.value) as Map<String, dynamic>,
      );
      final linkMsg = decodedMessage as SyncEntryLink;
      expect(linkMsg.coveredVectorClocks, isNotNull);
      final coveredCounters = linkMsg.coveredVectorClocks!
          .map((vc) => vc.vclock['hostA'])
          .whereType<int>()
          .toSet();
      expect(coveredCounters, contains(3));
    });

    test(
        'merges consecutive updates to same journal entry with coveredVectorClocks',
        () async {
      final sampleDate = DateTime.utc(2024);
      const oldVc = VectorClock({'hostA': 5});
      const newVc = VectorClock({'hostA': 7});

      // Create the "old" message that's already in the outbox
      const oldMessage = SyncMessage.journalEntity(
        id: 'entry-id',
        jsonPath: '/entries/test.json',
        vectorClock: oldVc,
        status: SyncEntryStatus.update,
      );

      // Existing pending outbox item
      final existingItem = OutboxItem(
        id: 1,
        createdAt: sampleDate,
        updatedAt: sampleDate,
        status: OutboxStatus.pending.index,
        retries: 0,
        message: jsonEncode(oldMessage.toJson()),
        subject: 'hhash:5',
        filePath: null,
        outboxEntryId: 'entry-id',
      );

      // Return existing item for this entry
      when(() => syncDatabase.findPendingByEntryId('entry-id'))
          .thenAnswer((_) async => existingItem);

      // Capture the update call
      String? capturedMessage;
      String? capturedSubject;
      when(
        () => syncDatabase.updateOutboxMessage(
          itemId: any(named: 'itemId'),
          newMessage: any(named: 'newMessage'),
          newSubject: any(named: 'newSubject'),
        ),
      ).thenAnswer((invocation) async {
        capturedMessage = invocation.namedArguments[#newMessage] as String?;
        capturedSubject = invocation.namedArguments[#newSubject] as String?;
        return 1;
      });

      final testService = TestableOutboxService(
        syncDatabase: syncDatabase,
        loggingService: loggingService,
        vectorClockService: vectorClockService,
        journalDb: journalDb,
        documentsDirectory: documentsDirectory,
        userActivityService: userActivityService,
        repository: repository,
        messageSender: messageSender,
        processor: processor,
      );

      final metadata = Metadata(
        id: 'entry-id',
        createdAt: sampleDate,
        updatedAt: sampleDate,
        dateFrom: sampleDate,
        dateTo: sampleDate,
        vectorClock: newVc,
      );
      final journalEntity = JournalEntity.journalEntry(
        meta: metadata,
        entryText: const EntryText(plainText: 'Updated text'),
      );

      const jsonPath = '/entries/test.json';
      File('${documentsDirectory.path}$jsonPath')
        ..createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(journalEntity.toJson()));

      await testService.enqueueMessage(
        const SyncMessage.journalEntity(
          id: 'entry-id',
          jsonPath: jsonPath,
          vectorClock: newVc,
          status: SyncEntryStatus.update,
        ),
      );

      // Verify updateOutboxMessage was called instead of addOutboxItem
      verify(
        () => syncDatabase.updateOutboxMessage(
          itemId: 1,
          newMessage: any(named: 'newMessage'),
          newSubject: any(named: 'newSubject'),
        ),
      ).called(1);
      verifyNever(() => syncDatabase.addOutboxItem(any()));

      // Verify the merged message contains coveredVectorClocks
      expect(capturedMessage, isNotNull);
      final decodedMessage = SyncMessage.fromJson(
        jsonDecode(capturedMessage!) as Map<String, dynamic>,
      );
      expect(decodedMessage, isA<SyncJournalEntity>());
      final journalMsg = decodedMessage as SyncJournalEntity;
      expect(journalMsg.coveredVectorClocks, isNotNull);
      final coveredCounters = journalMsg.coveredVectorClocks!
          .map((vc) => vc.vclock['hostA'])
          .whereType<int>()
          .toSet();
      expect(coveredCounters, containsAll([5, 7]));
      expect(coveredCounters, hasLength(2));
      expect(capturedSubject, 'hhash:7');
    });

    test('accumulates multiple covered clocks across successive merges',
        () async {
      final sampleDate = DateTime.utc(2024);
      const vc5 = VectorClock({'hostA': 5});
      const vc6 = VectorClock({'hostA': 6});
      const vc7 = VectorClock({'hostA': 7});

      // Existing item already has one covered clock from previous merge
      const oldMessage = SyncMessage.journalEntity(
        id: 'entry-id',
        jsonPath: '/entries/test.json',
        vectorClock: vc6,
        status: SyncEntryStatus.update,
        coveredVectorClocks: [vc5], // Already covered VC5
      );

      final existingItem = OutboxItem(
        id: 1,
        createdAt: sampleDate,
        updatedAt: sampleDate,
        status: OutboxStatus.pending.index,
        retries: 0,
        message: jsonEncode(oldMessage.toJson()),
        subject: 'hhash:6',
        filePath: null,
        outboxEntryId: 'entry-id',
      );

      when(() => syncDatabase.findPendingByEntryId('entry-id'))
          .thenAnswer((_) async => existingItem);

      String? capturedMessage;
      when(
        () => syncDatabase.updateOutboxMessage(
          itemId: any(named: 'itemId'),
          newMessage: any(named: 'newMessage'),
          newSubject: any(named: 'newSubject'),
        ),
      ).thenAnswer((invocation) async {
        capturedMessage = invocation.namedArguments[#newMessage] as String?;
        return 1;
      });

      final testService = TestableOutboxService(
        syncDatabase: syncDatabase,
        loggingService: loggingService,
        vectorClockService: vectorClockService,
        journalDb: journalDb,
        documentsDirectory: documentsDirectory,
        userActivityService: userActivityService,
        repository: repository,
        messageSender: messageSender,
        processor: processor,
      );

      final metadata = Metadata(
        id: 'entry-id',
        createdAt: sampleDate,
        updatedAt: sampleDate,
        dateFrom: sampleDate,
        dateTo: sampleDate,
        vectorClock: vc7,
      );
      final journalEntity = JournalEntity.journalEntry(
        meta: metadata,
        entryText: const EntryText(plainText: 'Third update'),
      );

      const jsonPath = '/entries/test.json';
      File('${documentsDirectory.path}$jsonPath')
        ..createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(journalEntity.toJson()));

      await testService.enqueueMessage(
        const SyncMessage.journalEntity(
          id: 'entry-id',
          jsonPath: jsonPath,
          vectorClock: vc7,
          status: SyncEntryStatus.update,
        ),
      );

      // Verify coveredVectorClocks accumulated both VC5 and VC6
      expect(capturedMessage, isNotNull);
      final decodedMessage = SyncMessage.fromJson(
        jsonDecode(capturedMessage!) as Map<String, dynamic>,
      );
      final journalMsg = decodedMessage as SyncJournalEntity;
      final coveredCounters = journalMsg.coveredVectorClocks!
          .map((vc) => vc.vclock['hostA'])
          .whereType<int>()
          .toSet();
      expect(coveredCounters, containsAll([5, 6, 7]));
      expect(coveredCounters, hasLength(3));
    });

    test('captures intermediate VC when DB has newer version than enqueue call',
        () async {
      // This tests the race condition scenario:
      // 1. Entry created with VC {A:5}, enqueue#1 called
      // 2. Entry updated to VC {A:6}, enqueue#2 called
      // 3. Entry updated to VC {A:7} (before enqueue#2 runs)
      // 4. enqueue#1 runs: creates outbox item with VC {A:5}
      // 5. enqueue#2 runs: journalEntityMsg.VC={A:6}, DB has VC={A:7}
      //    -> coveredClocks should be [{A:5}, {A:6}, {A:7}],
      //       final VC is {A:7}
      final sampleDate = DateTime.utc(2024);
      const oldVc = VectorClock({'hostA': 5}); // VC in existing outbox item
      const intermediateVc = VectorClock({'hostA': 6}); // VC from enqueue call
      const latestVc = VectorClock({'hostA': 7}); // VC now in DB

      // Existing item has VC 5 (from enqueue#1)
      const oldMessage = SyncMessage.journalEntity(
        id: 'entry-id',
        jsonPath: '/entries/test.json',
        vectorClock: oldVc,
        status: SyncEntryStatus.update,
      );

      final existingItem = OutboxItem(
        id: 1,
        createdAt: sampleDate,
        updatedAt: sampleDate,
        status: OutboxStatus.pending.index,
        retries: 0,
        message: jsonEncode(oldMessage.toJson()),
        subject: 'hhash:5',
        filePath: null,
        outboxEntryId: 'entry-id',
      );

      when(() => syncDatabase.findPendingByEntryId('entry-id'))
          .thenAnswer((_) async => existingItem);

      String? capturedMessage;
      when(
        () => syncDatabase.updateOutboxMessage(
          itemId: any(named: 'itemId'),
          newMessage: any(named: 'newMessage'),
          newSubject: any(named: 'newSubject'),
        ),
      ).thenAnswer((invocation) async {
        capturedMessage = invocation.namedArguments[#newMessage] as String?;
        return 1;
      });

      final testService = TestableOutboxService(
        syncDatabase: syncDatabase,
        loggingService: loggingService,
        vectorClockService: vectorClockService,
        journalDb: journalDb,
        documentsDirectory: documentsDirectory,
        userActivityService: userActivityService,
        repository: repository,
        messageSender: messageSender,
        processor: processor,
      );

      // Setup: DB returns entry with latest VC (7)
      final metadata = Metadata(
        id: 'entry-id',
        createdAt: sampleDate,
        updatedAt: sampleDate,
        dateFrom: sampleDate,
        dateTo: sampleDate,
        vectorClock: latestVc,
      );
      final journalEntity = JournalEntity.journalEntry(
        meta: metadata,
        entryText: const EntryText(plainText: 'Updated'),
      );

      when(() => journalDb.journalEntityById('entry-id'))
          .thenAnswer((_) async => journalEntity);

      final jsonPath = '${documentsDirectory.path}/entries/test.json';
      File(jsonPath)
        ..createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(journalEntity.toJson()));

      // Call enqueue with INTERMEDIATE VC (6) - simulating a call that was
      // delayed and the DB was updated in the meantime
      await testService.enqueueMessage(
        const SyncMessage.journalEntity(
          id: 'entry-id',
          jsonPath: '/entries/test.json',
          vectorClock: intermediateVc, // VC from when enqueue was called
          status: SyncEntryStatus.update,
        ),
      );

      // Verify the merge captured both the old VC and the intermediate VC
      expect(capturedMessage, isNotNull);
      final decodedMessage = SyncMessage.fromJson(
        jsonDecode(capturedMessage!) as Map<String, dynamic>,
      );
      expect(decodedMessage, isA<SyncJournalEntity>());
      final journalMsg = decodedMessage as SyncJournalEntity;

      // Final VC should be from DB (latest)
      expect(journalMsg.vectorClock?.vclock['hostA'], 7);

      // coveredVectorClocks should contain old VC (5), intermediate (6),
      // and current (7)
      expect(journalMsg.coveredVectorClocks, isNotNull);
      final coveredCounters = journalMsg.coveredVectorClocks!
          .map((vc) => vc.vclock['hostA'])
          .whereType<int>()
          .toSet();
      expect(coveredCounters, containsAll([5, 6, 7]));
      expect(coveredCounters, hasLength(3));
    });

    test('merges entry link updates with coveredVectorClocks', () async {
      final sampleDate = DateTime.utc(2024);
      const oldVc = VectorClock({'hostA': 3});
      const newVc = VectorClock({'hostA': 5});

      final oldLink = EntryLink.basic(
        id: 'link-id',
        fromId: 'from-entry',
        toId: 'to-entry',
        createdAt: sampleDate,
        updatedAt: sampleDate,
        vectorClock: oldVc,
      );

      final oldMessage = SyncMessage.entryLink(
        entryLink: oldLink,
        status: SyncEntryStatus.update,
      );

      final existingItem = OutboxItem(
        id: 1,
        createdAt: sampleDate,
        updatedAt: sampleDate,
        status: OutboxStatus.pending.index,
        retries: 0,
        message: jsonEncode(oldMessage.toJson()),
        subject: 'hhash:link:3',
        filePath: null,
        outboxEntryId: 'link-id',
      );

      when(() => syncDatabase.findPendingByEntryId('link-id'))
          .thenAnswer((_) async => existingItem);

      String? capturedMessage;
      String? capturedSubject;
      when(
        () => syncDatabase.updateOutboxMessage(
          itemId: any(named: 'itemId'),
          newMessage: any(named: 'newMessage'),
          newSubject: any(named: 'newSubject'),
        ),
      ).thenAnswer((invocation) async {
        capturedMessage = invocation.namedArguments[#newMessage] as String?;
        capturedSubject = invocation.namedArguments[#newSubject] as String?;
        return 1;
      });

      final testService = TestableOutboxService(
        syncDatabase: syncDatabase,
        loggingService: loggingService,
        vectorClockService: vectorClockService,
        journalDb: journalDb,
        documentsDirectory: documentsDirectory,
        userActivityService: userActivityService,
        repository: repository,
        messageSender: messageSender,
        processor: processor,
      );

      final newLink = EntryLink.basic(
        id: 'link-id',
        fromId: 'from-entry',
        toId: 'to-entry',
        createdAt: sampleDate,
        updatedAt: sampleDate,
        vectorClock: newVc,
      );

      await testService.enqueueMessage(
        SyncMessage.entryLink(
          entryLink: newLink,
          status: SyncEntryStatus.update,
        ),
      );

      // Verify updateOutboxMessage was called instead of addOutboxItem
      verify(
        () => syncDatabase.updateOutboxMessage(
          itemId: 1,
          newMessage: any(named: 'newMessage'),
          newSubject: any(named: 'newSubject'),
        ),
      ).called(1);
      verifyNever(() => syncDatabase.addOutboxItem(any()));

      // Verify the merged message contains coveredVectorClocks
      expect(capturedMessage, isNotNull);
      final decodedMessage = SyncMessage.fromJson(
        jsonDecode(capturedMessage!) as Map<String, dynamic>,
      );
      expect(decodedMessage, isA<SyncEntryLink>());
      final linkMsg = decodedMessage as SyncEntryLink;
      expect(linkMsg.coveredVectorClocks, isNotNull);
      final coveredCounters = linkMsg.coveredVectorClocks!
          .map((vc) => vc.vclock['hostA'])
          .whereType<int>()
          .toSet();
      expect(coveredCounters, containsAll([3, 5]));
      expect(coveredCounters, hasLength(2));
      expect(capturedSubject, 'hhash:link:5');
    });

    test('records sequence log entry during journal entity merge', () async {
      final sampleDate = DateTime.utc(2024);
      const oldVc = VectorClock({'hostA': 5});
      const newVc = VectorClock({'hostA': 7});

      const oldMessage = SyncMessage.journalEntity(
        id: 'entry-id',
        jsonPath: '/entries/test.json',
        vectorClock: oldVc,
        status: SyncEntryStatus.update,
      );

      final existingItem = OutboxItem(
        id: 1,
        createdAt: sampleDate,
        updatedAt: sampleDate,
        status: OutboxStatus.pending.index,
        retries: 0,
        message: jsonEncode(oldMessage.toJson()),
        subject: 'hhash:5',
        filePath: null,
        outboxEntryId: 'entry-id',
      );

      when(() => syncDatabase.findPendingByEntryId('entry-id'))
          .thenAnswer((_) async => existingItem);
      when(
        () => syncDatabase.updateOutboxMessage(
          itemId: any(named: 'itemId'),
          newMessage: any(named: 'newMessage'),
          newSubject: any(named: 'newSubject'),
        ),
      ).thenAnswer((_) async => 1);

      final mockSequenceService = MockSyncSequenceLogService();
      when(
        () => mockSequenceService.recordSentEntry(
          entryId: any(named: 'entryId'),
          vectorClock: any(named: 'vectorClock'),
        ),
      ).thenAnswer((_) async {});

      final testService = TestableOutboxService(
        syncDatabase: syncDatabase,
        loggingService: loggingService,
        vectorClockService: vectorClockService,
        journalDb: journalDb,
        documentsDirectory: documentsDirectory,
        userActivityService: userActivityService,
        repository: repository,
        messageSender: messageSender,
        processor: processor,
        sequenceLogService: mockSequenceService,
      );

      final metadata = Metadata(
        id: 'entry-id',
        createdAt: sampleDate,
        updatedAt: sampleDate,
        dateFrom: sampleDate,
        dateTo: sampleDate,
        vectorClock: newVc,
      );
      final journalEntity = JournalEntity.journalEntry(
        meta: metadata,
        entryText: const EntryText(plainText: 'Updated text'),
      );

      const jsonPath = '/entries/test.json';
      File('${documentsDirectory.path}$jsonPath')
        ..createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(journalEntity.toJson()));

      await testService.enqueueMessage(
        const SyncMessage.journalEntity(
          id: 'entry-id',
          jsonPath: jsonPath,
          vectorClock: newVc,
          status: SyncEntryStatus.update,
        ),
      );

      // Verify sequence log was recorded during merge
      verify(
        () => mockSequenceService.recordSentEntry(
          entryId: 'entry-id',
          vectorClock: newVc,
        ),
      ).called(1);
    });

    test('records sequence log entry during entry link merge', () async {
      final sampleDate = DateTime.utc(2024);
      const oldVc = VectorClock({'hostA': 3});
      const newVc = VectorClock({'hostA': 5});

      final oldLink = EntryLink.basic(
        id: 'link-id',
        fromId: 'from-entry',
        toId: 'to-entry',
        createdAt: sampleDate,
        updatedAt: sampleDate,
        vectorClock: oldVc,
      );

      final oldMessage = SyncMessage.entryLink(
        entryLink: oldLink,
        status: SyncEntryStatus.update,
      );

      final existingItem = OutboxItem(
        id: 1,
        createdAt: sampleDate,
        updatedAt: sampleDate,
        status: OutboxStatus.pending.index,
        retries: 0,
        message: jsonEncode(oldMessage.toJson()),
        subject: 'hhash:link:3',
        filePath: null,
        outboxEntryId: 'link-id',
      );

      when(() => syncDatabase.findPendingByEntryId('link-id'))
          .thenAnswer((_) async => existingItem);
      when(
        () => syncDatabase.updateOutboxMessage(
          itemId: any(named: 'itemId'),
          newMessage: any(named: 'newMessage'),
          newSubject: any(named: 'newSubject'),
        ),
      ).thenAnswer((_) async => 1);

      final mockSequenceService = MockSyncSequenceLogService();
      when(
        () => mockSequenceService.recordSentEntryLink(
          linkId: any(named: 'linkId'),
          vectorClock: any(named: 'vectorClock'),
        ),
      ).thenAnswer((_) async {});

      final testService = TestableOutboxService(
        syncDatabase: syncDatabase,
        loggingService: loggingService,
        vectorClockService: vectorClockService,
        journalDb: journalDb,
        documentsDirectory: documentsDirectory,
        userActivityService: userActivityService,
        repository: repository,
        messageSender: messageSender,
        processor: processor,
        sequenceLogService: mockSequenceService,
      );

      final newLink = EntryLink.basic(
        id: 'link-id',
        fromId: 'from-entry',
        toId: 'to-entry',
        createdAt: sampleDate,
        updatedAt: sampleDate,
        vectorClock: newVc,
      );

      await testService.enqueueMessage(
        SyncMessage.entryLink(
          entryLink: newLink,
          status: SyncEntryStatus.update,
        ),
      );

      // Verify sequence log was recorded during merge
      verify(
        () => mockSequenceService.recordSentEntryLink(
          linkId: 'link-id',
          vectorClock: newVc,
        ),
      ).called(1);
    });

    test('falls through to create new item when merge message decode fails',
        () async {
      final sampleDate = DateTime.utc(2024);
      const newVc = VectorClock({'hostA': 7});

      // Existing item with invalid JSON message
      final existingItem = OutboxItem(
        id: 1,
        createdAt: sampleDate,
        updatedAt: sampleDate,
        status: OutboxStatus.pending.index,
        retries: 0,
        message: 'invalid-json{{{',
        subject: 'hhash:5',
        filePath: null,
        outboxEntryId: 'entry-id',
      );

      when(() => syncDatabase.findPendingByEntryId('entry-id'))
          .thenAnswer((_) async => existingItem);
      when(() => syncDatabase.addOutboxItem(any())).thenAnswer((_) async => 2);

      final testService = TestableOutboxService(
        syncDatabase: syncDatabase,
        loggingService: loggingService,
        vectorClockService: vectorClockService,
        journalDb: journalDb,
        documentsDirectory: documentsDirectory,
        userActivityService: userActivityService,
        repository: repository,
        messageSender: messageSender,
        processor: processor,
      );

      final metadata = Metadata(
        id: 'entry-id',
        createdAt: sampleDate,
        updatedAt: sampleDate,
        dateFrom: sampleDate,
        dateTo: sampleDate,
        vectorClock: newVc,
      );
      final journalEntity = JournalEntity.journalEntry(
        meta: metadata,
        entryText: const EntryText(plainText: 'New text'),
      );

      const jsonPath = '/entries/test.json';
      File('${documentsDirectory.path}$jsonPath')
        ..createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(journalEntity.toJson()));

      await testService.enqueueMessage(
        const SyncMessage.journalEntity(
          id: 'entry-id',
          jsonPath: jsonPath,
          vectorClock: newVc,
          status: SyncEntryStatus.update,
        ),
      );

      // Should fall through to create new item since merge decode failed
      verify(() => syncDatabase.addOutboxItem(any())).called(1);
      verifyNever(
        () => syncDatabase.updateOutboxMessage(
          itemId: any(named: 'itemId'),
          newMessage: any(named: 'newMessage'),
          newSubject: any(named: 'newSubject'),
        ),
      );
    });
  });

  group('sendNext', () {
    test('uses SyncTuning.outboxIdleThreshold for default gate', () async {
      when(() => journalDb.getConfigFlag(enableMatrixFlag))
          .thenAnswer((_) async => true);
      when(() => processor.processQueue())
          .thenAnswer((_) async => OutboxProcessingResult.none);

      final matrixService = MockMatrixService();
      final client = MockMatrixClient();
      final cached = MockCachedLoginController();
      when(() => cached.stream)
          .thenAnswer((_) => const Stream<LoginState>.empty());
      when(() => cached.value).thenReturn(LoginState.loggedOut);
      when(() => client.onLoginStateChanged).thenReturn(cached);
      when(() => matrixService.client).thenReturn(client);

      final svc = OutboxService(
        syncDatabase: syncDatabase,
        loggingService: loggingService,
        vectorClockService: vectorClockService,
        journalDb: journalDb,
        documentsDirectory: documentsDirectory,
        userActivityService: userActivityService,
        repository: repository,
        messageSender: messageSender,
        processor: processor,
        matrixService: matrixService,
      );

      // Access the gate via reflection (private) by invoking sendNext; gate is
      // injected in ctor and should use the tuned threshold.
      final gate = svc.getActivityGateForTest();
      expect(gate.idleThreshold, SyncTuning.outboxIdleThreshold);
      await svc.dispose();
    });

    test('skips processing when Matrix disabled', () async {
      when(() => journalDb.getConfigFlag(enableMatrixFlag))
          .thenAnswer((_) async => false);

      final gate = createGate();

      final svc = TestableOutboxService(
        syncDatabase: syncDatabase,
        loggingService: loggingService,
        vectorClockService: vectorClockService,
        journalDb: journalDb,
        documentsDirectory: documentsDirectory,
        userActivityService: userActivityService,
        repository: repository,
        messageSender: messageSender,
        processor: processor,
        activityGate: gate,
      );

      await svc.sendNext();

      verifyNever(() => processor.processQueue());
      expect(svc.enqueueCalls, 0);

      await svc.dispose();
    });

    test('schedules next run when processor requests it', () async {
      when(() => journalDb.getConfigFlag(enableMatrixFlag))
          .thenAnswer((_) async => true);
      when(() => processor.processQueue()).thenAnswer(
        (_) async => OutboxProcessingResult.schedule(
          const Duration(seconds: 3),
        ),
      );

      final gate = createGate();

      final svc = TestableOutboxService(
        syncDatabase: syncDatabase,
        loggingService: loggingService,
        vectorClockService: vectorClockService,
        journalDb: journalDb,
        documentsDirectory: documentsDirectory,
        userActivityService: userActivityService,
        repository: repository,
        messageSender: messageSender,
        processor: processor,
        activityGate: gate,
      );

      await svc.sendNext();

      // Processor requested scheduling; sendNext returns after first drain
      verify(() => processor.processQueue()).called(1);
      expect(svc.enqueueCalls, 1);
      expectDelayCloseTo(svc.lastDelay, const Duration(seconds: 3));

      await svc.dispose();
    });

    test('does not reschedule when queue empty', () async {
      when(() => journalDb.getConfigFlag(enableMatrixFlag))
          .thenAnswer((_) async => true);
      when(() => processor.processQueue())
          .thenAnswer((_) async => OutboxProcessingResult.none);

      final gate = createGate();

      final svc = TestableOutboxService(
        syncDatabase: syncDatabase,
        loggingService: loggingService,
        vectorClockService: vectorClockService,
        journalDb: journalDb,
        documentsDirectory: documentsDirectory,
        userActivityService: userActivityService,
        repository: repository,
        messageSender: messageSender,
        processor: processor,
        activityGate: gate,
      );

      await svc.sendNext();

      expect(svc.enqueueCalls, 0);
      await svc.dispose();
    });

    test('logs error and reschedules on failure', () async {
      when(() => journalDb.getConfigFlag(enableMatrixFlag))
          .thenAnswer((_) async => true);
      final exception = Exception('boom');
      when(() => processor.processQueue()).thenThrow(exception);

      final gate = createGate();

      final svc = TestableOutboxService(
        syncDatabase: syncDatabase,
        loggingService: loggingService,
        vectorClockService: vectorClockService,
        journalDb: journalDb,
        documentsDirectory: documentsDirectory,
        userActivityService: userActivityService,
        repository: repository,
        messageSender: messageSender,
        processor: processor,
        activityGate: gate,
      );

      await svc.sendNext();

      verify(
        () => loggingService.captureException(
          exception,
          domain: 'OUTBOX',
          subDomain: 'sendNext',
          stackTrace: any<StackTrace>(named: 'stackTrace'),
        ),
      ).called(1);
      expect(svc.enqueueCalls, 1);
      expectDelayCloseTo(svc.lastDelay, const Duration(seconds: 15));

      await svc.dispose();
    });

    test(
        'schedules immediate continuation when drain pass cap reached and items remain',
        () async {
      when(() => journalDb.getConfigFlag(enableMatrixFlag))
          .thenAnswer((_) async => true);
      // Always indicate more work immediately.
      when(() => processor.processQueue()).thenAnswer(
        (_) async => OutboxProcessingResult.schedule(Duration.zero),
      );
      // Indicate there are still pending items after the pass cap is reached.
      when(() => repository.fetchPending(limit: any(named: 'limit')))
          .thenAnswer((_) async => [
                OutboxItem(
                  id: 1,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                  status: 0,
                  retries: 0,
                  message: '{}',
                  subject: 'test',
                  filePath: null,
                )
              ]);

      final gate = createGate();

      final svc = TestableOutboxService(
        syncDatabase: syncDatabase,
        loggingService: loggingService,
        vectorClockService: vectorClockService,
        journalDb: journalDb,
        documentsDirectory: documentsDirectory,
        userActivityService: userActivityService,
        repository: repository,
        messageSender: messageSender,
        processor: processor,
        activityGate: gate,
      );

      await svc.sendNext();

      // After hitting the internal pass cap, service should schedule an
      // immediate continuation because items remain pending.
      expect(svc.enqueueCalls, 1);
      expect(svc.lastDelay, Duration.zero);

      await svc.dispose();
    });
  });

  test('throws when neither matrix service nor message sender provided', () {
    expect(
      () => OutboxService(
        syncDatabase: syncDatabase,
        loggingService: loggingService,
        vectorClockService: vectorClockService,
        journalDb: journalDb,
        documentsDirectory: documentsDirectory,
        userActivityService: userActivityService,
      ),
      throwsArgumentError,
    );
  });

  test('constructs with matrixService fallback sender', () async {
    final matrixService = MockMatrixService();
    final client = MockMatrixClient();
    when(() => matrixService.client).thenReturn(client);
    final cached = MockCachedLoginController();
    when(() => cached.stream)
        .thenAnswer((_) => const Stream<LoginState>.empty());
    when(() => cached.value).thenReturn(LoginState.loggedOut);
    when(() => client.onLoginStateChanged).thenReturn(cached);

    final serviceWithMatrix = OutboxService(
      syncDatabase: syncDatabase,
      loggingService: loggingService,
      vectorClockService: vectorClockService,
      journalDb: journalDb,
      documentsDirectory: documentsDirectory,
      userActivityService: userActivityService,
      matrixService: matrixService,
    );

    await serviceWithMatrix.dispose();
  });

  test('MatrixOutboxMessageSender delegates to MatrixService', () async {
    final matrixService = MockMatrixService();
    const message = SyncMessage.aiConfigDelete(id: 'abc');
    when(() => matrixService.sendMatrixMsg(message))
        .thenAnswer((_) async => true);

    final sender = MatrixOutboxMessageSender(matrixService);

    final result = await sender.send(message);

    expect(result, isTrue);
    verify(() => matrixService.sendMatrixMsg(message)).called(1);
  });

  group('sendNext login gate - ', () {
    test('returns early when sync enabled but not logged in', () async {
      when(() => journalDb.getConfigFlag(enableMatrixFlag))
          .thenAnswer((_) async => true);
      when(() => processor.processQueue())
          .thenAnswer((_) async => OutboxProcessingResult.none);

      final gate = createGate();

      final matrixService = MockMatrixService();
      final client = MockMatrixClient();
      when(() => matrixService.client).thenReturn(client);
      final cached = MockCachedLoginController();
      when(() => cached.stream)
          .thenAnswer((_) => const Stream<LoginState>.empty());
      when(() => cached.value).thenReturn(LoginState.loggedOut);
      when(() => client.onLoginStateChanged).thenReturn(cached);
      when(matrixService.isLoggedIn).thenReturn(false);

      final svc = TestableOutboxService(
        syncDatabase: syncDatabase,
        loggingService: loggingService,
        vectorClockService: vectorClockService,
        journalDb: journalDb,
        documentsDirectory: documentsDirectory,
        userActivityService: userActivityService,
        repository: repository,
        messageSender: messageSender,
        processor: processor,
        activityGate: gate,
        ownsActivityGate: false,
      );

      // Inject matrixService by replacing the sender with MatrixOutboxMessageSender
      // and re-creating the service with matrixService for login gate.
      final gatedSvc = OutboxService(
        syncDatabase: syncDatabase,
        loggingService: loggingService,
        vectorClockService: vectorClockService,
        journalDb: journalDb,
        documentsDirectory: documentsDirectory,
        userActivityService: userActivityService,
        processor: processor,
        activityGate: gate,
        ownsActivityGate: false,
        matrixService: matrixService,
      );

      await gatedSvc.sendNext();

      // Should not attempt to drain
      verifyNever(() => processor.processQueue());

      await gatedSvc.dispose();
      await svc.dispose();
    });

    test('drains when sync enabled and logged in', () async {
      when(() => journalDb.getConfigFlag(enableMatrixFlag))
          .thenAnswer((_) async => true);
      when(() => processor.processQueue())
          .thenAnswer((_) async => OutboxProcessingResult.none);

      final gate = createGate();

      final matrixService = MockMatrixService();
      final client = MockMatrixClient();
      when(() => matrixService.client).thenReturn(client);
      final cached = MockCachedLoginController();
      when(() => cached.stream)
          .thenAnswer((_) => const Stream<LoginState>.empty());
      when(() => cached.value).thenReturn(LoginState.loggedOut);
      when(() => client.onLoginStateChanged).thenReturn(cached);
      when(matrixService.isLoggedIn).thenReturn(true);

      final svc = OutboxService(
        syncDatabase: syncDatabase,
        loggingService: loggingService,
        vectorClockService: vectorClockService,
        journalDb: journalDb,
        documentsDirectory: documentsDirectory,
        userActivityService: userActivityService,
        processor: processor,
        activityGate: gate,
        ownsActivityGate: false,
        matrixService: matrixService,
      );

      await svc.sendNext();

      // sendNext performs two drains (second after a short settle delay)
      verify(() => processor.processQueue()).called(2);

      await svc.dispose();
    });

    test('post-login nudge enqueues and drains after LoginState.loggedIn',
        () async {
      when(() => journalDb.getConfigFlag(enableMatrixFlag))
          .thenAnswer((_) async => true);
      when(() => processor.processQueue())
          .thenAnswer((_) async => OutboxProcessingResult.none);

      final gate = createGate();

      final matrixService = MockMatrixService();
      final client = MockMatrixClient();
      final loginController = StreamController<LoginState>.broadcast();
      addTearDown(loginController.close);
      when(() => matrixService.client).thenReturn(client);
      final cached = MockCachedLoginController();
      when(() => cached.stream).thenAnswer((_) => loginController.stream);
      when(() => cached.value).thenReturn(LoginState.loggedOut);
      when(() => client.onLoginStateChanged).thenReturn(cached);

      var loggedIn = false;
      when(matrixService.isLoggedIn).thenAnswer((_) => loggedIn);

      fakeAsync((async) {
        final svc = OutboxService(
          syncDatabase: syncDatabase,
          loggingService: loggingService,
          vectorClockService: vectorClockService,
          journalDb: journalDb,
          documentsDirectory: documentsDirectory,
          userActivityService: userActivityService,
          processor: processor,
          activityGate: gate,
          ownsActivityGate: false,
          matrixService: matrixService,
        );
        // Flip to logged in and emit login event
        loggedIn = true;
        loginController.add(LoginState.loggedIn);
        // Advance time to allow scheduled drain, then flush microtasks
        async
          ..elapse(const Duration(milliseconds: 50))
          ..flushMicrotasks();
        verify(() => processor.processQueue()).called(greaterThanOrEqualTo(1));
        unawaited(svc.dispose());
        async.flushMicrotasks();
      });
    });

    test('connectivity regain pre-login does not drain, drains after login',
        () async {
      when(() => journalDb.getConfigFlag(enableMatrixFlag))
          .thenAnswer((_) async => true);
      when(() => processor.processQueue())
          .thenAnswer((_) async => OutboxProcessingResult.none);
      when(() => repository.fetchPending(limit: any(named: 'limit')))
          .thenAnswer((_) async => [
                OutboxItem(
                  id: 1,
                  message: '{}',
                  subject: 's',
                  status: OutboxStatus.pending.index,
                  retries: 0,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                  filePath: null,
                )
              ]);

      final gate = createGate();

      final matrixService = MockMatrixService();
      final client = MockMatrixClient();
      final loginController = StreamController<LoginState>.broadcast();
      addTearDown(loginController.close);
      when(() => matrixService.client).thenReturn(client);
      final cached = MockCachedLoginController();
      when(() => cached.stream).thenAnswer((_) => loginController.stream);
      when(() => cached.value).thenReturn(LoginState.loggedOut);
      when(() => client.onLoginStateChanged).thenReturn(cached);

      var loggedIn = false;
      when(matrixService.isLoggedIn).thenAnswer((_) => loggedIn);

      final connectivityController =
          StreamController<List<ConnectivityResult>>.broadcast();
      addTearDown(connectivityController.close);

      fakeAsync((async) {
        final svc = OutboxService(
          syncDatabase: syncDatabase,
          loggingService: loggingService,
          vectorClockService: vectorClockService,
          journalDb: journalDb,
          documentsDirectory: documentsDirectory,
          userActivityService: userActivityService,
          processor: processor,
          activityGate: gate,
          ownsActivityGate: false,
          matrixService: matrixService,
          connectivityStream: connectivityController.stream,
        );
        // Connectivity regain before login — should enqueue but not drain
        connectivityController.add([ConnectivityResult.wifi]);
        async
          ..elapse(const Duration(milliseconds: 20))
          ..flushMicrotasks();
        verifyNever(() => processor.processQueue());

        // Now login completes — post-login nudge should drain
        loggedIn = true;
        loginController.add(LoginState.loggedIn);
        async
          ..elapse(const Duration(milliseconds: 40))
          ..flushMicrotasks();
        verify(() => processor.processQueue()).called(greaterThanOrEqualTo(1));

        unawaited(svc.dispose());
        async.flushMicrotasks();
      });
    });
  });

  group('drainOutbox behavior', () {
    test('pauses when canProcess is false initially', () async {
      when(() => journalDb.getConfigFlag(enableMatrixFlag))
          .thenAnswer((_) async => true);
      final gate = createGate(canProcess: false);

      final svc = TestableOutboxService(
        syncDatabase: syncDatabase,
        loggingService: loggingService,
        vectorClockService: vectorClockService,
        journalDb: journalDb,
        documentsDirectory: documentsDirectory,
        userActivityService: userActivityService,
        repository: repository,
        messageSender: messageSender,
        processor: processor,
        activityGate: gate,
        ownsActivityGate: false,
      );

      await svc.sendNext();

      verifyNever(() => processor.processQueue());
      expect(svc.enqueueCalls, 1);
      expectDelayCloseTo(svc.lastDelay, SyncTuning.outboxRetryDelay);

      await svc.dispose();
    });

    test('pauses mid-burst when canProcess flips to false', () async {
      when(() => journalDb.getConfigFlag(enableMatrixFlag))
          .thenAnswer((_) async => true);
      var canProcess = true;
      final gate = createGate();
      when(() => gate.canProcess).thenAnswer((_) => canProcess);

      var processCalls = 0;
      when(() => processor.processQueue()).thenAnswer((_) async {
        processCalls++;
        // First pass continues immediately; then mark active to force pause.
        if (processCalls == 1) {
          canProcess = false;
          return OutboxProcessingResult.schedule(Duration.zero);
        }
        return OutboxProcessingResult.none;
      });

      final svc = TestableOutboxService(
        syncDatabase: syncDatabase,
        loggingService: loggingService,
        vectorClockService: vectorClockService,
        journalDb: journalDb,
        documentsDirectory: documentsDirectory,
        userActivityService: userActivityService,
        repository: repository,
        messageSender: messageSender,
        processor: processor,
        activityGate: gate,
        ownsActivityGate: false,
      );

      await svc.sendNext();

      expect(processCalls, 1);
      expect(svc.enqueueCalls, 1);
      expectDelayCloseTo(svc.lastDelay, SyncTuning.outboxRetryDelay);

      await svc.dispose();
    });

    test('post-settle drain is skipped when activity resumes', () async {
      when(() => journalDb.getConfigFlag(enableMatrixFlag))
          .thenAnswer((_) async => true);
      var canProcess = true;
      final gate = createGate();
      when(() => gate.canProcess).thenAnswer((_) => canProcess);

      var calls = 0;
      when(() => processor.processQueue()).thenAnswer((_) async {
        calls++;
        if (calls == 1) {
          // Flip activity to false after first drain to skip post-settle.
          unawaited(Future.microtask(() => canProcess = false));
          return OutboxProcessingResult.none;
        }
        return OutboxProcessingResult.none;
      });

      final svc = TestableOutboxService(
        syncDatabase: syncDatabase,
        loggingService: loggingService,
        vectorClockService: vectorClockService,
        journalDb: journalDb,
        documentsDirectory: documentsDirectory,
        userActivityService: userActivityService,
        repository: repository,
        messageSender: messageSender,
        processor: processor,
        activityGate: gate,
        ownsActivityGate: false,
      );

      await svc.sendNext();

      expect(calls, 1);
      expect(svc.enqueueCalls, 1);
      expectDelayCloseTo(svc.lastDelay, SyncTuning.outboxRetryDelay);

      await svc.dispose();
    });

    test('respects retry backoff and skips immediate re-entry', () async {
      when(() => journalDb.getConfigFlag(enableMatrixFlag))
          .thenAnswer((_) async => true);
      final gate = createGate();

      const delay = Duration(seconds: 5);
      var processCalls = 0;
      when(() => processor.processQueue()).thenAnswer((_) async {
        processCalls++;
        return OutboxProcessingResult.schedule(delay);
      });

      final svc = TestableOutboxService(
        syncDatabase: syncDatabase,
        loggingService: loggingService,
        vectorClockService: vectorClockService,
        journalDb: journalDb,
        documentsDirectory: documentsDirectory,
        userActivityService: userActivityService,
        repository: repository,
        messageSender: messageSender,
        processor: processor,
        activityGate: gate,
        ownsActivityGate: false,
      );

      await svc.sendNext();
      expect(processCalls, 1);
      expectDelayCloseTo(svc.lastDelay, delay);

      await svc.sendNext();
      expect(processCalls, 1);

      await svc.dispose();
    });

    test('pass cap schedules immediate continuation (delay=0)', () async {
      when(() => journalDb.getConfigFlag(enableMatrixFlag))
          .thenAnswer((_) async => true);

      // Processor always returns schedule(Duration.zero) to keep the loop running
      when(() => processor.processQueue()).thenAnswer(
          (_) async => OutboxProcessingResult.schedule(Duration.zero));
      when(() => repository.fetchPending(limit: any(named: 'limit')))
          .thenAnswer((_) async => [
                OutboxItem(
                  id: 1,
                  message: '{}',
                  subject: 's',
                  status: OutboxStatus.pending.index,
                  retries: 0,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                  filePath: null,
                )
              ]);

      // Gate returns immediately to avoid delaying the test
      final gate = createGate();

      // Custom testable service to capture enqueueNextSendRequest calls
      final svc = TestableOutboxService(
        syncDatabase: syncDatabase,
        loggingService: loggingService,
        vectorClockService: vectorClockService,
        journalDb: journalDb,
        documentsDirectory: documentsDirectory,
        userActivityService: userActivityService,
        repository: repository,
        messageSender: messageSender,
        processor: processor,
        activityGate: gate,
        ownsActivityGate: false,
      );

      await svc.sendNext();

      // Since we hit the pass cap, the service should have enqueued an
      // immediate continuation (delay zero).
      expect(svc.enqueueCalls, greaterThanOrEqualTo(1));
      expect(svc.lastDelay, Duration.zero);

      await svc.dispose();
    });

    test('runner logs gate wait when > 50ms', () async {
      when(() => journalDb.getConfigFlag(enableMatrixFlag))
          .thenAnswer((_) async => true);
      when(() => processor.processQueue())
          .thenAnswer((_) async => OutboxProcessingResult.none);

      // Gate simulates a short delay to exceed logging threshold
      final gate = createGate();
      when(gate.waitUntilIdle).thenAnswer(
          (_) => Future<void>.delayed(const Duration(milliseconds: 120)));

      final svc = OutboxService(
        syncDatabase: syncDatabase,
        loggingService: loggingService,
        vectorClockService: vectorClockService,
        journalDb: journalDb,
        documentsDirectory: documentsDirectory,
        userActivityService: userActivityService,
        repository: repository,
        messageSender: messageSender,
        processor: processor,
        activityGate: gate,
        ownsActivityGate: false,
      );

      // Use real async waits here because the service measures with
      // DateTime.now(), which fakeAsync does not advance.
      // Trigger the runner via the public enqueue API
      await svc.enqueueNextSendRequest(delay: Duration.zero);
      // Allow enough wall time for the gate wait to exceed 50ms and the
      // runner to log the instrumentation line.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      verify(() => loggingService.captureEvent(
            startsWith('activityGate.wait ms='),
            domain: 'OUTBOX',
            subDomain: 'activityGate',
          )).called(greaterThanOrEqualTo(1));
      await svc.dispose();
    });
  });

  group('watchdog', () {
    test('enqueues when pending + logged in + idle queue', () async {
      when(() => journalDb.getConfigFlag(enableMatrixFlag))
          .thenAnswer((_) async => true);
      when(() => processor.processQueue())
          .thenAnswer((_) async => OutboxProcessingResult.none);
      when(() => repository.fetchPending(limit: any(named: 'limit')))
          .thenAnswer((_) async => [
                OutboxItem(
                  id: 1,
                  message: '{}',
                  subject: 's',
                  status: OutboxStatus.pending.index,
                  retries: 0,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                  filePath: null,
                )
              ]);
      final gate = createGate();
      final matrixService = MockMatrixService();
      when(() => matrixService.isLoggedIn()).thenReturn(true);
      final client = MockMatrixClient();
      final cached = MockCachedLoginController();
      when(() => cached.stream)
          .thenAnswer((_) => const Stream<LoginState>.empty());
      when(() => cached.value).thenReturn(LoginState.loggedOut);
      when(() => client.onLoginStateChanged).thenReturn(cached);
      when(() => matrixService.client).thenReturn(client);

      // Controlled outbox count stream to avoid extra nudges
      final countController = StreamController<int>.broadcast();
      addTearDown(countController.close);
      when(() => syncDatabase.watchOutboxCount())
          .thenAnswer((_) => countController.stream);

      fakeAsync((async) {
        final svc = OutboxService(
          syncDatabase: syncDatabase,
          loggingService: loggingService,
          vectorClockService: vectorClockService,
          journalDb: journalDb,
          documentsDirectory: documentsDirectory,
          userActivityService: userActivityService,
          repository: repository,
          messageSender: messageSender,
          processor: processor,
          activityGate: gate,
          ownsActivityGate: false,
          matrixService: matrixService,
        );

        // Tick the 10s watchdog
        async
          ..elapse(const Duration(seconds: 10))
          // Allow pending tasks and the post-drain settle (250ms)
          ..elapse(const Duration(milliseconds: 300));
        verify(() => loggingService.captureEvent(
              'watchdog: pending+loggedIn idleQueue → enqueue',
              domain: 'OUTBOX',
              subDomain: 'watchdog',
            )).called(1);
        verify(() => processor.processQueue()).called(greaterThanOrEqualTo(1));
        unawaited(svc.dispose());
        async.flushMicrotasks();
      });
    });

    test('does not enqueue when queue active', () async {
      when(() => journalDb.getConfigFlag(enableMatrixFlag))
          .thenAnswer((_) async => true);
      when(() => repository.fetchPending(limit: any(named: 'limit')))
          .thenAnswer((_) async => [
                OutboxItem(
                  id: 1,
                  message: '{}',
                  subject: 's',
                  status: OutboxStatus.pending.index,
                  retries: 0,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                  filePath: null,
                )
              ]);
      final gate = createGate();
      // Keep the runner busy so queueSize > 0 when watchdog fires
      when(gate.waitUntilIdle)
          .thenAnswer((_) => Future<void>.delayed(const Duration(seconds: 30)));
      final matrixService = MockMatrixService();
      when(() => matrixService.isLoggedIn()).thenReturn(true);
      final client = MockMatrixClient();
      final cached = MockCachedLoginController();
      when(() => cached.stream)
          .thenAnswer((_) => const Stream<LoginState>.empty());
      when(() => cached.value).thenReturn(LoginState.loggedOut);
      when(() => client.onLoginStateChanged).thenReturn(cached);
      when(() => matrixService.client).thenReturn(client);
      when(() => processor.processQueue())
          .thenAnswer((_) async => OutboxProcessingResult.none);
      when(() => syncDatabase.watchOutboxCount())
          .thenAnswer((_) => const Stream<int>.empty());

      fakeAsync((async) {
        final svc = OutboxService(
          syncDatabase: syncDatabase,
          loggingService: loggingService,
          vectorClockService: vectorClockService,
          journalDb: journalDb,
          documentsDirectory: documentsDirectory,
          userActivityService: userActivityService,
          repository: repository,
          messageSender: messageSender,
          processor: processor,
          activityGate: gate,
          ownsActivityGate: false,
          matrixService: matrixService,
        );
        // Make the queue active
        unawaited(svc.enqueueNextSendRequest(delay: Duration.zero));
        async
          ..flushMicrotasks()
          ..elapse(Duration.zero)
          // Now watchdog fires while the queue is active
          ..elapse(const Duration(seconds: 10));
        verifyNever(() => loggingService.captureEvent(
              'watchdog: pending+loggedIn idleQueue → enqueue',
              domain: 'OUTBOX',
              subDomain: 'watchdog',
            ));
        unawaited(svc.dispose());
        async.flushMicrotasks();
      });
    });

    test('does not enqueue when not logged in', () async {
      when(() => journalDb.getConfigFlag(enableMatrixFlag))
          .thenAnswer((_) async => true);
      final gate = createGate();
      final matrixService = MockMatrixService();
      when(() => matrixService.isLoggedIn()).thenReturn(false);
      final client = MockMatrixClient();
      final cached = MockCachedLoginController();
      when(() => cached.stream)
          .thenAnswer((_) => const Stream<LoginState>.empty());
      when(() => cached.value).thenReturn(LoginState.loggedOut);
      when(() => client.onLoginStateChanged).thenReturn(cached);
      when(() => matrixService.client).thenReturn(client);
      when(() => repository.fetchPending(limit: any(named: 'limit')))
          .thenAnswer((_) async => [
                OutboxItem(
                  id: 1,
                  message: '{}',
                  subject: 's',
                  status: OutboxStatus.pending.index,
                  retries: 0,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                  filePath: null,
                )
              ]);
      when(() => syncDatabase.watchOutboxCount())
          .thenAnswer((_) => const Stream<int>.empty());
      when(() => processor.processQueue())
          .thenAnswer((_) async => OutboxProcessingResult.none);

      fakeAsync((async) {
        final svc = OutboxService(
          syncDatabase: syncDatabase,
          loggingService: loggingService,
          vectorClockService: vectorClockService,
          journalDb: journalDb,
          documentsDirectory: documentsDirectory,
          userActivityService: userActivityService,
          repository: repository,
          messageSender: messageSender,
          processor: processor,
          activityGate: gate,
          ownsActivityGate: false,
          matrixService: matrixService,
        );
        async.elapse(const Duration(seconds: 10));
        verifyNever(() => loggingService.captureEvent(
              'watchdog: pending+loggedIn idleQueue → enqueue',
              domain: 'OUTBOX',
              subDomain: 'watchdog',
            ));
        unawaited(svc.dispose());
        async.flushMicrotasks();
      });
    });

    test('handles fetchPending errors gracefully', () async {
      when(() => journalDb.getConfigFlag(enableMatrixFlag))
          .thenAnswer((_) async => true);
      when(() => repository.fetchPending(limit: any(named: 'limit')))
          .thenThrow(Exception('boom'));
      when(() => processor.processQueue())
          .thenAnswer((_) async => OutboxProcessingResult.none);
      final gate = createGate();
      final matrixService = MockMatrixService();
      when(() => matrixService.isLoggedIn()).thenReturn(true);
      final client = MockMatrixClient();
      final cached = MockCachedLoginController();
      when(() => cached.stream)
          .thenAnswer((_) => const Stream<LoginState>.empty());
      when(() => cached.value).thenReturn(LoginState.loggedOut);
      when(() => client.onLoginStateChanged).thenReturn(cached);
      when(() => matrixService.client).thenReturn(client);
      when(() => syncDatabase.watchOutboxCount())
          .thenAnswer((_) => const Stream<int>.empty());

      fakeAsync((async) {
        final svc = OutboxService(
          syncDatabase: syncDatabase,
          loggingService: loggingService,
          vectorClockService: vectorClockService,
          journalDb: journalDb,
          documentsDirectory: documentsDirectory,
          userActivityService: userActivityService,
          repository: repository,
          messageSender: messageSender,
          processor: processor,
          activityGate: gate,
          ownsActivityGate: false,
          matrixService: matrixService,
        );
        async.elapse(const Duration(seconds: 10));
        verify(() => loggingService.captureException(
              any<Object>(),
              domain: 'OUTBOX',
              subDomain: 'watchdog',
              stackTrace: any<StackTrace>(named: 'stackTrace'),
            )).called(1);
        unawaited(svc.dispose());
        async.flushMicrotasks();
      });
    });

    test('stops after dispose', () async {
      when(() => journalDb.getConfigFlag(enableMatrixFlag))
          .thenAnswer((_) async => true);
      when(() => repository.fetchPending(limit: any(named: 'limit')))
          .thenAnswer((_) async => [
                OutboxItem(
                  id: 1,
                  message: '{}',
                  subject: 's',
                  status: OutboxStatus.pending.index,
                  retries: 0,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                  filePath: null,
                )
              ]);
      final gate = createGate();
      final matrixService = MockMatrixService();
      when(() => matrixService.isLoggedIn()).thenReturn(true);
      final client = MockMatrixClient();
      final cached = MockCachedLoginController();
      when(() => cached.stream)
          .thenAnswer((_) => const Stream<LoginState>.empty());
      when(() => cached.value).thenReturn(LoginState.loggedOut);
      when(() => client.onLoginStateChanged).thenReturn(cached);
      when(() => matrixService.client).thenReturn(client);
      when(() => syncDatabase.watchOutboxCount())
          .thenAnswer((_) => const Stream<int>.empty());
      when(() => processor.processQueue())
          .thenAnswer((_) async => OutboxProcessingResult.none);

      fakeAsync((async) {
        final svc = OutboxService(
          syncDatabase: syncDatabase,
          loggingService: loggingService,
          vectorClockService: vectorClockService,
          journalDb: journalDb,
          documentsDirectory: documentsDirectory,
          userActivityService: userActivityService,
          repository: repository,
          messageSender: messageSender,
          processor: processor,
          activityGate: gate,
          ownsActivityGate: false,
          matrixService: matrixService,
        );
        async.elapse(const Duration(seconds: 10));
        unawaited(svc.dispose());
        // Further elapse should not trigger watchdog again
        async.elapse(const Duration(seconds: 20));
        verify(() => loggingService.captureEvent(
              'watchdog: pending+loggedIn idleQueue → enqueue',
              domain: 'OUTBOX',
              subDomain: 'watchdog',
            )).called(1);
      });
    });
  });

  group('dbNudge', () {
    test('enqueues when count increases (>0)', () async {
      when(() => journalDb.getConfigFlag(enableMatrixFlag))
          .thenAnswer((_) async => true);
      final gate = createGate();
      when(() => processor.processQueue())
          .thenAnswer((_) async => OutboxProcessingResult.none);

      final countController = StreamController<int>.broadcast();
      addTearDown(countController.close);
      when(() => syncDatabase.watchOutboxCount())
          .thenAnswer((_) => countController.stream);

      fakeAsync((async) {
        final svc = OutboxService(
          syncDatabase: syncDatabase,
          loggingService: loggingService,
          vectorClockService: vectorClockService,
          journalDb: journalDb,
          documentsDirectory: documentsDirectory,
          userActivityService: userActivityService,
          repository: repository,
          messageSender: messageSender,
          processor: processor,
          activityGate: gate,
          ownsActivityGate: false,
        );

        countController.add(5);
        // Debounce delay is 50ms
        async
          ..elapse(const Duration(milliseconds: 60))
          ..flushMicrotasks();
        verify(() => loggingService.captureEvent(
              'dbNudge count=5 → enqueue',
              domain: 'OUTBOX',
              subDomain: 'dbNudge',
            )).called(1);
        verify(() => loggingService.captureEvent(
              'enqueueRequest() done',
              domain: 'OUTBOX',
              subDomain: any(named: 'subDomain'),
            )).called(1);
        unawaited(svc.dispose());
        async.flushMicrotasks();
      });
    });

    test('ignores count <= 0', () async {
      when(() => journalDb.getConfigFlag(enableMatrixFlag))
          .thenAnswer((_) async => true);
      final gate = createGate();
      when(() => processor.processQueue())
          .thenAnswer((_) async => OutboxProcessingResult.none);

      final countController = StreamController<int>.broadcast();
      addTearDown(countController.close);
      when(() => syncDatabase.watchOutboxCount())
          .thenAnswer((_) => countController.stream);

      fakeAsync((async) {
        final svc = OutboxService(
          syncDatabase: syncDatabase,
          loggingService: loggingService,
          vectorClockService: vectorClockService,
          journalDb: journalDb,
          documentsDirectory: documentsDirectory,
          userActivityService: userActivityService,
          repository: repository,
          messageSender: messageSender,
          processor: processor,
          activityGate: gate,
          ownsActivityGate: false,
        );

        countController.add(0);
        async
          ..elapse(const Duration(milliseconds: 100))
          ..flushMicrotasks();
        verifyNever(() => loggingService.captureEvent(
              startsWith('dbNudge'),
              domain: any(named: 'domain'),
              subDomain: any(named: 'subDomain'),
            ));
        verifyNever(() => loggingService.captureEvent(
              'enqueueRequest() done',
              domain: 'OUTBOX',
              subDomain: any(named: 'subDomain'),
            ));
        unawaited(svc.dispose());
        async.flushMicrotasks();
      });
    });

    test('stops after dispose', () async {
      when(() => journalDb.getConfigFlag(enableMatrixFlag))
          .thenAnswer((_) async => true);
      final gate = createGate();
      when(() => processor.processQueue())
          .thenAnswer((_) async => OutboxProcessingResult.none);

      final countController = StreamController<int>.broadcast();
      addTearDown(countController.close);
      when(() => syncDatabase.watchOutboxCount())
          .thenAnswer((_) => countController.stream);

      fakeAsync((async) {
        final svc = OutboxService(
          syncDatabase: syncDatabase,
          loggingService: loggingService,
          vectorClockService: vectorClockService,
          journalDb: journalDb,
          documentsDirectory: documentsDirectory,
          userActivityService: userActivityService,
          repository: repository,
          messageSender: messageSender,
          processor: processor,
          activityGate: gate,
          ownsActivityGate: false,
        );
        unawaited(svc.dispose());
        countController.add(2);
        async
          ..elapse(const Duration(milliseconds: 100))
          ..flushMicrotasks();
        verifyNever(() => loggingService.captureEvent(
              startsWith('dbNudge'),
              domain: any(named: 'domain'),
              subDomain: any(named: 'subDomain'),
            ));
      });
    });

    test('handles stream errors without crashing the test', () async {
      when(() => journalDb.getConfigFlag(enableMatrixFlag))
          .thenAnswer((_) async => true);
      final gate = createGate();
      when(() => processor.processQueue())
          .thenAnswer((_) async => OutboxProcessingResult.none);

      final countController = StreamController<int>.broadcast();
      addTearDown(countController.close);
      when(() => syncDatabase.watchOutboxCount())
          .thenAnswer((_) => countController.stream);

      fakeAsync((async) {
        Object? capturedError;
        StackTrace? capturedSt;
        OutboxService? svc;
        runZonedGuarded(() {
          svc = OutboxService(
            syncDatabase: syncDatabase,
            loggingService: loggingService,
            vectorClockService: vectorClockService,
            journalDb: journalDb,
            documentsDirectory: documentsDirectory,
            userActivityService: userActivityService,
            repository: repository,
            messageSender: messageSender,
            processor: processor,
            activityGate: gate,
            ownsActivityGate: false,
          );
          countController.addError(Exception('stream error'));
        }, (e, st) {
          capturedError = e;
          capturedSt = st;
        });
        // Allow the stream error to propagate
        async.flushMicrotasks();
        expect(capturedError, isNotNull);
        expect(capturedSt, isNotNull);
        unawaited(svc!.dispose());
        async.flushMicrotasks();
      });
    });
  });

  group('integration: triggers interplay', () {
    test('watchdog does not duplicate work when dbNudge already active',
        () async {
      when(() => journalDb.getConfigFlag(enableMatrixFlag))
          .thenAnswer((_) async => true);
      // One pending item in repository
      when(() => repository.fetchPending(limit: any(named: 'limit')))
          .thenAnswer((_) async => [
                OutboxItem(
                  id: 42,
                  message: '{}',
                  subject: 's',
                  status: OutboxStatus.pending.index,
                  retries: 0,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                  filePath: null,
                )
              ]);

      // Gate delays long enough so watchdog fires while runner is active
      final gate = createGate();
      when(gate.waitUntilIdle)
          .thenAnswer((_) => Future<void>.delayed(const Duration(seconds: 12)));

      final matrixService = MockMatrixService();
      final client = MockMatrixClient();
      when(() => matrixService.client).thenReturn(client);
      final cached = MockCachedLoginController();
      when(() => cached.stream)
          .thenAnswer((_) => const Stream<LoginState>.empty());
      when(() => cached.value).thenReturn(LoginState.loggedIn);
      when(() => client.onLoginStateChanged).thenReturn(cached);
      when(() => matrixService.isLoggedIn()).thenReturn(true);

      // Track db count stream
      final countController = StreamController<int>.broadcast();
      addTearDown(countController.close);
      when(() => syncDatabase.watchOutboxCount())
          .thenAnswer((_) => countController.stream);

      // Processor returns none for each drain (sendNext runs two drains per invocation)
      when(() => processor.processQueue())
          .thenAnswer((_) async => OutboxProcessingResult.none);

      fakeAsync((async) {
        final svc = OutboxService(
          syncDatabase: syncDatabase,
          loggingService: loggingService,
          vectorClockService: vectorClockService,
          journalDb: journalDb,
          documentsDirectory: documentsDirectory,
          userActivityService: userActivityService,
          repository: repository,
          messageSender: messageSender,
          processor: processor,
          activityGate: gate,
          ownsActivityGate: false,
          matrixService: matrixService,
        );

        // T=0: DB nudge fires → schedules enqueue after 50ms
        countController.add(1);
        async
          ..elapse(const Duration(milliseconds: 60))
          ..flushMicrotasks();

        // T=10s: Watchdog fires while runner is still blocked in waitUntilIdle
        async.elapse(const Duration(seconds: 10));

        // Let the runner finish and the second drain occur after settle
        async
          ..elapse(const Duration(seconds: 3))
          ..flushMicrotasks();

        // Exactly one runner invocation → two drains
        verify(() => processor.processQueue()).called(2);
        // Watchdog must not enqueue when queue active → no watchdog enqueue log
        verifyNever(() => loggingService.captureEvent(
              'watchdog: pending+loggedIn idleQueue → enqueue',
              domain: 'OUTBOX',
              subDomain: 'watchdog',
            ));

        unawaited(svc.dispose());
        async.flushMicrotasks();
      });
    });

    test('connectivity + login + watchdog dont cause triple processing',
        () async {
      when(() => journalDb.getConfigFlag(enableMatrixFlag))
          .thenAnswer((_) async => true);
      when(() => repository.fetchPending(limit: any(named: 'limit')))
          .thenAnswer((_) async => [
                OutboxItem(
                  id: 1,
                  message: '{}',
                  subject: 's',
                  status: OutboxStatus.pending.index,
                  retries: 0,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                  filePath: null,
                )
              ]);
      when(() => processor.processQueue())
          .thenAnswer((_) async => OutboxProcessingResult.none);

      // Long wait to keep the queue active till after watchdog
      final gate = createGate();
      when(gate.waitUntilIdle)
          .thenAnswer((_) => Future<void>.delayed(const Duration(seconds: 12)));

      final matrixService = MockMatrixService();
      final client = MockMatrixClient();
      final loginController = StreamController<LoginState>.broadcast();
      addTearDown(loginController.close);
      when(() => matrixService.client).thenReturn(client);
      final cached = MockCachedLoginController();
      when(() => cached.stream).thenAnswer((_) => loginController.stream);
      when(() => cached.value).thenReturn(LoginState.loggedOut);
      when(() => client.onLoginStateChanged).thenReturn(cached);
      when(() => matrixService.isLoggedIn()).thenReturn(false);

      final connectivityController =
          StreamController<List<ConnectivityResult>>.broadcast();
      addTearDown(connectivityController.close);

      // DB count stream inert for this test
      when(() => syncDatabase.watchOutboxCount())
          .thenAnswer((_) => const Stream<int>.empty());

      fakeAsync((async) {
        final svc = OutboxService(
          syncDatabase: syncDatabase,
          loggingService: loggingService,
          vectorClockService: vectorClockService,
          journalDb: journalDb,
          documentsDirectory: documentsDirectory,
          userActivityService: userActivityService,
          repository: repository,
          messageSender: messageSender,
          processor: processor,
          activityGate: gate,
          ownsActivityGate: false,
          matrixService: matrixService,
          connectivityStream: connectivityController.stream,
        );

        // T=0: Connectivity regain → enqueue
        connectivityController.add([ConnectivityResult.wifi]);
        async.flushMicrotasks();

        // T=10ms: Login completes → enqueue
        when(() => matrixService.isLoggedIn()).thenReturn(true);
        loginController.add(LoginState.loggedIn);
        async.flushMicrotasks();

        // T=10s: Watchdog fires while queue active → should not enqueue
        async.elapse(const Duration(seconds: 10));

        // Allow runner completion and second drains
        async
          ..elapse(const Duration(seconds: 3))
          ..flushMicrotasks();

        // Upper bound: two drains per runner invocation, at most two runner
        // callbacks (connectivity + login) = 4 drains total. Not 6+.
        verify(() => processor.processQueue()).called(lessThanOrEqualTo(4));
        verifyNever(() => loggingService.captureEvent(
              'watchdog: pending+loggedIn idleQueue → enqueue',
              domain: 'OUTBOX',
              subDomain: 'watchdog',
            ));

        unawaited(svc.dispose());
        async.flushMicrotasks();
      });
    });

    test('dbNudge during watchdog fetchPending does not duplicate excessively',
        () async {
      when(() => journalDb.getConfigFlag(enableMatrixFlag))
          .thenAnswer((_) async => true);
      when(() => processor.processQueue())
          .thenAnswer((_) async => OutboxProcessingResult.none);
      // Slow fetchPending simulates overlap window with dbNudge
      when(() => repository.fetchPending(limit: any(named: 'limit')))
          .thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return [
          OutboxItem(
            id: 7,
            message: '{}',
            subject: 's',
            status: OutboxStatus.pending.index,
            retries: 0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            filePath: null,
          )
        ];
      });

      // Gate immediate
      final gate = createGate();

      final matrixService = MockMatrixService();
      final client = MockMatrixClient();
      when(() => matrixService.client).thenReturn(client);
      final cached = MockCachedLoginController();
      when(() => cached.stream)
          .thenAnswer((_) => const Stream<LoginState>.empty());
      when(() => cached.value).thenReturn(LoginState.loggedIn);
      when(() => client.onLoginStateChanged).thenReturn(cached);
      when(() => matrixService.isLoggedIn()).thenReturn(true);

      // DB count stream for nudge
      final countController = StreamController<int>.broadcast();
      addTearDown(countController.close);
      when(() => syncDatabase.watchOutboxCount())
          .thenAnswer((_) => countController.stream);

      fakeAsync((async) {
        final svc = OutboxService(
          syncDatabase: syncDatabase,
          loggingService: loggingService,
          vectorClockService: vectorClockService,
          journalDb: journalDb,
          documentsDirectory: documentsDirectory,
          userActivityService: userActivityService,
          repository: repository,
          messageSender: messageSender,
          processor: processor,
          activityGate: gate,
          ownsActivityGate: false,
          matrixService: matrixService,
        );

        // T=10s: Watchdog fires and begins slow fetchPending
        async.elapse(const Duration(seconds: 10));
        // T=10s+20ms: DB nudge enqueues while watchdog is in-flight
        async.elapse(const Duration(milliseconds: 20));
        countController.add(1);
        // Let debounce (50ms) + remaining watchdog (30ms) pass
        async.elapse(const Duration(milliseconds: 80));
        async.flushMicrotasks();

        // Allow drains to complete
        async
          ..elapse(const Duration(seconds: 1))
          ..flushMicrotasks();

        // Should not explode in duplicate processing; 4 drains is an upper bound here
        verify(() => processor.processQueue()).called(lessThanOrEqualTo(4));
        unawaited(svc.dispose());
        async.flushMicrotasks();
      });
    });
  });

  group('SyncThemingSelection', () {
    test('enqueues theming message with correct subject', () async {
      final message = SyncMessage.themingSelection(
        lightThemeName: 'Indigo',
        darkThemeName: 'Shark',
        themeMode: 'dark',
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        status: SyncEntryStatus.update,
      );

      await service.enqueueMessage(message);

      final captured = verify(
              () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()))
          .captured;
      expect(captured.length, 1);

      final companion = captured.first as OutboxCompanion;
      expect(companion.subject.value, 'themingSelection');
    });

    test('logs theming message details', () async {
      final message = SyncMessage.themingSelection(
        lightThemeName: 'Indigo',
        darkThemeName: 'Shark',
        themeMode: 'dark',
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        status: SyncEntryStatus.update,
      );

      await service.enqueueMessage(message);

      verify(() => loggingService.captureEvent(
            allOf([
              contains('type=SyncThemingSelection'),
              contains('light=Indigo'),
              contains('dark=Shark'),
              contains('mode=dark'),
            ]),
            domain: 'OUTBOX',
            subDomain: 'enqueueMessage',
          )).called(1);
    });
  });

  group('Embedded Entry Links', () {
    test('embeds entry links when enqueueing journal entity', () async {
      const entryId = 'entry-123';
      final link1 = EntryLink.basic(
        id: 'link-1',
        fromId: entryId,
        toId: 'category-1',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
        vectorClock: null,
      );
      final link2 = EntryLink.basic(
        id: 'link-2',
        fromId: 'category-2',
        toId: entryId,
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
        vectorClock: null,
      );

      // Mock journalDb to return links for this entry (both directions)
      when(() => journalDb.linksForEntryIdsBidirectional(const {entryId}))
          .thenAnswer((_) async => [link1, link2]);

      final journalEntity = JournalEntity.journalEntry(
        meta: Metadata(
          id: entryId,
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 1),
          dateFrom: DateTime(2025, 1, 1),
          dateTo: DateTime(2025, 1, 1),
          vectorClock: const VectorClock({'host1': 1}),
        ),
        entryText: const EntryText(plainText: 'Test entry'),
      );

      when(() => journalDb.journalEntityById(entryId))
          .thenAnswer((_) async => journalEntity);

      // Create the JSON file so it can be read
      const jsonPath = '/test/path.json';
      File('${documentsDirectory.path}$jsonPath')
        ..createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(journalEntity.toJson()));

      const message = SyncMessage.journalEntity(
        id: entryId,
        jsonPath: jsonPath,
        vectorClock: VectorClock({'host1': 1}),
        status: SyncEntryStatus.initial,
      );

      await service.enqueueMessage(message);

      // Verify links were fetched
      verify(() => journalDb.linksForEntryIdsBidirectional(const {entryId}))
          .called(1);

      // Verify logging shows embedded links count
      verify(() => loggingService.captureEvent(
            contains(
              'enqueueMessage.attachedLinks id=$entryId count=2 from=1 to=1',
            ),
            domain: 'OUTBOX',
            subDomain: 'enqueueMessage.attachLinks',
          )).called(1);

      verify(() => loggingService.captureEvent(
            allOf([
              contains('type=SyncJournalEntity'),
              contains('embeddedLinks=2'),
            ]),
            domain: 'OUTBOX',
            subDomain: 'enqueueMessage',
          )).called(1);

      // Verify the message was encoded with embedded links
      final captured = verify(
              () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()))
          .captured;
      final companion = captured.first as OutboxCompanion;
      final encodedMessage =
          json.decode(companion.message.value) as Map<String, dynamic>;
      expect(encodedMessage['entryLinks'], hasLength(2));
      final entryLinks = encodedMessage['entryLinks'] as List<dynamic>;
      final entryLinkIds = entryLinks
          .map((entry) => (entry as Map<String, dynamic>)['id'])
          .toList();
      expect(entryLinkIds, containsAll([link1.id, link2.id]));
    });

    test('continues without links when linksForEntryIds fails', () async {
      const entryId = 'entry-456';

      // Mock journalDb.linksForEntryIdsBidirectional to throw an error
      when(() => journalDb.linksForEntryIdsBidirectional(const {entryId}))
          .thenThrow(Exception('Database error'));

      final journalEntity = JournalEntity.journalEntry(
        meta: Metadata(
          id: entryId,
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 1),
          dateFrom: DateTime(2025, 1, 1),
          dateTo: DateTime(2025, 1, 1),
          vectorClock: const VectorClock({'host1': 1}),
        ),
        entryText: const EntryText(plainText: 'Test entry'),
      );

      when(() => journalDb.journalEntityById(entryId))
          .thenAnswer((_) async => journalEntity);

      // Create the JSON file so it can be read
      const jsonPath = '/test/path2.json';
      File('${documentsDirectory.path}$jsonPath')
        ..createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(journalEntity.toJson()));

      const message = SyncMessage.journalEntity(
        id: entryId,
        jsonPath: jsonPath,
        vectorClock: VectorClock({'host1': 1}),
        status: SyncEntryStatus.initial,
      );

      // Should not throw
      await service.enqueueMessage(message);

      // Verify exception was logged
      verify(() => loggingService.captureException(
            any<Exception>(),
            domain: 'OUTBOX',
            subDomain: 'enqueueMessage.fetchLinks',
            stackTrace: any<StackTrace>(named: 'stackTrace'),
          )).called(1);

      // Verify message was still enqueued (without links)
      final captured = verify(
              () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()))
          .captured;
      final companion = captured.first as OutboxCompanion;
      final encodedMessage =
          json.decode(companion.message.value) as Map<String, dynamic>;
      expect(encodedMessage['entryLinks'], isNull);
    });

    test('does not log attachedLinks when no links found', () async {
      const entryId = 'entry-789';

      // Mock journalDb to return empty list
      when(() => journalDb.linksForEntryIdsBidirectional(const {entryId}))
          .thenAnswer((_) async => []);

      final journalEntity = JournalEntity.journalEntry(
        meta: Metadata(
          id: entryId,
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 1),
          dateFrom: DateTime(2025, 1, 1),
          dateTo: DateTime(2025, 1, 1),
          vectorClock: const VectorClock({'host1': 1}),
        ),
        entryText: const EntryText(plainText: 'Test entry'),
      );

      when(() => journalDb.journalEntityById(entryId))
          .thenAnswer((_) async => journalEntity);

      // Create the JSON file so it can be read
      const jsonPath = '/test/path3.json';
      File('${documentsDirectory.path}$jsonPath')
        ..createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(journalEntity.toJson()));

      const message = SyncMessage.journalEntity(
        id: entryId,
        jsonPath: jsonPath,
        vectorClock: VectorClock({'host1': 1}),
        status: SyncEntryStatus.initial,
      );

      await service.enqueueMessage(message);

      // Verify links were fetched
      verify(() => journalDb.linksForEntryIdsBidirectional(const {entryId}))
          .called(1);

      // Verify attachedLinks log was NOT called (no links to attach)
      verifyNever(() => loggingService.captureEvent(
            contains('enqueueMessage.attachedLinks'),
            domain: any(named: 'domain'),
            subDomain: any(named: 'subDomain'),
          ));

      // Verify no-links log was emitted
      verify(() => loggingService.captureEvent(
            contains('enqueueMessage.noLinks id=$entryId'),
            domain: 'OUTBOX',
            subDomain: 'enqueueMessage.attachLinks',
          )).called(1);

      // Verify embeddedLinks=0 in the log
      verify(() => loggingService.captureEvent(
            allOf([
              contains('type=SyncJournalEntity'),
              contains('embeddedLinks=0'),
            ]),
            domain: 'OUTBOX',
            subDomain: 'enqueueMessage',
          )).called(1);
    });
  });

  group('EntryLink sequence log recording -', () {
    late MockSyncSequenceLogService sequenceLogService;
    late OutboxService serviceWithSequenceLog;

    setUp(() {
      sequenceLogService = MockSyncSequenceLogService();
      registerFallbackValue(const VectorClock({'fallback': 1}));
    });

    tearDown(() async {
      await serviceWithSequenceLog.dispose();
    });

    test('records entry link in sequence log when vectorClock present',
        () async {
      const vc = VectorClock({'host-A': 10});
      final link = SyncMessage.entryLink(
        entryLink: EntryLink.basic(
          id: 'link-seq-1',
          fromId: 'A',
          toId: 'B',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
          vectorClock: vc,
        ),
        status: SyncEntryStatus.initial,
      );

      when(() => sequenceLogService.recordSentEntryLink(
            linkId: any(named: 'linkId'),
            vectorClock: any(named: 'vectorClock'),
          )).thenAnswer((_) async {});

      serviceWithSequenceLog = OutboxService(
        syncDatabase: syncDatabase,
        loggingService: loggingService,
        vectorClockService: vectorClockService,
        journalDb: journalDb,
        documentsDirectory: documentsDirectory,
        userActivityService: userActivityService,
        repository: repository,
        messageSender: messageSender,
        processor: processor,
        activityGate: createGate(),
        sequenceLogService: sequenceLogService,
      );

      await serviceWithSequenceLog.enqueueMessage(link);

      verify(() => sequenceLogService.recordSentEntryLink(
            linkId: 'link-seq-1',
            vectorClock: vc,
          )).called(1);
    });

    test('skips sequence log recording when vectorClock is null', () async {
      final link = SyncMessage.entryLink(
        entryLink: EntryLink.basic(
          id: 'link-no-vc',
          fromId: 'X',
          toId: 'Y',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
          vectorClock: null,
        ),
        status: SyncEntryStatus.initial,
      );

      serviceWithSequenceLog = OutboxService(
        syncDatabase: syncDatabase,
        loggingService: loggingService,
        vectorClockService: vectorClockService,
        journalDb: journalDb,
        documentsDirectory: documentsDirectory,
        userActivityService: userActivityService,
        repository: repository,
        messageSender: messageSender,
        processor: processor,
        activityGate: createGate(),
        sequenceLogService: sequenceLogService,
      );

      await serviceWithSequenceLog.enqueueMessage(link);

      // Should NOT call recordSentEntryLink
      verifyNever(() => sequenceLogService.recordSentEntryLink(
            linkId: any(named: 'linkId'),
            vectorClock: any(named: 'vectorClock'),
          ));
    });

    test('handles recordSentEntryLink errors gracefully', () async {
      const vc = VectorClock({'host-B': 5});
      final link = SyncMessage.entryLink(
        entryLink: EntryLink.basic(
          id: 'link-error',
          fromId: 'P',
          toId: 'Q',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
          vectorClock: vc,
        ),
        status: SyncEntryStatus.initial,
      );

      when(() => sequenceLogService.recordSentEntryLink(
            linkId: any(named: 'linkId'),
            vectorClock: any(named: 'vectorClock'),
          )).thenThrow(Exception('sequence log error'));

      serviceWithSequenceLog = OutboxService(
        syncDatabase: syncDatabase,
        loggingService: loggingService,
        vectorClockService: vectorClockService,
        journalDb: journalDb,
        documentsDirectory: documentsDirectory,
        userActivityService: userActivityService,
        repository: repository,
        messageSender: messageSender,
        processor: processor,
        activityGate: createGate(),
        sequenceLogService: sequenceLogService,
      );

      // Should not throw
      await serviceWithSequenceLog.enqueueMessage(link);

      // Verify exception was logged
      verify(() => loggingService.captureException(
            any<Object>(),
            domain: 'SYNC_SEQUENCE',
            subDomain: 'recordSent',
            stackTrace: any<StackTrace>(named: 'stackTrace'),
          )).called(1);
    });

    test('skips recording when sequenceLogService is null', () async {
      const vc = VectorClock({'host-C': 7});
      final link = SyncMessage.entryLink(
        entryLink: EntryLink.basic(
          id: 'link-no-service',
          fromId: 'M',
          toId: 'N',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
          vectorClock: vc,
        ),
        status: SyncEntryStatus.initial,
      );

      // Service without sequenceLogService
      serviceWithSequenceLog = OutboxService(
        syncDatabase: syncDatabase,
        loggingService: loggingService,
        vectorClockService: vectorClockService,
        journalDb: journalDb,
        documentsDirectory: documentsDirectory,
        userActivityService: userActivityService,
        repository: repository,
        messageSender: messageSender,
        processor: processor,
        activityGate: createGate(),
        // No sequenceLogService
      );

      // Should not throw and not attempt to record
      await serviceWithSequenceLog.enqueueMessage(link);

      // sequenceLogService is null so this is effectively a no-op test
      // Verify the message was still enqueued (logging event)
      verify(() => loggingService.captureEvent(
            contains('type=SyncEntryLink'),
            domain: 'OUTBOX',
            subDomain: 'enqueueMessage',
          )).called(1);
    });
  });

  group('Simple message handler edge cases', () {
    test('SyncEntityDefinition with null vectorClock uses null in subject',
        () async {
      final entityDef = HabitDefinition(
        id: 'habit-no-vc',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
        vectorClock: null, // Null vector clock
        name: 'Test Habit',
        description: 'A habit without vector clock',
        private: false,
        active: true,
        habitSchedule: const HabitSchedule.daily(requiredCompletions: 1),
      );

      final message = SyncMessage.entityDefinition(
        entityDefinition: entityDef,
        status: SyncEntryStatus.initial,
      );

      await service.enqueueMessage(message);

      final captured = verify(
        () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()),
      ).captured;
      expect(captured.length, 1);

      final companion = captured.first as OutboxCompanion;
      // Subject should contain null for the counter part (hhash is the mock value)
      expect(companion.subject.value, 'hhash:null');
    });

    test('SyncTagEntity with null hostHash handles gracefully', () async {
      // Create a vectorClockService that returns null hostHash
      final nullHashVcs = MockVectorClockService();
      when(() => nullHashVcs.getHost()).thenAnswer((_) async => 'testHost');
      when(() => nullHashVcs.getHostHash()).thenAnswer((_) async => null);

      final serviceWithNullHash = OutboxService(
        syncDatabase: syncDatabase,
        loggingService: loggingService,
        vectorClockService: nullHashVcs,
        journalDb: journalDb,
        documentsDirectory: documentsDirectory,
        userActivityService: userActivityService,
        repository: repository,
        messageSender: messageSender,
        processor: processor,
        activityGate: createGate(),
      );

      final tag = TagEntity.storyTag(
        id: 'tag-1',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
        tag: 'TestTag',
        private: false,
        vectorClock: const VectorClock({'host': 1}),
      );

      final message = SyncMessage.tagEntity(
        tagEntity: tag,
        status: SyncEntryStatus.initial,
      );

      await serviceWithNullHash.enqueueMessage(message);

      final captured = verify(
        () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()),
      ).captured;
      expect(captured.length, 1);

      final companion = captured.first as OutboxCompanion;
      expect(companion.subject.value, 'null:tag');
    });

    test('SyncBackfillRequest with empty entries list', () async {
      const message = SyncMessage.backfillRequest(
        requesterId: 'requester-device',
        entries: [], // Empty list
      );

      await service.enqueueMessage(message);

      final captured = verify(
        () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()),
      ).captured;
      expect(captured.length, 1);

      final companion = captured.first as OutboxCompanion;
      expect(companion.subject.value, 'backfillRequest:batch:0');

      verify(() => loggingService.captureEvent(
            contains('entries=0'),
            domain: 'OUTBOX',
            subDomain: 'enqueueMessage',
          )).called(1);
    });

    test('SyncBackfillRequest with multiple entries', () async {
      const message = SyncMessage.backfillRequest(
        requesterId: 'requester-device',
        entries: [
          BackfillRequestEntry(hostId: 'host1', counter: 1),
          BackfillRequestEntry(hostId: 'host1', counter: 2),
          BackfillRequestEntry(hostId: 'host2', counter: 1),
        ],
      );

      await service.enqueueMessage(message);

      final captured = verify(
        () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()),
      ).captured;
      expect(captured.length, 1);

      final companion = captured.first as OutboxCompanion;
      expect(companion.subject.value, 'backfillRequest:batch:3');
    });

    test('SyncBackfillResponse with deleted=true', () async {
      const message = SyncMessage.backfillResponse(
        hostId: 'host-abc',
        counter: 42,
        deleted: true,
      );

      await service.enqueueMessage(message);

      verify(() => loggingService.captureEvent(
            allOf([
              contains('type=SyncBackfillResponse'),
              contains('hostId=host-abc'),
              contains('counter=42'),
              contains('deleted=true'),
            ]),
            domain: 'OUTBOX',
            subDomain: 'enqueueMessage',
          )).called(1);
    });

    test('SyncBackfillResponse with deleted=false and entryId', () async {
      const message = SyncMessage.backfillResponse(
        hostId: 'host-abc',
        counter: 42,
        deleted: false,
        entryId: 'entry-123',
      );

      await service.enqueueMessage(message);

      final captured = verify(
        () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()),
      ).captured;
      expect(captured.length, 1);

      final companion = captured.first as OutboxCompanion;
      expect(companion.subject.value, 'backfillResponse:host-abc:42');

      verify(() => loggingService.captureEvent(
            contains('deleted=false'),
            domain: 'OUTBOX',
            subDomain: 'enqueueMessage',
          )).called(1);
    });

    test('SyncAiConfig logs config id correctly', () async {
      final config = AiConfig.inferenceProvider(
        id: 'config-xyz-789',
        name: 'Test Config',
        apiKey: 'sk-test',
        baseUrl: 'https://api.openai.com/v1',
        createdAt: DateTime(2025, 1, 1),
        inferenceProviderType: InferenceProviderType.genericOpenAi,
      );

      final message = SyncMessage.aiConfig(
        aiConfig: config,
        status: SyncEntryStatus.initial,
      );

      await service.enqueueMessage(message);

      verify(() => loggingService.captureEvent(
            allOf([
              contains('type=SyncAiConfig'),
              contains('id=config-xyz-789'),
            ]),
            domain: 'OUTBOX',
            subDomain: 'enqueueMessage',
          )).called(1);
    });

    test('SyncAiConfigDelete logs deleted config id', () async {
      const message = SyncMessage.aiConfigDelete(
        id: 'config-to-delete-456',
      );

      await service.enqueueMessage(message);

      verify(() => loggingService.captureEvent(
            allOf([
              contains('type=SyncAiConfigDelete'),
              contains('id=config-to-delete-456'),
            ]),
            domain: 'OUTBOX',
            subDomain: 'enqueueMessage',
          )).called(1);
    });

    test('enqueueMessage handles addOutboxItem error gracefully', () async {
      when(() => syncDatabase.addOutboxItem(any<OutboxCompanion>()))
          .thenThrow(Exception('DB write failed'));

      final message = SyncMessage.themingSelection(
        lightThemeName: 'Light',
        darkThemeName: 'Dark',
        themeMode: 'system',
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        status: SyncEntryStatus.update,
      );

      // Should not throw - error is caught and logged
      await service.enqueueMessage(message);

      verify(() => loggingService.captureException(
            any<Object>(),
            domain: 'OUTBOX',
            subDomain: 'enqueueMessage',
            stackTrace: any<StackTrace>(named: 'stackTrace'),
          )).called(1);
    });

    test('SyncEntityDefinition with null host uses null in counter lookup',
        () async {
      // Create a vectorClockService that returns null host
      final nullHostVcs = MockVectorClockService();
      when(() => nullHostVcs.getHost()).thenAnswer((_) async => null);
      when(() => nullHostVcs.getHostHash()).thenAnswer((_) async => 'hash123');

      final serviceWithNullHost = OutboxService(
        syncDatabase: syncDatabase,
        loggingService: loggingService,
        vectorClockService: nullHostVcs,
        journalDb: journalDb,
        documentsDirectory: documentsDirectory,
        userActivityService: userActivityService,
        repository: repository,
        messageSender: messageSender,
        processor: processor,
        activityGate: createGate(),
      );

      final entityDef = HabitDefinition(
        id: 'habit-1',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
        vectorClock: const VectorClock({'someHost': 5}),
        name: 'Test Habit',
        description: 'A habit with VC but null host lookup',
        private: false,
        active: true,
        habitSchedule: const HabitSchedule.daily(requiredCompletions: 1),
      );

      final message = SyncMessage.entityDefinition(
        entityDefinition: entityDef,
        status: SyncEntryStatus.initial,
      );

      await serviceWithNullHost.enqueueMessage(message);

      final captured = verify(
        () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()),
      ).captured;
      expect(captured.length, 1);

      final companion = captured.first as OutboxCompanion;
      // With null host, the vclock lookup returns null
      expect(companion.subject.value, 'hash123:null');
    });
  });

  group('Message preparation', () {
    test('prepareJournalEntity adds originatingHostId when null', () async {
      const entryId = 'entry-with-no-host';
      final journalEntity = JournalEntity.journalEntry(
        meta: Metadata(
          id: entryId,
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 1),
          dateFrom: DateTime(2025, 1, 1),
          dateTo: DateTime(2025, 1, 1),
          vectorClock: const VectorClock({'hostA': 1}),
        ),
        entryText: const EntryText(plainText: 'Test entry'),
      );

      // Create JSON file on disk (required by readEntityFromJson)
      final jsonPath = relativeEntityPath(journalEntity);
      File('${documentsDirectory.path}$jsonPath')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(journalEntity.toJson()));

      // Mock journalEntityById to return the entity
      when(() => journalDb.journalEntityById(entryId))
          .thenAnswer((_) async => journalEntity);

      final message = SyncMessage.journalEntity(
        id: entryId,
        jsonPath: jsonPath,
        vectorClock: const VectorClock({'hostA': 1}),
        status: SyncEntryStatus.initial,
        // originatingHostId is null
      );

      await service.enqueueMessage(message);

      // Verify the message was enqueued with originatingHostId set
      final captured = verify(
        () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()),
      ).captured;
      expect(captured.length, 1);

      final companion = captured.first as OutboxCompanion;
      final decodedMessage = SyncMessage.fromJson(
        json.decode(companion.message.value) as Map<String, dynamic>,
      );

      expect(decodedMessage, isA<SyncJournalEntity>());
      final journalMsg = decodedMessage as SyncJournalEntity;
      // hostA is the mock value returned by vectorClockService.getHost()
      expect(journalMsg.originatingHostId, 'hostA');
    });

    test('prepareJournalEntity preserves existing originatingHostId', () async {
      const entryId = 'entry-with-existing-host';
      final journalEntity = JournalEntity.journalEntry(
        meta: Metadata(
          id: entryId,
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 1),
          dateFrom: DateTime(2025, 1, 1),
          dateTo: DateTime(2025, 1, 1),
          vectorClock: const VectorClock({'hostA': 1}),
        ),
        entryText: const EntryText(plainText: 'Test entry'),
      );

      // Create JSON file on disk
      final jsonPath = relativeEntityPath(journalEntity);
      File('${documentsDirectory.path}$jsonPath')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(journalEntity.toJson()));

      when(() => journalDb.journalEntityById(entryId))
          .thenAnswer((_) async => journalEntity);

      final message = SyncMessage.journalEntity(
        id: entryId,
        jsonPath: jsonPath,
        vectorClock: const VectorClock({'hostA': 1}),
        status: SyncEntryStatus.initial,
        originatingHostId: 'originalHost', // Already set
      );

      await service.enqueueMessage(message);

      final captured = verify(
        () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()),
      ).captured;

      final companion = captured.first as OutboxCompanion;
      final decodedMessage = SyncMessage.fromJson(
        json.decode(companion.message.value) as Map<String, dynamic>,
      );

      final journalMsg = decodedMessage as SyncJournalEntity;
      // Should preserve the original value, not overwrite
      expect(journalMsg.originatingHostId, 'originalHost');
    });

    test('prepareJournalEntity merges coveredVectorClocks', () async {
      const entryId = 'entry-for-vc-merge';
      final journalEntity = JournalEntity.journalEntry(
        meta: Metadata(
          id: entryId,
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 1),
          dateFrom: DateTime(2025, 1, 1),
          dateTo: DateTime(2025, 1, 1),
          vectorClock: const VectorClock({'hostA': 3}),
        ),
        entryText: const EntryText(plainText: 'Test entry'),
      );

      // Create JSON file on disk
      final jsonPath = relativeEntityPath(journalEntity);
      File('${documentsDirectory.path}$jsonPath')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(journalEntity.toJson()));

      when(() => journalDb.journalEntityById(entryId))
          .thenAnswer((_) async => journalEntity);

      final message = SyncMessage.journalEntity(
        id: entryId,
        jsonPath: jsonPath,
        vectorClock: const VectorClock({'hostA': 3}),
        status: SyncEntryStatus.update,
        coveredVectorClocks: const [
          VectorClock({'hostA': 1}),
          VectorClock({'hostA': 2}),
        ],
      );

      await service.enqueueMessage(message);

      final captured = verify(
        () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()),
      ).captured;

      final companion = captured.first as OutboxCompanion;
      final decodedMessage = SyncMessage.fromJson(
        json.decode(companion.message.value) as Map<String, dynamic>,
      );

      final journalMsg = decodedMessage as SyncJournalEntity;
      // Should have all 3 VCs merged (1, 2, and the current 3)
      expect(journalMsg.coveredVectorClocks, isNotNull);
      expect(journalMsg.coveredVectorClocks!.length, 3);
    });

    test('prepareEntryLink adds originatingHostId when null', () async {
      final link = EntryLink.basic(
        id: 'link-no-host',
        fromId: 'entry-A',
        toId: 'entry-B',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
        vectorClock: const VectorClock({'hostA': 1}),
      );

      final message = SyncMessage.entryLink(
        entryLink: link,
        status: SyncEntryStatus.initial,
        // originatingHostId is null
      );

      await service.enqueueMessage(message);

      final captured = verify(
        () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()),
      ).captured;

      final companion = captured.first as OutboxCompanion;
      final decodedMessage = SyncMessage.fromJson(
        json.decode(companion.message.value) as Map<String, dynamic>,
      );

      final linkMsg = decodedMessage as SyncEntryLink;
      expect(linkMsg.originatingHostId, 'hostA');
    });

    test('prepareEntryLink merges coveredVectorClocks', () async {
      final link = EntryLink.basic(
        id: 'link-for-vc-merge',
        fromId: 'entry-A',
        toId: 'entry-B',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
        vectorClock: const VectorClock({'hostA': 3}),
      );

      final message = SyncMessage.entryLink(
        entryLink: link,
        status: SyncEntryStatus.update,
        coveredVectorClocks: const [
          VectorClock({'hostA': 1}),
          VectorClock({'hostA': 2}),
        ],
      );

      await service.enqueueMessage(message);

      final captured = verify(
        () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()),
      ).captured;

      final companion = captured.first as OutboxCompanion;
      final decodedMessage = SyncMessage.fromJson(
        json.decode(companion.message.value) as Map<String, dynamic>,
      );

      final linkMsg = decodedMessage as SyncEntryLink;
      expect(linkMsg.coveredVectorClocks, isNotNull);
      expect(linkMsg.coveredVectorClocks!.length, 3);
    });

    test('prepareMessage passes through non-entity messages unchanged',
        () async {
      final message = SyncMessage.themingSelection(
        lightThemeName: 'Light',
        darkThemeName: 'Dark',
        themeMode: 'system',
        updatedAt: DateTime(2025, 1, 1).millisecondsSinceEpoch,
        status: SyncEntryStatus.update,
      );

      await service.enqueueMessage(message);

      final captured = verify(
        () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()),
      ).captured;

      final companion = captured.first as OutboxCompanion;
      final decodedMessage = SyncMessage.fromJson(
        json.decode(companion.message.value) as Map<String, dynamic>,
      );

      // Should be unchanged (no originatingHostId or coveredVectorClocks added)
      expect(decodedMessage, isA<SyncThemingSelection>());
      final themingMsg = decodedMessage as SyncThemingSelection;
      expect(themingMsg.lightThemeName, 'Light');
      expect(themingMsg.darkThemeName, 'Dark');
    });
  });
}
