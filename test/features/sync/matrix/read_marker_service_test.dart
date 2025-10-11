import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/matrix/read_marker_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/cached_stream_controller.dart';
import 'package:mocktail/mocktail.dart';

class MockSettingsDb extends Mock implements SettingsDb {}

class MockLoggingService extends Mock implements LoggingService {}

class MockTimeline extends Mock implements Timeline {}

class MockRoom extends Mock implements Room {}

void main() {
  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
  });

  group('SyncReadMarkerService', () {
    late MockSettingsDb settingsDb;
    late MockLoggingService loggingService;
    late SyncReadMarkerService service;
    late MockTimeline timeline;
    late MockRoom room;
    late MockClient client;
    late CachedStreamController<LoginState> loginStateStream;

    setUp(() {
      settingsDb = MockSettingsDb();
      loggingService = MockLoggingService();
      service = SyncReadMarkerService(
        settingsDb: settingsDb,
        loggingService: loggingService,
      );
      timeline = MockTimeline();
      room = MockRoom();
      client = MockClient();
      loginStateStream =
          CachedStreamController<LoginState>(LoginState.loggedIn);

      when(() => client.onLoginStateChanged).thenReturn(loginStateStream);
      when(() => client.deviceName).thenReturn('device');
      when(() => room.setReadMarker(any())).thenAnswer((_) async {});
      when(() => settingsDb.saveSettingsItem(any(), any()))
          .thenAnswer((_) async => 1);
    });

    tearDown(() async {
      await loginStateStream.close();
    });

    test('updates read marker when logged in', () async {
      await service.updateReadMarker(
        client: client,
        room: room,
        eventId: r'$event',
        timeline: timeline,
      );

      verify(() => room.setReadMarker(r'$event')).called(1);
    });

    test('skips timeline update when not logged in', () async {
      await loginStateStream.close();
      loginStateStream =
          CachedStreamController<LoginState>(LoginState.loggedOut);
      when(() => client.onLoginStateChanged).thenReturn(loginStateStream);

      await service.updateReadMarker(
        client: client,
        room: room,
        eventId: r'$event',
        timeline: timeline,
      );

      verifyNever(() => room.setReadMarker(any()));
    });

    test('logs and continues when timeline update fails', () async {
      await loginStateStream.close();
      loginStateStream =
          CachedStreamController<LoginState>(LoginState.loggedIn);
      when(() => client.onLoginStateChanged).thenReturn(loginStateStream);

      final exception = Exception('setReadMarker failed');
      when(() => room.setReadMarker(any())).thenThrow(exception);
      when(
        () => loggingService.captureException(
          exception,
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
        ),
      ).thenAnswer((_) {});

      final future = service.updateReadMarker(
        client: client,
        room: room,
        eventId: r'$event',
        timeline: timeline,
      );

      await expectLater(future, completes);

      verify(
        () => loggingService.captureException(
          exception,
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
        ),
      ).called(1);
    });
  });
}

class MockClient extends Mock implements Client {}
