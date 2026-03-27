import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/consts.dart';

void main() {
  group('matrix consts', () {
    test('configNotFound has expected value', () {
      expect(configNotFound, 'Could not find Matrix Config');
    });

    test('syncMessageType has expected value', () {
      expect(syncMessageType, 'com.lotti.sync.message');
    });

    test('matrixConfigKey has expected value', () {
      expect(matrixConfigKey, 'MATRIX_CONFIG');
    });

    test('matrixRoomKey has expected value', () {
      expect(matrixRoomKey, 'MATRIX_ROOM');
    });

    test('lastReadMatrixEventId has expected value', () {
      expect(lastReadMatrixEventId, 'LAST_READ_MATRIX_EVENT_ID');
    });

    test('lastReadMatrixEventTs has expected value', () {
      expect(lastReadMatrixEventTs, 'LAST_READ_MATRIX_EVENT_TS');
    });

    test('syncLoggingDomain has expected value', () {
      expect(syncLoggingDomain, 'MATRIX_SYNC');
    });
  });
}
