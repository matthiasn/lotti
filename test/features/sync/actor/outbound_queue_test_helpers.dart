import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/matrix/sync_room_discovery.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

OutboxCompanion hBuildOutbox({
  required String subject,
  required String message,
  required DateTime createdAt,
  int retries = 0,
}) {
  return OutboxCompanion(
    status: Value(OutboxStatus.pending.index),
    subject: Value(subject),
    message: Value(message),
    createdAt: Value(createdAt),
    updatedAt: Value(createdAt),
    retries: Value(retries),
  );
}

String hSyncMessageJson(String id) =>
    jsonEncode(SyncMessage.aiConfigDelete(id: id).toJson());

const hGeneratedExplicitRoomId = '!generated-explicit:localhost';
const hGeneratedSyncRoomId = '!generated-sync:localhost';
const hGeneratedEventId = r'$generated-event';
const hGeneratedRetryDelay = Duration(milliseconds: 50);
const hGeneratedErrorDelay = Duration(milliseconds: 250);
const hGeneratedMaxRetries = 3;

enum GeneratedOutboundRoomMode {
  explicit,
  uniqueMarked,
  noMarked,
  multipleMarked,
  throwingAndUniqueMarked,
}

enum GeneratedOutboundStartState {
  connected,
  disconnected,
  disposed,
}

enum GeneratedOutboundPayloadShape {
  valid,
  invalidJson,
  nonMapJson,
}

enum GeneratedOutboundSendPlan {
  success,
  throws,
  throwsAndDisconnects,
  throwsAndDisposes,
}

class GeneratedOutboundDrainScenario {
  const GeneratedOutboundDrainScenario({
    required this.roomMode,
    required this.startState,
    required this.hasItem,
    required this.payloadShape,
    required this.sendPlan,
    required this.initialRetries,
    required this.pendingTailCount,
  });

  final GeneratedOutboundRoomMode roomMode;
  final GeneratedOutboundStartState startState;
  final bool hasItem;
  final GeneratedOutboundPayloadShape payloadShape;
  final GeneratedOutboundSendPlan sendPlan;
  final int initialRetries;
  final int pendingTailCount;

  String? get configuredRoomId => roomMode == GeneratedOutboundRoomMode.explicit
      ? hGeneratedExplicitRoomId
      : null;

  String? get expectedRoomId {
    return switch (roomMode) {
      GeneratedOutboundRoomMode.explicit => hGeneratedExplicitRoomId,
      GeneratedOutboundRoomMode.uniqueMarked => hGeneratedSyncRoomId,
      GeneratedOutboundRoomMode.noMarked => null,
      GeneratedOutboundRoomMode.multipleMarked => null,
      GeneratedOutboundRoomMode.throwingAndUniqueMarked => hGeneratedSyncRoomId,
    };
  }

  bool get isConnected =>
      startState != GeneratedOutboundStartState.disconnected;

  bool get isDisposedBeforeDrain =>
      startState == GeneratedOutboundStartState.disposed;

  bool get isReadyToClaim =>
      hasItem &&
      isConnected &&
      !isDisposedBeforeDrain &&
      expectedRoomId != null;

  bool get sendsToGateway =>
      isReadyToClaim && payloadShape == GeneratedOutboundPayloadShape.valid;

  bool get succeeds =>
      sendsToGateway && sendPlan == GeneratedOutboundSendPlan.success;

  bool get failsAfterClaim => isReadyToClaim && !succeeds;

  bool get reachesRetryCap => initialRetries + 1 >= hGeneratedMaxRetries;

  bool get failureChangesQueueState {
    return sendsToGateway &&
        (sendPlan == GeneratedOutboundSendPlan.throwsAndDisconnects ||
            sendPlan == GeneratedOutboundSendPlan.throwsAndDisposes);
  }

  String get headSubject => 'generated-head';

  String get headMessage {
    return switch (payloadShape) {
      GeneratedOutboundPayloadShape.valid => hSyncMessageJson(headSubject),
      GeneratedOutboundPayloadShape.invalidJson => '{not-json',
      GeneratedOutboundPayloadShape.nonMapJson => jsonEncode(['not-a-map']),
    };
  }

  Duration? get expectedDelay {
    if (!isReadyToClaim) {
      return null;
    }
    if (succeeds) {
      return pendingTailCount > 0 ? Duration.zero : null;
    }
    if (failureChangesQueueState) {
      return hGeneratedErrorDelay;
    }
    return reachesRetryCap ? Duration.zero : hGeneratedRetryDelay;
  }

  int? get expectedHeadStatus {
    if (!hasItem) {
      return null;
    }
    if (!isReadyToClaim) {
      return OutboxStatus.pending.index;
    }
    if (succeeds) {
      return OutboxStatus.sent.index;
    }
    return reachesRetryCap
        ? OutboxStatus.error.index
        : OutboxStatus.pending.index;
  }

  int? get expectedHeadRetries {
    if (!hasItem) {
      return null;
    }
    if (!failsAfterClaim) {
      return initialRetries;
    }
    return initialRetries + 1;
  }

  @override
  String toString() {
    return 'GeneratedOutboundDrainScenario('
        'roomMode: $roomMode, '
        'startState: $startState, '
        'hasItem: $hasItem, '
        'payloadShape: $payloadShape, '
        'sendPlan: $sendPlan, '
        'initialRetries: $initialRetries, '
        'pendingTailCount: $pendingTailCount'
        ')';
  }
}

extension AnyGeneratedOutboundDrainScenario on glados.Any {
  glados.Generator<GeneratedOutboundRoomMode> get outboundRoomMode =>
      glados.AnyUtils(this).choose(GeneratedOutboundRoomMode.values);

  glados.Generator<GeneratedOutboundStartState> get outboundStartState =>
      glados.AnyUtils(this).choose(GeneratedOutboundStartState.values);

  glados.Generator<GeneratedOutboundPayloadShape> get outboundPayloadShape =>
      glados.AnyUtils(this).choose(GeneratedOutboundPayloadShape.values);

  glados.Generator<GeneratedOutboundSendPlan> get outboundSendPlan =>
      glados.AnyUtils(this).choose(GeneratedOutboundSendPlan.values);

  glados.Generator<GeneratedOutboundDrainScenario> get outboundDrainScenario =>
      glados.CombinableAny(this).combine7(
        outboundRoomMode,
        outboundStartState,
        glados.BoolAny(this).bool,
        outboundPayloadShape,
        outboundSendPlan,
        glados.IntAnys(this).intInRange(0, 4),
        glados.IntAnys(this).intInRange(0, 3),
        (
          GeneratedOutboundRoomMode roomMode,
          GeneratedOutboundStartState startState,
          bool hasItem,
          GeneratedOutboundPayloadShape payloadShape,
          GeneratedOutboundSendPlan sendPlan,
          int initialRetries,
          int pendingTailCount,
        ) => GeneratedOutboundDrainScenario(
          roomMode: roomMode,
          startState: startState,
          hasItem: hasItem,
          payloadShape: payloadShape,
          sendPlan: sendPlan,
          initialRetries: initialRetries,
          pendingTailCount: pendingTailCount,
        ),
      );
}

/// A single room's behaviour for the room-resolution property.
///
/// [marked] rooms report a sync state event; [unmarked] report `null`;
/// [throwing] raise from `getState` (which `_resolveSyncRoomId` treats as
/// unmarked via its `catch`).
enum GeneratedRoomKind {
  marked,
  unmarked,
  throwing,
}

extension AnyGeneratedRoomKindList on glados.Any {
  glados.Generator<GeneratedRoomKind> get generatedRoomKind =>
      glados.AnyUtils(this).choose(GeneratedRoomKind.values);

  glados.Generator<List<GeneratedRoomKind>> get generatedRoomTopology =>
      glados.ListAnys(this).listWithLengthInRange(0, 6, generatedRoomKind);
}

MockRoom hGeneratedRoom({
  required String id,
  required bool isSyncMarked,
  bool throwsOnState = false,
}) {
  final room = MockRoom();
  when(() => room.id).thenReturn(id);
  if (throwsOnState) {
    when(() => room.getState(lottiSyncRoomStateType)).thenThrow(
      StateError('state unavailable'),
    );
  } else {
    when(() => room.getState(lottiSyncRoomStateType)).thenReturn(
      isSyncMarked ? MockStrippedStateEvent() : null,
    );
  }
  return room;
}

void hStubGeneratedRooms({
  required MockMatrixClient client,
  required GeneratedOutboundRoomMode roomMode,
}) {
  final rooms = switch (roomMode) {
    GeneratedOutboundRoomMode.explicit => <Room>[],
    GeneratedOutboundRoomMode.uniqueMarked => <Room>[
      hGeneratedRoom(id: '!generated-other:localhost', isSyncMarked: false),
      hGeneratedRoom(id: hGeneratedSyncRoomId, isSyncMarked: true),
    ],
    GeneratedOutboundRoomMode.noMarked => <Room>[
      hGeneratedRoom(id: '!generated-other:localhost', isSyncMarked: false),
    ],
    GeneratedOutboundRoomMode.multipleMarked => <Room>[
      hGeneratedRoom(id: '!generated-sync-a:localhost', isSyncMarked: true),
      hGeneratedRoom(id: '!generated-sync-b:localhost', isSyncMarked: true),
    ],
    GeneratedOutboundRoomMode.throwingAndUniqueMarked => <Room>[
      hGeneratedRoom(
        id: '!generated-throwing:localhost',
        isSyncMarked: false,
        throwsOnState: true,
      ),
      hGeneratedRoom(id: hGeneratedSyncRoomId, isSyncMarked: true),
    ],
  };
  when(() => client.rooms).thenReturn(rooms);
}

Future<void> hInsertGeneratedOutboxRows({
  required SyncDatabase db,
  required GeneratedOutboundDrainScenario scenario,
}) async {
  if (!scenario.hasItem) {
    return;
  }

  final base = DateTime(2024, 1, 2);
  await db.addOutboxItem(
    hBuildOutbox(
      subject: scenario.headSubject,
      message: scenario.headMessage,
      createdAt: base,
      retries: scenario.initialRetries,
    ),
  );

  for (var index = 0; index < scenario.pendingTailCount; index++) {
    await db.addOutboxItem(
      hBuildOutbox(
        subject: 'generated-tail-$index',
        message: hSyncMessageJson('generated-tail-$index'),
        createdAt: base.add(Duration(minutes: index + 1)),
      ),
    );
  }
}

Map<String, dynamic> hDecodeSentSyncMessage(String encoded) {
  return jsonDecode(utf8.decode(base64.decode(encoded)))
      as Map<String, dynamic>;
}
