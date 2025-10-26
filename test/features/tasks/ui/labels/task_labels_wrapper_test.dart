import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
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

class _MockLabelsRepository extends Mock implements LabelsRepository {}

JournalEntity taskWithLabels(List<String> labelIds) {
  final now = DateTime(2023);
  return JournalEntity.task(
    meta: Metadata(
      id: 'task-123',
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now,
      labelIds: labelIds,
    ),
    data: TaskData(
      status: TaskStatus.open(
        id: 'status-1',
        createdAt: now,
        utcOffset: now.timeZoneOffset.inMinutes,
      ),
      dateFrom: now,
      dateTo: now,
      statusHistory: [],
      title: 'Sample task',
    ),
  );
}

void main() {
  late MockEntitiesCacheService cacheService;
  late MockEditorStateService editorStateService;
  late MockJournalDb journalDb;
  late MockUpdateNotifications updateNotifications;
  late _MockLabelsRepository repository;

  setUpAll(() {
    registerFallbackValue(testLabelDefinition1);
  });

  setUp(() async {
    cacheService = MockEntitiesCacheService();
    editorStateService = MockEditorStateService();
    journalDb = MockJournalDb();
    updateNotifications = MockUpdateNotifications();
    repository = _MockLabelsRepository();

    await getIt.reset();
    getIt
      ..registerSingleton<EntitiesCacheService>(cacheService)
      ..registerSingleton<EditorStateService>(editorStateService)
      ..registerSingleton<JournalDb>(journalDb)
      ..registerSingleton<UpdateNotifications>(updateNotifications);

    when(() => cacheService.showPrivateEntries).thenReturn(true);
    when(() => cacheService.getLabelById(testLabelDefinition1.id))
        .thenReturn(testLabelDefinition1);
    when(() => cacheService.sortedLabels)
        .thenReturn([testLabelDefinition1, testLabelDefinition2]);
  });

  tearDown(() async {
    await getIt.reset();
  });

  ProviderScope buildWrapper(JournalEntity task) {
    return ProviderScope(
      overrides: [
        entryControllerProvider(id: 'task-123').overrideWith(
          () => _TestEntryController(task),
        ),
        labelsStreamProvider.overrideWith(
          (ref) => Stream<List<LabelDefinition>>.value(
            [testLabelDefinition1, testLabelDefinition2],
          ),
        ),
        labelsRepositoryProvider.overrideWithValue(repository),
      ],
      child: makeTestableWidgetWithScaffold(
        const TaskLabelsWrapper(taskId: 'task-123'),
      ),
    );
  }

  testWidgets('renders assigned labels as chips', (tester) async {
    final task = taskWithLabels(['label-1']);

    await tester.pumpWidget(buildWrapper(task));
    await tester.pumpAndSettle();

    expect(find.text('Labels'), findsOneWidget);
    expect(find.text('Urgent'), findsOneWidget);
  });

  testWidgets('shows description dialog on long press', (tester) async {
    final task = taskWithLabels(['label-1']);

    await tester.pumpWidget(buildWrapper(task));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Urgent'));
    await tester.pumpAndSettle();

    expect(find.text('Requires immediate attention'), findsOneWidget);
  });

  testWidgets('opens selector sheet from edit icon', (tester) async {
    final task = taskWithLabels(['label-1']);
    when(
      () => repository.setLabels(
        journalEntityId: any(named: 'journalEntityId'),
        labelIds: any(named: 'labelIds'),
      ),
    ).thenAnswer((_) async => true);

    await tester.pumpWidget(buildWrapper(task));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Edit labels'));
    await tester.pumpAndSettle();

    expect(find.text('Select labels'), findsOneWidget);
  });
}
