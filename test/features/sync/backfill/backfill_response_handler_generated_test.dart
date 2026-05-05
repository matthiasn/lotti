// ignore_for_file: unnecessary_lambdas

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/backfill/backfill_response_handler.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../features/agents/test_utils.dart';
import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

enum _GeneratedRequestHost { own, foreign }

enum _GeneratedLogEntryShape { absent, withoutEntryId, withEntryId }

enum _GeneratedPayloadShape { deleted, exact, ahead, behind, missingHost }

enum _ExpectedMessageKind { payload, deleted, unresolvable, hint }

class _GeneratedBackfillResponseScenario {
  const _GeneratedBackfillResponseScenario({
    required this.payloadType,
    required this.requestHost,
    required this.logEntryShape,
    required this.payloadShape,
    required this.requestedCounter,
    required this.counterDelta,
  });

  final SyncSequencePayloadType payloadType;
  final _GeneratedRequestHost requestHost;
  final _GeneratedLogEntryShape logEntryShape;
  final _GeneratedPayloadShape payloadShape;
  final int requestedCounter;
  final int counterDelta;

  String get payloadId => 'generated-${payloadType.name}-payload';

  String hostId({
    required String ownHostId,
    required String foreignHostId,
  }) {
    return switch (requestHost) {
      _GeneratedRequestHost.own => ownHostId,
      _GeneratedRequestHost.foreign => foreignHostId,
    };
  }

  VectorClock? vectorClockFor(String hostId) {
    return switch (payloadShape) {
      _GeneratedPayloadShape.deleted => null,
      _GeneratedPayloadShape.exact => VectorClock({hostId: requestedCounter}),
      _GeneratedPayloadShape.ahead => VectorClock({
        hostId: requestedCounter + counterDelta,
      }),
      _GeneratedPayloadShape.behind => VectorClock({
        hostId: requestedCounter - _boundedDelta,
      }),
      _GeneratedPayloadShape.missingHost => const VectorClock({
        'unrelated-host': 1,
      }),
    };
  }

  List<_ExpectedMessageKind> get expectedMessages {
    return switch (logEntryShape) {
      _GeneratedLogEntryShape.absent ||
      _GeneratedLogEntryShape.withoutEntryId => switch (requestHost) {
        _GeneratedRequestHost.own => const [_ExpectedMessageKind.unresolvable],
        _GeneratedRequestHost.foreign => const [],
      },
      _GeneratedLogEntryShape.withEntryId => switch (payloadShape) {
        _GeneratedPayloadShape.deleted => const [_ExpectedMessageKind.deleted],
        _GeneratedPayloadShape.exact => const [_ExpectedMessageKind.payload],
        _GeneratedPayloadShape.ahead => const [
          _ExpectedMessageKind.payload,
          _ExpectedMessageKind.hint,
        ],
        _GeneratedPayloadShape.behind ||
        _GeneratedPayloadShape.missingHost => switch (requestHost) {
          _GeneratedRequestHost.own => const [
            _ExpectedMessageKind.unresolvable,
          ],
          _GeneratedRequestHost.foreign => const [],
        },
      },
    };
  }

  bool get expectsOwnUnresolvableWrite =>
      requestHost == _GeneratedRequestHost.own &&
      expectedMessages.contains(_ExpectedMessageKind.unresolvable);

  SyncSequencePayloadType get expectedOwnUnresolvablePayloadType {
    return logEntryShape != _GeneratedLogEntryShape.absent
        ? payloadType
        : SyncSequencePayloadType.journalEntity;
  }

  SyncSequencePayloadType? get expectedUnresolvableResponsePayloadType {
    return logEntryShape == _GeneratedLogEntryShape.absent ? null : payloadType;
  }

  int get _boundedDelta => (counterDelta % requestedCounter) + 1;

  @override
  String toString() {
    return '_GeneratedBackfillResponseScenario('
        'payloadType: $payloadType, '
        'requestHost: $requestHost, '
        'logEntryShape: $logEntryShape, '
        'payloadShape: $payloadShape, '
        'requestedCounter: $requestedCounter, '
        'counterDelta: $counterDelta'
        ')';
  }
}

class _GeneratedBackfillResponseBench {
  _GeneratedBackfillResponseBench._({
    required this.journalDb,
    required this.sequenceService,
    required this.outboxService,
    required this.agentRepository,
    required this.handler,
  });

  factory _GeneratedBackfillResponseBench.create({
    required String ownHostId,
  }) {
    SharedPreferences.setMockInitialValues({'backfill_enabled': true});

    final journalDb = MockJournalDb();
    final sequenceService = MockSyncSequenceLogService();
    final outboxService = MockOutboxService();
    final logging = MockLoggingService();
    final vcService = MockVectorClockService();
    final agentRepository = MockAgentRepository();
    final handler = BackfillResponseHandler(
      journalDb: journalDb,
      sequenceLogService: sequenceService,
      outboxService: outboxService,
      loggingService: logging,
      vectorClockService: vcService,
    )..agentRepository = agentRepository;

    final bench = _GeneratedBackfillResponseBench._(
      journalDb: journalDb,
      sequenceService: sequenceService,
      outboxService: outboxService,
      agentRepository: agentRepository,
      handler: handler,
    );

    when(
      () => logging.captureEvent(
        any<String>(),
        domain: any(named: 'domain'),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenReturn(null);
    when(
      () => logging.captureException(
        any<Object>(),
        domain: any(named: 'domain'),
        subDomain: any(named: 'subDomain'),
        stackTrace: any<StackTrace?>(named: 'stackTrace'),
      ),
    ).thenAnswer((_) async {});
    when(() => vcService.initialized).thenAnswer(Future<void>.value);
    when(() => vcService.getHost()).thenAnswer((_) async => ownHostId);
    when(
      () => sequenceService.getNearestCoveringEntry(any(), any()),
    ).thenAnswer((_) async => null);
    when(
      () => sequenceService.markOwnCounterUnresolvable(
        hostId: any(named: 'hostId'),
        counter: any(named: 'counter'),
        payloadType: any(named: 'payloadType'),
      ),
    ).thenAnswer((invocation) async {
      bench.markedOwnUnresolvable.add((
        hostId: invocation.namedArguments[#hostId] as String,
        counter: invocation.namedArguments[#counter] as int,
        payloadType:
            invocation.namedArguments[#payloadType] as SyncSequencePayloadType,
      ));
    });
    when(() => outboxService.enqueueMessage(any())).thenAnswer((
      invocation,
    ) async {
      bench.sentMessages.add(
        invocation.positionalArguments.single as SyncMessage,
      );
    });

    return bench;
  }

  final MockJournalDb journalDb;
  final MockSyncSequenceLogService sequenceService;
  final MockOutboxService outboxService;
  final MockAgentRepository agentRepository;
  final BackfillResponseHandler handler;
  final sentMessages = <SyncMessage>[];
  final markedOwnUnresolvable =
      <({String hostId, int counter, SyncSequencePayloadType payloadType})>[];
}

extension _AnyGeneratedBackfillResponseScenario on glados.Any {
  glados.Generator<SyncSequencePayloadType> get generatedPayloadType =>
      glados.AnyUtils(this).choose(SyncSequencePayloadType.values);

  glados.Generator<_GeneratedRequestHost> get generatedRequestHost =>
      glados.AnyUtils(this).choose(_GeneratedRequestHost.values);

  glados.Generator<_GeneratedLogEntryShape> get generatedLogEntryShape =>
      glados.AnyUtils(this).choose(_GeneratedLogEntryShape.values);

  glados.Generator<_GeneratedPayloadShape> get generatedPayloadShape =>
      glados.AnyUtils(this).choose(_GeneratedPayloadShape.values);

  glados.Generator<_GeneratedBackfillResponseScenario>
  get generatedBackfillResponseScenario => glados.CombinableAny(this).combine6(
    generatedPayloadType,
    generatedRequestHost,
    generatedLogEntryShape,
    generatedPayloadShape,
    glados.IntAnys(this).intInRange(1, 9),
    glados.IntAnys(this).intInRange(1, 5),
    (
      SyncSequencePayloadType payloadType,
      _GeneratedRequestHost requestHost,
      _GeneratedLogEntryShape logEntryShape,
      _GeneratedPayloadShape payloadShape,
      int requestedCounter,
      int counterDelta,
    ) => _GeneratedBackfillResponseScenario(
      payloadType: payloadType,
      requestHost: requestHost,
      logEntryShape: logEntryShape,
      payloadShape: payloadShape,
      requestedCounter: requestedCounter,
      counterDelta: counterDelta,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const ownHostId = 'alice-host-uuid';
  const foreignHostId = 'bob-host-uuid';
  const requesterId = 'requester-uuid';

  setUpAll(registerAllFallbackValues);

  group('BackfillResponseHandler generated decisions', () {
    glados.Glados(
      glados.any.generatedBackfillResponseScenario,
      glados.ExploreConfig(numRuns: 160),
    ).test(
      'matches the generated single-request payload model',
      (scenario) async {
        final bench = _GeneratedBackfillResponseBench.create(
          ownHostId: ownHostId,
        );
        final hostId = scenario.hostId(
          ownHostId: ownHostId,
          foreignHostId: foreignHostId,
        );

        switch (scenario.logEntryShape) {
          case _GeneratedLogEntryShape.absent:
            when(
              () => bench.sequenceService.getEntryByHostAndCounter(
                hostId,
                scenario.requestedCounter,
              ),
            ).thenAnswer((_) async => null);
          case _GeneratedLogEntryShape.withoutEntryId:
            when(
              () => bench.sequenceService.getEntryByHostAndCounter(
                hostId,
                scenario.requestedCounter,
              ),
            ).thenAnswer(
              (_) async => _createLogItem(
                hostId,
                scenario.requestedCounter,
                payloadType: scenario.payloadType,
              ),
            );
          case _GeneratedLogEntryShape.withEntryId:
            when(
              () => bench.sequenceService.getEntryByHostAndCounter(
                hostId,
                scenario.requestedCounter,
              ),
            ).thenAnswer(
              (_) async => _createLogItem(
                hostId,
                scenario.requestedCounter,
                entryId: scenario.payloadId,
                payloadType: scenario.payloadType,
              ),
            );
            _stubPayload(bench, scenario, hostId);
        }

        await bench.handler.handleBackfillRequest(
          SyncBackfillRequest(
            entries: [
              BackfillRequestEntry(
                hostId: hostId,
                counter: scenario.requestedCounter,
              ),
            ],
            requesterId: requesterId,
          ),
        );

        _expectMessages(
          bench.sentMessages,
          scenario.expectedMessages,
          hostId: hostId,
          counter: scenario.requestedCounter,
          payloadType: scenario.payloadType,
          payloadId: scenario.payloadId,
          expectedUnresolvablePayloadType:
              scenario.expectedUnresolvableResponsePayloadType,
        );

        if (scenario.expectsOwnUnresolvableWrite) {
          expect(bench.markedOwnUnresolvable, [
            (
              hostId: hostId,
              counter: scenario.requestedCounter,
              payloadType: scenario.expectedOwnUnresolvablePayloadType,
            ),
          ]);
        } else {
          expect(bench.markedOwnUnresolvable, isEmpty);
        }
      },
    );
  });
}

void _stubPayload(
  _GeneratedBackfillResponseBench bench,
  _GeneratedBackfillResponseScenario scenario,
  String hostId,
) {
  final vectorClock = scenario.vectorClockFor(hostId);

  switch (scenario.payloadType) {
    case SyncSequencePayloadType.journalEntity:
      when(
        () => bench.journalDb.journalEntityById(scenario.payloadId),
      ).thenAnswer(
        (_) async => vectorClock == null
            ? null
            : _createJournalEntry(scenario.payloadId, vectorClock: vectorClock),
      );
    case SyncSequencePayloadType.entryLink:
      when(
        () => bench.journalDb.entryLinkById(scenario.payloadId),
      ).thenAnswer(
        (_) async => vectorClock == null
            ? null
            : _createEntryLink(scenario.payloadId, vectorClock: vectorClock),
      );
    case SyncSequencePayloadType.agentEntity:
      when(
        () => bench.agentRepository.getEntity(scenario.payloadId),
      ).thenAnswer(
        (_) async => vectorClock == null
            ? null
            : makeTestIdentity(
                id: scenario.payloadId,
                vectorClock: vectorClock,
              ),
      );
    case SyncSequencePayloadType.agentLink:
      when(
        () => bench.agentRepository.getLinkById(scenario.payloadId),
      ).thenAnswer(
        (_) async => vectorClock == null
            ? null
            : makeTestBasicLink(
                id: scenario.payloadId,
                vectorClock: vectorClock,
              ),
      );
  }
}

void _expectMessages(
  List<SyncMessage> actual,
  List<_ExpectedMessageKind> expected, {
  required String hostId,
  required int counter,
  required SyncSequencePayloadType payloadType,
  required String payloadId,
  required SyncSequencePayloadType? expectedUnresolvablePayloadType,
}) {
  expect(actual, hasLength(expected.length));
  for (var index = 0; index < expected.length; index++) {
    final message = actual[index];
    switch (expected[index]) {
      case _ExpectedMessageKind.payload:
        _expectPayloadMessage(message, payloadType, payloadId);
      case _ExpectedMessageKind.deleted:
        expect(message, isA<SyncBackfillResponse>());
        final response = message as SyncBackfillResponse;
        expect(response.hostId, hostId);
        expect(response.counter, counter);
        expect(response.deleted, isTrue);
        expect(response.payloadType, payloadType);
      case _ExpectedMessageKind.unresolvable:
        expect(message, isA<SyncBackfillResponse>());
        final response = message as SyncBackfillResponse;
        expect(response.hostId, hostId);
        expect(response.counter, counter);
        expect(response.deleted, isFalse);
        expect(response.unresolvable, isTrue);
        expect(response.payloadType, expectedUnresolvablePayloadType);
      case _ExpectedMessageKind.hint:
        expect(message, isA<SyncBackfillResponse>());
        final response = message as SyncBackfillResponse;
        expect(response.hostId, hostId);
        expect(response.counter, counter);
        expect(response.deleted, isFalse);
        expect(response.unresolvable, isNull);
        expect(
          response.entryId,
          payloadType == SyncSequencePayloadType.journalEntity
              ? payloadId
              : isNull,
        );
        expect(response.payloadId, payloadId);
        expect(response.payloadType, payloadType);
    }
  }
}

void _expectPayloadMessage(
  SyncMessage message,
  SyncSequencePayloadType payloadType,
  String payloadId,
) {
  switch (payloadType) {
    case SyncSequencePayloadType.journalEntity:
      expect(message, isA<SyncJournalEntity>());
      final journalEntity = message as SyncJournalEntity;
      expect(journalEntity.id, payloadId);
      expect(journalEntity.status, SyncEntryStatus.update);
    case SyncSequencePayloadType.entryLink:
      expect(message, isA<SyncEntryLink>());
      final entryLink = message as SyncEntryLink;
      expect(entryLink.entryLink.id, payloadId);
      expect(entryLink.status, SyncEntryStatus.update);
    case SyncSequencePayloadType.agentEntity:
      expect(message, isA<SyncAgentEntity>());
      final agentEntity = message as SyncAgentEntity;
      expect(agentEntity.agentEntity?.id, payloadId);
      expect(agentEntity.status, SyncEntryStatus.update);
    case SyncSequencePayloadType.agentLink:
      expect(message, isA<SyncAgentLink>());
      final agentLink = message as SyncAgentLink;
      expect(agentLink.agentLink?.id, payloadId);
      expect(agentLink.status, SyncEntryStatus.update);
  }
}

SyncSequenceLogItem _createLogItem(
  String hostId,
  int counter, {
  required SyncSequencePayloadType payloadType,
  String? entryId,
}) {
  return SyncSequenceLogItem(
    hostId: hostId,
    counter: counter,
    entryId: entryId,
    payloadType: payloadType.index,
    originatingHostId: hostId,
    status: SyncSequenceStatus.received.index,
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
    requestCount: 0,
  );
}

JournalEntity _createJournalEntry(
  String id, {
  required VectorClock vectorClock,
}) {
  return JournalEntity.journalEntry(
    meta: Metadata(
      id: id,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
      dateFrom: DateTime(2024),
      dateTo: DateTime(2024),
      vectorClock: vectorClock,
    ),
    entryText: const EntryText(plainText: 'Test entry'),
  );
}

EntryLink _createEntryLink(
  String id, {
  required VectorClock vectorClock,
}) {
  return EntryLink.basic(
    id: id,
    fromId: 'from-entry',
    toId: 'to-entry',
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
    vectorClock: vectorClock,
  );
}
