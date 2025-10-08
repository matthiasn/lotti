import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/sync/outbox_state.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_processor.dart';
import 'package:lotti/features/sync/outbox/outbox_repository.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/features/user_activity/state/user_activity_gate.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:mocktail/mocktail.dart';

class MockSyncDatabase extends Mock implements SyncDatabase {}

class MockLoggingService extends Mock implements LoggingService {}

class MockUserActivityGate extends Mock implements UserActivityGate {}

class MockUserActivityService extends Mock implements UserActivityService {}

class MockOutboxRepository extends Mock implements OutboxRepository {}

class MockOutboxMessageSender extends Mock implements OutboxMessageSender {}

class MockOutboxProcessor extends Mock implements OutboxProcessor {}

class MockJournalDb extends Mock implements JournalDb {}

class MockVectorClockService extends Mock implements VectorClockService {}

class MockMatrixService extends Mock implements MatrixService {}

class TestableOutboxService extends OutboxService {
  TestableOutboxService({
    required super.syncDatabase,
    required super.loggingService,
    required super.vectorClockService,
    required super.journalDb,
    required super.documentsDirectory,
    required super.userActivityService,
    required super.repository,
    required super.messageSender,
    required super.processor,
    super.activityGate,
    super.ownsActivityGate,
  });

  int enqueueCalls = 0;
  Duration? lastDelay;

  @override
  Future<void> enqueueNextSendRequest({
    Duration? delay,
  }) async {
    enqueueCalls++;
    lastDelay = delay ?? const Duration(milliseconds: 1);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const connectivityMethodChannel =
      MethodChannel('dev.fluttercommunity.plus/connectivity');

  setUpAll(() {
    registerFallbackValue(const SyncMessage.aiConfigDelete(id: 'fallback'));
    registerFallbackValue(const OutboxCompanion());
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

    registerFallbackValue(StackTrace.empty);
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
    when(() => vectorClockService.getHostHash())
        .thenAnswer((_) async => 'hostHash');
    when(() => vectorClockService.getHost()).thenAnswer((_) async => 'host');
    when(() => userActivityService.lastActivity).thenReturn(DateTime.now());
    when(() => userActivityService.activityStream)
        .thenAnswer((_) => const Stream<DateTime>.empty());
  });

  tearDown(() {
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

  test('dispose closes owned activity gate', () async {
    final ownedGate = MockUserActivityGate();
    when(ownedGate.waitUntilIdle).thenAnswer((_) async {});
    when(ownedGate.dispose).thenAnswer((_) async {});

    final service = OutboxService(
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

    await service.dispose();

    verify(ownedGate.dispose).called(1);
  });

  test('dispose does not close externally provided activity gate', () async {
    final externalGate = MockUserActivityGate();
    when(externalGate.waitUntilIdle).thenAnswer((_) async {});
    when(externalGate.dispose).thenAnswer((_) async {});

    final service = OutboxService(
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

    await service.dispose();

    verifyNever(externalGate.dispose);
  });

  group('enqueueMessage', () {
    test('stores relative attachment path for initial journal entry', () async {
      final capturedCompanions = <OutboxCompanion>[];
      when(() => syncDatabase.addOutboxItem(any<OutboxCompanion>()))
          .thenAnswer((invocation) async {
        capturedCompanions
            .add(invocation.positionalArguments.first as OutboxCompanion);
        return 1;
      });

      final service = TestableOutboxService(
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
        vectorClock: const VectorClock({'host': 1}),
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

      await service.enqueueMessage(
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
      expect(companion.subject.value, 'hostHash:1');
      expect(companion.status.value, OutboxStatus.pending.index);
      verify(() => syncDatabase.addOutboxItem(any<OutboxCompanion>())).called(1);
    });
  });

  group('sendNext', () {
    test('skips processing when Matrix disabled', () async {
      when(() => journalDb.getConfigFlag(enableMatrixFlag))
          .thenAnswer((_) async => false);

      final gate = MockUserActivityGate();
      when(gate.waitUntilIdle).thenAnswer((_) async {});
      when(gate.dispose).thenAnswer((_) async {});

      final service = TestableOutboxService(
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

      await service.sendNext();

      verifyNever(() => processor.processQueue());
      expect(service.enqueueCalls, 0);

      await service.dispose();
    });

    test('schedules next run when processor requests it', () async {
      when(() => journalDb.getConfigFlag(enableMatrixFlag))
          .thenAnswer((_) async => true);
      when(() => processor.processQueue()).thenAnswer(
        (_) async => OutboxProcessingResult.schedule(
          const Duration(seconds: 3),
        ),
      );

      final gate = MockUserActivityGate();
      when(gate.waitUntilIdle).thenAnswer((_) async {});
      when(gate.dispose).thenAnswer((_) async {});

      final service = TestableOutboxService(
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

      await service.sendNext();

      verify(() => processor.processQueue()).called(1);
      expect(service.enqueueCalls, 1);
      expect(service.lastDelay, const Duration(seconds: 3));

      await service.dispose();
    });

    test('does not reschedule when queue empty', () async {
      when(() => journalDb.getConfigFlag(enableMatrixFlag))
          .thenAnswer((_) async => true);
      when(() => processor.processQueue())
          .thenAnswer((_) async => OutboxProcessingResult.none);

      final gate = MockUserActivityGate();
      when(gate.waitUntilIdle).thenAnswer((_) async {});
      when(gate.dispose).thenAnswer((_) async {});

      final service = TestableOutboxService(
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

      await service.sendNext();

      expect(service.enqueueCalls, 0);
      await service.dispose();
    });

    test('logs error and reschedules on failure', () async {
      when(() => journalDb.getConfigFlag(enableMatrixFlag))
          .thenAnswer((_) async => true);
      final exception = Exception('boom');
      when(() => processor.processQueue()).thenThrow(exception);

      final gate = MockUserActivityGate();
      when(gate.waitUntilIdle).thenAnswer((_) async {});
      when(gate.dispose).thenAnswer((_) async {});

      final service = TestableOutboxService(
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

      await service.sendNext();

      verify(
        () => loggingService.captureException(
          exception,
          domain: 'OUTBOX',
          subDomain: 'sendNext',
          stackTrace: any<StackTrace>(named: 'stackTrace'),
        ),
      ).called(1);
      expect(service.enqueueCalls, 1);
      expect(service.lastDelay, const Duration(seconds: 15));

      await service.dispose();
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

    final service = OutboxService(
      syncDatabase: syncDatabase,
      loggingService: loggingService,
      vectorClockService: vectorClockService,
      journalDb: journalDb,
      documentsDirectory: documentsDirectory,
      userActivityService: userActivityService,
      matrixService: matrixService,
    );

    await service.dispose();
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
}
