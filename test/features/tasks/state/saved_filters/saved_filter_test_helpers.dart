import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_persistence.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

/// Registers the [OutboxService] + [SavedTaskFiltersRepository] that the
/// saved-task-filter controller resolves from GetIt since saved filters became
/// cross-device-synced. Call after [setUpTestGetIt] in any test that renders or
/// mutates saved filters.
///
/// Idempotent (guards on `isRegistered`) and backs the repository with the
/// same mock `SettingsDb` / `UpdateNotifications` that `setUpTestGetIt` created,
/// so existing `settingsDb.saveSettingsItem` assertions keep working. Returns
/// the registered [MockOutboxService] so callers can verify enqueued sync
/// messages.
MockOutboxService registerSavedTaskFilterSyncDeps(TestGetItMocks mocks) {
  registerFallbackValue(
    const SyncMessage.savedTaskFilterDelete(id: 'fallback'),
  );
  final outbox = MockOutboxService();
  when(() => outbox.enqueueMessage(any())).thenAnswer((_) async {});
  if (!getIt.isRegistered<OutboxService>()) {
    getIt.registerSingleton<OutboxService>(outbox);
  }
  if (!getIt.isRegistered<SavedTaskFiltersRepository>()) {
    getIt.registerSingleton<SavedTaskFiltersRepository>(
      SavedTaskFiltersRepository(
        SavedTaskFiltersPersistence(mocks.settingsDb),
        mocks.updateNotifications,
      ),
    );
  }
  return outbox;
}
