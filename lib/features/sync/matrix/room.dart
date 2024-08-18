import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/get_it.dart';
import 'package:matrix/matrix.dart';

Future<String?> joinMatrixRoom({
  required String roomId,
  required MatrixService service,
}) async {
  final loggingDb = getIt<LoggingDb>();

  try {
    final joinRes = await service.client.joinRoom(roomId).onError((
      error,
      stackTrace,
    ) {
      debugPrint('MatrixService join error $error');

      loggingDb.captureException(
        error,
        domain: 'MATRIX_SERVICE',
        subDomain: 'joinRoom',
        stackTrace: stackTrace,
      );

      return error.toString();
    });
    final syncRoom = service.client.getRoomById(joinRes);

    service
      ..syncRoom = syncRoom
      ..syncRoomId = roomId;

    loggingDb.captureEvent(
      'joined $roomId $joinRes',
      domain: 'MATRIX_SERVICE',
      subDomain: 'joinRoom',
    );

    return joinRes;
  } catch (e, stackTrace) {
    debugPrint('$e');
    loggingDb.captureException(
      e,
      domain: 'MATRIX_SERVICE',
      subDomain: 'joinRoom',
      stackTrace: stackTrace,
    );
    rethrow;
  }
}

Future<String> createMatrixRoom({
  required MatrixService service,
  List<String>? invite,
}) async {
  final name = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
  final client = service.client;

  final roomId = await client.createRoom(
    visibility: Visibility.private,
    name: name,
    invite: invite,
    preset: CreateRoomPreset.trustedPrivateChat,
  );
  final room = client.getRoomById(roomId);
  await room?.enableEncryption();

  await saveMatrixRoom(client: client, roomId: roomId);
  await joinMatrixRoom(roomId: roomId, service: service);

  return roomId;
}

Future<void> leaveMatrixRoom({
  required Client client,
}) async {
  final roomId = await getMatrixRoom(client: client);

  if (roomId != null) {
    await getIt<SettingsDb>().removeSettingsItem(matrixRoomKey);
    try {
      await client.leaveRoom(roomId);
    } catch (e) {
      debugPrint(e.toString());
    }
  }
}

Future<void> saveMatrixRoom({
  required Client client,
  required String roomId,
}) async {
  await getIt<SettingsDb>().saveSettingsItem(
    matrixRoomKey,
    roomId,
  );
}

Future<String?> getMatrixRoom({required Client client}) =>
    getIt<SettingsDb>().itemByKey(matrixRoomKey);

Future<void> inviteToMatrixRoom({
  required MatrixService service,
  required String userId,
}) async {
  await service.syncRoom?.invite(userId);
}

void listenToMatrixRoomInvites({
  required MatrixService service,
}) {
  final client = service.client;
  client.onRoomState.stream.listen((event) async {
    final roomIdFromEvent = event.roomId;
    if (service.syncRoom?.id == null) {
      await saveMatrixRoom(
        client: client,
        roomId: roomIdFromEvent,
      );

      await joinMatrixRoom(
        roomId: roomIdFromEvent,
        service: service,
      );
    }
  });
}
