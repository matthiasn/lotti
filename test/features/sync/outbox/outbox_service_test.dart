// ignore_for_file: avoid_redundant_argument_values, unnecessary_lambdas, cascade_invocations

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/model/sync_node_profile.dart';
import 'package:lotti/features/sync/outbox/outbox_processor.dart';
import 'package:lotti/features/sync/outbox/outbox_repository.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/features/user_activity/state/user_activity_gate.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/cached_stream_controller.dart' as matrix_utils;
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

class MockUserActivityGate extends Mock implements UserActivityGate {}

class MockOutboxRepository extends Mock implements OutboxRepository {}

class MockOutboxMessageSender extends Mock implements OutboxMessageSender {}

class MockOutboxProcessor extends Mock implements OutboxProcessor {}

class MockMatrixClient extends Mock implements Client {}

class MockCachedLoginController extends Mock
    implements matrix_utils.CachedStreamController<LoginState> {}

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
    super.postDrainSettle = Duration.zero,
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
  when(
    () => gate.canProcessStream,
  ).thenAnswer((_) => canProcessStream ?? Stream<bool>.value(canProcess));
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

enum _GeneratedPriorityMessageKind {
  journalEntity,
  entityDefinition,
  entryLink,
  aiConfig,
  aiConfigDelete,
  themingSelection,
  backfillRequest,
  backfillResponse,
  agentEntity,
  agentLink,
  agentBundle,
  notification,
  notificationStateUpdate,
  outboxBundle,
  syncNodeProfile,
}

class _GeneratedPriorityScenario {
  const _GeneratedPriorityScenario({
    required this.kind,
    required this.statusIsUpdate,
    required this.counterSlot,
    required this.deleted,
  });

  final _GeneratedPriorityMessageKind kind;
  final bool statusIsUpdate;
  final int counterSlot;
  final bool deleted;

  SyncEntryStatus get status =>
      statusIsUpdate ? SyncEntryStatus.update : SyncEntryStatus.initial;

  SyncMessage get message {
    final id = 'generated-$counterSlot';
    return switch (kind) {
      _GeneratedPriorityMessageKind.journalEntity => SyncMessage.journalEntity(
        id: id,
        jsonPath: '/entries/$id.json',
        vectorClock: VectorClock({'hostA': counterSlot}),
        status: status,
      ),
      _GeneratedPriorityMessageKind.entityDefinition =>
        SyncMessage.entityDefinition(
          entityDefinition: EntityDefinition.measurableDataType(
            id: id,
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
            displayName: 'Generated',
            description: 'Generated definition',
            unitName: 'count',
            version: 1,
            vectorClock: VectorClock({'hostA': counterSlot}),
          ),
          status: status,
        ),
      _GeneratedPriorityMessageKind.entryLink => SyncMessage.entryLink(
        entryLink: EntryLink.basic(
          id: id,
          fromId: 'from-$counterSlot',
          toId: 'to-$counterSlot',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          vectorClock: VectorClock({'hostA': counterSlot}),
        ),
        status: status,
      ),
      _GeneratedPriorityMessageKind.aiConfig => SyncMessage.aiConfig(
        aiConfig: AiConfig.inferenceProvider(
          id: id,
          name: 'Generated provider',
          apiKey: 'key-$counterSlot',
          baseUrl: 'https://example.invalid/v1',
          createdAt: DateTime(2024),
          inferenceProviderType: InferenceProviderType.genericOpenAi,
        ),
        status: status,
      ),
      _GeneratedPriorityMessageKind.aiConfigDelete =>
        SyncMessage.aiConfigDelete(id: id),
      _GeneratedPriorityMessageKind.themingSelection =>
        SyncMessage.themingSelection(
          lightThemeName: 'light-$counterSlot',
          darkThemeName: 'dark-$counterSlot',
          themeMode: statusIsUpdate ? 'dark' : 'light',
          updatedAt: counterSlot,
          status: status,
        ),
      _GeneratedPriorityMessageKind.backfillRequest =>
        SyncMessage.backfillRequest(
          entries: [
            for (var index = 0; index < counterSlot; index++)
              BackfillRequestEntry(hostId: 'host-$index', counter: index),
          ],
          requesterId: 'requester-$counterSlot',
        ),
      _GeneratedPriorityMessageKind.backfillResponse =>
        SyncMessage.backfillResponse(
          hostId: 'host-$counterSlot',
          counter: counterSlot,
          deleted: deleted,
          entryId: deleted ? null : id,
        ),
      _GeneratedPriorityMessageKind.agentEntity => SyncMessage.agentEntity(
        status: status,
        jsonPath: '/agents/entities/$id.json',
      ),
      _GeneratedPriorityMessageKind.agentLink => SyncMessage.agentLink(
        status: status,
        jsonPath: '/agents/links/$id.json',
      ),
      _GeneratedPriorityMessageKind.agentBundle => SyncMessage.agentBundle(
        agentId: 'agent-$counterSlot',
        wakeRunKey: 'wake-$counterSlot',
      ),
      _GeneratedPriorityMessageKind.notification => SyncMessage.notification(
        id: id,
        jsonPath: '/notifications/$id.json',
        vectorClock: VectorClock({'hostA': counterSlot}),
        originatingHostId: 'hostA',
      ),
      _GeneratedPriorityMessageKind.notificationStateUpdate =>
        SyncMessage.notificationStateUpdate(
          id: id,
          seenAt: deleted ? DateTime(2024) : null,
          vectorClock: VectorClock({'hostA': counterSlot}),
          originatingHostId: 'hostA',
        ),
      _GeneratedPriorityMessageKind.outboxBundle => SyncMessage.outboxBundle(
        children: [SyncMessage.aiConfigDelete(id: id)],
      ),
      _GeneratedPriorityMessageKind.syncNodeProfile =>
        SyncMessage.syncNodeProfile(
          profile: SyncNodeProfile(
            hostId: 'host-$counterSlot',
            displayName: 'Device $counterSlot',
            platform: 'macos',
            capabilities: const [NodeCapability.mlxAudio],
            updatedAt: DateTime.utc(2026, 3, 15, 12, counterSlot),
          ),
        ),
    };
  }

  int get expectedPriority {
    return switch (kind) {
      _GeneratedPriorityMessageKind.journalEntity ||
      _GeneratedPriorityMessageKind.entryLink => OutboxPriority.high.index,
      _GeneratedPriorityMessageKind.backfillRequest ||
      _GeneratedPriorityMessageKind.backfillResponse ||
      _GeneratedPriorityMessageKind.agentEntity ||
      _GeneratedPriorityMessageKind.agentLink ||
      _GeneratedPriorityMessageKind.agentBundle ||
      _GeneratedPriorityMessageKind.notification ||
      _GeneratedPriorityMessageKind.notificationStateUpdate ||
      _GeneratedPriorityMessageKind.themingSelection ||
      _GeneratedPriorityMessageKind.outboxBundle => OutboxPriority.normal.index,
      _GeneratedPriorityMessageKind.entityDefinition ||
      _GeneratedPriorityMessageKind.aiConfig ||
      _GeneratedPriorityMessageKind.aiConfigDelete ||
      _GeneratedPriorityMessageKind.syncNodeProfile => OutboxPriority.low.index,
    };
  }

  @override
  String toString() {
    return '_GeneratedPriorityScenario('
        'kind: $kind, '
        'statusIsUpdate: $statusIsUpdate, '
        'counterSlot: $counterSlot, '
        'deleted: $deleted'
        ')';
  }
}

extension _AnyGeneratedPriorityScenario on glados.Any {
  glados.Generator<_GeneratedPriorityMessageKind> get priorityMessageKind =>
      glados.AnyUtils(this).choose(_GeneratedPriorityMessageKind.values);

  glados.Generator<_GeneratedPriorityScenario> get priorityScenario =>
      glados.CombinableAny(this).combine4(
        priorityMessageKind,
        glados.BoolAny(this).bool,
        glados.IntAnys(this).intInRange(0, 5),
        glados.BoolAny(this).bool,
        (
          _GeneratedPriorityMessageKind kind,
          bool statusIsUpdate,
          int counterSlot,
          bool deleted,
        ) => _GeneratedPriorityScenario(
          kind: kind,
          statusIsUpdate: statusIsUpdate,
          counterSlot: counterSlot,
          deleted: deleted,
        ),
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const connectivityMethodChannel = MethodChannel(
    'dev.fluttercommunity.plus/connectivity',
  );

  setUpAll(() {
    registerFallbackValue(const SyncMessage.aiConfigDelete(id: 'fallback'));
    registerFallbackValue(Exception('fallback'));
    // Mocktail fallback for any<OutboxCompanion>() matchers
    registerFallbackValue(OutboxCompanion.insert(message: 'm', subject: 's'));
    registerFallbackValue(StackTrace.empty);
    registerFallbackValue(const VectorClock({'fallback': 1}));
    registerFallbackValue(Duration.zero);
    registerFallbackValue(SyncSequencePayloadType.journalEntity);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(connectivityMethodChannel, (
          MethodCall call,
        ) async {
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
  late MockDomainLogger loggingService;
  late MockOutboxRepository repository;
  late MockOutboxMessageSender messageSender;
  late MockOutboxProcessor processor;
  late MockJournalDb journalDb;
  late MockVectorClockService vectorClockService;
  late MockUserActivityService userActivityService;
  late Directory documentsDirectory;
  late TestableOutboxService service;
  late bool hadDirectoryRegistered;
  Directory? previousDirectory;

  setUp(() {
    syncDatabase = MockSyncDatabase();
    loggingService = MockDomainLogger();
    repository = MockOutboxRepository();
    messageSender = MockOutboxMessageSender();
    processor = MockOutboxProcessor();
    journalDb = MockJournalDb();
    vectorClockService = MockVectorClockService();
    userActivityService = MockUserActivityService();
    documentsDirectory = Directory.systemTemp.createTempSync(
      'outbox_service_test_',
    );
    hadDirectoryRegistered = getIt.isRegistered<Directory>();
    if (hadDirectoryRegistered) {
      previousDirectory = getIt<Directory>();
      getIt.unregister<Directory>();
    } else {
      previousDirectory = null;
    }
    getIt.allowReassignment = true;
    getIt.registerSingleton<Directory>(documentsDirectory);

    when(
      () => processor.processQueue(),
    ).thenAnswer((_) async => OutboxProcessingResult.none);
    when(
      () => vectorClockService.getHostHash(),
    ).thenAnswer((_) async => 'hhash');
    when(() => vectorClockService.getHost()).thenAnswer((_) async => 'hostA');
    when(
      () => syncDatabase.addOutboxItem(any<OutboxCompanion>()),
    ).thenAnswer((_) async => 1);
    // Avoid null stream issues from db-driven nudge subscription in service ctor
    when(
      () => syncDatabase.watchOutboxCount(),
    ).thenAnswer((_) => const Stream<int>.empty());
    // Default stub for findPendingByEntryId - no existing pending item
    when(
      () => syncDatabase.findPendingByEntryId(any()),
    ).thenAnswer((_) async => null);
    // Default stub so the periodic prune sweep fires without NSM errors
    // if a test happens to elapse past the 30s startup grace. Both the
    // unbounded and chunked variants are stubbed because tests that
    // existed before the chunked switch still call the unbounded
    // method directly via repository helpers.
    when(
      () => repository.pruneSentOutboxItems(
        retention: any(named: 'retention'),
      ),
    ).thenAnswer((_) async => 0);
    when(
      () => repository.pruneSentOutboxItemsChunked(
        retention: any(named: 'retention'),
        chunkSize: any(named: 'chunkSize'),
        vacuumWhenDone: any(named: 'vacuumWhenDone'),
        onProgress: any(named: 'onProgress'),
      ),
    ).thenAnswer((_) async => 0);
    when(
      () => journalDb.linksForEntryIdsBidirectional(any()),
    ).thenAnswer((_) async => <EntryLink>[]);
    // Ensure activity gate can construct if needed
    when(
      () => userActivityService.lastActivity,
    ).thenReturn(DateTime(2024, 3, 15, 10, 30));
    when(
      () => userActivityService.activityStream,
    ).thenAnswer((_) => const Stream<DateTime>.empty());

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

    verify(
      () => loggingService.log(
        LogDomain.sync,
        any<String>(that: contains('type=SyncEntityDefinition')),
        subDomain: 'enqueueMessage',
      ),
    ).called(1);
  });

  test('enqueueMessage logs SyncEntryLink with from/to', () async {
    final link = SyncMessage.entryLink(
      entryLink: EntryLink.basic(
        id: 'l1',
        fromId: 'A',
        toId: 'B',
        createdAt: DateTime(2024, 3, 15, 10, 30),
        updatedAt: DateTime(2024, 3, 15, 10, 30),
        vectorClock: null,
      ),
      status: SyncEntryStatus.initial,
    );

    await service.enqueueMessage(link);

    verify(
      () => loggingService.log(
        LogDomain.sync,
        any<String>(
          that: allOf([
            contains('type=SyncEntryLink'),
            contains('from=A'),
            contains('to=B'),
          ]),
        ),
        subDomain: 'enqueueMessage',
      ),
    ).called(1);
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
        title: 'Todos',
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

    when(
      () => journalDb.journalEntityById(id),
    ).thenAnswer((_) async => freshChecklist);

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

  test(
    'enqueueMessage logs missing entity when DB lookup returns null',
    () async {
      const id = 'missing-entity';
      final testDate = DateTime(2024, 3, 15, 10, 30);
      final entity = JournalEntity.journalEntry(
        meta: Metadata(
          id: id,
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate,
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
        () => loggingService.log(
          LogDomain.sync,
          any<String>(that: contains('enqueueMessage.missingEntity id=$id')),
          subDomain: 'enqueueMessage',
        ),
      ).called(1);
      verify(() => syncDatabase.addOutboxItem(any())).called(1);
    },
  );

  test('continues when saveJson throws during refresh', () async {
    const id = 'save-fails';
    final testDate = DateTime(2024, 3, 15, 10, 30);
    final entity = JournalEntity.journalEntry(
      meta: Metadata(
        id: id,
        createdAt: testDate,
        updatedAt: testDate,
        dateFrom: testDate,
        dateTo: testDate,
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
      saveJsonHandler: (_, _) => Future.error(Exception('disk full')),
    );

    final message = SyncMessage.journalEntity(
      id: id,
      jsonPath: jsonPath,
      vectorClock: entity.meta.vectorClock,
      status: SyncEntryStatus.initial,
    );

    await failingService.enqueueMessage(message);

    verify(
      () => loggingService.error(
        LogDomain.sync,
        any<Object>(),
        stackTrace: any<StackTrace?>(
          named: 'stackTrace',
        ),
        subDomain: 'enqueueMessage.refreshJson',
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

  test(
    'enqueueNotification saves JSON payload and queues notification',
    () async {
      final notification = _testNotification(
        id: 'notification-id',
        vectorClock: const VectorClock({'hostA': 3}),
      );

      await service.enqueueNotification(
        notification,
        originatingHostId: 'origin-host',
      );

      final captured = verify(
        () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()),
      ).captured;
      expect(captured, hasLength(1));

      final companion = captured.single as OutboxCompanion;
      expect(companion.subject.value, 'notification:notification-id');
      expect(companion.filePath.value, '/notifications/notification-id.json');
      expect(companion.outboxEntryId.value, 'notification-id');
      expect(companion.priority.value, OutboxPriority.normal.index);

      final queued = SyncMessage.fromJson(
        jsonDecode(companion.message.value) as Map<String, dynamic>,
      );
      expect(queued, isA<SyncNotification>());
      final syncNotification = queued as SyncNotification;
      expect(syncNotification.id, 'notification-id');
      expect(syncNotification.jsonPath, '/notifications/notification-id.json');
      expect(syncNotification.originatingHostId, 'origin-host');
      expect(
        syncNotification.coveredVectorClocks,
        [
          const VectorClock({'hostA': 3}),
        ],
      );

      final payloadFile = File(
        '${documentsDirectory.path}/notifications/notification-id.json',
      );
      expect(payloadFile.existsSync(), isTrue);
      final payload = NotificationEntity.fromJson(
        jsonDecode(payloadFile.readAsStringSync()) as Map<String, dynamic>,
      );
      expect(payload, notification);
    },
  );

  test(
    'enqueueMessage swallows sequence log throws on notification path',
    () async {
      final sequenceLog = MockSyncSequenceLogService();
      when(
        () => sequenceLog.recordSentEntry(
          entryId: any(named: 'entryId'),
          vectorClock: any(named: 'vectorClock'),
          payloadType: any(named: 'payloadType'),
        ),
      ).thenThrow(Exception('record sent boom'));

      final notification = _testNotification(
        id: 'throwing-record',
        vectorClock: const VectorClock({'hostA': 4}),
      );
      final relPath = relativeNotificationPath(notification.id);
      File('${documentsDirectory.path}$relPath')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(notification.toJson()));

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
        sequenceLogService: sequenceLog,
      );

      await svc.enqueueMessage(
        SyncMessage.notification(
          id: notification.id,
          jsonPath: relPath,
          vectorClock: notification.meta.vectorClock,
          originatingHostId: 'hostA',
        ),
      );

      verify(
        () => loggingService.error(
          LogDomain.sync,
          any<Object>(),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
          subDomain: 'recordSent',
        ),
      ).called(1);
    },
  );

  test(
    'enqueueMessage skips and logs when notification jsonPath escapes docs root',
    () async {
      await service.enqueueMessage(
        const SyncMessage.notification(
          id: 'escape',
          jsonPath: '/../escape.json',
          vectorClock: VectorClock({'hostA': 1}),
          originatingHostId: 'hostA',
        ),
      );

      verifyNever(
        () => syncDatabase.addOutboxItem(any<OutboxCompanion>()),
      );
      verify(
        () => loggingService.log(
          LogDomain.sync,
          any<String>(
            that: contains('enqueue.skip invalid notification payload path'),
          ),
          subDomain: 'enqueueMessage',
        ),
      ).called(1);
    },
  );

  test('enqueueNotificationStateUpdate queues inline state update', () async {
    final seenAt = DateTime.utc(2026, 5, 17, 11);

    await service.enqueueNotificationStateUpdate(
      id: 'notification-id',
      seenAt: seenAt,
      vectorClock: const VectorClock({'hostA': 4}),
      originatingHostId: 'hostA',
    );

    final captured = verify(
      () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()),
    ).captured;
    expect(captured, hasLength(1));

    final companion = captured.single as OutboxCompanion;
    expect(
      companion.subject.value,
      'notificationStateUpdate:notification-id',
    );
    expect(companion.filePath.value, isNull);
    expect(companion.priority.value, OutboxPriority.normal.index);

    final queued = SyncMessage.fromJson(
      jsonDecode(companion.message.value) as Map<String, dynamic>,
    );
    expect(queued, isA<SyncNotificationStateUpdate>());
    final stateUpdate = queued as SyncNotificationStateUpdate;
    expect(stateUpdate.id, 'notification-id');
    expect(stateUpdate.seenAt, seenAt);
    expect(stateUpdate.vectorClock, const VectorClock({'hostA': 4}));
    expect(stateUpdate.originatingHostId, 'hostA');
  });

  test('enqueueMessage logs SyncAiConfig', () async {
    final cfg = SyncMessage.aiConfig(
      aiConfig: AiConfig.inferenceProvider(
        id: 'cfg1',
        baseUrl: 'https://example.org',
        apiKey: 'k',
        name: 'p',
        createdAt: DateTime(2024, 3, 15, 10, 30),
        inferenceProviderType: InferenceProviderType.openAi,
      ),
      status: SyncEntryStatus.initial,
    );

    await service.enqueueMessage(cfg);

    verify(
      () => loggingService.log(
        LogDomain.sync,
        any<String>(that: contains('type=SyncAiConfig')),
        subDomain: 'enqueueMessage',
      ),
    ).called(1);
  });

  test('enqueueMessage logs SyncAiConfigDelete', () async {
    const del = SyncMessage.aiConfigDelete(id: 'cfg1');

    await service.enqueueMessage(del);

    verify(
      () => loggingService.log(
        LogDomain.sync,
        any<String>(that: contains('type=SyncAiConfigDelete')),
        subDomain: 'enqueueMessage',
      ),
    ).called(1);
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
        when(
          () => syncDatabase.addOutboxItem(any<OutboxCompanion>()),
        ).thenAnswer((invocation) async {
          capturedCompanions.add(
            invocation.positionalArguments.first as OutboxCompanion,
          );
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

        // Verify payloadSize includes file length (10 bytes) + JSON length
        expect(companion.payloadSize.value, isNotNull);
        expect(companion.payloadSize.value, greaterThan(10));
      },
    );

    test('payloadSize includes file bytes for journal image', () async {
      final capturedCompanions = <OutboxCompanion>[];
      when(() => syncDatabase.addOutboxItem(any<OutboxCompanion>())).thenAnswer(
        (invocation) async {
          capturedCompanions.add(
            invocation.positionalArguments.first as OutboxCompanion,
          );
          return 1;
        },
      );

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
        id: 'payload-test',
        createdAt: sampleDate,
        updatedAt: sampleDate,
        dateFrom: sampleDate,
        dateTo: sampleDate,
        vectorClock: const VectorClock({'hostA': 1}),
      );
      final imageData = ImageData(
        capturedAt: sampleDate,
        imageId: 'img-payload',
        imageFile: 'payload-image.jpg',
        imageDirectory: '/images/',
      );
      final journalEntity = JournalEntity.journalImage(
        meta: metadata,
        data: imageData,
        entryText: const EntryText(plainText: 'Payload test'),
      );

      const jsonPath = '/entries/payload-test.json';
      File('${documentsDirectory.path}$jsonPath')
        ..createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(journalEntity.toJson()));

      const fileSize = 5000;
      final imagePath =
          '${documentsDirectory.path}${imageData.imageDirectory}${imageData.imageFile}';
      File(imagePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(List<int>.filled(fileSize, 42));

      // Build the message to compute expected JSON length
      const syncMessage = SyncMessage.journalEntity(
        id: 'payload-test',
        jsonPath: jsonPath,
        vectorClock: VectorClock({'device': 1}),
        status: SyncEntryStatus.initial,
      );

      await testService.enqueueMessage(syncMessage);

      expect(capturedCompanions, hasLength(1));
      final companion = capturedCompanions.single;

      // payloadSize = JSON message length + file size (5000)
      final payloadSize = companion.payloadSize.value!;
      expect(payloadSize, greaterThanOrEqualTo(fileSize));
      // The JSON portion should be > 0, so total should exceed file size
      expect(payloadSize, greaterThan(fileSize));
    });

    test('payloadSize is JSON length for entry link (no file)', () async {
      final capturedCompanions = <OutboxCompanion>[];
      when(() => syncDatabase.addOutboxItem(any<OutboxCompanion>())).thenAnswer(
        (invocation) async {
          capturedCompanions.add(
            invocation.positionalArguments.first as OutboxCompanion,
          );
          return 1;
        },
      );

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
      final link = EntryLink.basic(
        id: 'link-payload',
        fromId: 'from-entry',
        toId: 'to-entry',
        createdAt: now,
        updatedAt: now,
        vectorClock: const VectorClock({'hostA': 3}),
      );

      await testService.enqueueMessage(
        SyncMessage.entryLink(
          entryLink: link,
          status: SyncEntryStatus.initial,
        ),
      );

      expect(capturedCompanions, hasLength(1));
      final companion = capturedCompanions.single;

      // payloadSize should equal the UTF-8 byte length of the JSON message
      final payloadSize = companion.payloadSize.value!;
      final messageByteLength = utf8.encode(companion.message.value).length;
      expect(payloadSize, messageByteLength);
    });

    test('payloadSize is JSON length for simple message types', () async {
      final capturedCompanions = <OutboxCompanion>[];
      when(() => syncDatabase.addOutboxItem(any<OutboxCompanion>())).thenAnswer(
        (invocation) async {
          capturedCompanions.add(
            invocation.positionalArguments.first as OutboxCompanion,
          );
          return 1;
        },
      );

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

      await testService.enqueueMessage(
        const SyncMessage.aiConfigDelete(id: 'cfg-1'),
      );

      expect(capturedCompanions, hasLength(1));
      final companion = capturedCompanions.single;
      final payloadSize = companion.payloadSize.value!;
      final messageByteLength = utf8.encode(companion.message.value).length;
      expect(payloadSize, messageByteLength);
    });

    test('enqueues entry link with coveredVectorClocks populated', () async {
      final capturedCompanions = <OutboxCompanion>[];
      when(() => syncDatabase.addOutboxItem(any<OutboxCompanion>())).thenAnswer(
        (invocation) async {
          capturedCompanions.add(
            invocation.positionalArguments.first as OutboxCompanion,
          );
          return 1;
        },
      );

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
          priority: OutboxPriority.low.index,
        );

        // Return existing item for this entry
        when(
          () => syncDatabase.findPendingByEntryId('entry-id'),
        ).thenAnswer((_) async => existingItem);

        // Capture the update call
        String? capturedMessage;
        String? capturedSubject;
        int? capturedPayloadSize;
        when(
          () => syncDatabase.updateOutboxMessage(
            itemId: any(named: 'itemId'),
            newMessage: any(named: 'newMessage'),
            newSubject: any(named: 'newSubject'),
            payloadSize: any(named: 'payloadSize'),
            priority: any(named: 'priority'),
          ),
        ).thenAnswer((invocation) async {
          capturedMessage = invocation.namedArguments[#newMessage] as String?;
          capturedSubject = invocation.namedArguments[#newSubject] as String?;
          capturedPayloadSize = invocation.namedArguments[#payloadSize] as int?;
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
            payloadSize: any(named: 'payloadSize'),
            priority: any(named: 'priority'),
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

        // Verify merged payloadSize = utf8 byte length of merged JSON
        // (no file attachment for text-only journal entry)
        expect(capturedPayloadSize, isNotNull);
        expect(
          capturedPayloadSize,
          utf8.encode(capturedMessage!).length,
        );
      },
    );

    test(
      'accumulates multiple covered clocks across successive merges',
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
          priority: OutboxPriority.low.index,
        );

        when(
          () => syncDatabase.findPendingByEntryId('entry-id'),
        ).thenAnswer((_) async => existingItem);

        String? capturedMessage;
        when(
          () => syncDatabase.updateOutboxMessage(
            itemId: any(named: 'itemId'),
            newMessage: any(named: 'newMessage'),
            newSubject: any(named: 'newSubject'),
            payloadSize: any(named: 'payloadSize'),
            priority: any(named: 'priority'),
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
      },
    );

    test(
      'captures intermediate VC when DB has newer version than enqueue call',
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
        const intermediateVc = VectorClock({
          'hostA': 6,
        }); // VC from enqueue call
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
          priority: OutboxPriority.low.index,
        );

        when(
          () => syncDatabase.findPendingByEntryId('entry-id'),
        ).thenAnswer((_) async => existingItem);

        String? capturedMessage;
        when(
          () => syncDatabase.updateOutboxMessage(
            itemId: any(named: 'itemId'),
            newMessage: any(named: 'newMessage'),
            newSubject: any(named: 'newSubject'),
            payloadSize: any(named: 'payloadSize'),
            priority: any(named: 'priority'),
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

        when(
          () => journalDb.journalEntityById('entry-id'),
        ).thenAnswer((_) async => journalEntity);

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
      },
    );

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
        priority: OutboxPriority.low.index,
      );

      when(
        () => syncDatabase.findPendingByEntryId('link-id'),
      ).thenAnswer((_) async => existingItem);

      String? capturedMessage;
      String? capturedSubject;
      int? capturedPayloadSize;
      when(
        () => syncDatabase.updateOutboxMessage(
          itemId: any(named: 'itemId'),
          newMessage: any(named: 'newMessage'),
          newSubject: any(named: 'newSubject'),
          payloadSize: any(named: 'payloadSize'),
          priority: any(named: 'priority'),
        ),
      ).thenAnswer((invocation) async {
        capturedMessage = invocation.namedArguments[#newMessage] as String?;
        capturedSubject = invocation.namedArguments[#newSubject] as String?;
        capturedPayloadSize = invocation.namedArguments[#payloadSize] as int?;
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
          payloadSize: any(named: 'payloadSize'),
          priority: any(named: 'priority'),
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

      // Verify merged payloadSize = utf8 byte length of merged JSON
      expect(capturedPayloadSize, isNotNull);
      expect(
        capturedPayloadSize,
        utf8.encode(capturedMessage!).length,
      );
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
        priority: OutboxPriority.low.index,
      );

      when(
        () => syncDatabase.findPendingByEntryId('entry-id'),
      ).thenAnswer((_) async => existingItem);
      when(
        () => syncDatabase.updateOutboxMessage(
          itemId: any(named: 'itemId'),
          newMessage: any(named: 'newMessage'),
          newSubject: any(named: 'newSubject'),
          payloadSize: any(named: 'payloadSize'),
          priority: any(named: 'priority'),
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
        priority: OutboxPriority.low.index,
      );

      when(
        () => syncDatabase.findPendingByEntryId('link-id'),
      ).thenAnswer((_) async => existingItem);
      when(
        () => syncDatabase.updateOutboxMessage(
          itemId: any(named: 'itemId'),
          newMessage: any(named: 'newMessage'),
          newSubject: any(named: 'newSubject'),
          payloadSize: any(named: 'payloadSize'),
          priority: any(named: 'priority'),
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

    test(
      'falls through to create new item when merge message decode fails',
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
          priority: OutboxPriority.low.index,
        );

        when(
          () => syncDatabase.findPendingByEntryId('entry-id'),
        ).thenAnswer((_) async => existingItem);
        when(
          () => syncDatabase.addOutboxItem(any()),
        ).thenAnswer((_) async => 2);

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
            payloadSize: any(named: 'payloadSize'),
            priority: any(named: 'priority'),
          ),
        );
      },
    );

    test(
      'journal merge whose update affects zero rows (row no longer pending) '
      'logs MERGE-MISS and inserts a fresh row with the merged data',
      () async {
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
          priority: OutboxPriority.low.index,
        );
        when(
          () => syncDatabase.findPendingByEntryId('entry-id'),
        ).thenAnswer((_) async => existingItem);
        // Row was sent out from under us between the SELECT and UPDATE.
        when(
          () => syncDatabase.updateOutboxMessage(
            itemId: any(named: 'itemId'),
            newMessage: any(named: 'newMessage'),
            newSubject: any(named: 'newSubject'),
            payloadSize: any(named: 'payloadSize'),
            priority: any(named: 'priority'),
          ),
        ).thenAnswer((_) async => 0);
        OutboxCompanion? insertedCompanion;
        when(() => syncDatabase.addOutboxItem(any())).thenAnswer((invocation) {
          insertedCompanion =
              invocation.positionalArguments.single as OutboxCompanion;
          return Future<int>.value(2);
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

        final journalEntity = JournalEntity.journalEntry(
          meta: Metadata(
            id: 'entry-id',
            createdAt: sampleDate,
            updatedAt: sampleDate,
            dateFrom: sampleDate,
            dateTo: sampleDate,
            vectorClock: newVc,
          ),
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

        verify(
          () => loggingService.log(
            LogDomain.sync,
            any<String>(
              that: allOf([
                contains('MERGE-MISS'),
                contains('type=SyncJournalEntity'),
                contains('id=entry-id'),
              ]),
            ),
            subDomain: 'enqueueMessage',
          ),
        ).called(1);
        // Fresh row carries the merged subject + the original entry id.
        expect(insertedCompanion, isNotNull);
        expect(insertedCompanion!.subject.value, 'hhash:7');
        expect(insertedCompanion!.outboxEntryId.value, 'entry-id');
      },
    );

    test(
      'a throw from recordSentEntry during a journal MERGE is caught and '
      'logged under recordSent so a broken sequence log never breaks the '
      'merge, and the merge still completes',
      () async {
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
          priority: OutboxPriority.low.index,
        );
        when(
          () => syncDatabase.findPendingByEntryId('entry-id'),
        ).thenAnswer((_) async => existingItem);
        when(
          () => syncDatabase.updateOutboxMessage(
            itemId: any(named: 'itemId'),
            newMessage: any(named: 'newMessage'),
            newSubject: any(named: 'newSubject'),
            payloadSize: any(named: 'payloadSize'),
            priority: any(named: 'priority'),
          ),
        ).thenAnswer((_) async => 1);

        final sequenceLog = MockSyncSequenceLogService();
        when(
          () => sequenceLog.recordSentEntry(
            entryId: any(named: 'entryId'),
            vectorClock: any(named: 'vectorClock'),
          ),
        ).thenThrow(StateError('sequence log gone'));

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
          sequenceLogService: sequenceLog,
        );

        final journalEntity = JournalEntity.journalEntry(
          meta: Metadata(
            id: 'entry-id',
            createdAt: sampleDate,
            updatedAt: sampleDate,
            dateFrom: sampleDate,
            dateTo: sampleDate,
            vectorClock: newVc,
          ),
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

        verify(
          () => loggingService.error(
            LogDomain.sync,
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: 'recordSent',
          ),
        ).called(1);
        // The merge still completed despite the sequence-log failure.
        verify(
          () => syncDatabase.updateOutboxMessage(
            itemId: 1,
            newMessage: any(named: 'newMessage'),
            newSubject: any(named: 'newSubject'),
            payloadSize: any(named: 'payloadSize'),
            priority: any(named: 'priority'),
          ),
        ).called(1);
      },
    );

    test(
      'a throw from recordSentEntry on the non-merge journal path is caught '
      'and logged under recordSent so the fresh enqueue still succeeds',
      () async {
        final sampleDate = DateTime.utc(2024);
        const newVc = VectorClock({'hostA': 7});

        // No existing pending item → fresh-insert path (not a merge).
        when(
          () => syncDatabase.findPendingByEntryId('entry-id'),
        ).thenAnswer((_) async => null);

        final sequenceLog = MockSyncSequenceLogService();
        when(
          () => sequenceLog.recordSentEntry(
            entryId: any(named: 'entryId'),
            vectorClock: any(named: 'vectorClock'),
          ),
        ).thenThrow(StateError('sequence log gone'));

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
          sequenceLogService: sequenceLog,
        );

        final journalEntity = JournalEntity.journalEntry(
          meta: Metadata(
            id: 'entry-id',
            createdAt: sampleDate,
            updatedAt: sampleDate,
            dateFrom: sampleDate,
            dateTo: sampleDate,
            vectorClock: newVc,
          ),
          entryText: const EntryText(plainText: 'Fresh text'),
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

        verify(
          () => loggingService.error(
            LogDomain.sync,
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: 'recordSent',
          ),
        ).called(1);
        // The fresh outbox row was still inserted.
        verify(() => syncDatabase.addOutboxItem(any())).called(1);
      },
    );

    test(
      'entry-link merge whose update affects zero rows logs MERGE-MISS and '
      'inserts a fresh row carrying the merged subject and link id',
      () async {
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
          priority: OutboxPriority.low.index,
        );
        when(
          () => syncDatabase.findPendingByEntryId('link-id'),
        ).thenAnswer((_) async => existingItem);
        when(
          () => syncDatabase.updateOutboxMessage(
            itemId: any(named: 'itemId'),
            newMessage: any(named: 'newMessage'),
            newSubject: any(named: 'newSubject'),
            payloadSize: any(named: 'payloadSize'),
            priority: any(named: 'priority'),
          ),
        ).thenAnswer((_) async => 0);
        OutboxCompanion? insertedCompanion;
        when(() => syncDatabase.addOutboxItem(any())).thenAnswer((invocation) {
          insertedCompanion =
              invocation.positionalArguments.single as OutboxCompanion;
          return Future<int>.value(2);
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

        verify(
          () => loggingService.log(
            LogDomain.sync,
            any<String>(
              that: allOf([
                contains('MERGE-MISS'),
                contains('type=SyncEntryLink'),
                contains('id=link-id'),
              ]),
            ),
            subDomain: 'enqueueMessage',
          ),
        ).called(1);
        expect(insertedCompanion, isNotNull);
        expect(insertedCompanion!.subject.value, 'hhash:link:5');
        expect(insertedCompanion!.outboxEntryId.value, 'link-id');
      },
    );

    test(
      'a throw from recordSentEntryLink during an entry-link MERGE is caught '
      'and logged under recordSent without breaking the merge',
      () async {
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
          priority: OutboxPriority.low.index,
        );
        when(
          () => syncDatabase.findPendingByEntryId('link-id'),
        ).thenAnswer((_) async => existingItem);
        when(
          () => syncDatabase.updateOutboxMessage(
            itemId: any(named: 'itemId'),
            newMessage: any(named: 'newMessage'),
            newSubject: any(named: 'newSubject'),
            payloadSize: any(named: 'payloadSize'),
            priority: any(named: 'priority'),
          ),
        ).thenAnswer((_) async => 1);

        final sequenceLog = MockSyncSequenceLogService();
        when(
          () => sequenceLog.recordSentEntryLink(
            linkId: any(named: 'linkId'),
            vectorClock: any(named: 'vectorClock'),
          ),
        ).thenThrow(StateError('sequence log gone'));

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
          sequenceLogService: sequenceLog,
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

        verify(
          () => loggingService.error(
            LogDomain.sync,
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: 'recordSent',
          ),
        ).called(1);
        verify(
          () => syncDatabase.updateOutboxMessage(
            itemId: 1,
            newMessage: any(named: 'newMessage'),
            newSubject: any(named: 'newSubject'),
            payloadSize: any(named: 'payloadSize'),
            priority: any(named: 'priority'),
          ),
        ).called(1);
      },
    );

    test(
      'an entry-link merge whose existing row holds undecodable JSON is '
      'caught under enqueueMessage.merge and falls through to a fresh insert',
      () async {
        final sampleDate = DateTime.utc(2024);
        const newVc = VectorClock({'hostA': 5});

        // Existing pending link row with a corrupt message body so the
        // merge `SyncMessage.fromJson` throws inside the link merge try.
        final existingItem = OutboxItem(
          id: 1,
          createdAt: sampleDate,
          updatedAt: sampleDate,
          status: OutboxStatus.pending.index,
          retries: 0,
          message: 'not-valid-json{{{',
          subject: 'hhash:link:3',
          filePath: null,
          outboxEntryId: 'link-id',
          priority: OutboxPriority.low.index,
        );
        when(
          () => syncDatabase.findPendingByEntryId('link-id'),
        ).thenAnswer((_) async => existingItem);
        when(
          () => syncDatabase.addOutboxItem(any()),
        ).thenAnswer((_) async => 2);

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

        verify(
          () => loggingService.error(
            LogDomain.sync,
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: 'enqueueMessage.merge',
          ),
        ).called(1);
        // The corrupt-merge fall-through still enqueues the link fresh.
        verify(() => syncDatabase.addOutboxItem(any())).called(1);
        verifyNever(
          () => syncDatabase.updateOutboxMessage(
            itemId: any(named: 'itemId'),
            newMessage: any(named: 'newMessage'),
            newSubject: any(named: 'newSubject'),
            payloadSize: any(named: 'payloadSize'),
            priority: any(named: 'priority'),
          ),
        );
      },
    );
  });

  group('sendNext', () {
    test('uses SyncTuning.outboxIdleThreshold for default gate', () async {
      when(
        () => journalDb.getConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) async => true);
      when(
        () => processor.processQueue(),
      ).thenAnswer((_) async => OutboxProcessingResult.none);

      final matrixService = MockMatrixService();
      final client = MockMatrixClient();
      final cached = MockCachedLoginController();
      when(
        () => cached.stream,
      ).thenAnswer((_) => const Stream<LoginState>.empty());
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
        postDrainSettle: Duration.zero,
      );

      // Access the gate via reflection (private) by invoking sendNext; gate is
      // injected in ctor and should use the tuned threshold.
      final gate = svc.getActivityGateForTest();
      expect(gate.idleThreshold, SyncTuning.outboxIdleThreshold);
      await svc.dispose();
    });

    test('skips processing when Matrix disabled', () async {
      when(
        () => journalDb.getConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) async => false);

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
      when(
        () => journalDb.getConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) async => true);
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
      when(
        () => journalDb.getConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) async => true);
      when(
        () => processor.processQueue(),
      ).thenAnswer((_) async => OutboxProcessingResult.none);

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
      when(
        () => journalDb.getConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) async => true);
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
        () => loggingService.error(
          LogDomain.sync,
          exception,
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: 'sendNext',
        ),
      ).called(1);
      expect(svc.enqueueCalls, 1);
      expectDelayCloseTo(svc.lastDelay, const Duration(seconds: 15));

      await svc.dispose();
    });

    test(
      'schedules immediate continuation when drain pass cap reached and items remain',
      () async {
        when(
          () => journalDb.getConfigFlag(enableMatrixFlag),
        ).thenAnswer((_) async => true);
        // Always indicate more work immediately.
        when(() => processor.processQueue()).thenAnswer(
          (_) async => OutboxProcessingResult.schedule(Duration.zero),
        );
        // Indicate there are still pending items after the pass cap is reached.
        when(
          () => repository.fetchPending(limit: any(named: 'limit')),
        ).thenAnswer(
          (_) async => [
            OutboxItem(
              id: 1,
              createdAt: DateTime(2024, 3, 15, 10, 30),
              updatedAt: DateTime(2024, 3, 15, 10, 30),
              status: 0,
              retries: 0,
              message: '{}',
              subject: 'test',
              filePath: null,
              priority: OutboxPriority.low.index,
            ),
          ],
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

        // After hitting the internal pass cap, service should schedule an
        // immediate continuation because items remain pending.
        expect(svc.enqueueCalls, 1);
        expect(svc.lastDelay, Duration.zero);

        await svc.dispose();
      },
    );
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
    when(
      () => cached.stream,
    ).thenAnswer((_) => const Stream<LoginState>.empty());
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
    when(
      () => matrixService.sendMatrixMsg(message),
    ).thenAnswer((_) async => true);

    final sender = MatrixOutboxMessageSender(matrixService);

    final result = await sender.send(message);

    expect(result, isTrue);
    verify(() => matrixService.sendMatrixMsg(message)).called(1);
  });

  group('sendNext login gate - ', () {
    test('returns early when sync enabled but not logged in', () async {
      when(
        () => journalDb.getConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) async => true);
      when(
        () => processor.processQueue(),
      ).thenAnswer((_) async => OutboxProcessingResult.none);

      final gate = createGate();

      final matrixService = MockMatrixService();
      final client = MockMatrixClient();
      when(() => matrixService.client).thenReturn(client);
      final cached = MockCachedLoginController();
      when(
        () => cached.stream,
      ).thenAnswer((_) => const Stream<LoginState>.empty());
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
        postDrainSettle: Duration.zero,
      );

      await gatedSvc.sendNext();

      // Should not attempt to drain
      verifyNever(() => processor.processQueue());

      await gatedSvc.dispose();
      await svc.dispose();
    });

    test('drains when sync enabled and logged in', () async {
      when(
        () => journalDb.getConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) async => true);
      when(
        () => processor.processQueue(),
      ).thenAnswer((_) async => OutboxProcessingResult.none);

      final gate = createGate();

      final matrixService = MockMatrixService();
      final client = MockMatrixClient();
      when(() => matrixService.client).thenReturn(client);
      final cached = MockCachedLoginController();
      when(
        () => cached.stream,
      ).thenAnswer((_) => const Stream<LoginState>.empty());
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
        postDrainSettle: Duration.zero,
      );

      await svc.sendNext();

      // sendNext performs two drains (second after a short settle delay)
      verify(() => processor.processQueue()).called(2);

      await svc.dispose();
    });

    test(
      'post-login nudge enqueues and drains after LoginState.loggedIn',
      () async {
        when(
          () => journalDb.getConfigFlag(enableMatrixFlag),
        ).thenAnswer((_) async => true);
        when(
          () => processor.processQueue(),
        ).thenAnswer((_) async => OutboxProcessingResult.none);

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
          verify(
            () => processor.processQueue(),
          ).called(greaterThanOrEqualTo(1));
          unawaited(svc.dispose());
          async.flushMicrotasks();
        });
      },
    );

    test(
      'connectivity regain pre-login does not drain, drains after login',
      () async {
        when(
          () => journalDb.getConfigFlag(enableMatrixFlag),
        ).thenAnswer((_) async => true);
        when(
          () => processor.processQueue(),
        ).thenAnswer((_) async => OutboxProcessingResult.none);
        when(
          () => repository.fetchPending(limit: any(named: 'limit')),
        ).thenAnswer(
          (_) async => [
            OutboxItem(
              id: 1,
              message: '{}',
              subject: 's',
              status: OutboxStatus.pending.index,
              retries: 0,
              createdAt: DateTime(2024, 3, 15, 10, 30),
              updatedAt: DateTime(2024, 3, 15, 10, 30),
              filePath: null,
              priority: OutboxPriority.low.index,
            ),
          ],
        );

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
          verify(
            () => processor.processQueue(),
          ).called(greaterThanOrEqualTo(1));

          unawaited(svc.dispose());
          async.flushMicrotasks();
        });
      },
    );
  });

  group('drainOutbox behavior', () {
    test('pauses when canProcess is false initially', () async {
      when(
        () => journalDb.getConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) async => true);
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
      when(
        () => journalDb.getConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) async => true);
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
      when(
        () => journalDb.getConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) async => true);
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

    test(
      'sendNext aborts second drain when disposed during settle',
      () {
        // Regression: with `outboxPostDrainSettle = 1500ms`, the disposal
        // window grows. After awaiting the settle, sendNext must not run a
        // second drain on a disposed service.
        fakeAsync((async) {
          when(
            () => journalDb.getConfigFlag(enableMatrixFlag),
          ).thenAnswer((_) async => true);
          final gate = createGate();

          var calls = 0;
          when(() => processor.processQueue()).thenAnswer((_) async {
            calls++;
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
            postDrainSettle: const Duration(milliseconds: 50),
          );

          var pendingCompleted = false;
          final pending = svc.sendNext()
            ..then((_) {
              pendingCompleted = true;
            });
          async.flushMicrotasks();
          expect(calls, 1);

          // Dispose mid-settle, before the trailing drain runs.
          async.elapse(const Duration(milliseconds: 10));
          unawaited(svc.dispose());
          async
            ..elapse(const Duration(milliseconds: 40))
            ..flushMicrotasks();
          expect(pendingCompleted, isTrue);

          // First drain ran; trailing drain skipped because of disposal.
          expect(calls, 1);
          unawaited(pending);
        });
      },
    );

    test('respects retry backoff and skips immediate re-entry', () async {
      when(
        () => journalDb.getConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) async => true);
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
      when(
        () => journalDb.getConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) async => true);

      // Processor always returns schedule(Duration.zero) to keep the loop running
      when(
        () => processor.processQueue(),
      ).thenAnswer((_) async => OutboxProcessingResult.schedule(Duration.zero));
      when(
        () => repository.fetchPending(limit: any(named: 'limit')),
      ).thenAnswer(
        (_) async => [
          OutboxItem(
            id: 1,
            message: '{}',
            subject: 's',
            status: OutboxStatus.pending.index,
            retries: 0,
            createdAt: DateTime(2024, 3, 15, 10, 30),
            updatedAt: DateTime(2024, 3, 15, 10, 30),
            filePath: null,
            priority: OutboxPriority.low.index,
          ),
        ],
      );

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
      when(
        () => journalDb.getConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) async => true);
      when(
        () => processor.processQueue(),
      ).thenAnswer((_) async => OutboxProcessingResult.none);

      // Gate simulates a short delay to exceed logging threshold
      final gate = createGate();
      when(gate.waitUntilIdle).thenAnswer(
        (_) => Future<void>.delayed(const Duration(milliseconds: 120)),
      );

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
      verify(
        () => loggingService.log(
          LogDomain.sync,
          any<String>(that: startsWith('activityGate.wait ms=')),
          subDomain: 'activityGate',
        ),
      ).called(greaterThanOrEqualTo(1));
      await svc.dispose();
    });
  });

  group('watchdog', () {
    test('enqueues when pending + logged in + idle queue', () async {
      when(
        () => journalDb.getConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) async => true);
      when(
        () => processor.processQueue(),
      ).thenAnswer((_) async => OutboxProcessingResult.none);
      when(
        () => repository.fetchPending(limit: any(named: 'limit')),
      ).thenAnswer(
        (_) async => [
          OutboxItem(
            id: 1,
            message: '{}',
            subject: 's',
            status: OutboxStatus.pending.index,
            retries: 0,
            createdAt: DateTime(2024, 3, 15, 10, 30),
            updatedAt: DateTime(2024, 3, 15, 10, 30),
            filePath: null,
            priority: OutboxPriority.low.index,
          ),
        ],
      );
      final gate = createGate();
      final matrixService = MockMatrixService();
      when(() => matrixService.isLoggedIn()).thenReturn(true);
      final client = MockMatrixClient();
      final cached = MockCachedLoginController();
      when(
        () => cached.stream,
      ).thenAnswer((_) => const Stream<LoginState>.empty());
      when(() => cached.value).thenReturn(LoginState.loggedOut);
      when(() => client.onLoginStateChanged).thenReturn(cached);
      when(() => matrixService.client).thenReturn(client);

      // Controlled outbox count stream to avoid extra nudges
      final countController = StreamController<int>.broadcast();
      addTearDown(countController.close);
      when(
        () => syncDatabase.watchOutboxCount(),
      ).thenAnswer((_) => countController.stream);

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
        verify(
          () => loggingService.log(
            LogDomain.sync,
            'watchdog: pending+loggedIn idleQueue → enqueue',
            subDomain: 'watchdog',
          ),
        ).called(1);
        verify(() => processor.processQueue()).called(greaterThanOrEqualTo(1));
        unawaited(svc.dispose());
        async.flushMicrotasks();
      });
    });

    test('does not enqueue when queue active', () async {
      when(
        () => journalDb.getConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) async => true);
      when(
        () => repository.fetchPending(limit: any(named: 'limit')),
      ).thenAnswer(
        (_) async => [
          OutboxItem(
            id: 1,
            message: '{}',
            subject: 's',
            status: OutboxStatus.pending.index,
            retries: 0,
            createdAt: DateTime(2024, 3, 15, 10, 30),
            updatedAt: DateTime(2024, 3, 15, 10, 30),
            filePath: null,
            priority: OutboxPriority.low.index,
          ),
        ],
      );
      final gate = createGate();
      // Keep the runner busy so queueSize > 0 when watchdog fires
      late Completer<void> gateReleased;
      when(
        gate.waitUntilIdle,
      ).thenAnswer((_) => gateReleased.future);
      final matrixService = MockMatrixService();
      when(() => matrixService.isLoggedIn()).thenReturn(true);
      final client = MockMatrixClient();
      final cached = MockCachedLoginController();
      when(
        () => cached.stream,
      ).thenAnswer((_) => const Stream<LoginState>.empty());
      when(() => cached.value).thenReturn(LoginState.loggedOut);
      when(() => client.onLoginStateChanged).thenReturn(cached);
      when(() => matrixService.client).thenReturn(client);
      when(
        () => processor.processQueue(),
      ).thenAnswer((_) async => OutboxProcessingResult.none);
      when(
        () => syncDatabase.watchOutboxCount(),
      ).thenAnswer((_) => const Stream<int>.empty());

      fakeAsync((async) {
        gateReleased = Completer<void>();
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
        verifyNever(
          () => loggingService.log(
            LogDomain.sync,
            'watchdog: pending+loggedIn idleQueue → enqueue',
            subDomain: 'watchdog',
          ),
        );
        gateReleased.complete();
        async.flushMicrotasks();
        unawaited(svc.dispose());
        async.flushMicrotasks();
      });
    });

    test('does not enqueue when not logged in', () async {
      when(
        () => journalDb.getConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) async => true);
      final gate = createGate();
      final matrixService = MockMatrixService();
      when(() => matrixService.isLoggedIn()).thenReturn(false);
      final client = MockMatrixClient();
      final cached = MockCachedLoginController();
      when(
        () => cached.stream,
      ).thenAnswer((_) => const Stream<LoginState>.empty());
      when(() => cached.value).thenReturn(LoginState.loggedOut);
      when(() => client.onLoginStateChanged).thenReturn(cached);
      when(() => matrixService.client).thenReturn(client);
      when(
        () => repository.fetchPending(limit: any(named: 'limit')),
      ).thenAnswer(
        (_) async => [
          OutboxItem(
            id: 1,
            message: '{}',
            subject: 's',
            status: OutboxStatus.pending.index,
            retries: 0,
            createdAt: DateTime(2024, 3, 15, 10, 30),
            updatedAt: DateTime(2024, 3, 15, 10, 30),
            filePath: null,
            priority: OutboxPriority.low.index,
          ),
        ],
      );
      when(
        () => syncDatabase.watchOutboxCount(),
      ).thenAnswer((_) => const Stream<int>.empty());
      when(
        () => processor.processQueue(),
      ).thenAnswer((_) async => OutboxProcessingResult.none);

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
        verifyNever(
          () => loggingService.log(
            LogDomain.sync,
            'watchdog: pending+loggedIn idleQueue → enqueue',
            subDomain: 'watchdog',
          ),
        );
        unawaited(svc.dispose());
        async.flushMicrotasks();
      });
    });

    test('handles fetchPending errors gracefully', () async {
      when(
        () => journalDb.getConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) async => true);
      when(
        () => repository.fetchPending(limit: any(named: 'limit')),
      ).thenThrow(Exception('boom'));
      when(
        () => processor.processQueue(),
      ).thenAnswer((_) async => OutboxProcessingResult.none);
      final gate = createGate();
      final matrixService = MockMatrixService();
      when(() => matrixService.isLoggedIn()).thenReturn(true);
      final client = MockMatrixClient();
      final cached = MockCachedLoginController();
      when(
        () => cached.stream,
      ).thenAnswer((_) => const Stream<LoginState>.empty());
      when(() => cached.value).thenReturn(LoginState.loggedOut);
      when(() => client.onLoginStateChanged).thenReturn(cached);
      when(() => matrixService.client).thenReturn(client);
      when(
        () => syncDatabase.watchOutboxCount(),
      ).thenAnswer((_) => const Stream<int>.empty());

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
        verify(
          () => loggingService.error(
            LogDomain.sync,
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: 'watchdog',
          ),
        ).called(1);
        unawaited(svc.dispose());
        async.flushMicrotasks();
      });
    });

    test('stops after dispose', () async {
      when(
        () => journalDb.getConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) async => true);
      when(
        () => repository.fetchPending(limit: any(named: 'limit')),
      ).thenAnswer(
        (_) async => [
          OutboxItem(
            id: 1,
            message: '{}',
            subject: 's',
            status: OutboxStatus.pending.index,
            retries: 0,
            createdAt: DateTime(2024, 3, 15, 10, 30),
            updatedAt: DateTime(2024, 3, 15, 10, 30),
            filePath: null,
            priority: OutboxPriority.low.index,
          ),
        ],
      );
      final gate = createGate();
      final matrixService = MockMatrixService();
      when(() => matrixService.isLoggedIn()).thenReturn(true);
      final client = MockMatrixClient();
      final cached = MockCachedLoginController();
      when(
        () => cached.stream,
      ).thenAnswer((_) => const Stream<LoginState>.empty());
      when(() => cached.value).thenReturn(LoginState.loggedOut);
      when(() => client.onLoginStateChanged).thenReturn(cached);
      when(() => matrixService.client).thenReturn(client);
      when(
        () => syncDatabase.watchOutboxCount(),
      ).thenAnswer((_) => const Stream<int>.empty());
      when(
        () => processor.processQueue(),
      ).thenAnswer((_) async => OutboxProcessingResult.none);

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
        verify(
          () => loggingService.log(
            LogDomain.sync,
            'watchdog: pending+loggedIn idleQueue → enqueue',
            subDomain: 'watchdog',
          ),
        ).called(1);
      });
    });
  });

  group('dbNudge', () {
    test('enqueues when count increases (>0)', () async {
      when(
        () => journalDb.getConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) async => true);
      final gate = createGate();
      when(
        () => processor.processQueue(),
      ).thenAnswer((_) async => OutboxProcessingResult.none);

      final countController = StreamController<int>.broadcast();
      addTearDown(countController.close);
      when(
        () => syncDatabase.watchOutboxCount(),
      ).thenAnswer((_) => countController.stream);

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
        verify(
          () => loggingService.log(
            LogDomain.sync,
            'dbNudge count=5 → enqueue',
            subDomain: 'dbNudge',
          ),
        ).called(1);
        unawaited(svc.dispose());
        async.flushMicrotasks();
      });
    });

    test(
      'coalesces repeat counts within the quiet window: logs once per '
      'magnitude-bucket transition, not once per stream event',
      () async {
        when(
          () => journalDb.getConfigFlag(enableMatrixFlag),
        ).thenAnswer((_) async => true);
        final gate = createGate();
        when(
          () => processor.processQueue(),
        ).thenAnswer((_) async => OutboxProcessingResult.none);

        final countController = StreamController<int>.broadcast();
        addTearDown(countController.close);
        when(
          () => syncDatabase.watchOutboxCount(),
        ).thenAnswer((_) => countController.stream);

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

          // First tick at count=1 crosses the "first-seen" / count=1 bucket.
          countController.add(1);
          async
            ..elapse(const Duration(milliseconds: 60))
            ..flushMicrotasks();
          // Same-bucket tick shortly after: must not log again.
          countController.add(2);
          async
            ..elapse(const Duration(milliseconds: 60))
            ..flushMicrotasks();
          countController.add(3);
          async
            ..elapse(const Duration(milliseconds: 60))
            ..flushMicrotasks();
          // Crossing into the >=10 bucket: must log.
          countController.add(12);
          async
            ..elapse(const Duration(milliseconds: 60))
            ..flushMicrotasks();

          final logged = verify(
            () => loggingService.log(
              LogDomain.sync,
              captureAny<String>(that: startsWith('dbNudge count=')),
              subDomain: 'dbNudge',
            ),
          ).captured;
          expect(
            logged,
            equals(<String>[
              'dbNudge count=1 → enqueue',
              'dbNudge count=12 → enqueue',
            ]),
            reason:
                'Only bucket transitions (first-seen, crossing >=10) '
                'should log within the coalesce window',
          );

          unawaited(svc.dispose());
          async.flushMicrotasks();
        });
      },
    );

    test('ignores count <= 0', () async {
      when(
        () => journalDb.getConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) async => true);
      final gate = createGate();
      when(
        () => processor.processQueue(),
      ).thenAnswer((_) async => OutboxProcessingResult.none);

      final countController = StreamController<int>.broadcast();
      addTearDown(countController.close);
      when(
        () => syncDatabase.watchOutboxCount(),
      ).thenAnswer((_) => countController.stream);

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
        verifyNever(
          () => loggingService.log(
            any<LogDomain>(),
            any<String>(that: startsWith('dbNudge')),
            subDomain: any(named: 'subDomain'),
          ),
        );
        unawaited(svc.dispose());
        async.flushMicrotasks();
      });
    });

    test('stops after dispose', () async {
      when(
        () => journalDb.getConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) async => true);
      final gate = createGate();
      when(
        () => processor.processQueue(),
      ).thenAnswer((_) async => OutboxProcessingResult.none);

      final countController = StreamController<int>.broadcast();
      addTearDown(countController.close);
      when(
        () => syncDatabase.watchOutboxCount(),
      ).thenAnswer((_) => countController.stream);

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
        verifyNever(
          () => loggingService.log(
            any<LogDomain>(),
            any<String>(that: startsWith('dbNudge')),
            subDomain: any(named: 'subDomain'),
          ),
        );
      });
    });

    test('handles stream errors without crashing the test', () async {
      when(
        () => journalDb.getConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) async => true);
      final gate = createGate();
      when(
        () => processor.processQueue(),
      ).thenAnswer((_) async => OutboxProcessingResult.none);

      final countController = StreamController<int>.broadcast();
      addTearDown(countController.close);
      when(
        () => syncDatabase.watchOutboxCount(),
      ).thenAnswer((_) => countController.stream);

      fakeAsync((async) {
        Object? capturedError;
        StackTrace? capturedSt;
        OutboxService? svc;
        runZonedGuarded(
          () {
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
          },
          (e, st) {
            capturedError = e;
            capturedSt = st;
          },
        );
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
    test('watchdog does not duplicate work when dbNudge already active', () async {
      when(
        () => journalDb.getConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) async => true);
      // One pending item in repository
      when(
        () => repository.fetchPending(limit: any(named: 'limit')),
      ).thenAnswer(
        (_) async => [
          OutboxItem(
            id: 42,
            message: '{}',
            subject: 's',
            status: OutboxStatus.pending.index,
            retries: 0,
            createdAt: DateTime(2024, 3, 15, 10, 30),
            updatedAt: DateTime(2024, 3, 15, 10, 30),
            filePath: null,
            priority: OutboxPriority.low.index,
          ),
        ],
      );

      // Gate delays long enough so watchdog fires while runner is active
      final gate = createGate();
      late Completer<void> gateReleased;
      when(
        gate.waitUntilIdle,
      ).thenAnswer((_) => gateReleased.future);

      final matrixService = MockMatrixService();
      final client = MockMatrixClient();
      when(() => matrixService.client).thenReturn(client);
      final cached = MockCachedLoginController();
      when(
        () => cached.stream,
      ).thenAnswer((_) => const Stream<LoginState>.empty());
      when(() => cached.value).thenReturn(LoginState.loggedIn);
      when(() => client.onLoginStateChanged).thenReturn(cached);
      when(() => matrixService.isLoggedIn()).thenReturn(true);

      // Track db count stream
      final countController = StreamController<int>.broadcast();
      addTearDown(countController.close);
      when(
        () => syncDatabase.watchOutboxCount(),
      ).thenAnswer((_) => countController.stream);

      // Processor returns none for each drain (sendNext runs two drains per invocation)
      when(
        () => processor.processQueue(),
      ).thenAnswer((_) async => OutboxProcessingResult.none);

      fakeAsync((async) {
        gateReleased = Completer<void>();
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
          postDrainSettle: Duration.zero,
        );

        // T=0: DB nudge fires → schedules enqueue after 50ms
        countController.add(1);
        async
          ..elapse(const Duration(milliseconds: 60))
          ..flushMicrotasks();

        // T=10s: Watchdog fires while runner is still blocked in waitUntilIdle
        async.elapse(const Duration(seconds: 10));

        // Let the runner finish and the second drain occur after settle
        gateReleased.complete();
        async
          ..flushMicrotasks()
          ..elapse(Duration.zero)
          ..flushMicrotasks();

        // Exactly one runner invocation → two drains
        verify(() => processor.processQueue()).called(2);
        // Watchdog must not enqueue when queue active → no watchdog enqueue log
        verifyNever(
          () => loggingService.log(
            LogDomain.sync,
            'watchdog: pending+loggedIn idleQueue → enqueue',
            subDomain: 'watchdog',
          ),
        );

        unawaited(svc.dispose());
        async.flushMicrotasks();
      });
    });

    test(
      'connectivity + login + watchdog dont cause triple processing',
      () async {
        when(
          () => journalDb.getConfigFlag(enableMatrixFlag),
        ).thenAnswer((_) async => true);
        when(
          () => repository.fetchPending(limit: any(named: 'limit')),
        ).thenAnswer(
          (_) async => [
            OutboxItem(
              id: 1,
              message: '{}',
              subject: 's',
              status: OutboxStatus.pending.index,
              retries: 0,
              createdAt: DateTime(2024, 3, 15, 10, 30),
              updatedAt: DateTime(2024, 3, 15, 10, 30),
              filePath: null,
              priority: OutboxPriority.low.index,
            ),
          ],
        );
        when(
          () => processor.processQueue(),
        ).thenAnswer((_) async => OutboxProcessingResult.none);

        // Long wait to keep the queue active till after watchdog
        final gate = createGate();
        late Completer<void> gateReleased;
        when(
          gate.waitUntilIdle,
        ).thenAnswer((_) => gateReleased.future);

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
        when(
          () => syncDatabase.watchOutboxCount(),
        ).thenAnswer((_) => const Stream<int>.empty());

        fakeAsync((async) {
          gateReleased = Completer<void>();
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
          gateReleased.complete();
          async
            ..flushMicrotasks()
            ..elapse(Duration.zero)
            ..flushMicrotasks();

          // Upper bound: two drains per runner invocation, at most two runner
          // callbacks (connectivity + login) = 4 drains total. Not 6+.
          verify(() => processor.processQueue()).called(lessThanOrEqualTo(4));
          verifyNever(
            () => loggingService.log(
              LogDomain.sync,
              'watchdog: pending+loggedIn idleQueue → enqueue',
              subDomain: 'watchdog',
            ),
          );

          unawaited(svc.dispose());
          async.flushMicrotasks();
        });
      },
    );

    test(
      'dbNudge during watchdog fetchPending does not duplicate excessively',
      () async {
        when(
          () => journalDb.getConfigFlag(enableMatrixFlag),
        ).thenAnswer((_) async => true);
        when(
          () => processor.processQueue(),
        ).thenAnswer((_) async => OutboxProcessingResult.none);
        // Slow fetchPending simulates overlap window with dbNudge
        late Completer<List<OutboxItem>> fetchPending;
        when(
          () => repository.fetchPending(limit: any(named: 'limit')),
        ).thenAnswer((_) => fetchPending.future);
        final pendingItems = [
          OutboxItem(
            id: 7,
            message: '{}',
            subject: 's',
            status: OutboxStatus.pending.index,
            retries: 0,
            createdAt: DateTime(2024, 3, 15, 10, 30),
            updatedAt: DateTime(2024, 3, 15, 10, 30),
            filePath: null,
            priority: OutboxPriority.low.index,
          ),
        ];

        // Gate immediate
        final gate = createGate();

        final matrixService = MockMatrixService();
        final client = MockMatrixClient();
        when(() => matrixService.client).thenReturn(client);
        final cached = MockCachedLoginController();
        when(
          () => cached.stream,
        ).thenAnswer((_) => const Stream<LoginState>.empty());
        when(() => cached.value).thenReturn(LoginState.loggedIn);
        when(() => client.onLoginStateChanged).thenReturn(cached);
        when(() => matrixService.isLoggedIn()).thenReturn(true);

        // DB count stream for nudge
        final countController = StreamController<int>.broadcast();
        addTearDown(countController.close);
        when(
          () => syncDatabase.watchOutboxCount(),
        ).thenAnswer((_) => countController.stream);

        fakeAsync((async) {
          fetchPending = Completer<List<OutboxItem>>();
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
          fetchPending.complete(pendingItems);
          async.flushMicrotasks();

          // Should not explode in duplicate processing; 4 drains is an upper bound here
          verify(() => processor.processQueue()).called(lessThanOrEqualTo(4));
          unawaited(svc.dispose());
          async.flushMicrotasks();
        });
      },
    );
  });

  group('SyncThemingSelection', () {
    test('enqueues theming message with correct subject', () async {
      final message = SyncMessage.themingSelection(
        lightThemeName: 'Indigo',
        darkThemeName: 'Shark',
        themeMode: 'dark',
        updatedAt: DateTime(2024, 3, 15, 10, 30).millisecondsSinceEpoch,
        status: SyncEntryStatus.update,
      );

      await service.enqueueMessage(message);

      final captured = verify(
        () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()),
      ).captured;
      expect(captured.length, 1);

      final companion = captured.first as OutboxCompanion;
      expect(companion.subject.value, 'themingSelection');
    });

    test('logs theming message details', () async {
      final message = SyncMessage.themingSelection(
        lightThemeName: 'Indigo',
        darkThemeName: 'Shark',
        themeMode: 'dark',
        updatedAt: DateTime(2024, 3, 15, 10, 30).millisecondsSinceEpoch,
        status: SyncEntryStatus.update,
      );

      await service.enqueueMessage(message);

      verify(
        () => loggingService.log(
          LogDomain.sync,
          any<String>(
            that: allOf([
              contains('type=SyncThemingSelection'),
              contains('light=Indigo'),
              contains('dark=Shark'),
              contains('mode=dark'),
            ]),
          ),
          subDomain: 'enqueueMessage',
        ),
      ).called(1);
    });
  });

  group('SyncSyncNodeProfile', () {
    test(
      'enqueues sync-node-profile message with correct subject',
      () async {
        final message = SyncMessage.syncNodeProfile(
          profile: SyncNodeProfile(
            hostId: 'host-uuid-abc',
            displayName: 'Studio Mac',
            platform: 'macos',
            capabilities: const [
              NodeCapability.mlxAudio,
              NodeCapability.ollamaLlm,
            ],
            updatedAt: DateTime.utc(2026, 3, 15, 12),
          ),
        );

        await service.enqueueMessage(message);

        final captured = verify(
          () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()),
        ).captured;
        expect(captured.length, 1);

        final companion = captured.first as OutboxCompanion;
        expect(companion.subject.value, 'syncNodeProfile');
        // Presence broadcasts ride at low priority so they never queue-jump
        // journal writes.
        expect(companion.priority.value, OutboxPriority.low.index);
      },
    );

    test(
      'logs sync-node-profile message details — hostId, name, and capability '
      'count appear in the structured event for log triage',
      () async {
        final message = SyncMessage.syncNodeProfile(
          profile: SyncNodeProfile(
            hostId: 'host-uuid-xyz',
            displayName: 'Linux Box',
            platform: 'linux',
            capabilities: const [NodeCapability.ollamaLlm],
            updatedAt: DateTime.utc(2026, 3, 15, 12),
          ),
        );

        await service.enqueueMessage(message);

        verify(
          () => loggingService.log(
            LogDomain.sync,
            any<String>(
              that: allOf([
                contains('type=SyncSyncNodeProfile'),
                contains('hostId=host-uuid-xyz'),
                contains('name=Linux Box'),
                contains('caps=1'),
              ]),
            ),
            subDomain: 'enqueueMessage',
          ),
        ).called(1);
      },
    );
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
      when(
        () => journalDb.linksForEntryIdsBidirectional(const {entryId}),
      ).thenAnswer((_) async => [link1, link2]);

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

      when(
        () => journalDb.journalEntityById(entryId),
      ).thenAnswer((_) async => journalEntity);

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
      verify(
        () => journalDb.linksForEntryIdsBidirectional(const {entryId}),
      ).called(1);

      // Verify logging shows embedded links count
      verify(
        () => loggingService.log(
          LogDomain.sync,
          any<String>(
            that: contains(
              'enqueueMessage.attachedLinks id=$entryId count=2 embedded=2 from=1 to=1',
            ),
          ),
          subDomain: 'enqueueMessage.attachLinks',
        ),
      ).called(1);

      verify(
        () => loggingService.log(
          LogDomain.sync,
          any<String>(
            that: allOf([
              contains('type=SyncJournalEntity'),
              contains('embeddedLinks=2'),
            ]),
          ),
          subDomain: 'enqueueMessage',
        ),
      ).called(1);

      // Verify the message was encoded with embedded links
      final captured = verify(
        () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()),
      ).captured;
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
      when(
        () => journalDb.linksForEntryIdsBidirectional(const {entryId}),
      ).thenThrow(Exception('Database error'));

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

      when(
        () => journalDb.journalEntityById(entryId),
      ).thenAnswer((_) async => journalEntity);

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
      verify(
        () => loggingService.error(
          LogDomain.sync,
          any<Exception>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: 'enqueueMessage.fetchLinks',
        ),
      ).called(1);

      // Verify message was still enqueued (without links)
      final captured = verify(
        () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()),
      ).captured;
      final companion = captured.first as OutboxCompanion;
      final encodedMessage =
          json.decode(companion.message.value) as Map<String, dynamic>;
      expect(encodedMessage['entryLinks'], isNull);
    });

    test('does not log attachedLinks when no links found', () async {
      const entryId = 'entry-789';

      // Mock journalDb to return empty list
      when(
        () => journalDb.linksForEntryIdsBidirectional(const {entryId}),
      ).thenAnswer((_) async => []);

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

      when(
        () => journalDb.journalEntityById(entryId),
      ).thenAnswer((_) async => journalEntity);

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
      verify(
        () => journalDb.linksForEntryIdsBidirectional(const {entryId}),
      ).called(1);

      // Verify attachedLinks log was NOT called (no links to attach)
      verifyNever(
        () => loggingService.log(
          any<LogDomain>(),
          any<String>(that: contains('enqueueMessage.attachedLinks')),
          subDomain: any(named: 'subDomain'),
        ),
      );

      // Verify no-links log was emitted
      verify(
        () => loggingService.log(
          LogDomain.sync,
          any<String>(that: contains('enqueueMessage.noLinks id=$entryId')),
          subDomain: 'enqueueMessage.attachLinks',
        ),
      ).called(1);

      // Verify embeddedLinks=0 in the log
      verify(
        () => loggingService.log(
          LogDomain.sync,
          any<String>(
            that: allOf([
              contains('type=SyncJournalEntity'),
              contains('embeddedLinks=0'),
            ]),
          ),
          subDomain: 'enqueueMessage',
        ),
      ).called(1);
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

    test(
      'records entry link in sequence log when vectorClock present',
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

        when(
          () => sequenceLogService.recordSentEntryLink(
            linkId: any(named: 'linkId'),
            vectorClock: any(named: 'vectorClock'),
          ),
        ).thenAnswer((_) async {});

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

        verify(
          () => sequenceLogService.recordSentEntryLink(
            linkId: 'link-seq-1',
            vectorClock: vc,
          ),
        ).called(1);
      },
    );

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
      verifyNever(
        () => sequenceLogService.recordSentEntryLink(
          linkId: any(named: 'linkId'),
          vectorClock: any(named: 'vectorClock'),
        ),
      );
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

      when(
        () => sequenceLogService.recordSentEntryLink(
          linkId: any(named: 'linkId'),
          vectorClock: any(named: 'vectorClock'),
        ),
      ).thenThrow(Exception('sequence log error'));

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
      verify(
        () => loggingService.error(
          LogDomain.sync,
          any<Object>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: 'recordSent',
        ),
      ).called(1);
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
      verify(
        () => loggingService.log(
          LogDomain.sync,
          any<String>(that: contains('type=SyncEntryLink')),
          subDomain: 'enqueueMessage',
        ),
      ).called(1);
    });
  });

  group('Agent sequence log recording -', () {
    late MockSyncSequenceLogService sequenceLogService;
    late OutboxService serviceWithSequenceLog;

    setUp(() {
      sequenceLogService = MockSyncSequenceLogService();
      registerFallbackValue(const VectorClock({'fallback': 1}));
      registerFallbackValue(SyncSequencePayloadType.journalEntity);
    });

    tearDown(() async {
      await serviceWithSequenceLog.dispose();
    });

    test(
      'records agent entity in sequence log when vectorClock present',
      () async {
        const vc = VectorClock({'host-A': 10});
        final entity = AgentDomainEntity.agent(
          id: 'agent-seq-1',
          agentId: 'agent-seq-1',
          kind: 'task_agent',
          displayName: 'Test',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-1',
          config: const AgentConfig(),
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: vc,
        );

        final message = SyncMessage.agentEntity(
          agentEntity: entity,
          status: SyncEntryStatus.update,
        );

        when(
          () => sequenceLogService.recordSentEntry(
            entryId: any(named: 'entryId'),
            vectorClock: any(named: 'vectorClock'),
            payloadType: any(named: 'payloadType'),
          ),
        ).thenAnswer((_) async {});

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

        await serviceWithSequenceLog.enqueueMessage(message);

        verify(
          () => sequenceLogService.recordSentEntry(
            entryId: 'agent-seq-1',
            vectorClock: vc,
            payloadType: SyncSequencePayloadType.agentEntity,
          ),
        ).called(1);
      },
    );

    test(
      'records agent link in sequence log when vectorClock present',
      () async {
        const vc = VectorClock({'host-B': 5});
        final link = AgentLink.basic(
          id: 'link-seq-1',
          fromId: 'agent-1',
          toId: 'state-1',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: vc,
        );

        final message = SyncMessage.agentLink(
          agentLink: link,
          status: SyncEntryStatus.update,
        );

        when(
          () => sequenceLogService.recordSentEntry(
            entryId: any(named: 'entryId'),
            vectorClock: any(named: 'vectorClock'),
            payloadType: any(named: 'payloadType'),
          ),
        ).thenAnswer((_) async {});

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

        await serviceWithSequenceLog.enqueueMessage(message);

        verify(
          () => sequenceLogService.recordSentEntry(
            entryId: 'link-seq-1',
            vectorClock: vc,
            payloadType: SyncSequencePayloadType.agentLink,
          ),
        ).called(1);
      },
    );

    test('skips agent entity recording when vectorClock is null', () async {
      final entity = AgentDomainEntity.agent(
        id: 'agent-no-vc',
        agentId: 'agent-no-vc',
        kind: 'task_agent',
        displayName: 'No VC',
        lifecycle: AgentLifecycle.active,
        mode: AgentInteractionMode.autonomous,
        allowedCategoryIds: const {},
        currentStateId: 'state-1',
        config: const AgentConfig(),
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
      );

      final message = SyncMessage.agentEntity(
        agentEntity: entity,
        status: SyncEntryStatus.update,
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

      await serviceWithSequenceLog.enqueueMessage(message);

      verifyNever(
        () => sequenceLogService.recordSentEntry(
          entryId: any(named: 'entryId'),
          vectorClock: any(named: 'vectorClock'),
          payloadType: any(named: 'payloadType'),
        ),
      );
    });

    test(
      'handles recordSentEntry errors gracefully for agent entity',
      () async {
        const vc = VectorClock({'host-C': 3});
        final entity = AgentDomainEntity.agent(
          id: 'agent-err',
          agentId: 'agent-err',
          kind: 'task_agent',
          displayName: 'Err',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-1',
          config: const AgentConfig(),
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: vc,
        );

        final message = SyncMessage.agentEntity(
          agentEntity: entity,
          status: SyncEntryStatus.update,
        );

        when(
          () => sequenceLogService.recordSentEntry(
            entryId: any(named: 'entryId'),
            vectorClock: any(named: 'vectorClock'),
            payloadType: any(named: 'payloadType'),
          ),
        ).thenThrow(Exception('sequence log error'));

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
        await serviceWithSequenceLog.enqueueMessage(message);

        // Verify exception was logged
        verify(
          () => loggingService.error(
            LogDomain.sync,
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: 'recordSent',
          ),
        ).called(1);
      },
    );
  });

  group('Simple message handler edge cases', () {
    test(
      'SyncEntityDefinition with null vectorClock uses null in subject',
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
      },
    );

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

      verify(
        () => loggingService.log(
          LogDomain.sync,
          any<String>(that: contains('entries=0')),
          subDomain: 'enqueueMessage',
        ),
      ).called(1);
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

      verify(
        () => loggingService.log(
          LogDomain.sync,
          any<String>(
            that: allOf([
              contains('type=SyncBackfillResponse'),
              contains('hostId=host-abc'),
              contains('counter=42'),
              contains('deleted=true'),
            ]),
          ),
          subDomain: 'enqueueMessage',
        ),
      ).called(1);
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

      verify(
        () => loggingService.log(
          LogDomain.sync,
          any<String>(that: contains('deleted=false')),
          subDomain: 'enqueueMessage',
        ),
      ).called(1);
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

      verify(
        () => loggingService.log(
          LogDomain.sync,
          any<String>(
            that: allOf([
              contains('type=SyncAiConfig'),
              contains('id=config-xyz-789'),
            ]),
          ),
          subDomain: 'enqueueMessage',
        ),
      ).called(1);
    });

    test('SyncAiConfigDelete logs deleted config id', () async {
      const message = SyncMessage.aiConfigDelete(
        id: 'config-to-delete-456',
      );

      await service.enqueueMessage(message);

      verify(
        () => loggingService.log(
          LogDomain.sync,
          any<String>(
            that: allOf([
              contains('type=SyncAiConfigDelete'),
              contains('id=config-to-delete-456'),
            ]),
          ),
          subDomain: 'enqueueMessage',
        ),
      ).called(1);
    });

    test('enqueueMessage handles addOutboxItem error gracefully', () async {
      when(
        () => syncDatabase.addOutboxItem(any<OutboxCompanion>()),
      ).thenThrow(Exception('DB write failed'));

      final message = SyncMessage.themingSelection(
        lightThemeName: 'Light',
        darkThemeName: 'Dark',
        themeMode: 'system',
        updatedAt: DateTime(2024, 3, 15, 10, 30).millisecondsSinceEpoch,
        status: SyncEntryStatus.update,
      );

      // Should not throw - error is caught and logged
      await service.enqueueMessage(message);

      verify(
        () => loggingService.error(
          LogDomain.sync,
          any<Object>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: 'enqueueMessage',
        ),
      ).called(1);
    });

    test(
      'SyncEntityDefinition with null host uses null in counter lookup',
      () async {
        // Create a vectorClockService that returns null host
        final nullHostVcs = MockVectorClockService();
        when(() => nullHostVcs.getHost()).thenAnswer((_) async => null);
        when(
          () => nullHostVcs.getHostHash(),
        ).thenAnswer((_) async => 'hash123');

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

        await serviceWithNullHost.dispose();
      },
    );
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
      when(
        () => journalDb.journalEntityById(entryId),
      ).thenAnswer((_) async => journalEntity);

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

      when(
        () => journalDb.journalEntityById(entryId),
      ).thenAnswer((_) async => journalEntity);

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

      when(
        () => journalDb.journalEntityById(entryId),
      ).thenAnswer((_) async => journalEntity);

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

    test('prepareMessage passes through non-entity messages unchanged', () async {
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

    test(
      'SyncAgentEntity enqueues with correct subject and saves JSON',
      () async {
        final entity = AgentDomainEntity.agent(
          id: 'agent-xyz',
          agentId: 'agent-xyz',
          kind: 'task_agent',
          displayName: 'Test',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-1',
          config: const AgentConfig(),
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
        );

        final message = SyncMessage.agentEntity(
          agentEntity: entity,
          status: SyncEntryStatus.update,
        );

        await service.enqueueMessage(message);

        final captured = verify(
          () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()),
        ).captured;
        expect(captured.length, 1);

        final companion = captured.first as OutboxCompanion;
        expect(companion.subject.value, 'agentEntity:agent-xyz');
        expect(companion.outboxEntryId.value, 'agent-xyz');

        // Verify JSON was saved to disk
        final expectedPath =
            '${documentsDirectory.path}/agent_entities/agent-xyz.json';
        expect(File(expectedPath).existsSync(), isTrue);

        // Verify the enriched message has jsonPath set
        final storedMessage =
            SyncMessage.fromJson(
                  json.decode(companion.message.value) as Map<String, dynamic>,
                )
                as SyncAgentEntity;
        expect(storedMessage.jsonPath, '/agent_entities/agent-xyz.json');

        verify(
          () => loggingService.log(
            LogDomain.sync,
            any<String>(
              that: allOf([
                contains('type=SyncAgentEntity'),
                contains('subject=agentEntity:agent-xyz'),
              ]),
            ),
            subDomain: 'enqueueMessage',
          ),
        ).called(1);
      },
    );

    test('SyncAgentEntity merges with existing pending item', () async {
      final entity = AgentDomainEntity.agent(
        id: 'agent-xyz',
        agentId: 'agent-xyz',
        kind: 'task_agent',
        displayName: 'Updated',
        lifecycle: AgentLifecycle.active,
        mode: AgentInteractionMode.autonomous,
        allowedCategoryIds: const {},
        currentStateId: 'state-1',
        config: const AgentConfig(),
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
      );

      final message = SyncMessage.agentEntity(
        agentEntity: entity,
        status: SyncEntryStatus.update,
      );

      when(() => syncDatabase.findPendingByEntryId('agent-xyz')).thenAnswer(
        (_) async => OutboxItem(
          id: 42,
          message: json.encode(message.toJson()),
          status: OutboxStatus.pending.index,
          retries: 0,
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          subject: 'agentEntity:agent-xyz',
          priority: OutboxPriority.low.index,
        ),
      );
      when(
        () => syncDatabase.updateOutboxMessage(
          itemId: any(named: 'itemId'),
          newMessage: any(named: 'newMessage'),
          newSubject: any(named: 'newSubject'),
          payloadSize: any(named: 'payloadSize'),
          priority: any(named: 'priority'),
        ),
      ).thenAnswer((_) async => 1);

      await service.enqueueMessage(message);

      verify(
        () => syncDatabase.updateOutboxMessage(
          itemId: 42,
          newMessage: any(named: 'newMessage'),
          newSubject: 'agentEntity:agent-xyz',
          payloadSize: any(named: 'payloadSize'),
          priority: any(named: 'priority'),
        ),
      ).called(1);
      verifyNever(
        () => syncDatabase.addOutboxItem(any<OutboxCompanion>()),
      );
    });

    test(
      'SyncAgentEntity merge preserves coveredVectorClocks',
      () async {
        const oldVc = VectorClock({'hostA': 3});
        const newVc = VectorClock({'hostA': 5});

        final oldEntity = AgentDomainEntity.agent(
          id: 'agent-xyz',
          agentId: 'agent-xyz',
          kind: 'task_agent',
          displayName: 'Old',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-1',
          config: const AgentConfig(),
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: oldVc,
        );

        final oldMessage = SyncMessage.agentEntity(
          agentEntity: oldEntity,
          status: SyncEntryStatus.update,
        );

        when(() => syncDatabase.findPendingByEntryId('agent-xyz')).thenAnswer(
          (_) async => OutboxItem(
            id: 42,
            message: json.encode(oldMessage.toJson()),
            status: OutboxStatus.pending.index,
            retries: 0,
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            subject: 'agentEntity:agent-xyz',
            priority: OutboxPriority.low.index,
          ),
        );

        String? capturedMessage;
        when(
          () => syncDatabase.updateOutboxMessage(
            itemId: any(named: 'itemId'),
            newMessage: any(named: 'newMessage'),
            newSubject: any(named: 'newSubject'),
            payloadSize: any(named: 'payloadSize'),
            priority: any(named: 'priority'),
          ),
        ).thenAnswer((invocation) async {
          capturedMessage = invocation.namedArguments[#newMessage] as String?;
          return 1;
        });

        final newEntity = AgentDomainEntity.agent(
          id: 'agent-xyz',
          agentId: 'agent-xyz',
          kind: 'task_agent',
          displayName: 'Updated',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-2',
          config: const AgentConfig(),
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 16),
          vectorClock: newVc,
        );

        final newMessage = SyncMessage.agentEntity(
          agentEntity: newEntity,
          status: SyncEntryStatus.update,
        );

        await service.enqueueMessage(newMessage);

        expect(capturedMessage, isNotNull);
        final decoded = SyncMessage.fromJson(
          json.decode(capturedMessage!) as Map<String, dynamic>,
        );
        expect(decoded, isA<SyncAgentEntity>());
        final agentMsg = decoded as SyncAgentEntity;
        expect(agentMsg.coveredVectorClocks, isNotNull);
        final coveredCounters = agentMsg.coveredVectorClocks!
            .map((vc) => vc.vclock['hostA'])
            .whereType<int>()
            .toSet();
        expect(coveredCounters, containsAll([3, 5]));
        expect(coveredCounters, hasLength(2));
      },
    );

    test(
      'SyncAgentEntity merge inserts fresh row when original no longer pending',
      () async {
        const oldVc = VectorClock({'hostA': 3});
        const newVc = VectorClock({'hostA': 5});

        final oldEntity = AgentDomainEntity.agent(
          id: 'agent-xyz',
          agentId: 'agent-xyz',
          kind: 'task_agent',
          displayName: 'Old',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-1',
          config: const AgentConfig(),
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: oldVc,
        );

        final oldMessage = SyncMessage.agentEntity(
          agentEntity: oldEntity,
          status: SyncEntryStatus.update,
        );

        when(() => syncDatabase.findPendingByEntryId('agent-xyz')).thenAnswer(
          (_) async => OutboxItem(
            id: 42,
            message: json.encode(oldMessage.toJson()),
            status: OutboxStatus.pending.index,
            retries: 0,
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            subject: 'agentEntity:agent-xyz',
            priority: OutboxPriority.low.index,
          ),
        );

        // Simulate row no longer pending (already sent)
        when(
          () => syncDatabase.updateOutboxMessage(
            itemId: any(named: 'itemId'),
            newMessage: any(named: 'newMessage'),
            newSubject: any(named: 'newSubject'),
            payloadSize: any(named: 'payloadSize'),
            priority: any(named: 'priority'),
          ),
        ).thenAnswer((_) async => 0);

        final newEntity = AgentDomainEntity.agent(
          id: 'agent-xyz',
          agentId: 'agent-xyz',
          kind: 'task_agent',
          displayName: 'Updated',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-2',
          config: const AgentConfig(),
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 16),
          vectorClock: newVc,
        );

        final newMessage = SyncMessage.agentEntity(
          agentEntity: newEntity,
          status: SyncEntryStatus.update,
        );

        await service.enqueueMessage(newMessage);

        // updateOutboxMessage was attempted but returned 0
        verify(
          () => syncDatabase.updateOutboxMessage(
            itemId: 42,
            newMessage: any(named: 'newMessage'),
            newSubject: any(named: 'newSubject'),
            payloadSize: any(named: 'payloadSize'),
            priority: any(named: 'priority'),
          ),
        ).called(1);

        // Fresh row inserted as fallback
        final captured = verify(
          () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()),
        ).captured;
        expect(captured, hasLength(1));
        final companion = captured.first as OutboxCompanion;
        expect(companion.outboxEntryId.value, 'agent-xyz');
        expect(companion.subject.value, 'agentEntity:agent-xyz');

        // Verify the inserted message has coveredVectorClocks
        final decoded = SyncMessage.fromJson(
          json.decode(companion.message.value) as Map<String, dynamic>,
        );
        expect(decoded, isA<SyncAgentEntity>());
        final agentMsg = decoded as SyncAgentEntity;
        expect(agentMsg.coveredVectorClocks, isNotNull);
        final coveredCounters = agentMsg.coveredVectorClocks!
            .map((vc) => vc.vclock['hostA'])
            .whereType<int>()
            .toSet();
        expect(coveredCounters, containsAll([3, 5]));
      },
    );

    test(
      'SyncAgentLink merge preserves coveredVectorClocks',
      () async {
        const oldVc = VectorClock({'hostA': 10});
        const newVc = VectorClock({'hostA': 12});

        final oldLink = AgentLink.agentTask(
          id: 'link-abc',
          fromId: 'agent-1',
          toId: 'task-1',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: oldVc,
        );

        final oldMessage = SyncMessage.agentLink(
          agentLink: oldLink,
          status: SyncEntryStatus.update,
        );

        when(() => syncDatabase.findPendingByEntryId('link-abc')).thenAnswer(
          (_) async => OutboxItem(
            id: 43,
            message: json.encode(oldMessage.toJson()),
            status: OutboxStatus.pending.index,
            retries: 0,
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            subject: 'agentLink:link-abc',
            priority: OutboxPriority.low.index,
          ),
        );

        String? capturedMessage;
        when(
          () => syncDatabase.updateOutboxMessage(
            itemId: any(named: 'itemId'),
            newMessage: any(named: 'newMessage'),
            newSubject: any(named: 'newSubject'),
            payloadSize: any(named: 'payloadSize'),
            priority: any(named: 'priority'),
          ),
        ).thenAnswer((invocation) async {
          capturedMessage = invocation.namedArguments[#newMessage] as String?;
          return 1;
        });

        final newLink = AgentLink.agentTask(
          id: 'link-abc',
          fromId: 'agent-1',
          toId: 'task-1',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 16),
          vectorClock: newVc,
        );

        final newMessage = SyncMessage.agentLink(
          agentLink: newLink,
          status: SyncEntryStatus.update,
        );

        await service.enqueueMessage(newMessage);

        expect(capturedMessage, isNotNull);
        final decoded = SyncMessage.fromJson(
          json.decode(capturedMessage!) as Map<String, dynamic>,
        );
        expect(decoded, isA<SyncAgentLink>());
        final linkMsg = decoded as SyncAgentLink;
        expect(linkMsg.coveredVectorClocks, isNotNull);
        final coveredCounters = linkMsg.coveredVectorClocks!
            .map((vc) => vc.vclock['hostA'])
            .whereType<int>()
            .toSet();
        expect(coveredCounters, containsAll([10, 12]));
        expect(coveredCounters, hasLength(2));
      },
    );

    test(
      'SyncAgentLink enqueues with correct subject and saves JSON',
      () async {
        final link = AgentLink.agentTask(
          id: 'link-abc',
          fromId: 'agent-1',
          toId: 'task-1',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
        );

        final message = SyncMessage.agentLink(
          agentLink: link,
          status: SyncEntryStatus.update,
        );

        await service.enqueueMessage(message);

        final captured = verify(
          () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()),
        ).captured;
        expect(captured.length, 1);

        final companion = captured.first as OutboxCompanion;
        expect(companion.subject.value, 'agentLink:link-abc');
        expect(companion.outboxEntryId.value, 'link-abc');

        // Verify JSON was saved to disk
        final expectedPath =
            '${documentsDirectory.path}/agent_links/link-abc.json';
        expect(File(expectedPath).existsSync(), isTrue);

        // Verify the enriched message has jsonPath set
        final storedMessage =
            SyncMessage.fromJson(
                  json.decode(companion.message.value) as Map<String, dynamic>,
                )
                as SyncAgentLink;
        expect(storedMessage.jsonPath, '/agent_links/link-abc.json');

        verify(
          () => loggingService.log(
            LogDomain.sync,
            any<String>(
              that: allOf([
                contains('type=SyncAgentLink'),
                contains('subject=agentLink:link-abc'),
              ]),
            ),
            subDomain: 'enqueueMessage',
          ),
        ).called(1);
      },
    );

    test('SyncAgentEntity skips enqueue when entity is null', () async {
      const message = SyncMessage.agentEntity(
        status: SyncEntryStatus.update,
      );

      await service.enqueueMessage(message);

      verifyNever(
        () => syncDatabase.addOutboxItem(any<OutboxCompanion>()),
      );
      verify(
        () => loggingService.log(
          LogDomain.sync,
          'enqueue.skip agentEntity is null',
          subDomain: 'enqueueMessage',
        ),
      ).called(1);
    });

    test('SyncAgentLink skips enqueue when link is null', () async {
      const message = SyncMessage.agentLink(
        status: SyncEntryStatus.update,
      );

      await service.enqueueMessage(message);

      verifyNever(
        () => syncDatabase.addOutboxItem(any<OutboxCompanion>()),
      );
      verify(
        () => loggingService.log(
          LogDomain.sync,
          'enqueue.skip agentLink is null',
          subDomain: 'enqueueMessage',
        ),
      ).called(1);
    });

    test('SyncAgentLink merges with existing pending item', () async {
      final link = AgentLink.agentTask(
        id: 'link-abc',
        fromId: 'agent-1',
        toId: 'task-1',
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
      );

      final message = SyncMessage.agentLink(
        agentLink: link,
        status: SyncEntryStatus.update,
      );

      when(() => syncDatabase.findPendingByEntryId('link-abc')).thenAnswer(
        (_) async => OutboxItem(
          id: 43,
          message: json.encode(message.toJson()),
          status: OutboxStatus.pending.index,
          retries: 0,
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          subject: 'agentLink:link-abc',
          priority: OutboxPriority.low.index,
        ),
      );
      when(
        () => syncDatabase.updateOutboxMessage(
          itemId: any(named: 'itemId'),
          newMessage: any(named: 'newMessage'),
          newSubject: any(named: 'newSubject'),
          payloadSize: any(named: 'payloadSize'),
          priority: any(named: 'priority'),
        ),
      ).thenAnswer((_) async => 1);

      await service.enqueueMessage(message);

      verify(
        () => syncDatabase.updateOutboxMessage(
          itemId: 43,
          newMessage: any(named: 'newMessage'),
          newSubject: 'agentLink:link-abc',
          payloadSize: any(named: 'payloadSize'),
          priority: any(named: 'priority'),
        ),
      ).called(1);
      verifyNever(
        () => syncDatabase.addOutboxItem(any<OutboxCompanion>()),
      );
    });

    test('SyncAgentEntity enqueues fallback when saveJson fails', () async {
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
        activityGate: createGate(),
        ownsActivityGate: false,
        saveJsonHandler: (_, _) => Future.error(Exception('disk full')),
      );

      final entity = AgentDomainEntity.agent(
        id: 'fail-agent',
        agentId: 'fail-agent',
        kind: 'task_agent',
        displayName: 'Fail',
        lifecycle: AgentLifecycle.active,
        mode: AgentInteractionMode.autonomous,
        allowedCategoryIds: const {},
        currentStateId: 'state-1',
        config: const AgentConfig(),
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
      );

      final message = SyncMessage.agentEntity(
        agentEntity: entity,
        status: SyncEntryStatus.update,
      );

      await failingService.enqueueMessage(message);

      // Fallback item still enqueued
      final captured = verify(
        () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()),
      ).captured;
      expect(captured.length, 1);

      final companion = captured.first as OutboxCompanion;
      expect(companion.subject.value, 'agentEntity:fail-agent');
      expect(companion.outboxEntryId.value, 'fail-agent');

      // Error was logged
      verify(
        () => loggingService.error(
          LogDomain.sync,
          any<Object>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: 'enqueueMessage.saveAgentPayload',
        ),
      ).called(1);

      await failingService.dispose();
    });

    test(
      'an agent entity whose id escapes the documents root is skipped and '
      'logged — the unencoded agent path builder makes a traversal id reach '
      'the !isWithin guard, unlike notification paths which are URL-encoded',
      () async {
        // `relativeAgentEntityPath` does NOT URL-encode the id, so an id
        // with `../` segments produces a path that normalizes outside the
        // docs root and trips the `!p.isWithin` guard.
        final entity = AgentDomainEntity.agent(
          id: '../../escape',
          agentId: '../../escape',
          kind: 'task_agent',
          displayName: 'Escape',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-1',
          config: const AgentConfig(),
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
        );

        await service.enqueueMessage(
          SyncMessage.agentEntity(
            agentEntity: entity,
            status: SyncEntryStatus.update,
          ),
        );

        verify(
          () => loggingService.log(
            LogDomain.sync,
            any<String>(
              that: contains('enqueue.skip invalid agent payload path'),
            ),
            subDomain: 'enqueueMessage',
          ),
        ).called(1);
        // Nothing was persisted: the row is never created for an
        // out-of-root payload path.
        verifyNever(() => syncDatabase.addOutboxItem(any<OutboxCompanion>()));
      },
    );

    test(
      'an agent merge whose existing row holds undecodable JSON is caught '
      'under enqueueMessage.agentMerge, logs the (no VC merge) fallback, and '
      'still updates the pending row',
      () async {
        const newVc = VectorClock({'hostA': 5});

        // Existing pending agent row with a corrupt message body so the
        // VC-merge `SyncMessage.fromJson` throws inside the agent merge try.
        when(() => syncDatabase.findPendingByEntryId('agent-xyz')).thenAnswer(
          (_) async => OutboxItem(
            id: 42,
            message: 'corrupt-agent-json{{{',
            status: OutboxStatus.pending.index,
            retries: 0,
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            subject: 'agentEntity:agent-xyz',
            priority: OutboxPriority.low.index,
          ),
        );
        when(
          () => syncDatabase.updateOutboxMessage(
            itemId: any(named: 'itemId'),
            newMessage: any(named: 'newMessage'),
            newSubject: any(named: 'newSubject'),
            payloadSize: any(named: 'payloadSize'),
            priority: any(named: 'priority'),
          ),
        ).thenAnswer((_) async => 1);

        final entity = AgentDomainEntity.agent(
          id: 'agent-xyz',
          agentId: 'agent-xyz',
          kind: 'task_agent',
          displayName: 'Updated',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-2',
          config: const AgentConfig(),
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 16),
          vectorClock: newVc,
        );

        await service.enqueueMessage(
          SyncMessage.agentEntity(
            agentEntity: entity,
            status: SyncEntryStatus.update,
          ),
        );

        verify(
          () => loggingService.error(
            LogDomain.sync,
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: 'enqueueMessage.agentMerge',
          ),
        ).called(1);
        verify(
          () => loggingService.log(
            LogDomain.sync,
            any<String>(that: contains('(no VC merge)')),
            subDomain: 'enqueueMessage',
          ),
        ).called(1);
        // The merge still proceeds (without merged covered clocks) and
        // updates the existing pending row rather than inserting fresh.
        verify(
          () => syncDatabase.updateOutboxMessage(
            itemId: 42,
            newMessage: any(named: 'newMessage'),
            newSubject: 'agentEntity:agent-xyz',
            payloadSize: any(named: 'payloadSize'),
            priority: any(named: 'priority'),
          ),
        ).called(1);
      },
    );
  });

  group('sent-outbox prune', () {
    test(
      'startup prune fires after the 30-second grace and logs the removed '
      'count when rows are deleted — uses the SyncTuning retention so both '
      'desktop and mobile agree on the cutoff window. Calls the chunked '
      'variant so the writer lock is released between batches even on '
      'devices with hundreds of thousands of stale sent rows',
      () {
        fakeAsync((async) {
          when(
            () => repository.pruneSentOutboxItemsChunked(
              retention: SyncTuning.outboxSentRetention,
              chunkSize: any(named: 'chunkSize'),
              vacuumWhenDone: any(named: 'vacuumWhenDone'),
              onProgress: any(named: 'onProgress'),
            ),
          ).thenAnswer((_) async => 42);

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
            activityGate: createGate(),
            ownsActivityGate: false,
          );
          addTearDown(() async {
            await svc.dispose();
            async.flushMicrotasks();
          });

          // Before the 30s grace — prune must not have fired yet.
          async
            ..elapse(const Duration(seconds: 20))
            ..flushMicrotasks();
          verifyNever(
            () => repository.pruneSentOutboxItemsChunked(
              retention: any(named: 'retention'),
              chunkSize: any(named: 'chunkSize'),
              vacuumWhenDone: any(named: 'vacuumWhenDone'),
              onProgress: any(named: 'onProgress'),
            ),
          );

          // Cross the 30s boundary — startup prune kicks.
          async
            ..elapse(const Duration(seconds: 20))
            ..flushMicrotasks();

          verify(
            () => repository.pruneSentOutboxItemsChunked(
              retention: SyncTuning.outboxSentRetention,
              chunkSize: any(named: 'chunkSize'),
              vacuumWhenDone: any(named: 'vacuumWhenDone'),
              onProgress: any(named: 'onProgress'),
            ),
          ).called(1);
          verify(
            () => loggingService.log(
              LogDomain.sync,
              any<String>(
                that: contains('prune.sent removed=42'),
              ),
              subDomain: 'prune',
            ),
          ).called(1);
        });
      },
    );

    test(
      'periodic background prune passes vacuumWhenDone=false — VACUUM '
      'rewrites the whole DB file and would dominate the daily sweep cost '
      'long after the backlog has settled. The user-triggered Maintenance '
      'action is the place that pays for VACUUM',
      () {
        fakeAsync((async) {
          bool? capturedVacuum;
          when(
            () => repository.pruneSentOutboxItemsChunked(
              retention: any(named: 'retention'),
              chunkSize: any(named: 'chunkSize'),
              vacuumWhenDone: any(named: 'vacuumWhenDone'),
              onProgress: any(named: 'onProgress'),
            ),
          ).thenAnswer((invocation) async {
            capturedVacuum =
                invocation.namedArguments[#vacuumWhenDone] as bool?;
            return 0;
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
            activityGate: createGate(),
            ownsActivityGate: false,
          );
          addTearDown(() async {
            await svc.dispose();
            async.flushMicrotasks();
          });

          // Step past the 30s startup grace so the one-shot startup
          // prune fires and returns. Reset the captured value + the
          // mock interaction log so the assertion below proves the
          // periodic timer (not the startup timer) called the
          // repository — without this clear the test could pass on
          // the startup invocation alone, which says nothing about
          // the periodic path.
          async
            ..elapse(const Duration(seconds: 31))
            ..flushMicrotasks();
          capturedVacuum = null;
          clearInteractions(repository);

          // Now advance one full periodic interval. Only the periodic
          // timer can fire here, so the captured `vacuumWhenDone`
          // value belongs to it.
          async
            ..elapse(
              SyncTuning.outboxPruneInterval + const Duration(seconds: 1),
            )
            ..flushMicrotasks();

          verify(
            () => repository.pruneSentOutboxItemsChunked(
              retention: any(named: 'retention'),
              chunkSize: any(named: 'chunkSize'),
              vacuumWhenDone: any(named: 'vacuumWhenDone'),
              onProgress: any(named: 'onProgress'),
            ),
          ).called(1);
          expect(capturedVacuum, isFalse);
        });
      },
    );

    test(
      'no log emission when the prune deletes zero rows — prevents the '
      'daily sweep from spamming the log once the backlog is drained',
      () {
        fakeAsync((async) {
          when(
            () => repository.pruneSentOutboxItemsChunked(
              retention: any(named: 'retention'),
              chunkSize: any(named: 'chunkSize'),
              vacuumWhenDone: any(named: 'vacuumWhenDone'),
              onProgress: any(named: 'onProgress'),
            ),
          ).thenAnswer((_) async => 0);

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
            activityGate: createGate(),
            ownsActivityGate: false,
          );
          addTearDown(() async {
            await svc.dispose();
            async.flushMicrotasks();
          });

          async
            ..elapse(const Duration(seconds: 31))
            ..flushMicrotasks();

          verify(
            () => repository.pruneSentOutboxItemsChunked(
              retention: any(named: 'retention'),
              chunkSize: any(named: 'chunkSize'),
              vacuumWhenDone: any(named: 'vacuumWhenDone'),
              onProgress: any(named: 'onProgress'),
            ),
          ).called(1);
          verifyNever(
            () => loggingService.log(
              LogDomain.sync,
              any<String>(),
              subDomain: 'prune',
            ),
          );
        });
      },
    );

    test(
      'prune errors are captured under OUTBOX/prune and do not propagate — '
      'a transient DB failure in the sweep must not kill the outbox '
      "service's background work",
      () {
        fakeAsync((async) {
          when(
            () => repository.pruneSentOutboxItemsChunked(
              retention: any(named: 'retention'),
              chunkSize: any(named: 'chunkSize'),
              vacuumWhenDone: any(named: 'vacuumWhenDone'),
              onProgress: any(named: 'onProgress'),
            ),
          ).thenAnswer((_) async => throw StateError('db gone'));

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
            activityGate: createGate(),
            ownsActivityGate: false,
          );
          addTearDown(() async {
            await svc.dispose();
            async.flushMicrotasks();
          });

          async
            ..elapse(const Duration(seconds: 31))
            ..flushMicrotasks();

          verify(
            () => loggingService.error(
              LogDomain.sync,
              any<Object>(),
              stackTrace: any<StackTrace>(named: 'stackTrace'),
              subDomain: 'prune',
            ),
          ).called(1);
        });
      },
    );

    test(
      'dispose cancels the periodic prune timer — after dispose no further '
      'prune fires even when time advances past the interval',
      () {
        fakeAsync((async) {
          when(
            () => repository.pruneSentOutboxItemsChunked(
              retention: any(named: 'retention'),
              chunkSize: any(named: 'chunkSize'),
              vacuumWhenDone: any(named: 'vacuumWhenDone'),
              onProgress: any(named: 'onProgress'),
            ),
          ).thenAnswer((_) async => 0);

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
            activityGate: createGate(),
            ownsActivityGate: false,
          );

          async
            ..elapse(const Duration(seconds: 31))
            ..flushMicrotasks();
          // Startup prune fired once.
          verify(
            () => repository.pruneSentOutboxItemsChunked(
              retention: any(named: 'retention'),
              chunkSize: any(named: 'chunkSize'),
              vacuumWhenDone: any(named: 'vacuumWhenDone'),
              onProgress: any(named: 'onProgress'),
            ),
          ).called(1);

          unawaited(svc.dispose());
          async.flushMicrotasks();

          // Advance past a full prune interval — nothing should fire.
          async
            ..elapse(SyncTuning.outboxPruneInterval + const Duration(hours: 1))
            ..flushMicrotasks();
          verifyNever(
            () => repository.pruneSentOutboxItemsChunked(
              retention: any(named: 'retention'),
              chunkSize: any(named: 'chunkSize'),
              vacuumWhenDone: any(named: 'vacuumWhenDone'),
              onProgress: any(named: 'onProgress'),
            ),
          );
        });
      },
    );
  });

  group('outbox bundling wiring', () {
    glados.Glados(
      glados.any.priorityScenario,
      glados.ExploreConfig(numRuns: 160),
    ).test(
      'generated priority classification is stable across sync message shapes',
      (scenario) {
        final message = scenario.message;
        final roundTrip = SyncMessage.fromJson(
          jsonDecode(jsonEncode(message)) as Map<String, dynamic>,
        );

        expect(
          OutboxService.priorityForMessageForTesting(message),
          scenario.expectedPriority,
        );
        expect(
          OutboxService.priorityForMessageForTesting(roundTrip),
          scenario.expectedPriority,
        );
      },
      tags: 'glados',
    );

    test(
      'priorityForMessageForTesting maps SyncOutboxBundle to normal priority '
      '— bundles never reach this path in production (the enqueue dispatch '
      'switch throws first), but a benign default keeps the priority lookup '
      'side-effect-free if some future caller does pass one',
      () {
        expect(
          OutboxService.priorityForMessageForTesting(
            const SyncMessage.outboxBundle(children: []),
          ),
          OutboxPriority.normal.index,
        );
      },
    );

    test(
      'enqueueMessage(SyncOutboxBundle) throws StateError to the caller — '
      'the early guard rejects the invariant breach instead of swallowing '
      'it inside the routine enqueue try/catch, so a buggy caller fails '
      'loudly in tests/CI rather than producing a silent drop in prod',
      () async {
        await expectLater(
          service.enqueueMessage(
            const SyncMessage.outboxBundle(children: []),
          ),
          throwsStateError,
        );
        verifyNever(() => syncDatabase.addOutboxItem(any()));
      },
    );
  });
}

NotificationEntity _testNotification({
  required String id,
  required VectorClock vectorClock,
}) {
  final timestamp = DateTime.utc(2026, 5, 17, 10);
  return NotificationEntity.taskSuggestion(
    meta: NotificationMeta(
      id: id,
      createdAt: timestamp,
      updatedAt: timestamp,
      scheduledFor: timestamp,
      vectorClock: vectorClock,
      originatingHostId: 'hostA',
    ),
    linkedTaskId: 'task-$id',
    suggestionCount: 2,
    title: 'Review suggestions',
    body: 'Two tasks need review',
  );
}
