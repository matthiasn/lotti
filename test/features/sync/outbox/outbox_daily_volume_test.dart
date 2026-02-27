import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/outbox/outbox_daily_volume.dart';

void main() {
  group('OutboxDailyVolume', () {
    test('totalMegabytes computes correctly for exact MB', () {
      final volume = OutboxDailyVolume(
        date: DateTime.utc(2024),
        totalBytes: 1048576,
        itemCount: 1,
      );
      expect(volume.totalMegabytes, closeTo(1.0, 0.001));
    });

    test('totalMegabytes computes correctly for fractional MB', () {
      final volume = OutboxDailyVolume(
        date: DateTime.utc(2024),
        totalBytes: 1572864, // 1.5 MB
        itemCount: 3,
      );
      expect(volume.totalMegabytes, closeTo(1.5, 0.001));
    });

    test('totalMegabytes returns 0.0 for zero bytes', () {
      final volume = OutboxDailyVolume(
        date: DateTime.utc(2024),
        totalBytes: 0,
        itemCount: 0,
      );
      expect(volume.totalMegabytes, 0.0);
    });

    test('equality holds for identical values', () {
      final date = DateTime.utc(2024, 3, 15);
      final a = OutboxDailyVolume(
        date: date,
        totalBytes: 1000,
        itemCount: 5,
      );
      final b = OutboxDailyVolume(
        date: date,
        totalBytes: 1000,
        itemCount: 5,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('inequality when date differs', () {
      final a = OutboxDailyVolume(
        date: DateTime.utc(2024, 3, 15),
        totalBytes: 1000,
        itemCount: 5,
      );
      final b = OutboxDailyVolume(
        date: DateTime.utc(2024, 3, 16),
        totalBytes: 1000,
        itemCount: 5,
      );
      expect(a, isNot(equals(b)));
    });

    test('inequality when totalBytes differs', () {
      final date = DateTime.utc(2024, 3, 15);
      final a = OutboxDailyVolume(
        date: date,
        totalBytes: 1000,
        itemCount: 5,
      );
      final b = OutboxDailyVolume(
        date: date,
        totalBytes: 2000,
        itemCount: 5,
      );
      expect(a, isNot(equals(b)));
    });

    test('inequality when itemCount differs', () {
      final date = DateTime.utc(2024, 3, 15);
      final a = OutboxDailyVolume(
        date: date,
        totalBytes: 1000,
        itemCount: 5,
      );
      final b = OutboxDailyVolume(
        date: date,
        totalBytes: 1000,
        itemCount: 10,
      );
      expect(a, isNot(equals(b)));
    });

    test('toString includes all fields', () {
      final volume = OutboxDailyVolume(
        date: DateTime.utc(2024, 3, 15),
        totalBytes: 4096,
        itemCount: 3,
      );
      final str = volume.toString();
      expect(str, contains('OutboxDailyVolume'));
      expect(str, contains('totalBytes: 4096'));
      expect(str, contains('itemCount: 3'));
      expect(str, contains('2024'));
    });

    test('is not equal to non-OutboxDailyVolume objects', () {
      final volume = OutboxDailyVolume(
        date: DateTime.utc(2024, 3, 15),
        totalBytes: 1000,
        itemCount: 1,
      );
      expect(volume, isNot(equals('not a volume')));
      expect(volume, isNot(equals(42)));
    });
  });
}
