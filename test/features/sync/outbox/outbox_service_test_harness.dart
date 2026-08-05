import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/outbox/outbox_processor.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/features/user_activity/state/user_activity_gate.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/consts.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

export 'dart:async';
export 'dart:convert';
export 'dart:io';

export 'package:clock/clock.dart';
export 'package:connectivity_plus/connectivity_plus.dart';
export 'package:fake_async/fake_async.dart';
export 'package:flutter/services.dart';
export 'package:flutter_test/flutter_test.dart';
export 'package:lotti/classes/checklist_data.dart';
export 'package:lotti/classes/entity_definitions.dart';
export 'package:lotti/classes/entry_link.dart';
export 'package:lotti/classes/entry_text.dart';
export 'package:lotti/classes/journal_entities.dart';
export 'package:lotti/classes/notification_entity.dart';
export 'package:lotti/database/sync_db.dart';
export 'package:lotti/features/agents/model/agent_config.dart';
export 'package:lotti/features/agents/model/agent_domain_entity.dart';
export 'package:lotti/features/agents/model/agent_enums.dart';
export 'package:lotti/features/agents/model/agent_link.dart';
export 'package:lotti/features/ai/model/ai_config.dart';
export 'package:lotti/features/journal/state/journal_page_state.dart';
export 'package:lotti/features/sync/model/sync_message.dart';
export 'package:lotti/features/sync/model/sync_node_profile.dart';
export 'package:lotti/features/sync/outbox/outbox_processor.dart';
export 'package:lotti/features/sync/outbox/outbox_service.dart';
export 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
export 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
export 'package:lotti/features/sync/state/outbox_state_controller.dart';
export 'package:lotti/features/sync/tuning.dart';
export 'package:lotti/features/sync/vector_clock.dart';
export 'package:lotti/features/tasks/state/saved_filters/saved_task_filter.dart';
export 'package:lotti/features/user_activity/state/user_activity_gate.dart';
export 'package:lotti/get_it.dart';
export 'package:lotti/services/domain_logging.dart';
export 'package:lotti/utils/consts.dart';
export 'package:lotti/utils/file_utils.dart';
export 'package:lotti/utils/image_utils.dart';
export 'package:matrix/matrix.dart';
export 'package:mocktail/mocktail.dart';

export '../../../mocks/mocks.dart';
export '../../ai_consumption/test_utils.dart';

class TestableOutboxService extends MatrixOutboxService {
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

/// Builds the OutboxService variant used by the sequence-log groups —
/// standard collaborators + activity gate, with an optional sequence log.
OutboxService buildSequenceLogService({
  required MockSyncDatabase syncDatabase,
  required MockDomainLogger loggingService,
  required MockVectorClockService vectorClockService,
  required MockJournalDb journalDb,
  required Directory documentsDirectory,
  required MockUserActivityService userActivityService,
  required MockOutboxRepository repository,
  required MockOutboxMessageSender messageSender,
  required MockOutboxProcessor processor,
  required UserActivityGate gate,
  SyncSequenceLogService? sequenceLogService,
}) {
  return MatrixOutboxService(
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
    sequenceLogService: sequenceLogService,
  );
}

/// Builds a [MockMatrixService] with the standard client/login-state wiring.
MockMatrixService stubMatrixService({
  LoginState loginState = LoginState.loggedOut,
  Stream<LoginState>? loginStream,
}) {
  final matrixService = MockMatrixService();
  final client = MockMatrixClient();
  final cached = MockCachedLoginController();
  when(
    () => cached.stream,
  ).thenAnswer((_) => loginStream ?? const Stream<LoginState>.empty());
  when(() => cached.value).thenReturn(loginState);
  when(() => client.onLoginStateChanged).thenReturn(cached);
  when(() => matrixService.client).thenReturn(client);
  return matrixService;
}

/// Single source of truth for the watchdog cadence in fake-time tests.
const Duration watchdogInterval = SyncTuning.outboxWatchdogInterval;

const _connectivityMethodChannel = MethodChannel(
  'dev.fluttercommunity.plus/connectivity',
);

void configureOutboxServiceTestSuite() {
  registerAllFallbackValues();
  registerFallbackValue(Exception('fallback'));
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_connectivityMethodChannel, (
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
}

/// Shared lifecycle and collaborators for the outbox facade satellites.
class OutboxServiceTestHarness {
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

  TestableOutboxService buildService({
    UserActivityGate? activityGate,
    bool? ownsActivityGate,
    SyncSequenceLogService? sequenceLogService,
    Future<void> Function(String path, String json)? saveJsonHandler,
    Duration postDrainSettle = Duration.zero,
  }) {
    return TestableOutboxService(
      syncDatabase: syncDatabase,
      loggingService: loggingService,
      vectorClockService: vectorClockService,
      journalDb: journalDb,
      documentsDirectory: documentsDirectory,
      userActivityService: userActivityService,
      repository: repository,
      messageSender: messageSender,
      processor: processor,
      activityGate: activityGate,
      ownsActivityGate: ownsActivityGate,
      sequenceLogService: sequenceLogService,
      saveJsonHandler: saveJsonHandler,
      postDrainSettle: postDrainSettle,
    );
  }

  Future<void> setUp() async {
    syncDatabase = MockSyncDatabase();
    loggingService = MockDomainLogger();
    when(
      () => loggingService.logSampled(
        any<LogDomain>(),
        any<String>(),
        sampleKey: any<String>(named: 'sampleKey'),
        subDomain: any<String?>(named: 'subDomain'),
        level: any(named: 'level'),
        every: any<int>(named: 'every'),
        maxInterval: any<Duration>(named: 'maxInterval'),
      ),
    ).thenAnswer((invocation) {
      loggingService.log(
        invocation.positionalArguments[0] as LogDomain,
        invocation.positionalArguments[1] as String,
        subDomain: invocation.namedArguments[#subDomain] as String?,
      );
    });
    repository = MockOutboxRepository();
    messageSender = MockOutboxMessageSender();
    processor = MockOutboxProcessor();
    journalDb = MockJournalDb();
    vectorClockService = MockVectorClockService();
    userActivityService = MockUserActivityService();
    documentsDirectory = Directory.systemTemp.createTempSync(
      'outbox_service_test_',
    );
    await setUpTestGetIt(
      additionalSetup: () {
        getIt.registerSingleton<Directory>(documentsDirectory);
      },
    );

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
    when(
      () => syncDatabase.watchOutboxCount(),
    ).thenAnswer((_) => const Stream<int>.empty());
    when(
      () => syncDatabase.findPendingByEntryId(any()),
    ).thenAnswer((_) async => null);
    when(
      () => repository.pruneSentOutboxItems(retention: any(named: 'retention')),
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
    when(
      () => journalDb.getConfigFlag(resendAttachments),
    ).thenAnswer((_) async => false);
    when(
      () => userActivityService.lastActivity,
    ).thenReturn(DateTime(2024, 3, 15, 10, 30));
    when(
      () => userActivityService.activityStream,
    ).thenAnswer((_) => const Stream<DateTime>.empty());

    service = buildService(activityGate: createGate(), ownsActivityGate: false);
  }

  Future<void> tearDown(TestableOutboxService currentService) async {
    await currentService.dispose();
    if (documentsDirectory.existsSync()) {
      documentsDirectory.deleteSync(recursive: true);
    }
    await tearDownTestGetIt();
  }
}
