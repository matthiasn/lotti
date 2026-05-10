import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/sync/matrix/pipeline/matrix_stream_signals.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/cached_stream_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';

class _MockClient extends Mock implements Client {}

class _MockSessionManager extends Mock implements MatrixSessionManager {}

class _MockRoomManager extends Mock implements SyncRoomManager {}

enum _GeneratedSignalOperationKind {
  currentLimited,
  currentNonLimited,
  currentMissingTimeline,
  otherLimited,
  noCurrentLimited,
  streamError,
}

class _GeneratedSignalOperation {
  const _GeneratedSignalOperation({
    required this.kind,
    required this.elapsedMs,
    required this.slot,
  });

  final _GeneratedSignalOperationKind kind;
  final int elapsedMs;
  final int slot;

  bool get isStreamError => kind == _GeneratedSignalOperationKind.streamError;

  bool get hasCurrentRoom =>
      kind != _GeneratedSignalOperationKind.noCurrentLimited;

  bool get logsLimited => kind == _GeneratedSignalOperationKind.currentLimited;

  Duration get elapsed => Duration(milliseconds: elapsedMs);

  @override
  String toString() {
    return '_GeneratedSignalOperation('
        'kind: $kind, '
        'elapsedMs: $elapsedMs, '
        'slot: $slot'
        ')';
  }
}

class _GeneratedSignalScenario {
  const _GeneratedSignalScenario({required this.operations});

  final List<_GeneratedSignalOperation> operations;

  String get currentRoomId => '!signals-current:example.org';

  List<bool> expectedInitialSinceMarkers() {
    final markers = <bool>[];
    var nowMs = 0;
    int? lastSyncMs;
    for (final operation in operations) {
      nowMs += operation.elapsedMs;
      if (operation.isStreamError) {
        continue;
      }
      final previous = lastSyncMs;
      lastSyncMs = nowMs;
      if (!operation.logsLimited) {
        continue;
      }
      markers.add(previous == null);
    }
    return markers;
  }

  @override
  String toString() {
    return '_GeneratedSignalScenario(operations: $operations)';
  }
}

extension _AnyGeneratedSignalScenario on glados.Any {
  glados.Generator<_GeneratedSignalOperationKind> get signalOperationKind =>
      glados.AnyUtils(this).choose(_GeneratedSignalOperationKind.values);

  glados.Generator<_GeneratedSignalOperation> get signalOperation =>
      glados.CombinableAny(this).combine3(
        signalOperationKind,
        glados.IntAnys(this).intInRange(0, 250),
        glados.IntAnys(this).intInRange(0, 7),
        (
          _GeneratedSignalOperationKind kind,
          int elapsedMs,
          int slot,
        ) => _GeneratedSignalOperation(
          kind: kind,
          elapsedMs: elapsedMs,
          slot: slot,
        ),
      );

  glados.Generator<_GeneratedSignalScenario> get signalScenario =>
      glados.ListAnys(
            this,
          )
          .listWithLengthInRange(1, 32, signalOperation)
          .map(
            (operations) => _GeneratedSignalScenario(operations: operations),
          );
}

SyncUpdate _syncUpdateFor(_GeneratedSignalScenario scenario, int index) {
  final operation = scenario.operations[index];
  final currentRoomId = scenario.currentRoomId;
  final otherRoomId = '!signals-other-${operation.slot}:example.org';
  final targetRoomId = switch (operation.kind) {
    _GeneratedSignalOperationKind.otherLimited => otherRoomId,
    _ => currentRoomId,
  };
  final timeline = switch (operation.kind) {
    _GeneratedSignalOperationKind.currentLimited ||
    _GeneratedSignalOperationKind.otherLimited ||
    _GeneratedSignalOperationKind.noCurrentLimited => TimelineUpdate(
      limited: true,
      prevBatch: 'prev-${operation.slot}',
      events: const <MatrixEvent>[],
    ),
    _GeneratedSignalOperationKind.currentNonLimited => TimelineUpdate(
      limited: false,
      prevBatch: 'prev-${operation.slot}',
      events: const <MatrixEvent>[],
    ),
    _GeneratedSignalOperationKind.currentMissingTimeline => null,
    _GeneratedSignalOperationKind.streamError => null,
  };

  return SyncUpdate(
    nextBatch: 'next-$index',
    rooms: RoomsUpdate(
      join: {
        targetRoomId: JoinedRoomUpdate(timeline: timeline),
      },
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
  });

  glados.Glados(
    glados.any.signalScenario,
    glados.ExploreConfig(numRuns: 160),
  ).test(
    'generated sync updates log only current-room limited signals',
    (scenario) {
      fakeAsync((async) {
        final sessionManager = _MockSessionManager();
        final roomManager = _MockRoomManager();
        final logging = MockLoggingService();
        final client = _MockClient();
        final syncController = CachedStreamController<SyncUpdate>();
        final loggedMessages = <String>[];
        var streamErrors = 0;
        String? currentRoomId = scenario.currentRoomId;

        when(() => sessionManager.client).thenReturn(client);
        when(() => client.onSync).thenReturn(syncController);
        when(() => roomManager.currentRoomId).thenAnswer((_) => currentRoomId);
        when(
          () => logging.captureEvent(
            any<String>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          ),
        ).thenAnswer((invocation) {
          loggedMessages.add(invocation.positionalArguments.first as String);
        });
        when(
          () => logging.captureException(
            any<dynamic>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
          ),
        ).thenAnswer((_) async {
          streamErrors++;
        });

        final binder = MatrixStreamSignalBinder(
          sessionManager: sessionManager,
          roomManager: roomManager,
          loggingService: logging,
        );

        unawaited(binder.start());
        async.flushMicrotasks();

        for (var i = 0; i < scenario.operations.length; i++) {
          final operation = scenario.operations[i];
          async.elapse(operation.elapsed);
          currentRoomId = operation.hasCurrentRoom
              ? scenario.currentRoomId
              : null;
          if (operation.isStreamError) {
            syncController.addError(
              StateError('generated sync stream error'),
              StackTrace.empty,
            );
          } else {
            syncController.add(_syncUpdateFor(scenario, i));
          }
          async.flushMicrotasks();
        }

        final expectedSinceMarkers = scenario.expectedInitialSinceMarkers();
        expect(loggedMessages, hasLength(expectedSinceMarkers.length));
        for (var i = 0; i < expectedSinceMarkers.length; i++) {
          final sinceMatcher = expectedSinceMarkers[i]
              ? contains('sinceMs=initial')
              : matches(RegExp(r'sinceMs=\d+$'));
          expect(loggedMessages[i], sinceMatcher, reason: '$scenario');
          expect(
            loggedMessages[i],
            contains('roomId=${scenario.currentRoomId}'),
          );
        }
        expect(
          streamErrors,
          scenario.operations
              .where((operation) => operation.isStreamError)
              .length,
          reason: '$scenario',
        );

        unawaited(binder.dispose());
        unawaited(syncController.close());
        async.flushMicrotasks();
      });
    },
  );
}
