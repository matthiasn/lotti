// ignore_for_file: cascade_invocations
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/pipeline/read_marker_manager.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

class MockRoom extends Mock implements Room {}

class MockLogging extends Mock implements LoggingService {}

void main() {
  setUpAll(() {
    registerFallbackValue(MockRoom());
  });

  test('schedules once with debounce and flushes latest id', () {
    fakeAsync((async) {
      final room = MockRoom();
      final log = MockLogging();
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
      final log = MockLogging();
      final mgr = ReadMarkerManager(
        debounce: const Duration(milliseconds: 10),
        onFlush: (r, id) async => throw Exception('x'),
        logging: log,
      );

      when(() => log.captureException(
            any<dynamic>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          )).thenReturn(null);

      mgr.schedule(room, 'e');
      async.elapse(const Duration(milliseconds: 15));

      verify(() => log.captureException(
            any<dynamic>(),
            domain: 'MATRIX_SYNC_V2',
            subDomain: 'flushReadMarker',
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          )).called(1);
    });
  });

  test('dispose cancels pending flush', () {
    fakeAsync((async) {
      final room = MockRoom();
      final log = MockLogging();
      var called = false;
      final mgr = ReadMarkerManager(
        debounce: const Duration(milliseconds: 50),
        onFlush: (r, id) async => called = true,
        logging: log,
      );

      mgr.schedule(room, 'e');
      mgr.dispose();
      async.elapse(const Duration(milliseconds: 60));
      expect(called, isFalse);
    });
  });
}
