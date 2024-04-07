import 'package:flutter/foundation.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:matrix/matrix.dart';

Future<(String?, Room?, String?)> joinMatrixRoom({
  required String roomId,
  required Client client,
}) async {
  final loggingDb = getIt<LoggingDb>();

  try {
    final joinRes = await client.joinRoom(roomId).onError((
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
    final syncRoom = client.getRoomById(joinRes);

    return (joinRes, syncRoom, null);
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
