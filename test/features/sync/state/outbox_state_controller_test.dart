import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../mocks/sync_config_test_mocks.dart';

void main() {
  group('OutboxStateController', () {
    late MockJournalDb mockDb;
    late MockSyncDatabase mockSyncDb;
    late StreamController<bool> flagStreamController;
    late StreamController<int> countStreamController;
    late ProviderContainer container;

    setUp(() {
      mockDb = MockJournalDb();
      mockSyncDb = MockSyncDatabase();
      flagStreamController = StreamController<bool>.broadcast();
      countStreamController = StreamController<int>.broadcast();

      when(() => mockDb.watchConfigFlag(enableMatrixFlag))
          .thenAnswer((_) => flagStreamController.stream);

      when(() => mockSyncDb.watchOutboxCount())
          .thenAnswer((_) => countStreamController.stream);

      getIt
        ..registerSingleton<JournalDb>(mockDb)
        ..registerSingleton<SyncDatabase>(mockSyncDb);

      container = ProviderContainer();
    });

    tearDown(() async {
      await flagStreamController.close();
      await countStreamController.close();
      container.dispose();
      await getIt.reset();
    });

    group('outboxConnectionStateProvider', () {
      test('initial state is loading', () {
        final state = container.read(outboxConnectionStateProvider);
        expect(
          state,
          const AsyncValue<OutboxConnectionState>.loading(),
        );
      });

      test('emits online when flag is true', () {
        fakeAsync((async) {
          final states = <AsyncValue<OutboxConnectionState>>[];
          container.listen(
            outboxConnectionStateProvider,
            (_, next) => states.add(next),
            fireImmediately: true,
          );

          async.flushMicrotasks();

          flagStreamController.add(true);
          async.flushMicrotasks();

          expect(states.last.hasValue, isTrue);
          expect(states.last.value, OutboxConnectionState.online);
        });
      });

      test('emits disabled when flag is false', () {
        fakeAsync((async) {
          final states = <AsyncValue<OutboxConnectionState>>[];
          container.listen(
            outboxConnectionStateProvider,
            (_, next) => states.add(next),
            fireImmediately: true,
          );

          async.flushMicrotasks();

          flagStreamController.add(false);
          async.flushMicrotasks();

          expect(states.last.hasValue, isTrue);
          expect(states.last.value, OutboxConnectionState.disabled);
        });
      });

      test('transitions from online to disabled', () {
        fakeAsync((async) {
          final states = <AsyncValue<OutboxConnectionState>>[];
          container.listen(
            outboxConnectionStateProvider,
            (_, next) => states.add(next),
            fireImmediately: true,
          );

          async.flushMicrotasks();

          // Start online
          flagStreamController.add(true);
          async.flushMicrotasks();
          expect(states.last.value, OutboxConnectionState.online);

          // Transition to disabled
          flagStreamController.add(false);
          async.flushMicrotasks();
          expect(states.last.value, OutboxConnectionState.disabled);
        });
      });

      test('transitions from disabled to online', () {
        fakeAsync((async) {
          final states = <AsyncValue<OutboxConnectionState>>[];
          container.listen(
            outboxConnectionStateProvider,
            (_, next) => states.add(next),
            fireImmediately: true,
          );

          async.flushMicrotasks();

          // Start disabled
          flagStreamController.add(false);
          async.flushMicrotasks();
          expect(states.last.value, OutboxConnectionState.disabled);

          // Transition to online
          flagStreamController.add(true);
          async.flushMicrotasks();
          expect(states.last.value, OutboxConnectionState.online);
        });
      });

      test('handles stream errors', () async {
        final error = Exception('Database error');
        final completer = Completer<void>();

        container.listen(
          outboxConnectionStateProvider,
          (_, next) {
            if (next.hasError && !completer.isCompleted) {
              completer.complete();
            }
          },
        );

        flagStreamController.addError(error);

        await completer.future.timeout(const Duration(milliseconds: 100));

        final state = container.read(outboxConnectionStateProvider);
        expect(state.hasError, isTrue);
      });
    });

    group('outboxPendingCountProvider', () {
      test('initial state is loading', () {
        final state = container.read(outboxPendingCountProvider);
        expect(state, const AsyncValue<int>.loading());
      });

      test('emits count from database stream', () {
        fakeAsync((async) {
          final states = <AsyncValue<int>>[];
          container.listen(
            outboxPendingCountProvider,
            (_, next) => states.add(next),
            fireImmediately: true,
          );

          async.flushMicrotasks();

          countStreamController.add(5);
          async.flushMicrotasks();

          expect(states.last.hasValue, isTrue);
          expect(states.last.value, 5);
        });
      });

      test('emits zero when no pending items', () {
        fakeAsync((async) {
          final states = <AsyncValue<int>>[];
          container.listen(
            outboxPendingCountProvider,
            (_, next) => states.add(next),
            fireImmediately: true,
          );

          async.flushMicrotasks();

          countStreamController.add(0);
          async.flushMicrotasks();

          expect(states.last.hasValue, isTrue);
          expect(states.last.value, 0);
        });
      });

      test('updates count when stream emits new value', () {
        fakeAsync((async) {
          final states = <AsyncValue<int>>[];
          container.listen(
            outboxPendingCountProvider,
            (_, next) => states.add(next),
            fireImmediately: true,
          );

          async.flushMicrotasks();

          countStreamController.add(5);
          async.flushMicrotasks();
          expect(states.last.value, 5);

          countStreamController.add(3);
          async.flushMicrotasks();
          expect(states.last.value, 3);

          countStreamController.add(0);
          async.flushMicrotasks();
          expect(states.last.value, 0);
        });
      });

      test('handles large count values', () {
        fakeAsync((async) {
          final states = <AsyncValue<int>>[];
          container.listen(
            outboxPendingCountProvider,
            (_, next) => states.add(next),
            fireImmediately: true,
          );

          async.flushMicrotasks();

          countStreamController.add(999999);
          async.flushMicrotasks();

          expect(states.last.hasValue, isTrue);
          expect(states.last.value, 999999);
        });
      });

      test('handles stream errors', () async {
        final error = Exception('Sync database error');
        final completer = Completer<void>();

        container.listen(
          outboxPendingCountProvider,
          (_, next) {
            if (next.hasError && !completer.isCompleted) {
              completer.complete();
            }
          },
        );

        countStreamController.addError(error);

        await completer.future.timeout(const Duration(milliseconds: 100));

        final state = container.read(outboxPendingCountProvider);
        expect(state.hasError, isTrue);
      });
    });

    group('OutboxConnectionState enum', () {
      test('has all expected values', () {
        expect(OutboxConnectionState.values.length, 2);
        expect(
          OutboxConnectionState.values,
          containsAll([
            OutboxConnectionState.online,
            OutboxConnectionState.disabled,
          ]),
        );
      });
    });
  });
}
