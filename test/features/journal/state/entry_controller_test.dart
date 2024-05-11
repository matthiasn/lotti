import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/journal/entry_state.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/ai/ai_logic.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/sync/outbox/outbox_service.dart';
import 'package:lotti/sync/secure_storage.dart';
import 'package:lotti/sync/utils.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';

class Listener<T> extends Mock {
  void call(T? previous, T next);
}

void main() {
  // a helper method to create a ProviderContainer that overrides the authRepositoryProvider
  ProviderContainer makeProviderContainer() {
    final container = ProviderContainer(
      overrides: [],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('EntryController Tests - ', () {
    var vcMockNext = '1';

    final mockUpdateNotifications = MockUpdateNotifications();
    final secureStorageMock = MockSecureStorage();
    final settingsDb = SettingsDb(inMemoryDatabase: true);
    final mockTimeService = MockTimeService();
    final mockJournalDb = MockJournalDb();
    final mockAiLogic = MockAiLogic();
    final mockPersistenceLogic = MockPersistenceLogic();
    final mockNavService = MockNavService();

    setUpAll(() {
      registerFallbackValue(FakeJournalEntity());
      registerFallbackValue(FakeMetadata());
      registerFallbackValue(const AsyncLoading<EntryState?>());

      when(() => mockUpdateNotifications.updateStream).thenAnswer(
        (_) => Stream<({DatabaseType type, String id})>.fromIterable([]),
      );
      getIt.registerSingleton<UpdateNotifications>(mockUpdateNotifications);

      when(() => secureStorageMock.readValue(hostKey))
          .thenAnswer((_) async => 'some_host');

      when(() => secureStorageMock.readValue(nextAvailableCounterKey))
          .thenAnswer((_) async {
        return vcMockNext;
      });

      when(() => secureStorageMock.writeValue(nextAvailableCounterKey, any()))
          .thenAnswer((invocation) async {
        vcMockNext = invocation.positionalArguments[1] as String;
      });

      getIt
        ..registerSingleton<SettingsDb>(settingsDb)
        ..registerSingleton<SyncDatabase>(SyncDatabase(inMemoryDatabase: true))
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<LoggingDb>(LoggingDb(inMemoryDatabase: true))
        ..registerSingleton<SecureStorage>(secureStorageMock)
        ..registerSingleton<OutboxService>(OutboxService())
        ..registerSingleton<TimeService>(mockTimeService)
        ..registerSingleton<VectorClockService>(VectorClockService())
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
        ..registerSingleton<AiLogic>(mockAiLogic)
        ..registerSingleton<NavService>(mockNavService)
        ..registerSingleton<EditorDb>(EditorDb(inMemoryDatabase: true))
        ..registerSingleton<EditorStateService>(EditorStateService());

      when(() => mockJournalDb.journalEntityById(testTextEntry.meta.id))
          .thenAnswer((_) async => testTextEntry);

      when(() => mockPersistenceLogic.updateJournalEntity(any(), any()))
          .thenAnswer(
        (_) async => true,
      );
    });

    tearDownAll(getIt.reset);

    test('toggle map visibility', () async {
      final container = makeProviderContainer();
      final entryId = testTextEntry.meta.id;
      final testEntryProvider = entryControllerProvider(id: entryId);
      final notifier = container.read(testEntryProvider.notifier);

      await expectLater(
        container.read(testEntryProvider.future),
        completion(
          EntryState.saved(
            entryId: entryId,
            entry: testTextEntry,
            showMap: false,
            isFocused: false,
          ),
        ),
      );

      notifier.toggleMapVisible();

      await expectLater(
        container.read(testEntryProvider.future),
        completion(
          EntryState.saved(
            entryId: entryId,
            entry: testTextEntry,
            showMap: true,
            isFocused: false,
          ),
        ),
      );

      notifier.toggleMapVisible();

      await expectLater(
        container.read(testEntryProvider.future),
        completion(
          EntryState.saved(
            entryId: entryId,
            entry: testTextEntry,
            showMap: false,
            isFocused: false,
          ),
        ),
      );
    });

    test('set dirty', () async {
      final container = makeProviderContainer();
      final entryId = testTextEntry.meta.id;
      final testEntryProvider = entryControllerProvider(id: entryId);
      final notifier = container.read(testEntryProvider.notifier);

      await expectLater(
        container.read(testEntryProvider.future),
        completion(
          EntryState.saved(
            entryId: entryId,
            entry: testTextEntry,
            showMap: false,
            isFocused: false,
          ),
        ),
      );

      notifier.setDirty(null);

      await expectLater(
        container.read(testEntryProvider.future),
        completion(
          EntryState.dirty(
            entryId: entryId,
            entry: testTextEntry,
            showMap: false,
            isFocused: false,
          ),
        ),
      );
    });

    test('delete entry', () async {
      final container = makeProviderContainer();
      final entryId = testTextEntry.meta.id;
      final testEntryProvider = entryControllerProvider(id: entryId);
      final notifier = container.read(testEntryProvider.notifier);

      await expectLater(
        container.read(testEntryProvider.future),
        completion(
          EntryState.saved(
            entryId: entryId,
            entry: testTextEntry,
            showMap: false,
            isFocused: false,
          ),
        ),
      );

      Future<bool> testFn() =>
          mockPersistenceLogic.deleteJournalEntity(entryId);

      when(testFn).thenAnswer((invocation) async => true);

      await notifier.delete(beamBack: false);
      verify(testFn).called(1);

      await expectLater(
        container.read(testEntryProvider.future),
        completion(null),
      );
    });

    test('delete entry & beam back', () async {
      reset(mockPersistenceLogic);
      final container = makeProviderContainer();
      final entryId = testTextEntry.meta.id;
      final testEntryProvider = entryControllerProvider(id: entryId);
      final notifier = container.read(testEntryProvider.notifier);

      await expectLater(
        container.read(testEntryProvider.future),
        completion(
          EntryState.saved(
            entryId: entryId,
            entry: testTextEntry,
            showMap: false,
            isFocused: false,
          ),
        ),
      );

      Future<bool> testFn() =>
          mockPersistenceLogic.deleteJournalEntity(entryId);

      when(testFn).thenAnswer((invocation) async => true);

      await notifier.delete(beamBack: true);
      verify(testFn).called(1);

      await expectLater(
        container.read(testEntryProvider.future),
        completion(null),
      );
    });
  });
}
