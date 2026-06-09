import 'dart:convert';
import 'dart:io';

import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:lotti/features/sync/queue/inbound_worker.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

// Local mock: the centralized `AdapterMockSyncEventProcessor` ships concrete
// default `prepare`/`apply` overrides, so `when(() => processor.prepare(
// event: any(named: 'event')))` would call the real method and leak the
// unconsumed matcher. This file stubs both via `when()`, so it needs the
// bare-Mock variant.
class AdapterMockSyncEventProcessor extends Mock
    implements SyncEventProcessor {}

class AdapterMockPreparedSyncEvent extends Mock implements PreparedSyncEvent {}

enum GeneratedAdapterPrepareOutcome {
  ready,
  nullPrepared,
  pendingDescriptor,
  pendingPath,
  retriableIo,
  permanentThrow,
}

enum GeneratedAdapterApplyOutcome {
  applied,
  pendingDescriptor,
  pendingPath,
  retriableIo,
  retriableThrow,
}

enum GeneratedAdapterMessageKind {
  journalEntity,
  entryLink,
  configFlag,
  themingSelection,
  backfillRequest,
}

class GeneratedAdapterScenario {
  const GeneratedAdapterScenario({
    required this.prepareOutcome,
    required this.applyOutcome,
    required this.messageKind,
    required this.usePrepareBatch,
    required this.slot,
  });

  final GeneratedAdapterPrepareOutcome prepareOutcome;
  final GeneratedAdapterApplyOutcome applyOutcome;
  final GeneratedAdapterMessageKind messageKind;
  final bool usePrepareBatch;
  final int slot;

  bool get prepareReady =>
      prepareOutcome == GeneratedAdapterPrepareOutcome.ready;

  ApplyOutcome get expectedOutcome {
    switch (prepareOutcome) {
      case GeneratedAdapterPrepareOutcome.ready:
        return _expectedApplyOutcome;
      case GeneratedAdapterPrepareOutcome.nullPrepared:
      case GeneratedAdapterPrepareOutcome.permanentThrow:
        return ApplyOutcome.permanentSkip;
      case GeneratedAdapterPrepareOutcome.pendingDescriptor:
      case GeneratedAdapterPrepareOutcome.pendingPath:
        return ApplyOutcome.pendingAttachment;
      case GeneratedAdapterPrepareOutcome.retriableIo:
        return ApplyOutcome.retriable;
    }
  }

  ApplyOutcome get _expectedApplyOutcome {
    switch (applyOutcome) {
      case GeneratedAdapterApplyOutcome.applied:
        return ApplyOutcome.applied;
      case GeneratedAdapterApplyOutcome.pendingDescriptor:
      case GeneratedAdapterApplyOutcome.pendingPath:
        return ApplyOutcome.pendingAttachment;
      case GeneratedAdapterApplyOutcome.retriableIo:
      case GeneratedAdapterApplyOutcome.retriableThrow:
        return ApplyOutcome.retriable;
    }
  }

  Object prepareException() {
    switch (prepareOutcome) {
      case GeneratedAdapterPrepareOutcome.pendingDescriptor:
        return const FileSystemException(
          'attachment descriptor not yet available',
        );
      case GeneratedAdapterPrepareOutcome.pendingPath:
        return FileSystemException(
          'missing',
          '/agent_entities/generated-$slot.json',
        );
      case GeneratedAdapterPrepareOutcome.retriableIo:
        return FileSystemException('disk busy', '/tmp/generated-$slot.json');
      case GeneratedAdapterPrepareOutcome.permanentThrow:
        return StateError('generated prepare failure');
      case GeneratedAdapterPrepareOutcome.ready:
      case GeneratedAdapterPrepareOutcome.nullPrepared:
        throw StateError('prepare outcome has no exception: $prepareOutcome');
    }
  }

  Object applyException() {
    switch (applyOutcome) {
      case GeneratedAdapterApplyOutcome.pendingDescriptor:
        return const FileSystemException(
          'attachment descriptor not yet available',
        );
      case GeneratedAdapterApplyOutcome.pendingPath:
        return FileSystemException('missing', '/images/generated-$slot.jpg');
      case GeneratedAdapterApplyOutcome.retriableIo:
        return FileSystemException('disk busy', '/tmp/generated-$slot.json');
      case GeneratedAdapterApplyOutcome.retriableThrow:
        return StateError('generated apply failure');
      case GeneratedAdapterApplyOutcome.applied:
        throw StateError('apply outcome has no exception: $applyOutcome');
    }
  }

  SyncMessage syncMessage() {
    switch (messageKind) {
      case GeneratedAdapterMessageKind.journalEntity:
        return SyncMessage.journalEntity(
          id: 'entity-$slot',
          jsonPath: '/entities/$slot.json',
          vectorClock: null,
          status: SyncEntryStatus.initial,
        );
      case GeneratedAdapterMessageKind.entryLink:
        return SyncMessage.entryLink(
          entryLink: EntryLink.basic(
            id: 'link-$slot',
            fromId: 'from-$slot',
            toId: 'to-$slot',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          ),
          status: SyncEntryStatus.initial,
        );
      case GeneratedAdapterMessageKind.configFlag:
        return SyncMessage.configFlag(
          name: 'generated-flag-$slot',
          description: 'Generated flag',
          status: slot.isEven,
        );
      case GeneratedAdapterMessageKind.themingSelection:
        return SyncMessage.themingSelection(
          lightThemeName: 'light-$slot',
          darkThemeName: 'dark-$slot',
          themeMode: 'system',
          updatedAt: slot,
          status: SyncEntryStatus.update,
        );
      case GeneratedAdapterMessageKind.backfillRequest:
        return SyncMessage.backfillRequest(
          entries: const <BackfillRequestEntry>[],
          requesterId: 'host-$slot',
        );
    }
  }

  @override
  String toString() {
    return 'GeneratedAdapterScenario('
        'prepareOutcome: $prepareOutcome, '
        'applyOutcome: $applyOutcome, '
        'messageKind: $messageKind, '
        'usePrepareBatch: $usePrepareBatch, '
        'slot: $slot'
        ')';
  }
}

extension AnyGeneratedAdapterScenario on glados.Any {
  glados.Generator<GeneratedAdapterPrepareOutcome> get adapterPrepareOutcome =>
      glados.AnyUtils(this).choose(GeneratedAdapterPrepareOutcome.values);

  glados.Generator<GeneratedAdapterApplyOutcome> get adapterApplyOutcome =>
      glados.AnyUtils(this).choose(GeneratedAdapterApplyOutcome.values);

  glados.Generator<GeneratedAdapterMessageKind> get adapterMessageKind =>
      glados.AnyUtils(this).choose(GeneratedAdapterMessageKind.values);

  glados.Generator<GeneratedAdapterScenario> get adapterScenario =>
      glados.CombinableAny(this).combine5(
        adapterPrepareOutcome,
        adapterApplyOutcome,
        adapterMessageKind,
        glados.IntAnys(this).intInRange(0, 2),
        glados.IntAnys(this).intInRange(0, 8),
        (
          GeneratedAdapterPrepareOutcome prepareOutcome,
          GeneratedAdapterApplyOutcome applyOutcome,
          GeneratedAdapterMessageKind messageKind,
          int usePrepareBatchSlot,
          int slot,
        ) => GeneratedAdapterScenario(
          prepareOutcome: prepareOutcome,
          applyOutcome: applyOutcome,
          messageKind: messageKind,
          usePrepareBatch: usePrepareBatchSlot == 1,
          slot: slot,
        ),
      );
}

InboundQueueEntry hBuildEntry({
  required String eventId,
  required String roomId,
  required int originTsMs,
}) {
  final content = <String, dynamic>{'msgtype': syncMessageType};
  final json = <String, dynamic>{
    'event_id': eventId,
    'room_id': roomId,
    'origin_server_ts': originTsMs,
    'type': EventTypes.Message,
    'sender': '@tester:example.org',
    'content': content,
  };
  return InboundQueueEntry(
    queueId: 1,
    eventId: eventId,
    roomId: roomId,
    originTs: originTsMs,
    producer: InboundEventProducer.live,
    enqueuedAt: originTsMs,
    attempts: 0,
    leaseUntil: 0,
    rawJson: jsonEncode(json),
  );
}
