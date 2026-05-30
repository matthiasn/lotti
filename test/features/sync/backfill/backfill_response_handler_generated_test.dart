// ignore_for_file: unnecessary_lambdas

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/backfill/backfill_response_handler.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../features/agents/test_utils.dart';
import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

enum _GeneratedRequestHost { own, foreign }

enum _GeneratedLogEntryShape { absent, withoutEntryId, withEntryId }

enum _GeneratedPayloadShape { deleted, exact, ahead, behind, missingHost }

enum _ExpectedMessageKind { payload, deleted, unresolvable, hint }

enum _GeneratedBatchOrder { sharedFirst, ownMissFirst, foreignMissFirst }

enum _GeneratedBatchCooldownTarget { none, firstShared, ownMiss }

enum _GeneratedIncomingResponseKind { deleted, unresolvable, hint }

enum _GeneratedResponsePayloadIdShape {
  none,
  legacyEntryId,
  payloadId,
  bothDifferent,
}

enum _GeneratedLocalPayloadShape {
  missing,
  withoutVectorClock,
  exact,
  ahead,
  behind,
  missingHost,
}

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

class _GeneratedBackfillBatchScenario {
  const _GeneratedBackfillBatchScenario({
    required this.payloadType,
    required this.sharedRequestHost,
    required this.sharedHighFirst,
    required this.batchOrder,
    required this.cooldownTarget,
    required this.responseSlots,
  });

  static const sharedLowCounter = 1;
  static const sharedHighCounter = 2;
  static const ownMissCounter = 10;
  static const foreignMissCounter = 99;

  final SyncSequencePayloadType payloadType;
  final _GeneratedRequestHost sharedRequestHost;
  final bool sharedHighFirst;
  final _GeneratedBatchOrder batchOrder;
  final _GeneratedBatchCooldownTarget cooldownTarget;
  final int responseSlots;

  String get payloadId => 'batch-${payloadType.name}-${sharedRequestHost.name}';

  int get firstSharedCounter =>
      sharedHighFirst ? sharedHighCounter : sharedLowCounter;

  int get secondSharedCounter =>
      sharedHighFirst ? sharedLowCounter : sharedHighCounter;

  String sharedHostId({
    required String ownHostId,
    required String foreignHostId,
  }) {
    return switch (sharedRequestHost) {
      _GeneratedRequestHost.own => ownHostId,
      _GeneratedRequestHost.foreign => foreignHostId,
    };
  }

  Set<String> initialCooldownKeys({
    required String ownHostId,
    required String foreignHostId,
  }) {
    final sharedHost = sharedHostId(
      ownHostId: ownHostId,
      foreignHostId: foreignHostId,
    );
    return switch (cooldownTarget) {
      _GeneratedBatchCooldownTarget.none => const {},
      _GeneratedBatchCooldownTarget.firstShared => {
        _cooldownKey(sharedHost, firstSharedCounter),
      },
      _GeneratedBatchCooldownTarget.ownMiss => {
        _cooldownKey(ownHostId, ownMissCounter),
      },
    };
  }

  List<BackfillRequestEntry> requestEntries({
    required String ownHostId,
    required String foreignHostId,
  }) {
    final sharedHost = sharedHostId(
      ownHostId: ownHostId,
      foreignHostId: foreignHostId,
    );
    final firstShared = BackfillRequestEntry(
      hostId: sharedHost,
      counter: firstSharedCounter,
    );
    final secondShared = BackfillRequestEntry(
      hostId: sharedHost,
      counter: secondSharedCounter,
    );
    final duplicateFirstShared = BackfillRequestEntry(
      hostId: sharedHost,
      counter: firstSharedCounter,
    );
    final ownMiss = BackfillRequestEntry(
      hostId: ownHostId,
      counter: ownMissCounter,
    );
    final foreignMiss = BackfillRequestEntry(
      hostId: foreignHostId,
      counter: foreignMissCounter,
    );

    return switch (batchOrder) {
      _GeneratedBatchOrder.sharedFirst => [
        firstShared,
        secondShared,
        duplicateFirstShared,
        foreignMiss,
        ownMiss,
      ],
      _GeneratedBatchOrder.ownMissFirst => [
        ownMiss,
        firstShared,
        foreignMiss,
        secondShared,
        duplicateFirstShared,
      ],
      _GeneratedBatchOrder.foreignMissFirst => [
        foreignMiss,
        firstShared,
        ownMiss,
        secondShared,
        duplicateFirstShared,
      ],
    };
  }

  _ExpectedBatchOutcome expectedOutcome({
    required String ownHostId,
    required String foreignHostId,
  }) {
    final sharedHost = sharedHostId(
      ownHostId: ownHostId,
      foreignHostId: foreignHostId,
    );
    final cooldownKeys = {
      ...initialCooldownKeys(
        ownHostId: ownHostId,
        foreignHostId: foreignHostId,
      ),
    };
    final messages = <_ExpectedBatchMessage>[];
    final markedOwnUnresolvable =
        <({String hostId, int counter, SyncSequencePayloadType payloadType})>[];
    final sentPayloads = <String>{};
    var slotsRemaining = responseSlots;
    var responses = 0;

    if (slotsRemaining <= 0) {
      return _ExpectedBatchOutcome(
        messages: messages,
        cooldownKeys: cooldownKeys,
        markedOwnUnresolvable: markedOwnUnresolvable,
        responses: responses,
      );
    }

    for (final entry in requestEntries(
      ownHostId: ownHostId,
      foreignHostId: foreignHostId,
    )) {
      final key = _cooldownKey(entry.hostId, entry.counter);
      if (cooldownKeys.contains(key)) {
        continue;
      }

      if (slotsRemaining <= 0) {
        break;
      }

      if (_isSharedPayloadEntry(entry, sharedHost)) {
        responses++;
        slotsRemaining--;
        cooldownKeys.add(key);

        if (sentPayloads.add(payloadId)) {
          messages.add(
            _ExpectedBatchMessage.payload(
              payloadType: payloadType,
              payloadId: payloadId,
            ),
          );
        }

        if (entry.counter != sharedHighCounter) {
          messages.add(
            _ExpectedBatchMessage.hint(
              hostId: sharedHost,
              counter: entry.counter,
              payloadType: payloadType,
              payloadId: payloadId,
            ),
          );
        }
      } else if (entry.hostId == ownHostId && entry.counter == ownMissCounter) {
        responses++;
        slotsRemaining--;
        cooldownKeys.add(key);
        markedOwnUnresolvable.add((
          hostId: ownHostId,
          counter: ownMissCounter,
          payloadType: SyncSequencePayloadType.journalEntity,
        ));
        messages.add(
          _ExpectedBatchMessage.unresolvable(
            hostId: ownHostId,
            counter: ownMissCounter,
            payloadType: null,
          ),
        );
      }
    }

    return _ExpectedBatchOutcome(
      messages: messages,
      cooldownKeys: cooldownKeys,
      markedOwnUnresolvable: markedOwnUnresolvable,
      responses: responses,
    );
  }

  bool _isSharedPayloadEntry(BackfillRequestEntry entry, String sharedHost) {
    return entry.hostId == sharedHost &&
        (entry.counter == sharedLowCounter ||
            entry.counter == sharedHighCounter);
  }

  @override
  String toString() {
    return '_GeneratedBackfillBatchScenario('
        'payloadType: $payloadType, '
        'sharedRequestHost: $sharedRequestHost, '
        'sharedHighFirst: $sharedHighFirst, '
        'batchOrder: $batchOrder, '
        'cooldownTarget: $cooldownTarget, '
        'responseSlots: $responseSlots'
        ')';
  }
}

class _GeneratedHandleBackfillResponseScenario {
  const _GeneratedHandleBackfillResponseScenario({
    required this.explicitPayloadType,
    required this.omitPayloadType,
    required this.responseKind,
    required this.payloadIdShape,
    required this.localPayloadShape,
    required this.agentRepositoryAvailable,
  });

  static const counter = 7;
  static const legacyEntryId = 'legacy-response-entry';
  static const payloadId = 'payload-response-entry';

  final SyncSequencePayloadType explicitPayloadType;
  final bool omitPayloadType;
  final _GeneratedIncomingResponseKind responseKind;
  final _GeneratedResponsePayloadIdShape payloadIdShape;
  final _GeneratedLocalPayloadShape localPayloadShape;
  final bool agentRepositoryAvailable;

  SyncSequencePayloadType get effectivePayloadType => omitPayloadType
      ? SyncSequencePayloadType.journalEntity
      : explicitPayloadType;

  String? get wireEntryId {
    return switch (payloadIdShape) {
      _GeneratedResponsePayloadIdShape.none ||
      _GeneratedResponsePayloadIdShape.payloadId => null,
      _GeneratedResponsePayloadIdShape.legacyEntryId ||
      _GeneratedResponsePayloadIdShape.bothDifferent => legacyEntryId,
    };
  }

  String? get wirePayloadId {
    return switch (payloadIdShape) {
      _GeneratedResponsePayloadIdShape.none ||
      _GeneratedResponsePayloadIdShape.legacyEntryId => null,
      _GeneratedResponsePayloadIdShape.payloadId ||
      _GeneratedResponsePayloadIdShape.bothDifferent => payloadId,
    };
  }

  String? get effectivePayloadId => wirePayloadId ?? wireEntryId;

  bool get isAgentPayload =>
      effectivePayloadType == SyncSequencePayloadType.agentEntity ||
      effectivePayloadType == SyncSequencePayloadType.agentLink;

  bool get isNotificationPayload =>
      effectivePayloadType == SyncSequencePayloadType.notification ||
      effectivePayloadType == SyncSequencePayloadType.notificationStateUpdate;

  bool get canLoadPayload => !isAgentPayload || agentRepositoryAvailable;

  bool get payloadExists =>
      localPayloadShape != _GeneratedLocalPayloadShape.missing;

  VectorClock? vectorClockFor(String hostId) {
    if (localPayloadShape == _GeneratedLocalPayloadShape.withoutVectorClock &&
        isNotificationPayload) {
      return const VectorClock({});
    }

    return switch (localPayloadShape) {
      _GeneratedLocalPayloadShape.missing ||
      _GeneratedLocalPayloadShape.withoutVectorClock => null,
      _GeneratedLocalPayloadShape.exact => VectorClock({hostId: counter}),
      _GeneratedLocalPayloadShape.ahead => VectorClock({hostId: counter + 2}),
      _GeneratedLocalPayloadShape.behind => VectorClock({hostId: counter - 1}),
      _GeneratedLocalPayloadShape.missingHost => const VectorClock({
        'unrelated-host': 1,
      }),
    };
  }

  bool get expectsVerification {
    return responseKind == _GeneratedIncomingResponseKind.hint &&
        effectivePayloadId != null &&
        canLoadPayload &&
        payloadExists &&
        (localPayloadShape != _GeneratedLocalPayloadShape.withoutVectorClock ||
            isNotificationPayload);
  }

  SyncBackfillResponse response(String hostId) {
    return SyncBackfillResponse(
      hostId: hostId,
      counter: counter,
      deleted: responseKind == _GeneratedIncomingResponseKind.deleted,
      unresolvable: responseKind == _GeneratedIncomingResponseKind.unresolvable
          ? true
          : null,
      entryId: wireEntryId,
      payloadId: wirePayloadId,
      payloadType: omitPayloadType ? null : explicitPayloadType,
    );
  }

  @override
  String toString() {
    return '_GeneratedHandleBackfillResponseScenario('
        'explicitPayloadType: $explicitPayloadType, '
        'omitPayloadType: $omitPayloadType, '
        'responseKind: $responseKind, '
        'payloadIdShape: $payloadIdShape, '
        'localPayloadShape: $localPayloadShape, '
        'agentRepositoryAvailable: $agentRepositoryAvailable'
        ')';
  }
}

class _ExpectedBatchOutcome {
  const _ExpectedBatchOutcome({
    required this.messages,
    required this.cooldownKeys,
    required this.markedOwnUnresolvable,
    required this.responses,
  });

  final List<_ExpectedBatchMessage> messages;
  final Set<String> cooldownKeys;
  final List<
    ({String hostId, int counter, SyncSequencePayloadType payloadType})
  >
  markedOwnUnresolvable;
  final int responses;
}

class _ExpectedBatchMessage {
  const _ExpectedBatchMessage._({
    required this.kind,
    required this.hostId,
    required this.counter,
    required this.payloadType,
    required this.payloadId,
  });

  const _ExpectedBatchMessage.payload({
    required SyncSequencePayloadType payloadType,
    required String payloadId,
  }) : this._(
         kind: _ExpectedMessageKind.payload,
         hostId: null,
         counter: null,
         payloadType: payloadType,
         payloadId: payloadId,
       );

  const _ExpectedBatchMessage.hint({
    required String hostId,
    required int counter,
    required SyncSequencePayloadType payloadType,
    required String payloadId,
  }) : this._(
         kind: _ExpectedMessageKind.hint,
         hostId: hostId,
         counter: counter,
         payloadType: payloadType,
         payloadId: payloadId,
       );

  const _ExpectedBatchMessage.unresolvable({
    required String hostId,
    required int counter,
    required SyncSequencePayloadType? payloadType,
  }) : this._(
         kind: _ExpectedMessageKind.unresolvable,
         hostId: hostId,
         counter: counter,
         payloadType: payloadType,
         payloadId: null,
       );

  final _ExpectedMessageKind kind;
  final String? hostId;
  final int? counter;
  final SyncSequencePayloadType? payloadType;
  final String? payloadId;
}

class _GeneratedBackfillResponseBench {
  _GeneratedBackfillResponseBench._({
    required this.journalDb,
    required this.sequenceService,
    required this.outboxService,
    required this.agentRepository,
    required this.notificationsDb,
    required this.handler,
  });

  factory _GeneratedBackfillResponseBench.create({
    required String ownHostId,
  }) {
    SharedPreferences.setMockInitialValues({'backfill_enabled': true});

    final journalDb = MockJournalDb();
    final sequenceService = MockSyncSequenceLogService();
    final outboxService = MockOutboxService();
    final logging = MockDomainLogger();
    final vcService = MockVectorClockService();
    final agentRepository = MockAgentRepository();
    final notificationsDb = MockNotificationsDb();
    final handler = BackfillResponseHandler(
      journalDb: journalDb,
      sequenceLogService: sequenceService,
      outboxService: outboxService,
      loggingService: logging,
      vectorClockService: vcService,
      notificationsDb: notificationsDb,
    )..agentRepository = agentRepository;

    final bench = _GeneratedBackfillResponseBench._(
      journalDb: journalDb,
      sequenceService: sequenceService,
      outboxService: outboxService,
      agentRepository: agentRepository,
      notificationsDb: notificationsDb,
      handler: handler,
    );

    when(
      () => logging.log(
        any<LogDomain>(),
        any<String>(),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenReturn(null);
    when(
      () => logging.error(
        any<LogDomain>(),
        any<Object>(),
        stackTrace: any<StackTrace?>(named: 'stackTrace'),
        subDomain: any(named: 'subDomain'),
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
    when(
      () => sequenceService.handleBackfillResponse(
        hostId: any(named: 'hostId'),
        counter: any(named: 'counter'),
        deleted: any(named: 'deleted'),
        unresolvable: any(named: 'unresolvable'),
        entryId: any(named: 'entryId'),
        payloadType: any(named: 'payloadType'),
      ),
    ).thenAnswer((invocation) async {
      bench.handledBackfillResponses.add((
        hostId: invocation.namedArguments[#hostId] as String,
        counter: invocation.namedArguments[#counter] as int,
        deleted: invocation.namedArguments[#deleted] as bool,
        unresolvable: invocation.namedArguments[#unresolvable] as bool,
        entryId: invocation.namedArguments[#entryId] as String?,
        payloadType:
            invocation.namedArguments[#payloadType] as SyncSequencePayloadType,
      ));
    });
    when(
      () => sequenceService.verifyAndMarkBackfilled(
        hostId: any(named: 'hostId'),
        counter: any(named: 'counter'),
        entryId: any(named: 'entryId'),
        entryVectorClock: any(named: 'entryVectorClock'),
        payloadType: any(named: 'payloadType'),
      ),
    ).thenAnswer((invocation) async {
      bench.verifiedBackfills.add((
        hostId: invocation.namedArguments[#hostId] as String,
        counter: invocation.namedArguments[#counter] as int,
        entryId: invocation.namedArguments[#entryId] as String,
        entryVectorClock:
            invocation.namedArguments[#entryVectorClock] as VectorClock,
        payloadType:
            invocation.namedArguments[#payloadType] as SyncSequencePayloadType,
      ));
      return true;
    });
    when(() => outboxService.enqueueMessage(any())).thenAnswer((
      invocation,
    ) async {
      bench.sentMessages.add(
        invocation.positionalArguments.single as SyncMessage,
      );
    });
    when(
      () => outboxService.enqueueNotification(
        any(),
        originatingHostId: any(named: 'originatingHostId'),
      ),
    ).thenAnswer((invocation) async {
      final notification =
          invocation.positionalArguments.single as NotificationEntity;
      final originatingHostId =
          invocation.namedArguments[#originatingHostId] as String?;
      bench.sentMessages.add(
        SyncMessage.notification(
          id: notification.meta.id,
          jsonPath: '/notifications/${notification.meta.id}.json',
          vectorClock: notification.meta.vectorClock,
          originatingHostId:
              originatingHostId ?? notification.meta.originatingHostId,
        ),
      );
    });
    when(
      () => outboxService.enqueueNotificationStateUpdate(
        id: any(named: 'id'),
        seenAt: any(named: 'seenAt'),
        actedOnAt: any(named: 'actedOnAt'),
        deletedAt: any(named: 'deletedAt'),
        vectorClock: any(named: 'vectorClock'),
        originatingHostId: any(named: 'originatingHostId'),
      ),
    ).thenAnswer((invocation) async {
      bench.sentMessages.add(
        SyncMessage.notificationStateUpdate(
          id: invocation.namedArguments[#id] as String,
          seenAt: invocation.namedArguments[#seenAt] as DateTime?,
          actedOnAt: invocation.namedArguments[#actedOnAt] as DateTime?,
          deletedAt: invocation.namedArguments[#deletedAt] as DateTime?,
          vectorClock: invocation.namedArguments[#vectorClock] as VectorClock,
          originatingHostId:
              invocation.namedArguments[#originatingHostId] as String,
        ),
      );
    });

    return bench;
  }

  final MockJournalDb journalDb;
  final MockSyncSequenceLogService sequenceService;
  final MockOutboxService outboxService;
  final MockAgentRepository agentRepository;
  final MockNotificationsDb notificationsDb;
  final BackfillResponseHandler handler;
  final sentMessages = <SyncMessage>[];
  final markedOwnUnresolvable =
      <({String hostId, int counter, SyncSequencePayloadType payloadType})>[];
  final handledBackfillResponses =
      <
        ({
          String hostId,
          int counter,
          bool deleted,
          bool unresolvable,
          String? entryId,
          SyncSequencePayloadType payloadType,
        })
      >[];
  final verifiedBackfills =
      <
        ({
          String hostId,
          int counter,
          String entryId,
          VectorClock entryVectorClock,
          SyncSequencePayloadType payloadType,
        })
      >[];
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

  glados.Generator<_GeneratedBatchOrder> get generatedBatchOrder =>
      glados.AnyUtils(this).choose(_GeneratedBatchOrder.values);

  glados.Generator<_GeneratedBatchCooldownTarget>
  get generatedBatchCooldownTarget =>
      glados.AnyUtils(this).choose(_GeneratedBatchCooldownTarget.values);

  glados.Generator<_GeneratedIncomingResponseKind>
  get generatedIncomingResponseKind =>
      glados.AnyUtils(this).choose(_GeneratedIncomingResponseKind.values);

  glados.Generator<_GeneratedResponsePayloadIdShape>
  get generatedResponsePayloadIdShape =>
      glados.AnyUtils(this).choose(_GeneratedResponsePayloadIdShape.values);

  glados.Generator<_GeneratedLocalPayloadShape>
  get generatedLocalPayloadShape =>
      glados.AnyUtils(this).choose(_GeneratedLocalPayloadShape.values);

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

  glados.Generator<_GeneratedBackfillBatchScenario>
  get generatedBackfillBatchScenario => glados.CombinableAny(this).combine6(
    generatedPayloadType,
    generatedRequestHost,
    glados.BoolAny(this).bool,
    generatedBatchOrder,
    generatedBatchCooldownTarget,
    glados.IntAnys(this).intInRange(0, 3),
    (
      SyncSequencePayloadType payloadType,
      _GeneratedRequestHost sharedRequestHost,
      bool sharedHighFirst,
      _GeneratedBatchOrder batchOrder,
      _GeneratedBatchCooldownTarget cooldownTarget,
      int responseSlots,
    ) => _GeneratedBackfillBatchScenario(
      payloadType: payloadType,
      sharedRequestHost: sharedRequestHost,
      sharedHighFirst: sharedHighFirst,
      batchOrder: batchOrder,
      cooldownTarget: cooldownTarget,
      responseSlots: responseSlots,
    ),
  );

  glados.Generator<_GeneratedHandleBackfillResponseScenario>
  get generatedHandleBackfillResponseScenario =>
      glados.CombinableAny(this).combine6(
        generatedPayloadType,
        glados.BoolAny(this).bool,
        generatedIncomingResponseKind,
        generatedResponsePayloadIdShape,
        generatedLocalPayloadShape,
        glados.BoolAny(this).bool,
        (
          SyncSequencePayloadType explicitPayloadType,
          bool omitPayloadType,
          _GeneratedIncomingResponseKind responseKind,
          _GeneratedResponsePayloadIdShape payloadIdShape,
          _GeneratedLocalPayloadShape localPayloadShape,
          bool agentRepositoryAvailable,
        ) => _GeneratedHandleBackfillResponseScenario(
          explicitPayloadType: explicitPayloadType,
          omitPayloadType: omitPayloadType,
          responseKind: responseKind,
          payloadIdShape: payloadIdShape,
          localPayloadShape: localPayloadShape,
          agentRepositoryAvailable: agentRepositoryAvailable,
        ),
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const ownHostId = 'alice-host-uuid';
  const foreignHostId = 'bob-host-uuid';
  const requesterId = 'requester-uuid';

  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(DateTime(2024));
  });

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
      tags: 'glados',
    );
  });

  group('BackfillResponseHandler generated batch behavior', () {
    glados.Glados(
      glados.any.generatedBackfillBatchScenario,
      glados.ExploreConfig(numRuns: 240),
    ).test(
      'matches the generated batch model for dedupe, cooldown, and rate limit',
      (scenario) async {
        final bench = _GeneratedBackfillResponseBench.create(
          ownHostId: ownHostId,
        );
        final sharedHost = scenario.sharedHostId(
          ownHostId: ownHostId,
          foreignHostId: foreignHostId,
        );
        final sharedClock = VectorClock({
          sharedHost: _GeneratedBackfillBatchScenario.sharedHighCounter,
        });

        bench.handler
          ..windowStart = DateTime(9999)
          ..responsesInWindow =
              SyncTuning.backfillResponseRateLimit - scenario.responseSlots;

        for (final key in scenario.initialCooldownKeys(
          ownHostId: ownHostId,
          foreignHostId: foreignHostId,
        )) {
          bench.handler.recentlyResponded[key] = DateTime(9999);
        }

        for (final counter in [
          _GeneratedBackfillBatchScenario.sharedLowCounter,
          _GeneratedBackfillBatchScenario.sharedHighCounter,
        ]) {
          when(
            () => bench.sequenceService.getEntryByHostAndCounter(
              sharedHost,
              counter,
            ),
          ).thenAnswer(
            (_) async => _createLogItem(
              sharedHost,
              counter,
              entryId: scenario.payloadId,
              payloadType: scenario.payloadType,
            ),
          );
        }
        when(
          () => bench.sequenceService.getEntryByHostAndCounter(
            ownHostId,
            _GeneratedBackfillBatchScenario.ownMissCounter,
          ),
        ).thenAnswer((_) async => null);
        when(
          () => bench.sequenceService.getEntryByHostAndCounter(
            foreignHostId,
            _GeneratedBackfillBatchScenario.foreignMissCounter,
          ),
        ).thenAnswer((_) async => null);
        _stubPayloadByType(
          bench,
          payloadType: scenario.payloadType,
          payloadId: scenario.payloadId,
          vectorClock: sharedClock,
        );

        await bench.handler.handleBackfillRequest(
          SyncBackfillRequest(
            entries: scenario.requestEntries(
              ownHostId: ownHostId,
              foreignHostId: foreignHostId,
            ),
            requesterId: requesterId,
          ),
        );

        final expected = scenario.expectedOutcome(
          ownHostId: ownHostId,
          foreignHostId: foreignHostId,
        );

        _expectBatchMessages(bench.sentMessages, expected.messages);
        expect(bench.markedOwnUnresolvable, expected.markedOwnUnresolvable);
        expect(
          bench.handler.recentlyResponded.keys.toSet(),
          expected.cooldownKeys,
        );
        expect(
          bench.handler.responsesInWindow,
          SyncTuning.backfillResponseRateLimit -
              scenario.responseSlots +
              expected.responses,
        );
      },
      tags: 'glados',
    );
  });

  group('BackfillResponseHandler generated response verification', () {
    glados.Glados(
      glados.any.generatedHandleBackfillResponseScenario,
      glados.ExploreConfig(numRuns: 260),
    ).test(
      'matches the generated receive-side verification model',
      (scenario) async {
        final bench = _GeneratedBackfillResponseBench.create(
          ownHostId: ownHostId,
        );

        if (!scenario.agentRepositoryAvailable) {
          bench.handler.agentRepository = null;
        }

        _stubVerificationPayload(bench, scenario, ownHostId);

        await bench.handler.handleBackfillResponse(
          scenario.response(ownHostId),
        );

        expect(bench.handledBackfillResponses, [
          (
            hostId: ownHostId,
            counter: _GeneratedHandleBackfillResponseScenario.counter,
            deleted:
                scenario.responseKind == _GeneratedIncomingResponseKind.deleted,
            unresolvable:
                scenario.responseKind ==
                _GeneratedIncomingResponseKind.unresolvable,
            entryId: scenario.effectivePayloadId,
            payloadType: scenario.effectivePayloadType,
          ),
        ]);

        if (scenario.expectsVerification) {
          expect(bench.verifiedBackfills, hasLength(1));
          final verified = bench.verifiedBackfills.single;
          expect(verified.hostId, ownHostId);
          expect(
            verified.counter,
            _GeneratedHandleBackfillResponseScenario.counter,
          );
          expect(verified.entryId, scenario.effectivePayloadId);
          expect(verified.payloadType, scenario.effectivePayloadType);
          expect(
            verified.entryVectorClock.vclock,
            scenario.vectorClockFor(ownHostId)?.vclock,
          );
        } else {
          expect(bench.verifiedBackfills, isEmpty);
        }
      },
      tags: 'glados',
    );
  });
}

void _stubPayload(
  _GeneratedBackfillResponseBench bench,
  _GeneratedBackfillResponseScenario scenario,
  String hostId,
) {
  _stubPayloadByType(
    bench,
    payloadType: scenario.payloadType,
    payloadId: scenario.payloadId,
    vectorClock: scenario.vectorClockFor(hostId),
  );
}

void _stubPayloadByType(
  _GeneratedBackfillResponseBench bench, {
  required SyncSequencePayloadType payloadType,
  required String payloadId,
  required VectorClock? vectorClock,
}) {
  switch (payloadType) {
    case SyncSequencePayloadType.journalEntity:
      when(
        () => bench.journalDb.journalEntityById(payloadId),
      ).thenAnswer(
        (_) async => vectorClock == null
            ? null
            : _createJournalEntry(payloadId, vectorClock: vectorClock),
      );
    case SyncSequencePayloadType.entryLink:
      when(
        () => bench.journalDb.entryLinkById(payloadId),
      ).thenAnswer(
        (_) async => vectorClock == null
            ? null
            : _createEntryLink(payloadId, vectorClock: vectorClock),
      );
    case SyncSequencePayloadType.agentEntity:
      when(
        () => bench.agentRepository.getEntity(payloadId),
      ).thenAnswer(
        (_) async => vectorClock == null
            ? null
            : makeTestIdentity(
                id: payloadId,
                vectorClock: vectorClock,
              ),
      );
    case SyncSequencePayloadType.agentLink:
      when(
        () => bench.agentRepository.getLinkById(payloadId),
      ).thenAnswer(
        (_) async => vectorClock == null
            ? null
            : makeTestBasicLink(
                id: payloadId,
                vectorClock: vectorClock,
              ),
      );
    case SyncSequencePayloadType.notification:
    case SyncSequencePayloadType.notificationStateUpdate:
      when(
        () => bench.notificationsDb.notificationById(payloadId),
      ).thenAnswer(
        (_) async => vectorClock == null
            ? null
            : _createNotification(payloadId, vectorClock: vectorClock),
      );
  }
}

void _stubVerificationPayload(
  _GeneratedBackfillResponseBench bench,
  _GeneratedHandleBackfillResponseScenario scenario,
  String hostId,
) {
  final payloadId = scenario.effectivePayloadId;
  if (payloadId == null || !scenario.canLoadPayload) {
    return;
  }

  final vectorClock = scenario.vectorClockFor(hostId);

  switch (scenario.effectivePayloadType) {
    case SyncSequencePayloadType.journalEntity:
      when(
        () => bench.journalDb.journalEntityById(payloadId),
      ).thenAnswer(
        (_) async => scenario.payloadExists
            ? _createJournalEntry(payloadId, vectorClock: vectorClock)
            : null,
      );
    case SyncSequencePayloadType.entryLink:
      when(
        () => bench.journalDb.entryLinkById(payloadId),
      ).thenAnswer(
        (_) async => scenario.payloadExists
            ? _createEntryLink(payloadId, vectorClock: vectorClock)
            : null,
      );
    case SyncSequencePayloadType.agentEntity:
      when(
        () => bench.agentRepository.getEntity(payloadId),
      ).thenAnswer(
        (_) async => scenario.payloadExists
            ? makeTestIdentity(id: payloadId, vectorClock: vectorClock)
            : null,
      );
    case SyncSequencePayloadType.agentLink:
      when(
        () => bench.agentRepository.getLinkById(payloadId),
      ).thenAnswer(
        (_) async => scenario.payloadExists
            ? makeTestBasicLink(id: payloadId, vectorClock: vectorClock)
            : null,
      );
    case SyncSequencePayloadType.notification:
    case SyncSequencePayloadType.notificationStateUpdate:
      when(
        () => bench.notificationsDb.notificationById(payloadId),
      ).thenAnswer(
        (_) async => scenario.payloadExists
            ? _createNotification(payloadId, vectorClock: vectorClock!)
            : null,
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

void _expectBatchMessages(
  List<SyncMessage> actual,
  List<_ExpectedBatchMessage> expected,
) {
  expect(actual, hasLength(expected.length));
  for (var index = 0; index < expected.length; index++) {
    final message = actual[index];
    final expectedMessage = expected[index];

    switch (expectedMessage.kind) {
      case _ExpectedMessageKind.payload:
        _expectPayloadMessage(
          message,
          expectedMessage.payloadType!,
          expectedMessage.payloadId!,
        );
      case _ExpectedMessageKind.hint:
        expect(message, isA<SyncBackfillResponse>());
        final response = message as SyncBackfillResponse;
        expect(response.hostId, expectedMessage.hostId);
        expect(response.counter, expectedMessage.counter);
        expect(response.deleted, isFalse);
        expect(response.unresolvable, isNull);
        expect(response.payloadType, expectedMessage.payloadType);
        expect(response.payloadId, expectedMessage.payloadId);
        expect(
          response.entryId,
          expectedMessage.payloadType == SyncSequencePayloadType.journalEntity
              ? expectedMessage.payloadId
              : isNull,
        );
      case _ExpectedMessageKind.unresolvable:
        expect(message, isA<SyncBackfillResponse>());
        final response = message as SyncBackfillResponse;
        expect(response.hostId, expectedMessage.hostId);
        expect(response.counter, expectedMessage.counter);
        expect(response.deleted, isFalse);
        expect(response.unresolvable, isTrue);
        expect(response.payloadType, expectedMessage.payloadType);
      case _ExpectedMessageKind.deleted:
        fail('Batch generated model does not emit deleted expectations');
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
    case SyncSequencePayloadType.notification:
      expect(message, isA<SyncNotification>());
      final notification = message as SyncNotification;
      expect(notification.id, payloadId);
      expect(notification.jsonPath, '/notifications/$payloadId.json');
    case SyncSequencePayloadType.notificationStateUpdate:
      expect(message, isA<SyncNotificationStateUpdate>());
      final stateUpdate = message as SyncNotificationStateUpdate;
      expect(stateUpdate.id, payloadId);
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

String _cooldownKey(String hostId, int counter) => '$hostId:$counter';

JournalEntity _createJournalEntry(
  String id, {
  required VectorClock? vectorClock,
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
  required VectorClock? vectorClock,
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

NotificationEntity _createNotification(
  String id, {
  required VectorClock vectorClock,
}) {
  final timestamp = DateTime(2024);
  return NotificationEntity.taskSuggestion(
    meta: NotificationMeta(
      id: id,
      createdAt: timestamp,
      updatedAt: timestamp,
      scheduledFor: timestamp,
      seenAt: timestamp,
      vectorClock: vectorClock,
      originatingHostId: 'host',
    ),
    linkedTaskId: 'task-$id',
    suggestionCount: 1,
    title: 'Generated notification',
    body: 'Generated body',
  );
}
