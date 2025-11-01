import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

class MockJournalDb extends Mock implements JournalDb {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConfigFlagProvider Tests', () {
    late MockJournalDb mockDb;
    ProviderContainer? container;

    setUp(() {
      mockDb = MockJournalDb();
    });

    tearDown(() {
      container?.dispose();
    });

    test('emits flag status from database stream', () {
      fakeAsync((async) {
        // Mock database to return flag enabled
        when(() => mockDb.watchConfigFlags()).thenAnswer(
          (_) => Stream<Set<ConfigFlag>>.fromIterable([
            {
              const ConfigFlag(
                name: enableEventsFlag,
                description: 'Enable Events?',
                status: true,
              ),
            },
          ]),
        );

        container = ProviderContainer(
          overrides: [
            journalDbProvider.overrideWithValue(mockDb),
          ],
        );

        // Listen to the provider
        final subscription = container!.listen(
          configFlagProvider(enableEventsFlag),
          (previous, next) {},
        );

        // Allow stream to emit and provider to update
        async.flushMicrotasks();

        // Assert: Provider emits true
        final asyncValue = subscription.read();
        expect(asyncValue.value, isTrue);
      });
    });

    test('returns false when flag not found', () {
      fakeAsync((async) {
        // Mock database to return empty set
        when(() => mockDb.watchConfigFlags()).thenAnswer(
          (_) => Stream<Set<ConfigFlag>>.fromIterable([<ConfigFlag>{}]),
        );

        container = ProviderContainer(
          overrides: [
            journalDbProvider.overrideWithValue(mockDb),
          ],
        );

        final subscription = container!.listen(
          configFlagProvider(enableEventsFlag),
          (previous, next) {},
        );

        async.flushMicrotasks();

        // Assert: Provider emits false when flag not found
        final asyncValue = subscription.read();
        expect(asyncValue.value, isFalse);
      });
    });

    test('returns false when flag status is false', () {
      fakeAsync((async) {
        // Mock database to return flag disabled
        when(() => mockDb.watchConfigFlags()).thenAnswer(
          (_) => Stream<Set<ConfigFlag>>.fromIterable([
            {
              const ConfigFlag(
                name: enableEventsFlag,
                description: 'Enable Events?',
                status: false,
              ),
            },
          ]),
        );

        container = ProviderContainer(
          overrides: [
            journalDbProvider.overrideWithValue(mockDb),
          ],
        );

        final subscription = container!.listen(
          configFlagProvider(enableEventsFlag),
          (previous, next) {},
        );

        async.flushMicrotasks();

        // Assert: Provider emits false
        final asyncValue = subscription.read();
        expect(asyncValue.value, isFalse);
      });
    });

    test('multiple watchers get independent streams', () {
      fakeAsync((async) {
        final flagController = StreamController<Set<ConfigFlag>>.broadcast();

        when(() => mockDb.watchConfigFlags()).thenAnswer(
          (_) => flagController.stream,
        );

        container = ProviderContainer(
          overrides: [
            journalDbProvider.overrideWithValue(mockDb),
          ],
        );

        // Create multiple listeners for the same flag
        final subscription1 = container!.listen(
          configFlagProvider(enableEventsFlag),
          (previous, next) {},
        );

        final subscription2 = container!.listen(
          configFlagProvider(enableEventsFlag),
          (previous, next) {},
        );

        // Emit initial value
        flagController.add({
          const ConfigFlag(
            name: enableEventsFlag,
            description: 'Enable Events?',
            status: true,
          ),
        });

        async.flushMicrotasks();

        // Assert: Both subscriptions receive the same value
        expect(subscription1.read().value, isTrue);
        expect(subscription2.read().value, isTrue);

        // Emit new value
        flagController.add({
          const ConfigFlag(
            name: enableEventsFlag,
            description: 'Enable Events?',
            status: false,
          ),
        });

        async.flushMicrotasks();

        // Assert: Both subscriptions updated
        expect(subscription1.read().value, isFalse);
        expect(subscription2.read().value, isFalse);

        unawaited(flagController.close());
      });
    });

    test('handles stream errors gracefully', () {
      fakeAsync((async) {
        // Mock database to emit error
        when(() => mockDb.watchConfigFlags()).thenAnswer(
          (_) => Stream<Set<ConfigFlag>>.error(Exception('Database error')),
        );

        container = ProviderContainer(
          overrides: [
            journalDbProvider.overrideWithValue(mockDb),
          ],
        );

        final subscription = container!.listen(
          configFlagProvider(enableEventsFlag),
          (previous, next) {},
        );

        async.flushMicrotasks();

        // Assert: Provider is in error state
        final asyncValue = subscription.read();
        expect(asyncValue.hasError, isTrue);
        expect(asyncValue.error, isA<Exception>());
      });
    });

    test('disposes stream subscription on provider disposal', () {
      fakeAsync((async) async {
        final flagController = StreamController<Set<ConfigFlag>>();
        var listenerCalled = false;

        when(() => mockDb.watchConfigFlags()).thenAnswer(
          (_) => flagController.stream,
        );

        container = ProviderContainer(
          overrides: [
            journalDbProvider.overrideWithValue(mockDb),
          ],
        )
          // Create subscription
          ..listen(
            configFlagProvider(enableEventsFlag),
            (previous, next) {
              listenerCalled = true;
            },
          );

        // Emit value - listener should be called
        flagController.add(<ConfigFlag>{});
        async.flushMicrotasks();
        expect(listenerCalled, isTrue);

        // Dispose container to test cleanup (tearDown will skip since container becomes null)
        container?.dispose();
        container = null;
        async.flushMicrotasks();

        // Reset flag and emit again - listener should NOT be called after disposal
        listenerCalled = false;
        flagController.add(<ConfigFlag>{});
        async.flushMicrotasks();
        expect(listenerCalled, isFalse,
            reason: 'Listener should not be called after disposal');

        await flagController.close();
      });
    });

    test('emits updates when flag value changes', () {
      fakeAsync((async) async {
        final flagController = StreamController<Set<ConfigFlag>>();

        when(() => mockDb.watchConfigFlags()).thenAnswer(
          (_) => flagController.stream,
        );

        container = ProviderContainer(
          overrides: [
            journalDbProvider.overrideWithValue(mockDb),
          ],
        );

        final values = <bool>[];
        container!.listen<AsyncValue<bool>>(
          configFlagProvider(enableEventsFlag),
          (previous, next) {
            next.whenData(values.add);
          },
        );

        // Emit sequence: false → true → false
        flagController.add({
          const ConfigFlag(
            name: enableEventsFlag,
            description: 'Enable Events?',
            status: false,
          ),
        });
        async.flushMicrotasks();

        flagController.add({
          const ConfigFlag(
            name: enableEventsFlag,
            description: 'Enable Events?',
            status: true,
          ),
        });
        async.flushMicrotasks();

        flagController.add({
          const ConfigFlag(
            name: enableEventsFlag,
            description: 'Enable Events?',
            status: false,
          ),
        });
        async.flushMicrotasks();

        // Assert: All values received
        expect(values, equals([false, true, false]));

        await flagController.close();
      });
    });

    test('different flags have independent values', () {
      fakeAsync((async) {
        when(() => mockDb.watchConfigFlags()).thenAnswer(
          (_) => Stream<Set<ConfigFlag>>.fromIterable([
            {
              const ConfigFlag(
                name: enableEventsFlag,
                description: 'Enable Events?',
                status: true,
              ),
              const ConfigFlag(
                name: enableHabitsPageFlag,
                description: 'Enable Habits?',
                status: false,
              ),
            },
          ]),
        );

        container = ProviderContainer(
          overrides: [
            journalDbProvider.overrideWithValue(mockDb),
          ],
        );

        final eventsSubscription = container!.listen(
          configFlagProvider(enableEventsFlag),
          (previous, next) {},
        );

        final habitsSubscription = container!.listen(
          configFlagProvider(enableHabitsPageFlag),
          (previous, next) {},
        );

        async.flushMicrotasks();

        // Assert: Different flags have different values
        expect(eventsSubscription.read().value, isTrue);
        expect(habitsSubscription.read().value, isFalse);
      });
    });
  });
}
