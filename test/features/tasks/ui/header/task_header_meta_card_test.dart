import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/tasks/ui/header/task_category_wrapper.dart';
import 'package:lotti/features/tasks/ui/header/task_header_meta_card.dart';
import 'package:lotti/features/tasks/ui/header/task_language_wrapper.dart';
import 'package:lotti/features/tasks/ui/header/task_priority_wrapper.dart';
import 'package:lotti/features/tasks/ui/task_date_row.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../test_helper.dart';

class _TestEntryController extends EntryController {
  _TestEntryController(this._task);

  final Task _task;

  @override
  Future<EntryState?> build({required String id}) async {
    return EntryState.saved(
      entryId: id,
      entry: _task,
      showMap: false,
      isFocused: false,
      shouldShowEditorToolBar: false,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockPersistenceLogic mockPersistenceLogic;
  late MockEditorStateService mockEditorStateService;
  late MockJournalDb mockJournalDb;
  late MockUpdateNotifications mockUpdateNotifications;
  late MockEntitiesCacheService mockEntitiesCacheService;

  setUpAll(() {
    registerFallbackValue(fallbackJournalEntity);
    registerFallbackValue(FakeTaskData());

    mockPersistenceLogic = MockPersistenceLogic();
    mockEditorStateService = MockEditorStateService();
    mockJournalDb = MockJournalDb();
    mockUpdateNotifications = MockUpdateNotifications();

    when(() => mockUpdateNotifications.updateStream)
        .thenAnswer((_) => const Stream<Set<String>>.empty());

    getIt
      ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
      ..registerSingleton<EditorStateService>(mockEditorStateService)
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
      ..registerSingleton<TimeService>(TimeService());
  });

  setUp(() {
    mockEntitiesCacheService = MockEntitiesCacheService();
    when(() => mockEntitiesCacheService.sortedCategories).thenReturn([]);
    if (!getIt.isRegistered<EntitiesCacheService>()) {
      getIt.registerSingleton<EntitiesCacheService>(mockEntitiesCacheService);
    }
  });

  tearDown(() {
    if (getIt.isRegistered<EntitiesCacheService>()) {
      getIt.unregister<EntitiesCacheService>();
    }
  });

  tearDownAll(() async {
    await getIt.reset();
  });

  testWidgets('TaskHeaderMetaCard renders date row and metadata items',
      (tester) async {
    final task = testTask;

    final overrides = <Override>[
      entryControllerProvider(id: task.meta.id).overrideWith(
        () => _TestEntryController(task),
      ),
    ];

    await tester.pumpWidget(
      RiverpodWidgetTestBench(
        overrides: overrides,
        child: TaskHeaderMetaCard(taskId: task.meta.id),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TaskHeaderMetaCard), findsOneWidget);
    expect(find.byType(TaskDateRow), findsOneWidget);

    // All metadata wrappers should be present
    expect(find.byType(TaskPriorityWrapper), findsOneWidget);
    expect(find.byType(TaskCategoryWrapper), findsOneWidget);
    expect(find.byType(TaskLanguageWrapper), findsOneWidget);
  });

  testWidgets('TaskHeaderMetaCard shows estimate placeholder when no estimate',
      (tester) async {
    final taskWithoutEstimate = testTask.copyWith(
      data: testTask.data.copyWith(estimate: null),
    );

    final overrides = <Override>[
      entryControllerProvider(id: taskWithoutEstimate.meta.id).overrideWith(
        () => _TestEntryController(taskWithoutEstimate),
      ),
    ];

    await tester.pumpWidget(
      RiverpodWidgetTestBench(
        overrides: overrides,
        child: TaskHeaderMetaCard(taskId: taskWithoutEstimate.meta.id),
      ),
    );
    await tester.pumpAndSettle();

    // Placeholder pill text and timer icon should be visible.
    expect(find.text('No estimate set'), findsOneWidget);
    expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
  });

  testWidgets('TaskHeaderMetaCard keeps metadata visible on narrow layouts',
      (tester) async {
    final task = testTask;

    final overrides = <Override>[
      entryControllerProvider(id: task.meta.id).overrideWith(
        () => _TestEntryController(task),
      ),
    ];

    await tester.pumpWidget(
      RiverpodWidgetTestBench(
        overrides: overrides,
        mediaQueryData: const MediaQueryData(
          size: Size(360, 640),
        ),
        child: TaskHeaderMetaCard(taskId: task.meta.id),
      ),
    );
    await tester.pumpAndSettle();

    // Even on narrow layouts, all metadata items should remain visible.
    expect(find.byType(TaskPriorityWrapper), findsOneWidget);
    expect(find.byType(TaskCategoryWrapper), findsOneWidget);
    expect(find.byType(TaskLanguageWrapper), findsOneWidget);
  });
}
