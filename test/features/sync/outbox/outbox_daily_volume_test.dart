import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/sync/outbox/outbox_daily_volume.dart';

class _GeneratedDailyVolumeScenario {
  const _GeneratedDailyVolumeScenario({
    required this.dayOffset,
    required this.totalBytes,
    required this.itemCount,
  });

  final int dayOffset;
  final int totalBytes;
  final int itemCount;

  DateTime get date => DateTime.utc(2024).add(Duration(days: dayOffset));

  OutboxDailyVolume get volume => OutboxDailyVolume(
    date: date,
    totalBytes: totalBytes,
    itemCount: itemCount,
  );

  double get expectedMegabytes => totalBytes / (1024 * 1024);

  @override
  String toString() {
    return '_GeneratedDailyVolumeScenario('
        'dayOffset: $dayOffset, '
        'totalBytes: $totalBytes, '
        'itemCount: $itemCount'
        ')';
  }
}

extension _AnyGeneratedDailyVolumeScenario on glados.Any {
  glados.Generator<_GeneratedDailyVolumeScenario> get dailyVolumeScenario =>
      glados.CombinableAny(this).combine3(
        glados.IntAnys(this).intInRange(0, 31),
        glados.IntAnys(this).intInRange(0, 10000000),
        glados.IntAnys(this).intInRange(0, 1000),
        (
          int dayOffset,
          int totalBytes,
          int itemCount,
        ) => _GeneratedDailyVolumeScenario(
          dayOffset: dayOffset,
          totalBytes: totalBytes,
          itemCount: itemCount,
        ),
      );
}

void main() {
  group('OutboxDailyVolume', () {
    glados.Glados(
      glados.any.dailyVolumeScenario,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'generated value semantics match bytes/date/count model',
      (scenario) {
        final volume = scenario.volume;
        final identical = OutboxDailyVolume(
          date: scenario.date,
          totalBytes: scenario.totalBytes,
          itemCount: scenario.itemCount,
        );
        final differentDate = OutboxDailyVolume(
          date: scenario.date.add(const Duration(days: 1)),
          totalBytes: scenario.totalBytes,
          itemCount: scenario.itemCount,
        );
        final differentBytes = OutboxDailyVolume(
          date: scenario.date,
          totalBytes: scenario.totalBytes + 1,
          itemCount: scenario.itemCount,
        );
        final differentCount = OutboxDailyVolume(
          date: scenario.date,
          totalBytes: scenario.totalBytes,
          itemCount: scenario.itemCount + 1,
        );

        expect(
          volume.totalMegabytes,
          closeTo(scenario.expectedMegabytes, 1e-9),
        );
        expect(volume, identical);
        expect(volume.hashCode, identical.hashCode);
        expect(volume, isNot(differentDate));
        expect(volume, isNot(differentBytes));
        expect(volume, isNot(differentCount));
        expect(
          volume.toString(),
          contains('totalBytes: ${scenario.totalBytes}'),
        );
        expect(volume.toString(), contains('itemCount: ${scenario.itemCount}'));
      },
      tags: 'glados',
    );

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
