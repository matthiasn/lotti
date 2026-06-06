import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  late MockSettingsDb settingsDb;

  setUp(() {
    settingsDb = MockSettingsDb();
  });

  group('isServerAssignedMatrixEventId', () {
    test('accepts only server-assigned ids (leading dollar sign)', () {
      expect(isServerAssignedMatrixEventId(r'$abc123'), isTrue);
      expect(isServerAssignedMatrixEventId(r'$'), isTrue);
      expect(isServerAssignedMatrixEventId('abc123'), isFalse);
      expect(isServerAssignedMatrixEventId(r'txn$abc'), isFalse);
      expect(isServerAssignedMatrixEventId(''), isFalse);
      expect(isServerAssignedMatrixEventId(null), isFalse);
    });
  });

  group('setLastReadMatrixEventId', () {
    test('persists the event id under the last-read key', () async {
      when(
        () => settingsDb.saveSettingsItem(lastReadMatrixEventId, r'$evt-1'),
      ).thenAnswer((_) async => 1);

      await setLastReadMatrixEventId(r'$evt-1', settingsDb);

      verify(
        () => settingsDb.saveSettingsItem(lastReadMatrixEventId, r'$evt-1'),
      ).called(1);
    });
  });

  group('getLastReadMatrixEventId', () {
    test('returns the stored id', () async {
      when(
        () => settingsDb.itemByKey(lastReadMatrixEventId),
      ).thenAnswer((_) async => r'$evt-2');

      expect(await getLastReadMatrixEventId(settingsDb), r'$evt-2');
    });

    test('returns null when nothing is stored', () async {
      when(
        () => settingsDb.itemByKey(lastReadMatrixEventId),
      ).thenAnswer((_) async => null);

      expect(await getLastReadMatrixEventId(settingsDb), isNull);
    });
  });

  group('getLastReadMatrixEventTs', () {
    test('parses the stored timestamp', () async {
      when(
        () => settingsDb.itemByKey(lastReadMatrixEventTs),
      ).thenAnswer((_) async => '1748160000000');

      expect(await getLastReadMatrixEventTs(settingsDb), 1748160000000);
    });

    test('returns null when nothing is stored', () async {
      when(
        () => settingsDb.itemByKey(lastReadMatrixEventTs),
      ).thenAnswer((_) async => null);

      expect(await getLastReadMatrixEventTs(settingsDb), isNull);
    });

    test('silently returns null when the stored value is not an int', () async {
      when(
        () => settingsDb.itemByKey(lastReadMatrixEventTs),
      ).thenAnswer((_) async => 'not-a-number');

      expect(await getLastReadMatrixEventTs(settingsDb), isNull);
    });
  });
}
