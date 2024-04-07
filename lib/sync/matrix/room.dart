import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/sync/matrix/matrix_service.dart';
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
      ..syncRoomId = joinRes;

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
  required Client client,
}) async {
  final name = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
  final roomId = await client.createRoom(
    visibility: Visibility.private,
    name: name,
  );
  final room = client.getRoomById(roomId);
  await room?.enableEncryption();
  return roomId;
}
