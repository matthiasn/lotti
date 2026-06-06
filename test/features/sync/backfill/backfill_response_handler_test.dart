import 'package:clock/clock.dart';
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

// ignore_for_file: unnecessary_lambdas

// ---------------------------------------------------------------------------
// Declarations moved from backfill_response_handler_generated_test.dart
// ---------------------------------------------------------------------------

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

  late MockJournalDb mockJournalDb;
  late MockSyncSequenceLogService mockSequenceService;
  late MockOutboxService mockOutboxService;
  late MockDomainLogger mockLogging;
  late MockVectorClockService mockVcService;
  late MockAgentRepository mockAgentRepository;
  late BackfillResponseHandler handler;

  const aliceHostId = 'alice-host-uuid';
  const bobHostId = 'bob-host-uuid';
  const requesterId = 'requester-uuid';
  const entryId = 'test-entry-id';

  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(
      const SyncMessage.backfillRequest(
        entries: [],
        requesterId: '',
      ),
    );
    registerFallbackValue(
      const SyncMessage.backfillResponse(
        hostId: '',
        counter: 0,
        deleted: false,
      ),
    );
    registerFallbackValue(
      SyncMessage.entryLink(
        entryLink: EntryLink.basic(
          id: '',
          fromId: '',
          toId: '',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          vectorClock: null,
        ),
        status: SyncEntryStatus.initial,
      ),
    );
  });

  setUp(() {
    // Set up SharedPreferences with backfill enabled
    SharedPreferences.setMockInitialValues({'backfill_enabled': true});

    mockJournalDb = MockJournalDb();
    mockSequenceService = MockSyncSequenceLogService();
    mockOutboxService = MockOutboxService();
    mockLogging = MockDomainLogger();
    mockVcService = MockVectorClockService();

    when(
      () => mockLogging.log(
        any<LogDomain>(),
        any<String>(),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenReturn(null);
    when(
      () => mockLogging.error(
        any<LogDomain>(),
        any<Object>(),
        stackTrace: any<StackTrace?>(named: 'stackTrace'),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenAnswer((_) async {});
    when(() => mockVcService.initialized).thenAnswer((_) async {});
    when(() => mockVcService.getHost()).thenAnswer((_) async => aliceHostId);

    mockAgentRepository = MockAgentRepository();

    // Default stub for covering entry fallback — returns null (no covering entry)
    when(
      () => mockSequenceService.getNearestCoveringEntry(any(), any()),
    ).thenAnswer((_) async => null);

    // `_sendUnresolvableResponse` now also writes to our own sequence log so
    // the local state matches what peers will see after receiving the
    // broadcast. Stub as a no-op for every test — assertions that care can
    // still verify the call via `verify(...)`.
    when(
      () => mockSequenceService.markOwnCounterUnresolvable(
        hostId: any(named: 'hostId'),
        counter: any(named: 'counter'),
        payloadType: any(named: 'payloadType'),
      ),
    ).thenAnswer((_) async {});

    handler = BackfillResponseHandler(
      journalDb: mockJournalDb,
      sequenceLogService: mockSequenceService,
      outboxService: mockOutboxService,
      loggingService: mockLogging,
      vectorClockService: mockVcService,
    )..agentRepository = mockAgentRepository;
  });

  group('handleBackfillRequest', () {
    test('skips own backfill requests (self-request guard)', () async {
      // The handler's host is aliceHostId (set in setUp).
      // Send a request where requesterId matches our own host.
      const request = SyncBackfillRequest(
        entries: [
          BackfillRequestEntry(hostId: bobHostId, counter: 1),
          BackfillRequestEntry(hostId: bobHostId, counter: 2),
        ],
        requesterId: aliceHostId, // Same as our host
      );

      await handler.handleBackfillRequest(request);

      // Should NOT check backfill enabled, look up entries, or enqueue anything
      verifyNever(
        () => mockSequenceService.getEntryByHostAndCounter(any(), any()),
      );
      verifyNever(() => mockOutboxService.enqueueMessage(any()));

      // Logging now goes through DomainLogger (not injected in tests)
    });

    test('ignores request when backfill is disabled', () async {
      // Set backfill_enabled to false
      SharedPreferences.setMockInitialValues({'backfill_enabled': false});

      const request = SyncBackfillRequest(
        entries: [
          BackfillRequestEntry(hostId: aliceHostId, counter: 3),
        ],
        requesterId: requesterId,
      );

      await handler.handleBackfillRequest(request);

      // Should not call any database methods
      verifyNever(
        () => mockSequenceService.getEntryByHostAndCounter(any(), any()),
      );
      verifyNever(() => mockOutboxService.enqueueMessage(any()));
    });

    test(
      'processes all entries when at or below maxBackfillResponseBatchSize',
      () async {
        // A batch exactly at the limit must NOT be truncated.
        final entries = List.generate(
          SyncTuning.maxBackfillResponseBatchSize,
          (i) => BackfillRequestEntry(hostId: bobHostId, counter: i + 1),
        );
        final request = SyncBackfillRequest(
          entries: entries,
          requesterId: requesterId,
        );

        // All entries are for bob (not our host) with no log row, so each is
        // looked up and skipped silently.
        when(
          () => mockSequenceService.getEntryByHostAndCounter(bobHostId, any()),
        ).thenAnswer((_) async => null);

        await handler.handleBackfillRequest(request);

        // Every entry is processed: capture the counters looked up and assert
        // the exact set is 1..N (not just the right COUNT, which would pass
        // even if the wrong subset of counters were processed).
        final captured = verify(
          () => mockSequenceService.getEntryByHostAndCounter(
            bobHostId,
            captureAny(),
          ),
        ).captured.cast<int>();
        expect(
          captured,
          List.generate(
            SyncTuning.maxBackfillResponseBatchSize,
            (i) => i + 1,
          ),
        );
      },
    );

    test(
      'truncates request to maxBackfillResponseBatchSize when oversized',
      () async {
        // Exercises the `.take(...).toList()` truncation branch: a request
        // larger than the batch cap must only process the first N entries.
        const overflow = 5;
        final entries = List.generate(
          SyncTuning.maxBackfillResponseBatchSize + overflow,
          (i) => BackfillRequestEntry(hostId: bobHostId, counter: i + 1),
        );
        final request = SyncBackfillRequest(
          entries: entries,
          requesterId: requesterId,
        );

        when(
          () => mockSequenceService.getEntryByHostAndCounter(bobHostId, any()),
        ).thenAnswer((_) async => null);

        await handler.handleBackfillRequest(request);

        // Only the first batch-size entries (counters 1..N) are looked up; the
        // overflow tail (counters N+1..N+overflow) is dropped by truncation.
        // Capture the exact counters to prove the correct prefix is processed,
        // not merely that the right number of lookups happened.
        final captured = verify(
          () => mockSequenceService.getEntryByHostAndCounter(
            bobHostId,
            captureAny(),
          ),
        ).captured.cast<int>();
        expect(
          captured,
          List.generate(
            SyncTuning.maxBackfillResponseBatchSize,
            (i) => i + 1,
          ),
        );

        // None of the overflow tail counters (N+1..N+overflow) were looked up.
        for (
          var counter = SyncTuning.maxBackfillResponseBatchSize + 1;
          counter <= SyncTuning.maxBackfillResponseBatchSize + overflow;
          counter++
        ) {
          expect(captured, isNot(contains(counter)));
        }
      },
    );

    test(
      'ignores request when entry not in sequence log and not our host',
      () async {
        // Request for Bob's counter - we don't have it, skip silently
        // (another device might have it)
        const request = SyncBackfillRequest(
          entries: [
            BackfillRequestEntry(hostId: bobHostId, counter: 3),
          ],
          requesterId: requesterId,
        );

        when(
          () => mockSequenceService.getEntryByHostAndCounter(bobHostId, 3),
        ).thenAnswer((_) async => null);

        await handler.handleBackfillRequest(request);

        // Should not enqueue any messages - we don't own this counter
        verifyNever(() => mockOutboxService.enqueueMessage(any()));
      },
    );

    test(
      'skips notification backfill when notificationsDb is not wired',
      () async {
        const request = SyncBackfillRequest(
          entries: [
            BackfillRequestEntry(hostId: aliceHostId, counter: 5),
          ],
          requesterId: requesterId,
        );
        when(
          () => mockSequenceService.getEntryByHostAndCounter(aliceHostId, 5),
        ).thenAnswer(
          (_) async => _createLogItem(
            aliceHostId,
            5,
            entryId: 'notif-no-db',
            originatingHostId: aliceHostId,
            payloadType: SyncSequencePayloadType.notification,
          ),
        );

        await handler.handleBackfillRequest(request);

        verifyNever(() => mockOutboxService.enqueueMessage(any()));
      },
    );

    test(
      'skips notification state update backfill when notificationsDb is not wired',
      () async {
        const request = SyncBackfillRequest(
          entries: [
            BackfillRequestEntry(hostId: aliceHostId, counter: 6),
          ],
          requesterId: requesterId,
        );
        when(
          () => mockSequenceService.getEntryByHostAndCounter(aliceHostId, 6),
        ).thenAnswer(
          (_) async => _createLogItem(
            aliceHostId,
            6,
            entryId: 'notif-state-no-db',
            originatingHostId: aliceHostId,
            payloadType: SyncSequencePayloadType.notificationStateUpdate,
          ),
        );

        await handler.handleBackfillRequest(request);

        verifyNever(() => mockOutboxService.enqueueMessage(any()));
      },
    );

    test('sends unresolvable when own counter not in sequence log', () async {
      // Request for Alice's counter (our own) - we can't find it
      // Only we can answer for our own counters, so send unresolvable
      const request = SyncBackfillRequest(
        entries: [
          BackfillRequestEntry(hostId: aliceHostId, counter: 3),
        ],
        requesterId: requesterId,
      );

      when(
        () => mockSequenceService.getEntryByHostAndCounter(aliceHostId, 3),
      ).thenAnswer((_) async => null);
      when(
        () => mockOutboxService.enqueueMessage(any()),
      ).thenAnswer((_) async {});

      await handler.handleBackfillRequest(request);

      // Should send unresolvable response for our own counter
      verify(
        () => mockOutboxService.enqueueMessage(
          const SyncMessage.backfillResponse(
            hostId: aliceHostId,
            counter: 3,
            deleted: false,
            unresolvable: true,
          ),
        ),
      ).called(1);
    });

    test(
      'does not terminalize own missing counter when unresolvable enqueue '
      'fails, leaving the retryable reservation/miss state intact',
      () async {
        const request = SyncBackfillRequest(
          entries: [
            BackfillRequestEntry(hostId: aliceHostId, counter: 3),
          ],
          requesterId: requesterId,
        );

        when(
          () => mockSequenceService.getEntryByHostAndCounter(aliceHostId, 3),
        ).thenAnswer((_) async => null);
        when(() => mockOutboxService.enqueueMessage(any())).thenThrow(
          StateError('outbox unavailable'),
        );

        await handler.handleBackfillRequest(request);

        verify(
          () => mockOutboxService.enqueueMessage(
            const SyncMessage.backfillResponse(
              hostId: aliceHostId,
              counter: 3,
              deleted: false,
              unresolvable: true,
            ),
          ),
        ).called(1);
        verifyNever(
          () => mockSequenceService.markOwnCounterUnresolvable(
            hostId: any(named: 'hostId'),
            counter: any(named: 'counter'),
            payloadType: any(named: 'payloadType'),
          ),
        );
      },
    );

    test(
      'ignores request when entry in log but has no entryId and not our host',
      () async {
        // Request for Bob's counter - entry exists but no entryId
        const request = SyncBackfillRequest(
          entries: [
            BackfillRequestEntry(hostId: bobHostId, counter: 3),
          ],
          requesterId: requesterId,
        );

        when(
          () => mockSequenceService.getEntryByHostAndCounter(bobHostId, 3),
        ).thenAnswer(
          (_) async => _createLogItem(bobHostId, 3),
        );

        await handler.handleBackfillRequest(request);

        // Should not enqueue any messages - not our counter
        verifyNever(() => mockOutboxService.enqueueMessage(any()));
      },
    );

    test(
      'sends unresolvable when own counter in log but has no entryId',
      () async {
        // Request for Alice's counter (our own) - entry exists but no entryId
        const request = SyncBackfillRequest(
          entries: [
            BackfillRequestEntry(hostId: aliceHostId, counter: 3),
          ],
          requesterId: requesterId,
        );

        when(
          () => mockSequenceService.getEntryByHostAndCounter(aliceHostId, 3),
        ).thenAnswer(
          (_) async => _createLogItem(aliceHostId, 3),
        );
        when(
          () => mockOutboxService.enqueueMessage(any()),
        ).thenAnswer((_) async {});

        await handler.handleBackfillRequest(request);

        // Should send unresolvable response for our own counter
        verify(
          () => mockOutboxService.enqueueMessage(
            const SyncMessage.backfillResponse(
              hostId: aliceHostId,
              counter: 3,
              deleted: false,
              unresolvable: true,
              payloadType: SyncSequencePayloadType.journalEntity,
            ),
          ),
        ).called(1);
      },
    );

    test('uses covering entry when exact counter not found', () async {
      // Request for Bob's counter 3, which is not in our log directly.
      // But we have a covering entry at counter 5 with the same host.
      const request = SyncBackfillRequest(
        entries: [
          BackfillRequestEntry(hostId: bobHostId, counter: 3),
        ],
        requesterId: requesterId,
      );

      // Exact counter returns null
      when(
        () => mockSequenceService.getEntryByHostAndCounter(bobHostId, 3),
      ).thenAnswer((_) async => null);

      // Covering entry returns a resolved entry at counter 5
      when(
        () => mockSequenceService.getNearestCoveringEntry(bobHostId, 3),
      ).thenAnswer(
        (_) async => _createLogItem(
          bobHostId,
          5,
          entryId: entryId,
          originatingHostId: bobHostId,
        ),
      );

      // The journal entry exists locally
      when(
        () => mockJournalDb.journalEntityById(entryId),
      ).thenAnswer(
        (_) async => _createJournalEntry(
          entryId,
          vectorClock: const VectorClock({bobHostId: 5}),
        ),
      );
      when(
        () => mockOutboxService.enqueueMessage(any()),
      ).thenAnswer((_) async {});

      final captured = <SyncMessage>[];
      when(
        () => mockOutboxService.enqueueMessage(captureAny()),
      ).thenAnswer((inv) async {
        captured.add(inv.positionalArguments.first as SyncMessage);
      });

      await handler.handleBackfillRequest(request);

      // Two enqueues: (1) re-sync the journal entity, (2) backfill hint
      // because the VC counter 5 != requested counter 3
      expect(captured, hasLength(2));

      // First: re-send the journal entity
      final entityMsg = captured[0];
      expect(entityMsg, isA<SyncJournalEntity>());
      expect((entityMsg as SyncJournalEntity).id, entryId);

      // Second: backfill response hint mapping counter 3 → entryId
      final hintMsg = captured[1];
      expect(hintMsg, isA<SyncBackfillResponse>());
      final hint = hintMsg as SyncBackfillResponse;
      expect(hint.hostId, bobHostId);
      expect(hint.counter, 3);
      expect(hint.payloadId, entryId);
      expect(hint.deleted, isFalse);
    });

    test(
      'covering search skips a candidate whose payload VC is behind, then '
      'uses the next candidate that covers',
      () async {
        // Foreign host (bob): exact counter 3 missing, so the handler walks
        // covering candidates. The first candidate at counter 5 maps to a
        // payload whose VC ({bob: 2}) is BEHIND the requested counter 3, so it
        // is rejected and the search advances to counter 6. The second
        // candidate at counter 10 maps to a payload whose VC ({bob: 12})
        // covers counter 3, so it is used.
        const staleEntryId = 'stale-covering-id';
        const coveringEntryId = 'good-covering-id';
        const request = SyncBackfillRequest(
          entries: [
            BackfillRequestEntry(hostId: bobHostId, counter: 3),
          ],
          requesterId: requesterId,
        );

        when(
          () => mockSequenceService.getEntryByHostAndCounter(bobHostId, 3),
        ).thenAnswer((_) async => null);

        // First covering candidate at counter 5 — VC behind, will be skipped.
        when(
          () => mockSequenceService.getNearestCoveringEntry(bobHostId, 3),
        ).thenAnswer(
          (_) async => _createLogItem(
            bobHostId,
            5,
            entryId: staleEntryId,
            originatingHostId: bobHostId,
          ),
        );
        when(
          () => mockJournalDb.journalEntityById(staleEntryId),
        ).thenAnswer(
          (_) async => _createJournalEntry(
            staleEntryId,
            vectorClock: const VectorClock({bobHostId: 2}),
          ),
        );

        // Search advances to counter 6 (covering.counter + 1). The next
        // candidate at counter 10 has a VC that covers counter 3.
        when(
          () => mockSequenceService.getNearestCoveringEntry(bobHostId, 6),
        ).thenAnswer(
          (_) async => _createLogItem(
            bobHostId,
            10,
            entryId: coveringEntryId,
            originatingHostId: bobHostId,
          ),
        );
        when(
          () => mockJournalDb.journalEntityById(coveringEntryId),
        ).thenAnswer(
          (_) async => _createJournalEntry(
            coveringEntryId,
            vectorClock: const VectorClock({bobHostId: 12}),
          ),
        );

        final captured = <SyncMessage>[];
        when(
          () => mockOutboxService.enqueueMessage(captureAny()),
        ).thenAnswer((inv) async {
          captured.add(inv.positionalArguments.first as SyncMessage);
        });

        await handler.handleBackfillRequest(request);

        // The stale candidate must have been consulted (proves the skip path
        // ran) and then the next candidate at counter 6.
        verify(
          () => mockSequenceService.getNearestCoveringEntry(bobHostId, 3),
        ).called(1);
        verify(
          () => mockSequenceService.getNearestCoveringEntry(bobHostId, 6),
        ).called(1);

        // The good covering entry is re-sent, plus a hint mapping counter 3 to
        // it (VC counter 12 != requested 3).
        expect(captured, hasLength(2));
        expect(captured[0], isA<SyncJournalEntity>());
        expect((captured[0] as SyncJournalEntity).id, coveringEntryId);
        expect(
          captured[1],
          isA<SyncBackfillResponse>()
              .having((r) => r.hostId, 'hostId', bobHostId)
              .having((r) => r.counter, 'counter', 3)
              .having((r) => r.payloadId, 'payloadId', coveringEntryId)
              .having((r) => r.deleted, 'deleted', false),
        );

        // The stale payload must never be sent.
        expect(
          captured.whereType<SyncJournalEntity>().map((m) => m.id),
          isNot(contains(staleEntryId)),
        );
      },
    );

    test(
      'rejects covering entry when payload VC does not cover counter '
      'and no further candidates exist',
      () async {
        // Request for our own counter 100, not in the log directly.
        // Covering entry exists at counter 200 mapped to entryId, BUT
        // the entry's VC is {aliceHostId: 50} which is BEHIND counter 100.
        // No further covering entries exist after counter 200.
        const request = SyncBackfillRequest(
          entries: [
            BackfillRequestEntry(hostId: aliceHostId, counter: 100),
          ],
          requesterId: requesterId,
        );

        when(
          () => mockSequenceService.getEntryByHostAndCounter(aliceHostId, 100),
        ).thenAnswer((_) async => null);

        when(
          () => mockSequenceService.getNearestCoveringEntry(aliceHostId, 100),
        ).thenAnswer(
          (_) async => _createLogItem(
            aliceHostId,
            200,
            entryId: entryId,
            originatingHostId: aliceHostId,
          ),
        );

        // No further covering entries after counter 200
        when(
          () => mockSequenceService.getNearestCoveringEntry(aliceHostId, 201),
        ).thenAnswer((_) async => null);

        // Entry exists but VC is behind the requested counter
        when(
          () => mockJournalDb.journalEntityById(entryId),
        ).thenAnswer(
          (_) async => _createJournalEntry(
            entryId,
            vectorClock: const VectorClock({aliceHostId: 50}),
          ),
        );
        when(
          () => mockOutboxService.enqueueMessage(any()),
        ).thenAnswer((_) async {});

        await handler.handleBackfillRequest(request);

        // Should send unresolvable (our own counter, all covering entries
        // exhausted)
        verify(
          () => mockOutboxService.enqueueMessage(
            any(
              that: isA<SyncBackfillResponse>()
                  .having((r) => r.hostId, 'hostId', aliceHostId)
                  .having((r) => r.counter, 'counter', 100)
                  .having((r) => r.deleted, 'deleted', false)
                  .having((r) => r.unresolvable, 'unresolvable', true),
            ),
          ),
        ).called(1);

        // Should NOT have sent the journal entity (wrong covering entry)
        verifyNever(
          () => mockOutboxService.enqueueMessage(
            any(that: isA<SyncJournalEntity>()),
          ),
        );
      },
    );

    test(
      'own-host miss sends unresolvable immediately — does NOT attempt '
      'covering. A covering entity is a DIFFERENT entity whose VC '
      'monotonically dominates the requested counter only on the same '
      'host axis, which is not true VC dominance (would require same '
      'entity). For our own host the sequence log is authoritative, so '
      'a miss is definitively a burn and the correct answer is '
      'unresolvable — otherwise the requester mis-attributes the '
      "covering entity's payload to a counter it never carried.",
      () async {
        const staleEntryId = 'stale-entry-id';
        const validEntryId = 'valid-entry-id';
        const request = SyncBackfillRequest(
          entries: [
            BackfillRequestEntry(hostId: aliceHostId, counter: 100),
          ],
          requesterId: requesterId,
        );

        when(
          () => mockSequenceService.getEntryByHostAndCounter(aliceHostId, 100),
        ).thenAnswer((_) async => null);

        // Even if a covering entity were available, own-host burns must
        // not take that path — these stubs model what USED to happen.
        when(
          () => mockSequenceService.getNearestCoveringEntry(aliceHostId, 100),
        ).thenAnswer(
          (_) async => _createLogItem(
            aliceHostId,
            200,
            entryId: staleEntryId,
            originatingHostId: aliceHostId,
          ),
        );
        when(
          () => mockSequenceService.getNearestCoveringEntry(aliceHostId, 201),
        ).thenAnswer(
          (_) async => _createLogItem(
            aliceHostId,
            300,
            entryId: validEntryId,
            originatingHostId: aliceHostId,
          ),
        );
        when(
          () => mockJournalDb.journalEntityById(staleEntryId),
        ).thenAnswer(
          (_) async => _createJournalEntry(
            staleEntryId,
            vectorClock: const VectorClock({aliceHostId: 50}),
          ),
        );
        when(
          () => mockJournalDb.journalEntityById(validEntryId),
        ).thenAnswer(
          (_) async => _createJournalEntry(
            validEntryId,
            vectorClock: const VectorClock({aliceHostId: 100}),
          ),
        );

        when(
          () => mockOutboxService.enqueueMessage(any()),
        ).thenAnswer((_) async {});

        await handler.handleBackfillRequest(request);

        final captured = verify(
          () => mockOutboxService.enqueueMessage(captureAny()),
        ).captured.cast<SyncMessage>();

        // Exactly one response — unresolvable. No covering entity sent.
        expect(captured.length, 1);
        expect(
          captured.single,
          isA<SyncBackfillResponse>()
              .having((r) => r.hostId, 'hostId', aliceHostId)
              .having((r) => r.counter, 'counter', 100)
              .having((r) => r.unresolvable, 'unresolvable', true),
        );
        expect(captured.whereType<SyncJournalEntity>(), isEmpty);
      },
    );

    test('sends deleted response when journal entry was deleted', () async {
      const request = SyncBackfillRequest(
        entries: [
          BackfillRequestEntry(hostId: aliceHostId, counter: 3),
        ],
        requesterId: requesterId,
      );

      when(
        () => mockSequenceService.getEntryByHostAndCounter(aliceHostId, 3),
      ).thenAnswer(
        (_) async => _createLogItem(aliceHostId, 3, entryId: entryId),
      );

      when(
        () => mockJournalDb.journalEntityById(entryId),
      ).thenAnswer((_) async => null);

      when(
        () => mockOutboxService.enqueueMessage(any()),
      ).thenAnswer((_) async {});

      await handler.handleBackfillRequest(request);

      // Should send a deleted response
      final captured = verify(
        () => mockOutboxService.enqueueMessage(captureAny()),
      ).captured;

      expect(captured.length, 1);
      final response = captured[0] as SyncMessage;
      expect(
        response,
        isA<SyncBackfillResponse>()
            .having((r) => r.hostId, 'hostId', aliceHostId)
            .having((r) => r.counter, 'counter', 3)
            .having((r) => r.deleted, 'deleted', true),
      );
    });

    test('re-sends entry via normal sync when entry exists', () async {
      const request = SyncBackfillRequest(
        entries: [
          BackfillRequestEntry(hostId: aliceHostId, counter: 3),
        ],
        requesterId: requesterId,
      );

      when(
        () => mockSequenceService.getEntryByHostAndCounter(aliceHostId, 3),
      ).thenAnswer(
        (_) async => _createLogItem(aliceHostId, 3, entryId: entryId),
      );

      final journalEntry = _createJournalEntry(
        entryId,
        vectorClock: const VectorClock({aliceHostId: 3}),
      );
      when(
        () => mockJournalDb.journalEntityById(entryId),
      ).thenAnswer((_) async => journalEntry);

      when(
        () => mockOutboxService.enqueueMessage(any()),
      ).thenAnswer((_) async {});

      await handler.handleBackfillRequest(request);

      final captured = verify(
        () => mockOutboxService.enqueueMessage(captureAny()),
      ).captured;

      expect(captured.length, 1);

      // Should send the journal entity
      expect(captured[0], isA<SyncJournalEntity>());
      final syncEntity = captured[0] as SyncJournalEntity;
      expect(syncEntity.id, entryId);
      expect(syncEntity.status, SyncEntryStatus.update);
    });

    test(
      'sends only unresolvable when exact own counter VC is behind',
      () async {
        // Entry VC is {'test-host': 1} but we request counter=3 for our own
        // host (aliceHostId). VC doesn't contain aliceHostId at all, so this
        // mapping is permanently wrong → send unresolvable.
        const request = SyncBackfillRequest(
          entries: [
            BackfillRequestEntry(hostId: aliceHostId, counter: 3),
          ],
          requesterId: requesterId,
        );

        when(
          () => mockSequenceService.getEntryByHostAndCounter(aliceHostId, 3),
        ).thenAnswer(
          (_) async => _createLogItem(aliceHostId, 3, entryId: entryId),
        );

        final journalEntry = _createJournalEntry(entryId);
        when(
          () => mockJournalDb.journalEntityById(entryId),
        ).thenAnswer((_) async => journalEntry);

        when(
          () => mockOutboxService.enqueueMessage(any()),
        ).thenAnswer((_) async {});

        await handler.handleBackfillRequest(request);

        final captured = verify(
          () => mockOutboxService.enqueueMessage(captureAny()),
        ).captured;

        expect(captured.length, 1);
        expect(
          captured[0],
          isA<SyncBackfillResponse>()
              .having((r) => r.hostId, 'hostId', aliceHostId)
              .having((r) => r.counter, 'counter', 3)
              .having((r) => r.deleted, 'deleted', false)
              .having((r) => r.unresolvable, 'unresolvable', true),
        );
      },
    );

    test('sends hint when own counter VC is ahead (superseded)', () async {
      // Entry VC is {aliceHostId: 10} and we request counter=3 for our own
      // host. VC is ahead (10 >= 3), so this is a legitimate supersession
      // → send a hint so the receiver can map counter 3 → this entry.
      const request = SyncBackfillRequest(
        entries: [
          BackfillRequestEntry(hostId: aliceHostId, counter: 3),
        ],
        requesterId: requesterId,
      );

      when(
        () => mockSequenceService.getEntryByHostAndCounter(aliceHostId, 3),
      ).thenAnswer(
        (_) async => _createLogItem(aliceHostId, 3, entryId: entryId),
      );

      final journalEntry = _createJournalEntry(
        entryId,
        vectorClock: const VectorClock({aliceHostId: 10}),
      );
      when(
        () => mockJournalDb.journalEntityById(entryId),
      ).thenAnswer((_) async => journalEntry);

      when(
        () => mockOutboxService.enqueueMessage(any()),
      ).thenAnswer((_) async {});

      await handler.handleBackfillRequest(request);

      final captured = verify(
        () => mockOutboxService.enqueueMessage(captureAny()),
      ).captured;

      expect(captured.length, 2);
      expect(captured[0], isA<SyncJournalEntity>());
      expect(
        captured[1],
        isA<SyncBackfillResponse>()
            .having((r) => r.hostId, 'hostId', aliceHostId)
            .having((r) => r.counter, 'counter', 3)
            .having((r) => r.deleted, 'deleted', false)
            .having((r) => r.unresolvable, 'unresolvable', isNull)
            .having((r) => r.payloadId, 'payloadId', entryId)
            .having(
              (r) => r.payloadType,
              'payloadType',
              SyncSequencePayloadType.journalEntity,
            ),
      );
    });

    test(
      'own-host entry with null payload VC re-sends the entity then sends '
      'unresolvable via the hint-or-unresolvable path',
      () async {
        // The exact-row staleness guard only fires when the payload VC is
        // non-null. Here the journal entity has a NULL vector clock, so that
        // guard is bypassed and the entity is re-sent. Afterwards the
        // requested counter is absent from the (null) VC, so the
        // hint-or-unresolvable decision runs: own host + vcCounter == null
        // means the mapping can never self-heal, so an unresolvable response
        // is emitted (not a hint).
        const request = SyncBackfillRequest(
          entries: [
            BackfillRequestEntry(hostId: aliceHostId, counter: 3),
          ],
          requesterId: requesterId,
        );

        when(
          () => mockSequenceService.getEntryByHostAndCounter(aliceHostId, 3),
        ).thenAnswer(
          (_) async => _createLogItem(aliceHostId, 3, entryId: entryId),
        );

        // Entry exists locally but carries NO vector clock.
        when(
          () => mockJournalDb.journalEntityById(entryId),
        ).thenAnswer((_) async => _createJournalEntryWithoutVC(entryId));

        when(
          () => mockOutboxService.enqueueMessage(any()),
        ).thenAnswer((_) async {});

        await handler.handleBackfillRequest(request);

        final captured = verify(
          () => mockOutboxService.enqueueMessage(captureAny()),
        ).captured.cast<SyncMessage>();

        // First the entity is re-sent, then the unresolvable response.
        expect(captured.length, 2);
        expect(captured[0], isA<SyncJournalEntity>());
        expect((captured[0] as SyncJournalEntity).id, entryId);
        expect(
          captured[1],
          isA<SyncBackfillResponse>()
              .having((r) => r.hostId, 'hostId', aliceHostId)
              .having((r) => r.counter, 'counter', 3)
              .having((r) => r.deleted, 'deleted', false)
              .having((r) => r.unresolvable, 'unresolvable', true)
              .having(
                (r) => r.payloadType,
                'payloadType',
                SyncSequencePayloadType.journalEntity,
              ),
        );

        // The unresolvable path also terminalizes our own counter locally.
        verify(
          () => mockSequenceService.markOwnCounterUnresolvable(
            hostId: aliceHostId,
            counter: 3,
            // ignore: avoid_redundant_argument_values
            payloadType: SyncSequencePayloadType.journalEntity,
          ),
        ).called(1);
      },
    );

    test(
      'own-host exact row with stale VC sends unresolvable — does NOT '
      'fall back to covering. Stale here means our authoritative '
      "sequence-log row exists but the payload's current VC has "
      'regressed below the requested counter, so the row is orphaned. '
      'Covering by a later (necessarily different) entity would silently '
      "mis-attribute its payload to this counter on the requester's "
      'side — the only safe answer from the originator is unresolvable.',
      () async {
        const coveringEntryId = 'covering-entry-id';
        const request = SyncBackfillRequest(
          entries: [
            BackfillRequestEntry(hostId: aliceHostId, counter: 3),
          ],
          requesterId: requesterId,
        );

        when(
          () => mockSequenceService.getEntryByHostAndCounter(aliceHostId, 3),
        ).thenAnswer(
          (_) async => _createLogItem(aliceHostId, 3, entryId: entryId),
        );

        // Covering stub retained to prove the handler does NOT consult it
        // for own-host misses.
        when(
          () => mockSequenceService.getNearestCoveringEntry(aliceHostId, 4),
        ).thenAnswer(
          (_) async => _createLogItem(
            aliceHostId,
            10,
            entryId: coveringEntryId,
            originatingHostId: aliceHostId,
          ),
        );

        // Exact row's payload has a stale VC ({alice: 0}) that does not
        // cover counter 3.
        when(
          () => mockJournalDb.journalEntityById(entryId),
        ).thenAnswer((_) async => _createJournalEntry(entryId));

        when(
          () => mockJournalDb.journalEntityById(coveringEntryId),
        ).thenAnswer(
          (_) async => _createJournalEntry(
            coveringEntryId,
            vectorClock: const VectorClock({aliceHostId: 10}),
          ),
        );

        when(
          () => mockOutboxService.enqueueMessage(any()),
        ).thenAnswer((_) async {});

        await handler.handleBackfillRequest(request);

        final captured = verify(
          () => mockOutboxService.enqueueMessage(captureAny()),
        ).captured;

        expect(captured.length, 1);
        expect(
          captured.single,
          isA<SyncBackfillResponse>()
              .having((r) => r.hostId, 'hostId', aliceHostId)
              .having((r) => r.counter, 'counter', 3)
              .having((r) => r.unresolvable, 'unresolvable', true),
        );
        expect(
          captured.whereType<SyncJournalEntity>(),
          isEmpty,
          reason: 'No covering payload must be sent for own-host stale rows',
        );
      },
    );

    test('handles errors gracefully', () async {
      const request = SyncBackfillRequest(
        entries: [
          BackfillRequestEntry(hostId: aliceHostId, counter: 3),
        ],
        requesterId: requesterId,
      );

      when(
        () => mockSequenceService.getEntryByHostAndCounter(aliceHostId, 3),
      ).thenThrow(Exception('Database error'));

      // Should not throw
      await handler.handleBackfillRequest(request);

      // Should log the exception
      verify(
        () => mockLogging.error(
          any<LogDomain>(),
          any<Object>(),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
          subDomain: any(named: 'subDomain'),
        ),
      ).called(1);
    });

    test('skips entries within cooldown period', () async {
      final fixedNow = DateTime(2026, 5, 25, 9);
      // Pre-populate the cooldown cache with a response from one minute ago —
      // squarely inside the cooldown window under the fixed clock.
      handler.recentlyResponded['$aliceHostId:3'] = fixedNow.subtract(
        const Duration(minutes: 1),
      );

      const request = SyncBackfillRequest(
        entries: [
          BackfillRequestEntry(hostId: aliceHostId, counter: 3),
        ],
        requesterId: requesterId,
      );

      await withClock(
        Clock.fixed(fixedNow),
        () => handler.handleBackfillRequest(request),
      );

      // Should not call any sequence log or outbox methods
      verifyNever(
        () => mockSequenceService.getEntryByHostAndCounter(any(), any()),
      );
      verifyNever(() => mockOutboxService.enqueueMessage(any()));
    });

    test('records response in cooldown cache after responding', () async {
      const request = SyncBackfillRequest(
        entries: [
          BackfillRequestEntry(hostId: aliceHostId, counter: 3),
        ],
        requesterId: requesterId,
      );

      when(
        () => mockSequenceService.getEntryByHostAndCounter(aliceHostId, 3),
      ).thenAnswer((_) async => null);
      when(
        () => mockOutboxService.enqueueMessage(any()),
      ).thenAnswer((_) async {});

      await handler.handleBackfillRequest(request);

      // Verify the response was recorded in the cooldown cache
      expect(
        handler.recentlyResponded.containsKey('$aliceHostId:3'),
        isTrue,
      );
    });

    test('stops processing when rate limit is reached', () async {
      // Use a handler with zero cooldown so cooldowns don't interfere
      handler =
          BackfillResponseHandler(
              journalDb: mockJournalDb,
              sequenceLogService: mockSequenceService,
              outboxService: mockOutboxService,
              loggingService: mockLogging,
              vectorClockService: mockVcService,
              responseCooldown: Duration.zero,
            )
            // Set window to now so the rate window is still active
            ..windowStart = DateTime(2026, 5, 25, 9)
            ..responsesInWindow =
                SyncTuning.backfillResponseRateLimit; // At the limit

      const request = SyncBackfillRequest(
        entries: [
          BackfillRequestEntry(hostId: aliceHostId, counter: 1),
          BackfillRequestEntry(hostId: aliceHostId, counter: 2),
        ],
        requesterId: requesterId,
      );

      await withClock(
        Clock.fixed(DateTime(2026, 5, 25, 9)),
        () => handler.handleBackfillRequest(request),
      );

      // Should be rate limited - no processing
      verifyNever(
        () => mockSequenceService.getEntryByHostAndCounter(any(), any()),
      );
    });

    test('cleans expired cooldown entries at batch start', () async {
      final now = DateTime(2026, 5, 25, 9);

      // Add an entry that's already expired (well past 5-minute cooldown)
      handler.recentlyResponded['$aliceHostId:99'] = now.subtract(
        const Duration(hours: 2),
      );
      // Add a non-expired entry (within 5-minute cooldown)
      handler.recentlyResponded['$bobHostId:5'] = now.subtract(
        const Duration(minutes: 2),
      );

      // Request for a different counter so processing is independent
      const request = SyncBackfillRequest(
        entries: [
          BackfillRequestEntry(hostId: bobHostId, counter: 10),
        ],
        requesterId: requesterId,
      );

      when(
        () => mockSequenceService.getEntryByHostAndCounter(bobHostId, 10),
      ).thenAnswer((_) async => null);

      await withClock(
        Clock.fixed(now),
        () => handler.handleBackfillRequest(request),
      );

      // Expired entry should be cleaned
      expect(
        handler.recentlyResponded.containsKey('$aliceHostId:99'),
        isFalse,
      );
      // Non-expired entry should remain
      expect(
        handler.recentlyResponded.containsKey('$bobHostId:5'),
        isTrue,
      );
    });

    test(
      'an entry aged exactly the cooldown duration is no longer skipped',
      () async {
        final fixedNow = DateTime(2026, 5, 25, 9);
        // Exactly at the boundary: difference == cooldown fails the
        // strictly-less-than check, so the entry must be processed again
        // (and swept by the batch-start cleanup).
        handler.recentlyResponded['$aliceHostId:3'] = fixedNow.subtract(
          SyncTuning.backfillResponseCooldown,
        );

        const request = SyncBackfillRequest(
          entries: [
            BackfillRequestEntry(hostId: aliceHostId, counter: 3),
          ],
          requesterId: requesterId,
        );

        when(
          () => mockSequenceService.getEntryByHostAndCounter(aliceHostId, 3),
        ).thenAnswer((_) async => null);
        when(
          () => mockOutboxService.enqueueMessage(any()),
        ).thenAnswer((_) async {});

        await withClock(
          Clock.fixed(fixedNow),
          () => handler.handleBackfillRequest(request),
        );

        verify(
          () => mockSequenceService.getEntryByHostAndCounter(aliceHostId, 3),
        ).called(1);
        // The boundary-aged entry was replaced by a fresh cooldown stamp.
        expect(handler.recentlyResponded['$aliceHostId:3'], fixedNow);
      },
    );
  });

  group('handleBackfillResponse', () {
    test('delegates to sequenceLogService for deleted response', () async {
      const response = SyncBackfillResponse(
        hostId: aliceHostId,
        counter: 3,
        deleted: true,
      );

      when(
        () => mockSequenceService.handleBackfillResponse(
          hostId: aliceHostId,
          counter: 3,
          deleted: true,
        ),
      ).thenAnswer((_) async {});

      await handler.handleBackfillResponse(response);

      verify(
        () => mockSequenceService.handleBackfillResponse(
          hostId: aliceHostId,
          counter: 3,
          deleted: true,
        ),
      ).called(1);
    });

    test('stores hint and verifies entry when it exists locally', () async {
      const response = SyncBackfillResponse(
        hostId: aliceHostId,
        counter: 3,
        deleted: false,
        entryId: entryId,
      );

      when(
        () => mockSequenceService.handleBackfillResponse(
          hostId: aliceHostId,
          counter: 3,
          deleted: false,
          entryId: entryId,
        ),
      ).thenAnswer((_) async {});

      // Entry exists locally
      final journalEntry = _createJournalEntry(entryId);
      when(
        () => mockJournalDb.journalEntityById(entryId),
      ).thenAnswer((_) async => journalEntry);

      when(
        () => mockSequenceService.verifyAndMarkBackfilled(
          hostId: aliceHostId,
          counter: 3,
          entryId: entryId,
          entryVectorClock: any(named: 'entryVectorClock'),
        ),
      ).thenAnswer((_) async => true);

      await handler.handleBackfillResponse(response);

      // Should store the hint
      verify(
        () => mockSequenceService.handleBackfillResponse(
          hostId: aliceHostId,
          counter: 3,
          deleted: false,
          entryId: entryId,
        ),
      ).called(1);

      // Should verify and mark as backfilled
      verify(
        () => mockSequenceService.verifyAndMarkBackfilled(
          hostId: aliceHostId,
          counter: 3,
          entryId: entryId,
          entryVectorClock: any(named: 'entryVectorClock'),
        ),
      ).called(1);
    });

    test(
      'stores hint but skips verification when entry not found locally',
      () async {
        const response = SyncBackfillResponse(
          hostId: aliceHostId,
          counter: 3,
          deleted: false,
          entryId: entryId,
        );

        when(
          () => mockSequenceService.handleBackfillResponse(
            hostId: aliceHostId,
            counter: 3,
            deleted: false,
            entryId: entryId,
          ),
        ).thenAnswer((_) async {});

        // Entry does NOT exist locally
        when(
          () => mockJournalDb.journalEntityById(entryId),
        ).thenAnswer((_) async => null);

        await handler.handleBackfillResponse(response);

        // Should store the hint
        verify(
          () => mockSequenceService.handleBackfillResponse(
            hostId: aliceHostId,
            counter: 3,
            deleted: false,
            entryId: entryId,
          ),
        ).called(1);

        // Should NOT try to verify (entry not found)
        verifyNever(
          () => mockSequenceService.verifyAndMarkBackfilled(
            hostId: any(named: 'hostId'),
            counter: any(named: 'counter'),
            entryId: any(named: 'entryId'),
            entryVectorClock: any(named: 'entryVectorClock'),
          ),
        );
      },
    );

    test('skips verification when response has no entryId', () async {
      const response = SyncBackfillResponse(
        hostId: aliceHostId,
        counter: 3,
        deleted: false,
        // No entryId
      );

      when(
        () => mockSequenceService.handleBackfillResponse(
          hostId: aliceHostId,
          counter: 3,
          deleted: false,
        ),
      ).thenAnswer((_) async {});

      await handler.handleBackfillResponse(response);

      // Should store the hint
      verify(
        () => mockSequenceService.handleBackfillResponse(
          hostId: aliceHostId,
          counter: 3,
          deleted: false,
        ),
      ).called(1);

      // Should NOT try to verify (no entryId)
      verifyNever(() => mockJournalDb.journalEntityById(any()));
    });

    test('skips verification when entry has null vectorClock', () async {
      const response = SyncBackfillResponse(
        hostId: aliceHostId,
        counter: 3,
        deleted: false,
        entryId: entryId,
      );

      when(
        () => mockSequenceService.handleBackfillResponse(
          hostId: aliceHostId,
          counter: 3,
          deleted: false,
          entryId: entryId,
        ),
      ).thenAnswer((_) async {});

      // Entry exists but has null vectorClock
      final journalEntry = _createJournalEntryWithoutVC(entryId);
      when(
        () => mockJournalDb.journalEntityById(entryId),
      ).thenAnswer((_) async => journalEntry);

      await handler.handleBackfillResponse(response);

      // Should NOT try to verify (no VC)
      verifyNever(
        () => mockSequenceService.verifyAndMarkBackfilled(
          hostId: any(named: 'hostId'),
          counter: any(named: 'counter'),
          entryId: any(named: 'entryId'),
          entryVectorClock: any(named: 'entryVectorClock'),
        ),
      );
    });

    test('handles errors gracefully', () async {
      const response = SyncBackfillResponse(
        hostId: aliceHostId,
        counter: 3,
        deleted: true,
      );

      when(
        () => mockSequenceService.handleBackfillResponse(
          hostId: any(named: 'hostId'),
          counter: any(named: 'counter'),
          deleted: any(named: 'deleted'),
          entryId: any(named: 'entryId'),
        ),
      ).thenThrow(Exception('Database error'));

      // Should not throw
      await handler.handleBackfillResponse(response);

      // Should log the exception
      verify(
        () => mockLogging.error(
          any<LogDomain>(),
          any<Object>(),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
          subDomain: any(named: 'subDomain'),
        ),
      ).called(1);
    });
  });

  group('handleBackfillRequest - EntryLink', () {
    test('sends deleted response when entry link was deleted', () async {
      final logItem = _createLogItem(
        aliceHostId,
        10,
        entryId: 'deleted-link-id',
        payloadType: SyncSequencePayloadType.entryLink,
      );

      when(
        () => mockSequenceService.getEntryByHostAndCounter(aliceHostId, 10),
      ).thenAnswer((_) async => logItem);

      when(
        () => mockJournalDb.entryLinkById('deleted-link-id'),
      ).thenAnswer((_) async => null);

      when(
        () => mockOutboxService.enqueueMessage(any()),
      ).thenAnswer((_) async {});

      const request = SyncBackfillRequest(
        entries: [BackfillRequestEntry(hostId: aliceHostId, counter: 10)],
        requesterId: requesterId,
      );

      await handler.handleBackfillRequest(request);

      verify(
        () => mockOutboxService.enqueueMessage(
          any(
            that: isA<SyncBackfillResponse>()
                .having((r) => r.hostId, 'hostId', aliceHostId)
                .having((r) => r.counter, 'counter', 10)
                .having((r) => r.deleted, 'deleted', true)
                .having(
                  (r) => r.payloadType,
                  'payloadType',
                  SyncSequencePayloadType.entryLink,
                ),
          ),
        ),
      ).called(1);
    });

    test('re-sends entry link when it exists', () async {
      final logItem = _createLogItem(
        aliceHostId,
        20,
        entryId: 'existing-link-id',
        originatingHostId: aliceHostId,
        payloadType: SyncSequencePayloadType.entryLink,
      );

      final link = _createEntryLink(
        'existing-link-id',
        vectorClock: const VectorClock({aliceHostId: 20}),
      );

      when(
        () => mockSequenceService.getEntryByHostAndCounter(aliceHostId, 20),
      ).thenAnswer((_) async => logItem);

      when(
        () => mockJournalDb.entryLinkById('existing-link-id'),
      ).thenAnswer((_) async => link);

      when(
        () => mockOutboxService.enqueueMessage(any()),
      ).thenAnswer((_) async {});

      const request = SyncBackfillRequest(
        entries: [BackfillRequestEntry(hostId: aliceHostId, counter: 20)],
        requesterId: requesterId,
      );

      await handler.handleBackfillRequest(request);

      final captured = verify(
        () => mockOutboxService.enqueueMessage(captureAny()),
      ).captured;

      expect(captured.length, 1);
      expect(captured[0], isA<SyncEntryLink>());
    });

    test(
      'sends only unresolvable for entry link when exact own counter VC is behind',
      () async {
        // Link VC is {'test-host': 1} — doesn't contain aliceHostId at all.
        // Since aliceHostId is our own host, this is permanently wrong.
        final logItem = _createLogItem(
          aliceHostId,
          20,
          entryId: 'existing-link-id',
          originatingHostId: aliceHostId,
          payloadType: SyncSequencePayloadType.entryLink,
        );

        final link = _createEntryLink('existing-link-id');

        when(
          () => mockSequenceService.getEntryByHostAndCounter(aliceHostId, 20),
        ).thenAnswer((_) async => logItem);

        when(
          () => mockJournalDb.entryLinkById('existing-link-id'),
        ).thenAnswer((_) async => link);

        when(
          () => mockOutboxService.enqueueMessage(any()),
        ).thenAnswer((_) async {});

        const request = SyncBackfillRequest(
          entries: [BackfillRequestEntry(hostId: aliceHostId, counter: 20)],
          requesterId: requesterId,
        );

        await handler.handleBackfillRequest(request);

        final captured = verify(
          () => mockOutboxService.enqueueMessage(captureAny()),
        ).captured;

        expect(captured.length, 1);
        expect(
          captured[0],
          isA<SyncBackfillResponse>()
              .having((r) => r.deleted, 'deleted', false)
              .having((r) => r.unresolvable, 'unresolvable', true),
        );
      },
    );

    test(
      'sends hint for entry link when own counter VC is ahead',
      () async {
        // Link VC is {aliceHostId: 50} — ahead of counter 20 → legitimate
        // supersession, send a hint.
        final logItem = _createLogItem(
          aliceHostId,
          20,
          entryId: 'existing-link-id',
          originatingHostId: aliceHostId,
          payloadType: SyncSequencePayloadType.entryLink,
        );

        final link = _createEntryLink(
          'existing-link-id',
          vectorClock: const VectorClock({aliceHostId: 50}),
        );

        when(
          () => mockSequenceService.getEntryByHostAndCounter(aliceHostId, 20),
        ).thenAnswer((_) async => logItem);

        when(
          () => mockJournalDb.entryLinkById('existing-link-id'),
        ).thenAnswer((_) async => link);

        when(
          () => mockOutboxService.enqueueMessage(any()),
        ).thenAnswer((_) async {});

        const request = SyncBackfillRequest(
          entries: [BackfillRequestEntry(hostId: aliceHostId, counter: 20)],
          requesterId: requesterId,
        );

        await handler.handleBackfillRequest(request);

        final captured = verify(
          () => mockOutboxService.enqueueMessage(captureAny()),
        ).captured;

        expect(captured.length, 2);
        expect(captured[0], isA<SyncEntryLink>());
        expect(
          captured[1],
          isA<SyncBackfillResponse>()
              .having((r) => r.deleted, 'deleted', false)
              .having((r) => r.unresolvable, 'unresolvable', isNull)
              .having((r) => r.payloadId, 'payloadId', 'existing-link-id')
              .having(
                (r) => r.payloadType,
                'payloadType',
                SyncSequencePayloadType.entryLink,
              ),
        );
      },
    );
  });

  group('handleBackfillResponse - EntryLink', () {
    test(
      'verifies entry link and marks backfilled when link exists locally',
      () async {
        const response = SyncBackfillResponse(
          hostId: aliceHostId,
          counter: 30,
          deleted: false,
          payloadType: SyncSequencePayloadType.entryLink,
          payloadId: 'local-link-id',
        );

        final link = _createEntryLink('local-link-id');

        when(
          () => mockSequenceService.handleBackfillResponse(
            hostId: any(named: 'hostId'),
            counter: any(named: 'counter'),
            deleted: any(named: 'deleted'),
            entryId: any(named: 'entryId'),
            payloadType: any(named: 'payloadType'),
          ),
        ).thenAnswer((_) async {});

        when(
          () => mockJournalDb.entryLinkById('local-link-id'),
        ).thenAnswer((_) async => link);

        when(
          () => mockSequenceService.verifyAndMarkBackfilled(
            hostId: any(named: 'hostId'),
            counter: any(named: 'counter'),
            entryId: any(named: 'entryId'),
            entryVectorClock: any(named: 'entryVectorClock'),
            payloadType: any(named: 'payloadType'),
          ),
        ).thenAnswer((_) async => true);

        await handler.handleBackfillResponse(response);

        verify(
          () => mockSequenceService.verifyAndMarkBackfilled(
            hostId: aliceHostId,
            counter: 30,
            entryId: 'local-link-id',
            entryVectorClock: any(named: 'entryVectorClock'),
            payloadType: SyncSequencePayloadType.entryLink,
          ),
        ).called(1);
      },
    );

    test('stores hint when entry link not found locally', () async {
      const response = SyncBackfillResponse(
        hostId: aliceHostId,
        counter: 40,
        deleted: false,
        payloadType: SyncSequencePayloadType.entryLink,
        payloadId: 'missing-link-id',
      );

      when(
        () => mockSequenceService.handleBackfillResponse(
          hostId: any(named: 'hostId'),
          counter: any(named: 'counter'),
          deleted: any(named: 'deleted'),
          entryId: any(named: 'entryId'),
          payloadType: any(named: 'payloadType'),
        ),
      ).thenAnswer((_) async {});

      when(
        () => mockJournalDb.entryLinkById('missing-link-id'),
      ).thenAnswer((_) async => null);

      await handler.handleBackfillResponse(response);

      // Should store the hint
      verify(
        () => mockSequenceService.handleBackfillResponse(
          hostId: aliceHostId,
          counter: 40,
          deleted: false,
          entryId: 'missing-link-id',
          payloadType: SyncSequencePayloadType.entryLink,
        ),
      ).called(1);

      // Should NOT call verifyAndMarkBackfilled since link not found
      verifyNever(
        () => mockSequenceService.verifyAndMarkBackfilled(
          hostId: any(named: 'hostId'),
          counter: any(named: 'counter'),
          entryId: any(named: 'entryId'),
          entryVectorClock: any(named: 'entryVectorClock'),
          payloadType: any(named: 'payloadType'),
        ),
      );
    });

    test('skips verification when entry link has null vectorClock', () async {
      const response = SyncBackfillResponse(
        hostId: aliceHostId,
        counter: 50,
        deleted: false,
        payloadType: SyncSequencePayloadType.entryLink,
        payloadId: 'link-no-vc',
      );

      final link = _createEntryLinkWithoutVC('link-no-vc');

      when(
        () => mockSequenceService.handleBackfillResponse(
          hostId: any(named: 'hostId'),
          counter: any(named: 'counter'),
          deleted: any(named: 'deleted'),
          entryId: any(named: 'entryId'),
          payloadType: any(named: 'payloadType'),
        ),
      ).thenAnswer((_) async {});

      when(
        () => mockJournalDb.entryLinkById('link-no-vc'),
      ).thenAnswer((_) async => link);

      await handler.handleBackfillResponse(response);

      // Should NOT call verifyAndMarkBackfilled since VC is null
      verifyNever(
        () => mockSequenceService.verifyAndMarkBackfilled(
          hostId: any(named: 'hostId'),
          counter: any(named: 'counter'),
          entryId: any(named: 'entryId'),
          entryVectorClock: any(named: 'entryVectorClock'),
          payloadType: any(named: 'payloadType'),
        ),
      );
    });
  });

  group('handleBackfillRequest - AgentEntity', () {
    test('re-sends agent entity and hint when counter not in VC', () async {
      const agentEntityId = 'agent-entity-id';

      final logItem = _createLogItem(
        aliceHostId,
        10,
        entryId: agentEntityId,
        originatingHostId: bobHostId,
        payloadType: SyncSequencePayloadType.agentEntity,
      );

      when(
        () => mockSequenceService.getEntryByHostAndCounter(aliceHostId, 10),
      ).thenAnswer((_) async => logItem);

      final agentEntity = makeTestIdentity(
        id: agentEntityId,
        vectorClock: const VectorClock({
          'alice-host-uuid': 15, // Counter 10 is not in VC (superseded)
        }),
      );

      when(
        () => mockAgentRepository.getEntity(agentEntityId),
      ).thenAnswer((_) async => agentEntity);

      when(
        () => mockOutboxService.enqueueMessage(any()),
      ).thenAnswer((_) async {});

      const request = SyncBackfillRequest(
        entries: [
          BackfillRequestEntry(hostId: aliceHostId, counter: 10),
        ],
        requesterId: requesterId,
      );

      await handler.handleBackfillRequest(request);

      final captured = verify(
        () => mockOutboxService.enqueueMessage(captureAny()),
      ).captured;

      expect(captured.length, 2);
      expect(captured[0], isA<SyncAgentEntity>());
      expect(
        captured[1],
        isA<SyncBackfillResponse>()
            .having((r) => r.deleted, 'deleted', false)
            .having((r) => r.payloadId, 'payloadId', agentEntityId)
            .having(
              (r) => r.payloadType,
              'payloadType',
              SyncSequencePayloadType.agentEntity,
            ),
      );
    });

    test(
      'sends only unresolvable for agent entity when exact own counter VC is behind',
      () async {
        const agentEntityId = 'agent-entity-id';

        final logItem = _createLogItem(
          aliceHostId,
          10,
          entryId: agentEntityId,
          originatingHostId: aliceHostId,
          payloadType: SyncSequencePayloadType.agentEntity,
        );

        when(
          () => mockSequenceService.getEntryByHostAndCounter(aliceHostId, 10),
        ).thenAnswer((_) async => logItem);

        final agentEntity = makeTestIdentity(
          id: agentEntityId,
          vectorClock: const VectorClock({'other-host': 1}),
        );

        when(
          () => mockAgentRepository.getEntity(agentEntityId),
        ).thenAnswer((_) async => agentEntity);

        when(
          () => mockOutboxService.enqueueMessage(any()),
        ).thenAnswer((_) async {});

        const request = SyncBackfillRequest(
          entries: [
            BackfillRequestEntry(hostId: aliceHostId, counter: 10),
          ],
          requesterId: requesterId,
        );

        await handler.handleBackfillRequest(request);

        final captured = verify(
          () => mockOutboxService.enqueueMessage(captureAny()),
        ).captured;

        expect(captured.length, 1);
        expect(
          captured[0],
          isA<SyncBackfillResponse>()
              .having((r) => r.deleted, 'deleted', false)
              .having((r) => r.unresolvable, 'unresolvable', true)
              .having(
                (r) => r.payloadType,
                'payloadType',
                SyncSequencePayloadType.agentEntity,
              ),
        );
      },
    );

    test('sends deleted response when agent entity not found', () async {
      final logItem = _createLogItem(
        aliceHostId,
        10,
        entryId: 'missing-agent-id',
        originatingHostId: bobHostId,
        payloadType: SyncSequencePayloadType.agentEntity,
      );

      when(
        () => mockSequenceService.getEntryByHostAndCounter(aliceHostId, 10),
      ).thenAnswer((_) async => logItem);

      when(
        () => mockAgentRepository.getEntity('missing-agent-id'),
      ).thenAnswer((_) async => null);

      when(
        () => mockOutboxService.enqueueMessage(any()),
      ).thenAnswer((_) async {});

      const request = SyncBackfillRequest(
        entries: [
          BackfillRequestEntry(hostId: aliceHostId, counter: 10),
        ],
        requesterId: requesterId,
      );

      await handler.handleBackfillRequest(request);

      verify(
        () => mockOutboxService.enqueueMessage(
          any<SyncMessage>(
            that: isA<SyncBackfillResponse>()
                .having((r) => r.deleted, 'deleted', true)
                .having(
                  (r) => r.payloadType,
                  'payloadType',
                  SyncSequencePayloadType.agentEntity,
                ),
          ),
        ),
      ).called(1);
    });

    test('skips backfill when agentRepository is null', () async {
      handler.agentRepository = null;

      final logItem = _createLogItem(
        aliceHostId,
        10,
        entryId: 'some-agent-id',
        originatingHostId: bobHostId,
        payloadType: SyncSequencePayloadType.agentEntity,
      );

      when(
        () => mockSequenceService.getEntryByHostAndCounter(aliceHostId, 10),
      ).thenAnswer((_) async => logItem);

      const request = SyncBackfillRequest(
        entries: [
          BackfillRequestEntry(hostId: aliceHostId, counter: 10),
        ],
        requesterId: requesterId,
      );

      await handler.handleBackfillRequest(request);

      // Should not enqueue anything since there's no agent repository
      verifyNever(() => mockOutboxService.enqueueMessage(any()));

      // Logging now goes through DomainLogger (not injected in tests)
    });
  });

  group('handleBackfillRequest - AgentLink', () {
    test('re-sends agent link and hint when counter not in VC', () async {
      const agentLinkId = 'agent-link-id';

      final logItem = _createLogItem(
        aliceHostId,
        20,
        entryId: agentLinkId,
        originatingHostId: bobHostId,
        payloadType: SyncSequencePayloadType.agentLink,
      );

      when(
        () => mockSequenceService.getEntryByHostAndCounter(aliceHostId, 20),
      ).thenAnswer((_) async => logItem);

      final agentLink = makeTestBasicLink(
        id: agentLinkId,
        vectorClock: const VectorClock({
          'alice-host-uuid': 25, // Counter 20 is not in VC (superseded)
        }),
      );

      when(
        () => mockAgentRepository.getLinkById(agentLinkId),
      ).thenAnswer((_) async => agentLink);

      when(
        () => mockOutboxService.enqueueMessage(any()),
      ).thenAnswer((_) async {});

      const request = SyncBackfillRequest(
        entries: [
          BackfillRequestEntry(hostId: aliceHostId, counter: 20),
        ],
        requesterId: requesterId,
      );

      await handler.handleBackfillRequest(request);

      final captured = verify(
        () => mockOutboxService.enqueueMessage(captureAny()),
      ).captured;

      expect(captured.length, 2);
      expect(captured[0], isA<SyncAgentLink>());
      expect(
        captured[1],
        isA<SyncBackfillResponse>()
            .having((r) => r.deleted, 'deleted', false)
            .having((r) => r.payloadId, 'payloadId', agentLinkId)
            .having(
              (r) => r.payloadType,
              'payloadType',
              SyncSequencePayloadType.agentLink,
            ),
      );
    });

    test('sends deleted response when agent link not found', () async {
      final logItem = _createLogItem(
        aliceHostId,
        20,
        entryId: 'missing-link-id',
        originatingHostId: bobHostId,
        payloadType: SyncSequencePayloadType.agentLink,
      );

      when(
        () => mockSequenceService.getEntryByHostAndCounter(aliceHostId, 20),
      ).thenAnswer((_) async => logItem);

      when(
        () => mockAgentRepository.getLinkById('missing-link-id'),
      ).thenAnswer((_) async => null);

      when(
        () => mockOutboxService.enqueueMessage(any()),
      ).thenAnswer((_) async {});

      const request = SyncBackfillRequest(
        entries: [
          BackfillRequestEntry(hostId: aliceHostId, counter: 20),
        ],
        requesterId: requesterId,
      );

      await handler.handleBackfillRequest(request);

      verify(
        () => mockOutboxService.enqueueMessage(
          any<SyncMessage>(
            that: isA<SyncBackfillResponse>()
                .having((r) => r.deleted, 'deleted', true)
                .having(
                  (r) => r.payloadType,
                  'payloadType',
                  SyncSequencePayloadType.agentLink,
                ),
          ),
        ),
      ).called(1);
    });

    test('skips backfill when agentRepository is null', () async {
      handler.agentRepository = null;

      final logItem = _createLogItem(
        aliceHostId,
        20,
        entryId: 'some-link-id',
        originatingHostId: bobHostId,
        payloadType: SyncSequencePayloadType.agentLink,
      );

      when(
        () => mockSequenceService.getEntryByHostAndCounter(aliceHostId, 20),
      ).thenAnswer((_) async => logItem);

      const request = SyncBackfillRequest(
        entries: [
          BackfillRequestEntry(hostId: aliceHostId, counter: 20),
        ],
        requesterId: requesterId,
      );

      await handler.handleBackfillRequest(request);

      verifyNever(() => mockOutboxService.enqueueMessage(any()));

      // Logging now goes through DomainLogger (not injected in tests)
    });
  });

  group('handleBackfillResponse - AgentEntity', () {
    test('verifies agent entity and marks backfilled when found', () async {
      const response = SyncBackfillResponse(
        hostId: aliceHostId,
        counter: 10,
        deleted: false,
        payloadType: SyncSequencePayloadType.agentEntity,
        payloadId: 'agent-entity-id',
      );

      when(
        () => mockSequenceService.handleBackfillResponse(
          hostId: any(named: 'hostId'),
          counter: any(named: 'counter'),
          deleted: any(named: 'deleted'),
          entryId: any(named: 'entryId'),
          payloadType: any(named: 'payloadType'),
        ),
      ).thenAnswer((_) async {});

      final agentEntity = makeTestIdentity(
        id: 'agent-entity-id',
        vectorClock: const VectorClock({'test-host': 1}),
      );

      when(
        () => mockAgentRepository.getEntity('agent-entity-id'),
      ).thenAnswer((_) async => agentEntity);

      when(
        () => mockSequenceService.verifyAndMarkBackfilled(
          hostId: any(named: 'hostId'),
          counter: any(named: 'counter'),
          entryId: any(named: 'entryId'),
          entryVectorClock: any(named: 'entryVectorClock'),
          payloadType: any(named: 'payloadType'),
        ),
      ).thenAnswer((_) async => true);

      await handler.handleBackfillResponse(response);

      verify(
        () => mockSequenceService.verifyAndMarkBackfilled(
          hostId: aliceHostId,
          counter: 10,
          entryId: 'agent-entity-id',
          entryVectorClock: any(named: 'entryVectorClock'),
          payloadType: SyncSequencePayloadType.agentEntity,
        ),
      ).called(1);
    });
  });

  group('handleBackfillResponse - AgentLink', () {
    test('verifies agent link and marks backfilled when found', () async {
      const response = SyncBackfillResponse(
        hostId: aliceHostId,
        counter: 20,
        deleted: false,
        payloadType: SyncSequencePayloadType.agentLink,
        payloadId: 'agent-link-id',
      );

      when(
        () => mockSequenceService.handleBackfillResponse(
          hostId: any(named: 'hostId'),
          counter: any(named: 'counter'),
          deleted: any(named: 'deleted'),
          entryId: any(named: 'entryId'),
          payloadType: any(named: 'payloadType'),
        ),
      ).thenAnswer((_) async {});

      final agentLink = makeTestBasicLink(
        id: 'agent-link-id',
        vectorClock: const VectorClock({'test-host': 1}),
      );

      when(
        () => mockAgentRepository.getLinkById('agent-link-id'),
      ).thenAnswer((_) async => agentLink);

      when(
        () => mockSequenceService.verifyAndMarkBackfilled(
          hostId: any(named: 'hostId'),
          counter: any(named: 'counter'),
          entryId: any(named: 'entryId'),
          entryVectorClock: any(named: 'entryVectorClock'),
          payloadType: any(named: 'payloadType'),
        ),
      ).thenAnswer((_) async => true);

      await handler.handleBackfillResponse(response);

      verify(
        () => mockSequenceService.verifyAndMarkBackfilled(
          hostId: aliceHostId,
          counter: 20,
          entryId: 'agent-link-id',
          entryVectorClock: any(named: 'entryVectorClock'),
          payloadType: SyncSequencePayloadType.agentLink,
        ),
      ).called(1);
    });

    test('skips verify when agentRepository is null', () async {
      handler.agentRepository = null;

      const response = SyncBackfillResponse(
        hostId: aliceHostId,
        counter: 20,
        deleted: false,
        payloadType: SyncSequencePayloadType.agentLink,
        payloadId: 'agent-link-id',
      );

      when(
        () => mockSequenceService.handleBackfillResponse(
          hostId: any(named: 'hostId'),
          counter: any(named: 'counter'),
          deleted: any(named: 'deleted'),
          entryId: any(named: 'entryId'),
          payloadType: any(named: 'payloadType'),
        ),
      ).thenAnswer((_) async {});

      await handler.handleBackfillResponse(response);

      // Should NOT call verifyAndMarkBackfilled since repo is null
      verifyNever(
        () => mockSequenceService.verifyAndMarkBackfilled(
          hostId: any(named: 'hostId'),
          counter: any(named: 'counter'),
          entryId: any(named: 'entryId'),
          entryVectorClock: any(named: 'entryVectorClock'),
          payloadType: any(named: 'payloadType'),
        ),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Tests merged from backfill_response_handler_generated_test.dart
  // ---------------------------------------------------------------------------
  group('BackfillResponseHandler generated tests', () {
    // Same values as aliceHostId / bobHostId used elsewhere in the suite.
    const ownHostId = 'alice-host-uuid';
    const foreignHostId = 'bob-host-uuid';

    setUpAll(() {
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
                (_) async => _createLogItemSrc(
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
                (_) async => _createLogItemSrc(
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
        glados.ExploreConfig(numRuns: 160),
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
              (_) async => _createLogItemSrc(
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
        glados.ExploreConfig(numRuns: 160),
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
                  scenario.responseKind ==
                  _GeneratedIncomingResponseKind.deleted,
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
  });
}

SyncSequenceLogItem _createLogItem(
  String hostId,
  int counter, {
  String? entryId,
  String? originatingHostId,
  SyncSequenceStatus status = SyncSequenceStatus.received,
  SyncSequencePayloadType payloadType = SyncSequencePayloadType.journalEntity,
}) {
  return SyncSequenceLogItem(
    hostId: hostId,
    counter: counter,
    entryId: entryId,
    payloadType: payloadType.index,
    originatingHostId: originatingHostId,
    status: status.index,
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
    requestCount: 0,
  );
}

JournalEntity _createJournalEntry(
  String id, {
  VectorClock? vectorClock,
}) {
  return JournalEntity.journalEntry(
    meta: Metadata(
      id: id,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
      dateFrom: DateTime(2024),
      dateTo: DateTime(2024),
      vectorClock: vectorClock ?? const VectorClock({'test-host': 1}),
    ),
    entryText: const EntryText(plainText: 'Test entry'),
  );
}

JournalEntity _createJournalEntryWithoutVC(String id) {
  return JournalEntity.journalEntry(
    meta: Metadata(
      id: id,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
      dateFrom: DateTime(2024),
      dateTo: DateTime(2024),
      // vectorClock is null
    ),
    entryText: const EntryText(plainText: 'Test entry'),
  );
}

EntryLink _createEntryLink(
  String id, {
  VectorClock? vectorClock,
}) {
  return EntryLink.basic(
    id: id,
    fromId: 'from-entry',
    toId: 'to-entry',
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
    vectorClock: vectorClock ?? const VectorClock({'test-host': 1}),
  );
}

EntryLink _createEntryLinkWithoutVC(String id) {
  return EntryLink.basic(
    id: id,
    fromId: 'from-entry',
    toId: 'to-entry',
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
    vectorClock: null,
  );
}

// ---------------------------------------------------------------------------
// Helper functions moved from backfill_response_handler_generated_test.dart
// (renamed with Src suffix to avoid conflicts with existing helpers above)
// ---------------------------------------------------------------------------

String _cooldownKey(String hostId, int counter) => '$hostId:$counter';

SyncSequenceLogItem _createLogItemSrc(
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

JournalEntity _createJournalEntrySrc(
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

EntryLink _createEntryLinkSrc(
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
            : _createJournalEntrySrc(payloadId, vectorClock: vectorClock),
      );
    case SyncSequencePayloadType.entryLink:
      when(
        () => bench.journalDb.entryLinkById(payloadId),
      ).thenAnswer(
        (_) async => vectorClock == null
            ? null
            : _createEntryLinkSrc(payloadId, vectorClock: vectorClock),
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
            ? _createJournalEntrySrc(payloadId, vectorClock: vectorClock)
            : null,
      );
    case SyncSequencePayloadType.entryLink:
      when(
        () => bench.journalDb.entryLinkById(payloadId),
      ).thenAnswer(
        (_) async => scenario.payloadExists
            ? _createEntryLinkSrc(payloadId, vectorClock: vectorClock)
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
