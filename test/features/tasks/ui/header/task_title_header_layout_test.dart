import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/tasks/ui/header/task_title_header.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
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
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications);
  });

  tearDownAll(() async {
    await getIt.reset();
  });

  testWidgets('TaskTitleHeader shows title and edit icon', (tester) async {
    final task = testTask;

    final overrides = <Override>[
      entryControllerProvider(id: task.meta.id).overrideWith(
        () => _TestEntryController(task),
      ),
    ];

    await tester.pumpWidget(
      RiverpodWidgetTestBench(
        overrides: overrides,
        child: TaskTitleHeader(taskId: task.meta.id),
      ),
    );
    await tester.pumpAndSettle();

    // Title text
    final titleTextFinder = find.byWidgetPredicate(
      (widget) => widget is Text && widget.data == task.data.title,
    );
    expect(titleTextFinder, findsOneWidget);

    // Edit icon is visible
    expect(find.byIcon(Icons.edit), findsOneWidget);
  });

  testWidgets('TaskTitleHeader enters edit mode when edit icon tapped',
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
        child: TaskTitleHeader(taskId: taskWithoutEstimate.meta.id),
      ),
    );
    await tester.pumpAndSettle();

    // Tap edit icon to enter edit mode
    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();

    // TitleTextField should be present in edit mode
    expect(find.byType(TextField), findsOneWidget);
  });
}
