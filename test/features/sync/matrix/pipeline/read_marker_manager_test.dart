// ignore_for_file: cascade_invocations
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/sync/matrix/pipeline/read_marker_manager.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';

class MockRoom extends Mock implements Room {}

enum _GeneratedMarkerOperationKind {
  schedule,
  elapseBeforeDebounce,
  elapseAtDebounce,
  elapseAfterDebounce,
  dispose,
}

class _GeneratedMarkerOperation {
  const _GeneratedMarkerOperation({
    required this.kind,
    required this.eventSlot,
  });

  final _GeneratedMarkerOperationKind kind;
  final int eventSlot;

  String get eventId => 'event-$eventSlot';

  Duration elapsed(Duration debounce) {
    switch (kind) {
      case _GeneratedMarkerOperationKind.schedule:
      case _GeneratedMarkerOperationKind.dispose:
        return Duration.zero;
      case _GeneratedMarkerOperationKind.elapseBeforeDebounce:
        return debounce > const Duration(milliseconds: 1)
            ? debounce - const Duration(milliseconds: 1)
            : Duration.zero;
      case _GeneratedMarkerOperationKind.elapseAtDebounce:
        return debounce;
      case _GeneratedMarkerOperationKind.elapseAfterDebounce:
        return debounce + const Duration(milliseconds: 1);
    }
  }

  @override
  String toString() {
    return '_GeneratedMarkerOperation('
        'kind: $kind, '
        'eventSlot: $eventSlot'
        ')';
  }
}

class _GeneratedMarkerScenario {
  const _GeneratedMarkerScenario({
    required this.debounceMs,
    required this.operations,
  });

  final int debounceMs;
  final List<_GeneratedMarkerOperation> operations;

  Duration get debounce => Duration(milliseconds: debounceMs);

  List<String> expectedFlushes() {
    var nowMs = 0;
    String? pendingEventId;
    int? dueMs;
    final flushed = <String>[];

    void elapse(int deltaMs) {
      nowMs += deltaMs;
      final due = dueMs;
      if (pendingEventId != null && due != null && nowMs >= due) {
        flushed.add(pendingEventId!);
        pendingEventId = null;
        dueMs = null;
      }
    }

    void disposePending() {
      if (pendingEventId != null) {
        flushed.add(pendingEventId!);
      }
      pendingEventId = null;
      dueMs = null;
    }

    for (final operation in operations) {
      switch (operation.kind) {
        case _GeneratedMarkerOperationKind.schedule:
          pendingEventId = operation.eventId;
          dueMs = nowMs + debounceMs;
        case _GeneratedMarkerOperationKind.elapseBeforeDebounce:
        case _GeneratedMarkerOperationKind.elapseAtDebounce:
        case _GeneratedMarkerOperationKind.elapseAfterDebounce:
          elapse(operation.elapsed(debounce).inMilliseconds);
        case _GeneratedMarkerOperationKind.dispose:
          disposePending();
      }
    }
    disposePending();
    return flushed;
  }

  @override
  String toString() {
    return '_GeneratedMarkerScenario('
        'debounceMs: $debounceMs, '
        'operations: $operations'
        ')';
  }
}

extension _AnyGeneratedMarkerScenario on glados.Any {
  glados.Generator<_GeneratedMarkerOperationKind> get markerOperationKind =>
      glados.AnyUtils(this).choose(_GeneratedMarkerOperationKind.values);

  glados.Generator<_GeneratedMarkerOperation> get markerOperation =>
      glados.CombinableAny(this).combine2(
        markerOperationKind,
        glados.IntAnys(this).intInRange(0, 8),
        (
          _GeneratedMarkerOperationKind kind,
          int eventSlot,
        ) => _GeneratedMarkerOperation(kind: kind, eventSlot: eventSlot),
      );

  glados.Generator<_GeneratedMarkerScenario> get markerScenario =>
      glados.CombinableAny(this).combine2(
        glados.IntAnys(this).intInRange(1, 24),
        glados.ListAnys(this).listWithLengthInRange(1, 40, markerOperation),
        (
          int debounceMs,
          List<_GeneratedMarkerOperation> operations,
        ) => _GeneratedMarkerScenario(
          debounceMs: debounceMs,
          operations: operations,
        ),
      );
}

void main() {
  setUpAll(() {
    registerFallbackValue(MockRoom());
  });

  test('schedules once with debounce and flushes latest id', () {
    fakeAsync((async) {
      final room = MockRoom();
      final log = MockLoggingService();
      final calls = <String>[];
      final mgr = ReadMarkerManager(
        debounce: const Duration(milliseconds: 50),
        onFlush: (r, id) async => calls.add(id),
        logging: log,
      );

      mgr.schedule(room, 'e1');
      async.elapse(const Duration(milliseconds: 25));
      mgr.schedule(room, 'e2'); // replaces pending

      // before debounce: no calls
      expect(calls, isEmpty);

      async.elapse(const Duration(milliseconds: 60));
      expect(calls, ['e2']);
    });
  });

  test('captures exceptions from onFlush', () {
    fakeAsync((async) {
      final room = MockRoom();
      final log = MockLoggingService();
      final mgr = ReadMarkerManager(
        debounce: const Duration(milliseconds: 10),
        onFlush: (r, id) async => throw Exception('x'),
        logging: log,
      );

      when(
        () => log.captureException(
          any<dynamic>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ),
      ).thenAnswer((_) async {});

      mgr.schedule(room, 'e');
      async.elapse(const Duration(milliseconds: 15));

      verify(
        () => log.captureException(
          any<dynamic>(),
          domain: any<String>(named: 'domain'),
          subDomain: 'flushReadMarker',
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ),
      ).called(1);
    });
  });

  test('dispose flushes pending marker immediately', () {
    fakeAsync((async) {
      final room = MockRoom();
      final log = MockLoggingService();
      var called = false;
      final mgr = ReadMarkerManager(
        debounce: const Duration(milliseconds: 50),
        onFlush: (r, id) async => called = true,
        logging: log,
      );

      mgr.schedule(room, 'e');
      mgr.dispose();
      async.elapse(const Duration(milliseconds: 60));
      expect(called, isTrue);
    });
  });

  glados.Glados(
    glados.any.markerScenario,
    glados.ExploreConfig(numRuns: 160),
  ).test(
    'generated schedule/elapse/dispose sequences flush only the latest marker',
    (scenario) {
      fakeAsync((async) {
        final room = MockRoom();
        final log = MockLoggingService();
        final calls = <String>[];
        final mgr = ReadMarkerManager(
          debounce: scenario.debounce,
          onFlush: (r, id) async => calls.add(id),
          logging: log,
        );

        for (final operation in scenario.operations) {
          switch (operation.kind) {
            case _GeneratedMarkerOperationKind.schedule:
              mgr.schedule(room, operation.eventId);
            case _GeneratedMarkerOperationKind.elapseBeforeDebounce:
            case _GeneratedMarkerOperationKind.elapseAtDebounce:
            case _GeneratedMarkerOperationKind.elapseAfterDebounce:
              async.elapse(operation.elapsed(scenario.debounce));
            case _GeneratedMarkerOperationKind.dispose:
              mgr.dispose();
          }
          async.flushMicrotasks();
        }
        mgr.dispose();
        async.flushMicrotasks();

        expect(calls, scenario.expectedFlushes(), reason: '$scenario');
      });
    },
  );
}
