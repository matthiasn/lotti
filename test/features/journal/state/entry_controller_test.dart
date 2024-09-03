import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/journal/entry_state.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/editor/editor_tools.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/secure_storage.dart';
import 'package:lotti/features/sync/utils.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/ai/ai_logic.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../../utils/utils.dart';
import '../../../utils/wait.dart';

class Listener<T> extends Mock {
  void call(T? previous, T next);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
        (_) => Stream<Set<String>>.fromIterable([]),
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

      when(() => mockJournalDb.journalEntityById(testTextEntryNoGeo.meta.id))
          .thenAnswer((_) async => testTextEntryNoGeo);

      when(() => mockJournalDb.journalEntityById(testTask.meta.id))
          .thenAnswer((_) async => testTask);

      when(() => mockPersistenceLogic.updateJournalEntity(any(), any()))
          .thenAnswer(
        (_) async => true,
      );
    });

    tearDownAll(getIt.reset);

    test('entry loads', () async {
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
            shouldShowEditorToolBar: false,
            formKey: notifier.formKey,
          ),
        ),
      );
    });

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
            shouldShowEditorToolBar: false,
            formKey: notifier.formKey,
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
            shouldShowEditorToolBar: false,
            formKey: notifier.formKey,
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
            shouldShowEditorToolBar: false,
            formKey: notifier.formKey,
          ),
        ),
      );
    });

    test('toggle map does nothing for entry without geolocation', () async {
      final container = makeProviderContainer();
      final entryId = testTextEntryNoGeo.meta.id;
      final testEntryProvider = entryControllerProvider(id: entryId);
      final notifier = container.read(testEntryProvider.notifier);

      await expectLater(
        container.read(testEntryProvider.future),
        completion(
          EntryState.saved(
            entryId: entryId,
            entry: testTextEntryNoGeo,
            showMap: false,
            isFocused: false,
            shouldShowEditorToolBar: false,
            formKey: notifier.formKey,
          ),
        ),
      );

      notifier.toggleMapVisible();

      await expectLater(
        container.read(testEntryProvider.future),
        completion(
          EntryState.saved(
            entryId: entryId,
            entry: testTextEntryNoGeo,
            showMap: false,
            isFocused: false,
            shouldShowEditorToolBar: false,
            formKey: notifier.formKey,
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
            shouldShowEditorToolBar: false,
            formKey: notifier.formKey,
          ),
        ),
      );

      notifier.setDirty(value: true);

      await expectLater(
        container.read(testEntryProvider.future),
        completion(
          EntryState.dirty(
            entryId: entryId,
            entry: testTextEntry,
            showMap: false,
            isFocused: false,
            shouldShowEditorToolBar: false,
            formKey: notifier.formKey,
          ),
        ),
      );
    });

    test('delete entry', () async {
      final container = makeProviderContainer();
      final entryId = testTextEntry.meta.id;
      final testEntryProvider = entryControllerProvider(id: entryId);
      final notifier = container.read(testEntryProvider.notifier);

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
            shouldShowEditorToolBar: false,
            formKey: notifier.formKey,
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

    test('toggle starred', () async {
      reset(mockPersistenceLogic);
      final container = makeProviderContainer();
      final entryId = testTextEntry.meta.id;
      final testEntryProvider = entryControllerProvider(id: entryId);
      final notifier = container.read(testEntryProvider.notifier);

      Future<bool> testFn() => mockPersistenceLogic.updateJournalEntity(
            testTextEntry,
            testTextEntry.meta.copyWith(starred: false),
          );
      when(testFn).thenAnswer((invocation) async => true);
      await notifier.toggleStarred();
      verify(testFn).called(1);
    });

    test('toggle private', () async {
      reset(mockPersistenceLogic);
      final container = makeProviderContainer();
      final entryId = testTextEntry.meta.id;
      final testEntryProvider = entryControllerProvider(id: entryId);
      final notifier = container.read(testEntryProvider.notifier);

      Future<bool> testFn() => mockPersistenceLogic.updateJournalEntity(
            testTextEntry,
            testTextEntry.meta.copyWith(private: true),
          );
      when(testFn).thenAnswer((invocation) async => true);
      await notifier.togglePrivate();
      verify(testFn).called(1);
    });

    test('toggle flagged', () async {
      reset(mockPersistenceLogic);
      final container = makeProviderContainer();
      final entryId = testTextEntry.meta.id;
      final testEntryProvider = entryControllerProvider(id: entryId);
      final notifier = container.read(testEntryProvider.notifier);

      Future<bool> testFn() => mockPersistenceLogic.updateJournalEntity(
            testTextEntry,
            testTextEntry.meta.copyWith(flag: EntryFlag.import),
          );
      when(testFn).thenAnswer((invocation) async => true);
      await notifier.toggleFlagged();
      verify(testFn).called(1);
    });

    test('set dirty & save text', () async {
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
            shouldShowEditorToolBar: false,
            formKey: notifier.formKey,
          ),
        ),
      );

      notifier.setDirty(value: true);

      await expectLater(
        container.read(testEntryProvider.future),
        completion(
          EntryState.dirty(
            entryId: entryId,
            entry: testTextEntry,
            showMap: false,
            isFocused: false,
            shouldShowEditorToolBar: false,
            formKey: notifier.formKey,
          ),
        ),
      );

      Future<bool> testFn() => mockPersistenceLogic.updateJournalEntityText(
            entryId,
            entryTextFromController(notifier.controller),
            testTextEntry.meta.dateTo,
          );
      when(testFn).thenAnswer((invocation) async => true);

      await notifier.save();
      verify(testFn).called(1);
    });

    test(
      'insert & save text',
      () async {
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
              shouldShowEditorToolBar: false,
            ),
          ),
        );

        // inserting text changes to dirty state
        notifier.controller.document.insert(0, 'PREFIXED: ');

        // wait until state change, not sure why waitUntilAsync alone not working
        await waitMilliseconds(100);
        await waitUntilAsync(
          () async => (await container.read(testEntryProvider.future)) != null,
        );

        await expectLater(
          container.read(testEntryProvider.future),
          completion(
            EntryState.dirty(
              entryId: entryId,
              entry: testTextEntry,
              showMap: false,
              isFocused: false,
              shouldShowEditorToolBar: false,
            ),
          ),
        );

        Future<bool> testFn() => mockPersistenceLogic.updateJournalEntityText(
              entryId,
              entryTextFromController(notifier.controller),
              testTextEntry.meta.dateTo,
            );
        when(testFn).thenAnswer((invocation) async => true);

        await notifier.save();
        verify(testFn).called(1);

        final plainText =
            entryTextFromController(notifier.controller).plainText;
        expect(plainText, 'PREFIXED: test entry text\n');
      },
      skip: true,
    );

    test('focus', () async {
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
            shouldShowEditorToolBar: false,
            formKey: notifier.formKey,
          ),
        ),
      );

      notifier.focus();
    });
  });
}
