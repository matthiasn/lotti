import 'dart:collection';

import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

Event buildEvent({
  required String eventId,
  required String roomId,
  required int originTsMs,
  required String type,
  Map<String, dynamic>? content,
}) {
  final event = MockEvent();
  final c = content ?? <String, dynamic>{'msgtype': syncMessageType};
  when(() => event.eventId).thenReturn(eventId);
  when(() => event.roomId).thenReturn(roomId);
  when(() => event.type).thenReturn(type);
  when(() => event.content).thenReturn(c);
  when(() => event.text).thenReturn('stub');
  when(
    () => event.originServerTs,
  ).thenReturn(DateTime.fromMillisecondsSinceEpoch(originTsMs));
  when(event.toJson).thenReturn(<String, dynamic>{
    'event_id': eventId,
    'room_id': roomId,
    'origin_server_ts': originTsMs,
    'type': type,
    'content': c,
  });
  return event;
}

enum GeneratedPenOperationKind {
  holdEncrypted,
  holdPlain,
  flushAllStillEncrypted,
  flushAllDecrypt,
  flushTargetDecrypt,
  flushTargetThrows,
}

class GeneratedPenOperation {
  const GeneratedPenOperation({
    required this.kind,
    required this.targetSlot,
  });

  final GeneratedPenOperationKind kind;
  final int targetSlot;

  String get eventId =>
      r'$pen-'
      '$targetSlot';

  bool get isFlush {
    switch (kind) {
      case GeneratedPenOperationKind.flushAllStillEncrypted:
      case GeneratedPenOperationKind.flushAllDecrypt:
      case GeneratedPenOperationKind.flushTargetDecrypt:
      case GeneratedPenOperationKind.flushTargetThrows:
        return true;
      case GeneratedPenOperationKind.holdEncrypted:
      case GeneratedPenOperationKind.holdPlain:
        return false;
    }
  }

  bool decrypts(String eventId) {
    switch (kind) {
      case GeneratedPenOperationKind.flushAllDecrypt:
        return true;
      case GeneratedPenOperationKind.flushTargetDecrypt:
        return eventId == this.eventId;
      case GeneratedPenOperationKind.holdEncrypted:
      case GeneratedPenOperationKind.holdPlain:
      case GeneratedPenOperationKind.flushAllStillEncrypted:
      case GeneratedPenOperationKind.flushTargetThrows:
        return false;
    }
  }

  bool throwsFor(String eventId) =>
      kind == GeneratedPenOperationKind.flushTargetThrows &&
      eventId == this.eventId;

  @override
  String toString() {
    return 'GeneratedPenOperation('
        'kind: $kind, '
        'targetSlot: $targetSlot'
        ')';
  }
}

class GeneratedPenScenario {
  const GeneratedPenScenario({
    required this.capacity,
    required this.maxAttempts,
    required this.operations,
  });

  final int capacity;
  final int maxAttempts;
  final List<GeneratedPenOperation> operations;

  @override
  String toString() {
    return 'GeneratedPenScenario('
        'capacity: $capacity, '
        'maxAttempts: $maxAttempts, '
        'operations: $operations'
        ')';
  }
}

class ExpectedHeldPenEntry {
  int attempts = 0;
}

class ExpectedPenFlush {
  const ExpectedPenFlush({
    required this.enqueued,
    required this.stillEncrypted,
    required this.dropped,
  });

  final int enqueued;
  final int stillEncrypted;
  final int dropped;
}

class ExpectedPenModel {
  ExpectedPenModel({
    required this.capacity,
    required this.maxAttempts,
  });

  final int capacity;
  final int maxAttempts;
  final LinkedHashMap<String, ExpectedHeldPenEntry> held =
      LinkedHashMap<String, ExpectedHeldPenEntry>();
  final Set<String> queuedEventIds = <String>{};

  void holdEncrypted(String eventId) {
    final existing = held.remove(eventId) ?? ExpectedHeldPenEntry();
    held[eventId] = existing;
    while (held.length > capacity) {
      held.remove(held.keys.first);
    }
  }

  ExpectedPenFlush flush(GeneratedPenOperation operation) {
    var enqueued = 0;
    var stillEncrypted = 0;
    var dropped = 0;
    final decrypted = <String>[];

    for (final eventId in held.keys.toList(growable: false)) {
      final entry = held[eventId];
      if (entry == null) continue;

      if (operation.decrypts(eventId)) {
        decrypted.add(eventId);
        continue;
      }

      entry.attempts++;
      if (entry.attempts >= maxAttempts) {
        held.remove(eventId);
        dropped++;
      } else {
        stillEncrypted++;
      }
    }

    for (final eventId in decrypted) {
      held.remove(eventId);
      queuedEventIds.add(eventId);
    }
    enqueued = decrypted.length;

    return ExpectedPenFlush(
      enqueued: enqueued,
      stillEncrypted: stillEncrypted,
      dropped: dropped,
    );
  }
}

extension AnyPendingDecryptionPenScenario on glados.Any {
  glados.Generator<GeneratedPenOperationKind> get penOperationKind =>
      glados.AnyUtils(this).choose(GeneratedPenOperationKind.values);

  glados.Generator<GeneratedPenOperation> get penOperation =>
      glados.CombinableAny(this).combine2(
        penOperationKind,
        glados.IntAnys(this).intInRange(0, 5),
        (
          GeneratedPenOperationKind kind,
          int targetSlot,
        ) => GeneratedPenOperation(kind: kind, targetSlot: targetSlot),
      );

  glados.Generator<GeneratedPenScenario> get penScenario =>
      glados.CombinableAny(this).combine3(
        glados.IntAnys(this).intInRange(1, 5),
        glados.IntAnys(this).intInRange(1, 4),
        glados.ListAnys(this).listWithLengthInRange(1, 24, penOperation),
        (
          int capacity,
          int maxAttempts,
          List<GeneratedPenOperation> operations,
        ) => GeneratedPenScenario(
          capacity: capacity,
          maxAttempts: maxAttempts,
          operations: operations,
        ),
      );
}
