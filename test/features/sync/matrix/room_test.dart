import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/matrix/room.dart';
import 'package:lotti/features/user_activity/state/user_activity_gate.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/cached_stream_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/matrix/fake_matrix_gateway.dart';

class MockJournalDb extends Mock implements JournalDb {}

class MockSettingsDb extends Mock implements SettingsDb {}

class MockMatrixClient extends Mock implements Client {}

class MockRoom extends Mock implements Room {}

class MockUpdateNotifications extends Mock implements UpdateNotifications {}

class MockLoggingService extends Mock implements LoggingService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const connectivityMethodChannel =
      MethodChannel('dev.fluttercommunity.plus/connectivity');

  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
  });

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(connectivityMethodChannel,
          (MethodCall call) async {
    if (call.method == 'check') {
      return 'wifi';
    }
    return null;
  });

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler(
    'dev.fluttercommunity.plus/connectivity_status',
    (ByteData? message) async => null,
  );

  late MockSettingsDb mockSettingsDb;
  late MockMatrixClient mockClient;
  late MockRoom mockRoom;
  late MockJournalDb mockJournalDb;
  late MockLoggingService mockLoggingService;

  setUp(() {
    mockSettingsDb = MockSettingsDb();
    mockClient = MockMatrixClient();
    mockRoom = MockRoom();
    mockJournalDb = MockJournalDb();
    mockLoggingService = MockLoggingService();

    getIt
      ..reset()
      ..allowReassignment = true
      ..registerSingleton<SettingsDb>(mockSettingsDb)
      ..registerSingleton<UserActivityService>(UserActivityService())
      ..registerSingleton<UserActivityGate>(
        UserActivityGate(
          activityService: getIt<UserActivityService>(),
          idleThreshold: Duration.zero,
        ),
      )
      ..registerSingleton<LoggingService>(mockLoggingService)
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<UpdateNotifications>(MockUpdateNotifications())
      ..registerSingleton<Directory>(Directory.systemTemp);

    when(() => mockSettingsDb.itemByKey(any<String>()))
        .thenAnswer((_) async => null);
    when(() => mockClient.isLogged()).thenReturn(true);
  });

  tearDown(getIt.reset);

  group('Matrix room helpers', () {
    test('saveMatrixRoom stores id in settings database', () async {
      when(() => mockSettingsDb.saveSettingsItem(any(), any()))
          .thenAnswer((_) async => 1);

      await saveMatrixRoom(client: mockClient, roomId: '!room:server');

      verify(
        () => mockSettingsDb.saveSettingsItem(
          matrixRoomKey,
          '!room:server',
        ),
      ).called(1);
    });

    test('getMatrixRoom returns stored room id', () async {
      when(() => mockSettingsDb.itemByKey(matrixRoomKey))
          .thenAnswer((_) async => '!room:server');

      final roomId = await getMatrixRoom(client: mockClient);

      expect(roomId, '!room:server');
    });

    test('leaveMatrixRoom removes stored room and calls client', () async {
      when(() => mockSettingsDb.itemByKey(matrixRoomKey))
          .thenAnswer((_) async => '!room:server');
      when(() => mockSettingsDb.removeSettingsItem(matrixRoomKey))
          .thenAnswer((_) async {});
      when(() => mockClient.leaveRoom('!room:server')).thenAnswer((_) async {});

      await leaveMatrixRoom(client: mockClient);

      verify(() => mockSettingsDb.removeSettingsItem(matrixRoomKey)).called(1);
      verify(() => mockClient.leaveRoom('!room:server')).called(1);
    });

    test('inviteToMatrixRoom calls room invite when syncRoom set', () async {
      final matrixService = MatrixService(
        client: mockClient,
        gateway: FakeMatrixGateway(client: mockClient),
      )..syncRoom = mockRoom;

      when(() => mockRoom.invite('@user:server')).thenAnswer((_) async {});

      await inviteToMatrixRoom(
        service: matrixService,
        userId: '@user:server',
      );

      verify(() => mockRoom.invite('@user:server')).called(1);
    });

    test('listenToMatrixRoomInvites auto-joins when no room set', () async {
      final matrixService = MatrixService(
        client: mockClient,
        gateway: FakeMatrixGateway(client: mockClient),
      );
      final roomController =
          CachedStreamController<({String roomId, StrippedStateEvent state})>();
      final joinedRoom = MockRoom();

      when(() => mockClient.onRoomState).thenReturn(roomController);
      when(() => mockClient.joinRoom('!room:server'))
          .thenAnswer((_) async => '!room:server');
      when(() => mockClient.getRoomById('!room:server')).thenReturn(joinedRoom);
      when(() => mockSettingsDb.saveSettingsItem(matrixRoomKey, '!room:server'))
          .thenAnswer((_) async => 1);

      listenToMatrixRoomInvites(service: matrixService);

      roomController.add(
        (
          roomId: '!room:server',
          state: StrippedStateEvent.fromJson(
            {
              'type': 'm.room.member',
              'sender': '@user:server',
              'state_key': '@user:server',
              'content': const <String, Object?>{},
            },
          ),
        ),
      );

      await Future<void>.delayed(Duration.zero);

      verify(() =>
              mockSettingsDb.saveSettingsItem(matrixRoomKey, '!room:server'))
          .called(1);
      verify(() => mockClient.joinRoom('!room:server')).called(1);
      expect(matrixService.syncRoom, joinedRoom);
      verify(
        () => mockLoggingService.captureEvent(
          contains('onRoomState triggered'),
          domain: 'MATRIX_SERVICE',
          subDomain: 'listenToMatrixRoomInvites',
        ),
      ).called(1);
      verify(
        () => mockLoggingService.captureEvent(
          contains('⚠️ AUTO-JOINING room'),
          domain: 'MATRIX_SERVICE',
          subDomain: 'listenToMatrixRoomInvites',
        ),
      ).called(1);

      await roomController.close();
    });
  });
}
