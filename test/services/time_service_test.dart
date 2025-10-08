import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/services/time_service.dart';

import '../test_data/test_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TimeService Tests', () {
    late TimeService timeService;

    setUp(() {
      timeService = TimeService();
    });

    tearDown(() async {
      await timeService.stop();
    });

    test('getCurrent returns null initially', () {
      expect(timeService.getCurrent(), isNull);
    });

    test('start sets current entity and begins periodic updates', () async {
      final entity = testTextEntry;

      await timeService.start(entity, null);

      expect(timeService.getCurrent(), isNotNull);
      expect(timeService.getCurrent()?.id, entity.id);
    });

    test('start with linked entity stores linkedFrom', () async {
      final entity = testTextEntry;
      final linkedEntity = testImageEntry;

      await timeService.start(entity, linkedEntity);

      expect(timeService.linkedFrom, linkedEntity);
    });

    test('getStream emits periodic updates', () async {
      final entity = testTextEntry;
      final stream = timeService.getStream();

      // Using take(3) ensures we only wait for 3 emissions, making the test faster and more deterministic.
      final emissionsFuture = stream.take(3).toList();

      await timeService.start(entity, null);

      final emissions =
          await emissionsFuture.timeout(const Duration(seconds: 5));

      // Should have received 3 updates
      expect(emissions, hasLength(3));

      // All emitted entities should have the same ID
      for (final emission in emissions) {
        expect(emission?.id, entity.id);
      }
    });

    test('stream updates contain updated dateTo timestamp', () async {
      final entity = testTextEntry;
      final stream = timeService.getStream();

      final startTime = DateTime.now();

      // Using take(2) to wait for 2 emissions
      final emissionsFuture = stream.take(2).toList();

      await timeService.start(entity, null);

      final emissions =
          await emissionsFuture.timeout(const Duration(seconds: 3));

      // Check that dateTo timestamps are being updated
      final filteredEmissions =
          emissions.where((e) => e != null).cast<JournalEntity>().toList();
      expect(filteredEmissions.length, greaterThan(0));

      for (final emission in filteredEmissions) {
        final dateTo = emission.meta.dateTo;
        expect(dateTo, isNotNull);
        expect(dateTo.isAfter(startTime), true);
      }
    });

    test('stop clears current entity and stops stream', () async {
      final entity = testTextEntry;
      final stream = timeService.getStream();

      await timeService.start(entity, null);

      // The stream should emit null when stop is called
      expectLater(stream, emits(isNull));

      await timeService.stop();

      expect(timeService.getCurrent(), isNull);
      expect(timeService.linkedFrom, isNull);
    });

    test('start stops existing timer before starting new one', () async {
      final entity1 = testTextEntry;
      final entity2 = testImageEntry;

      await timeService.start(entity1, null);
      expect(timeService.getCurrent()?.id, entity1.id);

      await timeService.start(entity2, null);
      expect(timeService.getCurrent()?.id, entity2.id);

      // Should only be tracking entity2 now
      final current = timeService.getCurrent();
      expect(current?.id, entity2.id);
    });

    test('updateCurrent updates entity when IDs match', () async {
      final entity = testTextEntry;

      await timeService.start(entity, null);

      final updatedEntity = entity.copyWith(
        meta: entity.meta.copyWith(starred: true),
      );

      timeService.updateCurrent(updatedEntity);

      final current = timeService.getCurrent();
      expect(current?.meta.starred, true);
    });

    test('updateCurrent does not update when IDs do not match', () async {
      final entity1 = testTextEntry;
      final entity2 = testImageEntry;

      await timeService.start(entity1, null);

      timeService.updateCurrent(entity2);

      final current = timeService.getCurrent();
      expect(current?.id, entity1.id);
    });

    test('updateCurrent does nothing when current is null', () {
      final entity = testTextEntry;

      timeService.updateCurrent(entity);

      expect(timeService.getCurrent(), isNull);
    });

    test('stop does nothing when current is null', () async {
      await timeService.stop();

      expect(timeService.getCurrent(), isNull);
    });

    test('multiple start-stop cycles work correctly', () async {
      final entity = testTextEntry;

      // First cycle
      await timeService.start(entity, null);
      expect(timeService.getCurrent(), isNotNull);
      await timeService.stop();
      expect(timeService.getCurrent(), isNull);

      // Second cycle
      await timeService.start(entity, null);
      expect(timeService.getCurrent(), isNotNull);
      await timeService.stop();
      expect(timeService.getCurrent(), isNull);
    });

    test('getStream can be called multiple times', () async {
      final stream1 = timeService.getStream();
      final stream2 = timeService.getStream();

      expect(stream1, isNotNull);
      expect(stream2, isNotNull);

      // Both streams should receive the same data (broadcast)
      final emissions1Future = stream1.take(2).toList();
      final emissions2Future = stream2.take(2).toList();

      await timeService.start(testTextEntry, null);

      final emissions1 =
          await emissions1Future.timeout(const Duration(seconds: 3));
      final emissions2 =
          await emissions2Future.timeout(const Duration(seconds: 3));

      await timeService.stop();

      // Both should have received 2 emissions
      expect(emissions1, hasLength(2));
      expect(emissions2, hasLength(2));
    });
  });
}
