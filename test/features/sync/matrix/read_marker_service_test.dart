// ignore_for_file: unnecessary_lambdas, avoid_redundant_argument_values
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/matrix/read_marker_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/platform.dart' as pf;
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

class MockClient extends Mock implements Client {}

class MockRoom extends Mock implements Room {}

class MockTimeline extends Mock implements Timeline {}

class MockLogging extends Mock implements LoggingService {}

class MockSettingsDb extends Mock implements SettingsDb {}

class MockEvent extends Mock implements Event {}

class MockMatrixException extends Mock implements MatrixException {}

void main() {
  setUpAll(() {
    registerFallbackValue(MockRoom());
    registerFallbackValue(StackTrace.current);
  });

  group('SyncReadMarkerService guard + fallback', () {
    test('allows when remote is empty', () async {
      final client = MockClient();
      final room = MockRoom();
      final log = MockLogging();
      final db = MockSettingsDb();
      final svc = SyncReadMarkerService(settingsDb: db, loggingService: log);

      when(() => client.isLogged()).thenReturn(true);
      when(() => room.fullyRead).thenReturn('');
      when(() => room.setReadMarker(any())).thenAnswer((_) async {});
      when(() => db.saveSettingsItem(any(), any())).thenAnswer((_) async => 1);

      await svc.updateReadMarker(
        client: client,
        room: room,
        eventId: r'$e1',
      );

      verify(() => room.setReadMarker(r'$e1')).called(1);
    });

    test('allows when no timeline snapshot is provided', () async {
      final client = MockClient();
      final room = MockRoom();
      final log = MockLogging();
      final db = MockSettingsDb();
      final svc = SyncReadMarkerService(settingsDb: db, loggingService: log);

      when(() => client.isLogged()).thenReturn(true);
      when(() => room.fullyRead).thenReturn(r'$remote');
      when(() => room.setReadMarker(any())).thenAnswer((_) async {});
      when(() => db.saveSettingsItem(any(), any())).thenAnswer((_) async => 1);

      await svc.updateReadMarker(
        client: client,
        room: room,
        eventId: r'$e2',
        timeline: null,
      );

      verify(() => room.setReadMarker(r'$e2')).called(1);
    });

    test('skips remote update when event id is not server-assigned', () async {
      final client = MockClient();
      final room = MockRoom();
      final log = MockLogging();
      final db = MockSettingsDb();
      final svc = SyncReadMarkerService(settingsDb: db, loggingService: log);

      when(() => client.isLogged()).thenReturn(true);
      when(() => db.saveSettingsItem(any(), any())).thenAnswer((_) async => 1);

      await svc.updateReadMarker(
        client: client,
        room: room,
        eventId: 'lotti-123',
      );

      verifyNever(() => room.setReadMarker(any()));
      verify(() => log.captureEvent(
            'marker.remote.skip(nonServerId) id=lotti-123',
            domain: 'MATRIX_SERVICE',
            subDomain: 'setReadMarker.guard',
          )).called(1);
    });

    test('logs and suppresses M_UNKNOWN errors from room.setReadMarker',
        () async {
      final client = MockClient();
      final room = MockRoom();
      final log = MockLogging();
      final db = MockSettingsDb();
      final tl = MockTimeline();
      final svc = SyncReadMarkerService(settingsDb: db, loggingService: log);

      final matrixException = MockMatrixException();
      when(() => matrixException.errcode).thenReturn('M_UNKNOWN');

      when(() => client.isLogged()).thenReturn(true);
      when(() => client.deviceName).thenReturn('dev');
      when(() => room.fullyRead).thenReturn('');
      when(() => room.id).thenReturn('!room');
      when(() => room.setReadMarker(any())).thenThrow(matrixException);
      when(() => db.saveSettingsItem(any(), any())).thenAnswer((_) async => 1);

      await svc.updateReadMarker(
        client: client,
        room: room,
        eventId: r'$missing',
        timeline: tl,
      );

      verify(() => db.saveSettingsItem(any(), any())).called(1);
      verify(() => room.setReadMarker(r'$missing')).called(1);
      verify(() => log.captureEvent(
            any<String>(
                that: contains(
                    r'marker.remote.missingEvent id=$missing (M_UNKNOWN)')),
            domain: 'MATRIX_SERVICE',
            subDomain: 'setReadMarker',
          )).called(1);
      verifyNever(() => tl.setReadMarker(eventId: any(named: 'eventId')));
      verifyNever(() => log.captureException(any<dynamic>(),
          domain: any(named: 'domain'),
          subDomain: any(named: 'subDomain'),
          stackTrace: any<dynamic>(named: 'stackTrace')));
    });

    test('blocks when both visible and candidate is not newer', () async {
      final client = MockClient();
      final room = MockRoom();
      final log = MockLogging();
      final db = MockSettingsDb();
      final tl = MockTimeline();
      final newer = MockEvent();
      final older = MockEvent();
      final svc = SyncReadMarkerService(settingsDb: db, loggingService: log);

      when(() => client.isLogged()).thenReturn(true);
      when(() => client.deviceName).thenReturn('dev');
      when(() => room.fullyRead).thenReturn(r'$remote');
      when(() => room.setReadMarker(any())).thenAnswer((_) async {});
      when(() => db.saveSettingsItem(any(), any())).thenAnswer((_) async => 1);

      when(() => older.eventId).thenReturn(r'$e');
      when(() => newer.eventId).thenReturn(r'$remote');
      when(() => older.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(100));
      when(() => newer.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(200));
      when(() => tl.events).thenReturn(<Event>[older, newer]);

      // Enable guard in tests
      final prev = pf.isTestEnv;
      pf.isTestEnv = false;
      await svc.updateReadMarker(
        client: client,
        room: room,
        eventId: r'$e',
        timeline: tl,
      );
      // restore
      pf.isTestEnv = prev;

      verifyNever(() => room.setReadMarker(any()));
      verify(() => log.captureEvent(
            any<String>(that: contains('marker.remote.skip')),
            domain: 'MATRIX_SERVICE',
            subDomain: 'setReadMarker.guard',
          )).called(1);
    });

    test('allows when both visible and candidate is newer', () async {
      final client = MockClient();
      final room = MockRoom();
      final log = MockLogging();
      final db = MockSettingsDb();
      final tl = MockTimeline();
      final newer = MockEvent();
      final older = MockEvent();
      final svc = SyncReadMarkerService(settingsDb: db, loggingService: log);

      when(() => client.isLogged()).thenReturn(true);
      when(() => room.fullyRead).thenReturn(r'$remote');
      when(() => room.setReadMarker(any())).thenAnswer((_) async {});
      when(() => db.saveSettingsItem(any(), any())).thenAnswer((_) async => 1);

      when(() => older.eventId).thenReturn(r'$remote');
      when(() => newer.eventId).thenReturn(r'$e');
      when(() => older.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(100));
      when(() => newer.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(200));
      when(() => tl.events).thenReturn(<Event>[older, newer]);

      await svc.updateReadMarker(
        client: client,
        room: room,
        eventId: r'$e',
        timeline: tl,
      );

      verify(() => room.setReadMarker(r'$e')).called(1);
    });

    test('allows when either base or candidate not visible in timeline',
        () async {
      final client = MockClient();
      final room = MockRoom();
      final log = MockLogging();
      final db = MockSettingsDb();
      final tl = MockTimeline();
      final only = MockEvent();
      final svc = SyncReadMarkerService(settingsDb: db, loggingService: log);

      when(() => client.isLogged()).thenReturn(true);
      when(() => room.fullyRead).thenReturn(r'$remote');
      when(() => room.setReadMarker(any())).thenAnswer((_) async {});
      when(() => db.saveSettingsItem(any(), any())).thenAnswer((_) async => 1);

      when(() => only.eventId).thenReturn(r'$e');
      when(() => only.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(100));
      when(() => tl.events).thenReturn(<Event>[only]);

      await svc.updateReadMarker(
        client: client,
        room: room,
        eventId: r'$e',
        timeline: tl,
      );

      verify(() => room.setReadMarker(r'$e')).called(1);
    });

    test('does not attempt remote update when client not logged', () async {
      final client = MockClient();
      final room = MockRoom();
      final log = MockLogging();
      final db = MockSettingsDb();
      final svc = SyncReadMarkerService(settingsDb: db, loggingService: log);

      when(() => client.isLogged()).thenReturn(false);
      when(() => db.saveSettingsItem(any(), any())).thenAnswer((_) async => 1);

      await svc.updateReadMarker(
        client: client,
        room: room,
        eventId: r'$e',
      );

      verifyNever(() => room.setReadMarker(any()));
    });

    test('falls back to timeline.setReadMarker when room.setReadMarker fails',
        () async {
      final client = MockClient();
      final room = MockRoom();
      final log = MockLogging();
      final db = MockSettingsDb();
      final tl = MockTimeline();
      final svc = SyncReadMarkerService(settingsDb: db, loggingService: log);

      when(() => client.isLogged()).thenReturn(true);
      when(() => room.fullyRead).thenReturn('');
      when(() => room.id).thenReturn('!room');
      when(() => room.setReadMarker(any())).thenThrow(Exception('x'));
      when(() => tl.setReadMarker(eventId: any<String>(named: 'eventId')))
          .thenAnswer((_) async {});
      when(() => db.saveSettingsItem(any(), any())).thenAnswer((_) async => 1);

      await svc.updateReadMarker(
        client: client,
        room: room,
        eventId: r'$e',
        timeline: tl,
      );

      verify(() => tl.setReadMarker(eventId: r'$e')).called(1);
    });

    test('logs exception when room and timeline updates both fail', () async {
      final client = MockClient();
      final room = MockRoom();
      final log = MockLogging();
      final db = MockSettingsDb();
      final tl = MockTimeline();
      final svc = SyncReadMarkerService(settingsDb: db, loggingService: log);

      when(() => client.isLogged()).thenReturn(true);
      when(() => client.deviceName).thenReturn('dev');
      when(() => room.fullyRead).thenReturn('');
      when(() => room.id).thenReturn('!room');
      when(() => room.setReadMarker(any())).thenThrow(Exception('x'));
      when(() => tl.setReadMarker(eventId: any<String>(named: 'eventId')))
          .thenThrow(Exception('y'));
      when(() => db.saveSettingsItem(any(), any())).thenAnswer((_) async => 1);

      await svc.updateReadMarker(
        client: client,
        room: room,
        eventId: r'$e',
        timeline: tl,
      );

      verify(() => log.captureException(
            any<Object>(),
            domain: 'MATRIX_SERVICE',
            subDomain: any<String>(
                named: 'subDomain', that: contains('setReadMarker ')),
            stackTrace: any<dynamic>(named: 'stackTrace'),
          )).called(1);
    });

    test('allows when timeline.events throws during comparison', () async {
      final client = MockClient();
      final room = MockRoom();
      final log = MockLogging();
      final db = MockSettingsDb();
      final tl = MockTimeline();
      final svc = SyncReadMarkerService(settingsDb: db, loggingService: log);

      when(() => client.isLogged()).thenReturn(true);
      when(() => room.fullyRead).thenReturn(r'$remote');
      when(() => room.setReadMarker(any())).thenAnswer((_) async {});
      when(() => db.saveSettingsItem(any(), any())).thenAnswer((_) async => 1);

      when(() => tl.events).thenThrow(Exception('boom'));

      await svc.updateReadMarker(
        client: client,
        room: room,
        eventId: r'$e',
        timeline: tl,
      );

      verify(() => room.setReadMarker(r'$e')).called(1);
    });
  });
}
