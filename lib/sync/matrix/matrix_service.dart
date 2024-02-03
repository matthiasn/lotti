import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:matrix/matrix.dart';
import 'package:path_provider/path_provider.dart';

class MatrixService {
  MatrixService()
      : client = Client(
          'lotti',
          databaseBuilder: (_) async {
            final dir = await getApplicationDocumentsDirectory();
            final db = HiveCollectionsDatabase('lotti_sync', dir.path);
            await db.open();
            return db;
          },
        ) {
    login().then((value) => printUnverified()).then((value) => listen());
  }

  Future<void> login() async {
    try {
      const homeServer = String.fromEnvironment('MATRIX_HOME_SERVER');
      const userName = String.fromEnvironment('MATRIX_USER');
      const password = String.fromEnvironment('MATRIX_PASSWORD');
      const roomId = String.fromEnvironment('MATRIX_ROOM_ID');

      await client.checkHomeserver(
        Uri.parse(homeServer),
      );

      await client.init(
        waitForFirstSync: false,
        waitUntilLoadCompletedLoaded: false,
      );

      // TODO(unassigned): find non-deprecated solution
      // ignore: deprecated_member_use
      if (client.loginState == LoginState.loggedOut) {
        final loginResponse = await client.login(
          LoginType.mLoginPassword,
          identifier: AuthenticationUserIdentifier(user: userName),
          password: password,
        );

        debugPrint('MatrixService userId ${loginResponse.userId}');
        debugPrint(
          'MatrixService loginResponse deviceId ${loginResponse.deviceId}',
        );
      }

      final joinRes = await client.joinRoom(roomId).onError((
        error,
        stackTrace,
      ) {
        debugPrint('MatrixService join error $error');
        return error.toString();
      });

      debugPrint('MatrixService joinRes $joinRes');
    } catch (e, stackTrace) {
      debugPrint('$e');
      _loggingDb.captureException(
        e,
        domain: 'MATRIX',
        subDomain: 'login',
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> loadArchive() async {
    final rooms = await client.loadArchive();
    debugPrint('Matrix $rooms');
  }

  Future<void> printUnverified() async {
    final unverified = client.unverifiedDevices;
    final keyVerification = await unverified.firstOrNull?.startVerification();
    debugPrint('Matrix keyVerification ${keyVerification?.qrCode}');
    debugPrint('Matrix unverified ${unverified.length} $unverified');
  }

  final Client client;
  final LoggingDb _loggingDb = getIt<LoggingDb>();

  Future<void> listen() async {
    try {
      client.onLoginStateChanged.stream.listen((LoginState loginState) {
        debugPrint('LoginState: $loginState');
      });

      client.onEvent.stream.listen((EventUpdate eventUpdate) {
        //debugPrint('New event update! $eventUpdate');
      });

      const roomId = String.fromEnvironment('MATRIX_ROOM_ID');

      final room = client.getRoomById(roomId);
      debugPrint('Matrix room $room');

      client.onRoomState.stream.listen((Event eventUpdate) async {
        debugPrint(
          'MatrixService onRoomState.stream.listen plaintextBody: ${eventUpdate.plaintextBody}',
        );

        // final t = await room?.getTimeline();
        // await t?.setReadMarker(
        //   eventId: eventUpdate.eventId,
        //   public: true,
        // );

        final attachmentMimetype = eventUpdate.attachmentMimetype;
        if (attachmentMimetype.isNotEmpty) {
          debugPrint('attachmentMimetype: $attachmentMimetype');
        }
      });

      // await client.checkHomeserver(
      //   Uri.parse(homeServer),
      // );
      //
      // final timeline = await room?.getTimeline(
      //   onInsert: (i) async {
      //     debugPrint('New message in timeline! $i');
      //   },
      // );
    } catch (e, stackTrace) {
      debugPrint('$e');
      _loggingDb.captureException(
        e,
        domain: 'MATRIX',
        subDomain: 'listen',
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> sendMatrixMsg(String msg) async {
    try {
      const roomId = String.fromEnvironment('MATRIX_ROOM_ID');
      final room = client.getRoomById(roomId);
      await room?.sendTextEvent(msg);
    } catch (e, stackTrace) {
      debugPrint('MATRIX: Error sending message: $e');
      _loggingDb.captureException(
        e,
        domain: 'MATRIX',
        subDomain: 'sendMatrixMsg',
        stackTrace: stackTrace,
      );
    }
  }
}
