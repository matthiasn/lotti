import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/journal/entry_cubit.dart';
import 'package:lotti/blocs/journal/entry_state.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/sync_config_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/sync/connectivity.dart';
import 'package:lotti/sync/fg_bg.dart';
import 'package:lotti/sync/outbox_service.dart';
import 'package:lotti/sync/secure_storage.dart';
import 'package:lotti/sync/utils.dart';
import 'package:mocktail/mocktail.dart';

import '../../journal_test_data/test_data.dart';
import '../../mocks/mocks.dart';
import '../../mocks/sync_config_test_mocks.dart';
import '../../test_data/sync_config_test_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EntryCubit Tests - ', () {
    var vcMockNext = '1';

    setUpAll(() {
      final secureStorageMock = MockSecureStorage();
      final mockConnectivityService = MockConnectivityService();
      final mockFgBgService = MockFgBgService();

      final syncConfigMock = MockSyncConfigService();
      when(syncConfigMock.getSyncConfig)
          .thenAnswer((_) async => testSyncConfigConfigured);

      when(() => mockConnectivityService.connectedStream).thenAnswer(
        (_) => Stream<bool>.fromIterable([true]),
      );

      when(() => mockFgBgService.fgBgStream).thenAnswer(
        (_) => Stream<bool>.fromIterable([true]),
      );

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
        ..registerSingleton<ConnectivityService>(mockConnectivityService)
        ..registerSingleton<FgBgService>(mockFgBgService)
        ..registerSingleton<SyncConfigService>(syncConfigMock)
        ..registerSingleton<SyncDatabase>(SyncDatabase(inMemoryDatabase: true))
        ..registerSingleton<JournalDb>(JournalDb(inMemoryDatabase: true))
        ..registerSingleton<LoggingDb>(LoggingDb(inMemoryDatabase: true))
        ..registerSingleton<SecureStorage>(secureStorageMock)
        ..registerSingleton<OutboxService>(OutboxService())
        ..registerSingleton<VectorClockService>(VectorClockService())
        ..registerSingleton<PersistenceLogic>(PersistenceLogic())
        ..registerSingleton<EditorDb>(EditorDb(inMemoryDatabase: true))
        ..registerSingleton<EditorStateService>(EditorStateService());
    });
    tearDownAll(getIt.reset);

    blocTest<EntryCubit, EntryState>(
      'set dirty and save text entry',
      build: () => EntryCubit(
        entry: testTextEntry,
        entryId: testTextEntry.meta.id,
      ),
      setUp: () {},
      act: (c) async {
        c.setDirty(null);
        await c.save();
      },
      wait: defaultWait,
      expect: () => <EntryState>[
        EntryState.dirty(
          entry: testTextEntry,
          entryId: testTextEntry.meta.id,
        ),
        EntryState.saved(
          entry: testTextEntry,
          entryId: testTextEntry.meta.id,
        ),
      ],
      verify: (c) {},
    );

    blocTest<EntryCubit, EntryState>(
      'set dirty and save task',
      build: () => EntryCubit(
        entry: testTask,
        entryId: testTask.meta.id,
      ),
      setUp: () {},
      act: (c) async {
        c.setDirty(null);
        await c.save();
      },
      wait: defaultWait,
      expect: () => <EntryState>[
        EntryState.dirty(
          entry: testTask,
          entryId: testTask.meta.id,
        ),
        EntryState.saved(
          entry: testTask,
          entryId: testTask.meta.id,
        ),
      ],
      verify: (c) {},
    );

    blocTest<EntryCubit, EntryState>(
      'insert text',
      build: () => EntryCubit(
        entry: testTask,
        entryId: testTask.meta.id,
      ),
      setUp: () {},
      act: (c) async {
        c.controller.document.insert(0, 'foo');
        c.controller.document.insert(0, 'bar ');
      },
      wait: defaultWait,
      expect: () => <EntryState>[
        EntryState.saved(
          entry: testTask,
          entryId: testTask.meta.id,
        ),
        EntryState.dirty(
          entry: testTask,
          entryId: testTask.meta.id,
        ),
      ],
      verify: (c) {},
    );

    blocTest<EntryCubit, EntryState>(
      'toggle',
      build: () => EntryCubit(
        entry: testTextEntry,
        entryId: testTextEntry.meta.id,
      ),
      setUp: () {},
      act: (c) async {
        c.controller.document.insert(0, 'foo');
        await c.save();
        await c.toggleStarred();
        await c.toggleFlagged();
        await c.togglePrivate();
      },
      wait: defaultWait,
      expect: () => <EntryState>[
        EntryState.saved(
          entry: testTextEntry,
          entryId: testTextEntry.meta.id,
        ),
        EntryState.dirty(
          entry: testTextEntry,
          entryId: testTextEntry.meta.id,
        ),
        EntryState.saved(
          entry: testTextEntry,
          entryId: testTextEntry.meta.id,
        ),
      ],
      verify: (c) {},
    );
  });
}