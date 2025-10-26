import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/features/tasks/ui/labels/task_labels_wrapper.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';

class _TestEntryController extends EntryController {
  _TestEntryController(this.entry);

  final JournalEntity entry;

  @override
  Future<EntryState?> build({required String id}) async {
    return EntryState.saved(
      entryId: id,
      entry: entry,
      showMap: false,
      isFocused: false,
      shouldShowEditorToolBar: false,
    );
  }
}

JournalEntity _taskNoLabels() {
  final now = DateTime(2023);
  return JournalEntity.task(
    meta: Metadata(
      id: 'task-privacy',
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now,
      labelIds: const <String>[],
    ),
    data: TaskData(
      status: TaskStatus.open(
        id: 'status-1',
        createdAt: now,
        utcOffset: now.timeZoneOffset.inMinutes,
      ),
      dateFrom: now,
      dateTo: now,
      statusHistory: const [],
      title: 'Sample task',
    ),
  );
}

void main() {
  testWidgets('hides wrapper when only private labels and showPrivate=false',
      (tester) async {
    final cacheService = MockEntitiesCacheService();
    final editorStateService = MockEditorStateService();
    final journalDb = MockJournalDb();
    final updateNotifications = MockUpdateNotifications();
    await getIt.reset();
    getIt
      ..registerSingleton<EntitiesCacheService>(cacheService)
      ..registerSingleton<EditorStateService>(editorStateService)
      ..registerSingleton<JournalDb>(journalDb)
      ..registerSingleton<UpdateNotifications>(updateNotifications);

    // Only private labels available in cache
    final privateLabel = testLabelDefinition1.copyWith(private: true);
    when(() => cacheService.showPrivateEntries).thenReturn(false);
    // When private is hidden, sortedLabels should be empty.
    when(() => cacheService.sortedLabels).thenReturn(const <LabelDefinition>[]);

    final task = _taskNoLabels();
    final widget = ProviderScope(
      overrides: [
        entryControllerProvider(id: task.meta.id).overrideWith(
          () => _TestEntryController(task),
        ),
        labelsStreamProvider.overrideWith(
          (ref) => Stream<List<LabelDefinition>>.value([privateLabel]),
        ),
      ],
      child: makeTestableWidgetWithScaffold(
        TaskLabelsWrapper(taskId: task.meta.id),
      ),
    );

    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    // Wrapper should be hidden; no header text
    expect(find.text('Labels'), findsNothing);
  });
}
