import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/pipeline/matrix_stream_catch_up.dart';
import 'package:lotti/features/sync/matrix/pipeline/matrix_stream_live_scan.dart';
import 'package:lotti/features/sync/matrix/pipeline/matrix_stream_signals.dart';
import 'package:lotti/features/sync/matrix/pipeline/metrics_counters.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

class _MockSessionManager extends Mock implements MatrixSessionManager {}

class _MockRoomManager extends Mock implements SyncRoomManager {}

class _MockCatchUp extends Mock implements MatrixStreamCatchUpCoordinator {}

class _MockLiveScan extends Mock implements MatrixStreamLiveScanController {}

void main() {
  late _MockSessionManager sessionManager;
  late _MockRoomManager roomManager;
  late LoggingService loggingService;
  late MetricsCounters metrics;
  late _MockCatchUp catchUp;
  late _MockLiveScan liveScan;
  late MatrixStreamSignalBinder binder;

  setUp(() {
    sessionManager = _MockSessionManager();
    roomManager = _MockRoomManager();
    loggingService = LoggingService();
    metrics = MetricsCounters(collect: true);
    catchUp = _MockCatchUp();
    liveScan = _MockLiveScan();

    binder = MatrixStreamSignalBinder(
      sessionManager: sessionManager,
      roomManager: roomManager,
      loggingService: loggingService,
      metrics: metrics,
      collectMetrics: true,
      catchUpCoordinator: catchUp,
      liveScanController: liveScan,
      withInstance: (msg) => 'inst: $msg',
    );
  });

  group('MatrixStreamSignalBinder', () {
    test('can be constructed', () {
      expect(binder, isNotNull);
    });

    group('start', () {
      test('subscribes to timeline events filtered by room', () async {
        final controller = StreamController<Event>.broadcast();
        addTearDown(controller.close);

        when(
          () => sessionManager.timelineEvents,
        ).thenAnswer((_) => controller.stream);
        when(() => roomManager.currentRoomId).thenReturn('!room:server');
        when(() => roomManager.currentRoom).thenReturn(null);
        when(() => catchUp.handleFirstStreamEvent()).thenReturn(false);
        when(() => catchUp.handleClientStreamSignal()).thenReturn(false);
        when(() => liveScan.scheduleLiveScan()).thenReturn(null);

        await binder.start(lastProcessedEventId: null);

        // Emit an event for the wrong room
        final wrongRoomEvent = _createMockEvent('!other:room');
        controller.add(wrongRoomEvent);

        // Give stream time to process
        await Future<void>.delayed(Duration.zero);

        // Should not trigger any processing for wrong room
        verifyNever(() => catchUp.handleFirstStreamEvent());
      });

      test('delegates to catch-up when signal returns true', () async {
        final controller = StreamController<Event>.broadcast();
        addTearDown(controller.close);

        when(
          () => sessionManager.timelineEvents,
        ).thenAnswer((_) => controller.stream);
        when(() => roomManager.currentRoomId).thenReturn('!room:server');
        when(() => roomManager.currentRoom).thenReturn(null);
        when(() => catchUp.handleFirstStreamEvent()).thenReturn(false);
        when(() => catchUp.handleClientStreamSignal()).thenReturn(true);
        when(() => liveScan.scheduleLiveScan()).thenReturn(null);

        await binder.start(lastProcessedEventId: null);

        final event = _createMockEvent('!room:server');
        controller.add(event);
        await Future<void>.delayed(Duration.zero);

        verify(() => catchUp.handleFirstStreamEvent()).called(1);
        verify(() => catchUp.handleClientStreamSignal()).called(1);
        // When catch-up handles the signal, live scan should NOT be called
        verifyNever(() => liveScan.scheduleLiveScan());
      });
    });

    test('dispose cancels subscription', () async {
      final controller = StreamController<Event>.broadcast();
      addTearDown(controller.close);

      when(
        () => sessionManager.timelineEvents,
      ).thenAnswer((_) => controller.stream);
      when(() => roomManager.currentRoomId).thenReturn('!room:s');
      when(() => roomManager.currentRoom).thenReturn(null);
      when(() => catchUp.handleFirstStreamEvent()).thenReturn(false);
      when(() => catchUp.handleClientStreamSignal()).thenReturn(true);

      await binder.start(lastProcessedEventId: null);
      await binder.dispose();

      // Emit after disposal and verify no binder callbacks are invoked
      controller.add(_createMockEvent('!room:s'));
      await Future<void>.delayed(Duration.zero);
      verifyNever(() => catchUp.handleFirstStreamEvent());
    });
  });
}

Event _createMockEvent(String roomId) {
  final event = _MockEvent();
  when(() => event.roomId).thenReturn(roomId);
  return event;
}

class _MockEvent extends Mock implements Event {}
