import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/supported_language.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/state/direct_task_summary_refresh_controller.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/tasks/ui/header/task_language_widget.dart';
import 'package:lotti/features/tasks/ui/header/task_language_wrapper.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../test_helper.dart';

class _MockJournalRepository extends Mock implements JournalRepository {}

class _MockDirectTaskSummaryRefreshController extends Mock
    implements DirectTaskSummaryRefreshController {}

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

class _DirectTaskSummaryRefreshControllerAdapter extends Notifier<void>
    implements DirectTaskSummaryRefreshController {
  _DirectTaskSummaryRefreshControllerAdapter(this._delegate);

  final _MockDirectTaskSummaryRefreshController _delegate;

  @override
  void build() {}

  @override
  Future<void> requestTaskSummaryRefresh(String taskId) {
    return _delegate.requestTaskSummaryRefresh(taskId);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockJournalRepository mockJournalRepository;
  late _MockDirectTaskSummaryRefreshController mockSummaryController;
  late Task baseTask;
  late MockEditorStateService mockEditorStateService;
  late MockPersistenceLogic mockPersistenceLogic;
  late MockJournalDb mockJournalDb;
  late MockUpdateNotifications mockUpdateNotifications;

  setUpAll(() {
    registerFallbackValue(fallbackJournalEntity);

    mockEditorStateService = MockEditorStateService();
    mockPersistenceLogic = MockPersistenceLogic();
    mockJournalDb = MockJournalDb();
    mockUpdateNotifications = MockUpdateNotifications();

    when(() => mockUpdateNotifications.updateStream)
        .thenAnswer((_) => const Stream<Set<String>>.empty());

    getIt
      ..registerSingleton<EditorStateService>(mockEditorStateService)
      ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications);
  });

  setUp(() {
    mockJournalRepository = _MockJournalRepository();
    mockSummaryController = _MockDirectTaskSummaryRefreshController();
    baseTask = testTask;
  });

  tearDownAll(() async {
    await getIt.reset();
  });

  Future<Future<void> Function(SupportedLanguage?)> pumpWrapper(
    WidgetTester tester, {
    required Task task,
  }) async {
    final overrides = <Override>[
      journalRepositoryProvider.overrideWith((ref) => mockJournalRepository),
      directTaskSummaryRefreshControllerProvider.overrideWith(
        () => _DirectTaskSummaryRefreshControllerAdapter(mockSummaryController),
      ),
      entryControllerProvider(id: task.meta.id).overrideWith(
        () => _TestEntryController(task),
      ),
    ];

    when(() => mockSummaryController.requestTaskSummaryRefresh(any()))
        .thenAnswer((_) async {});

    await tester.pumpWidget(
      RiverpodWidgetTestBench(
        overrides: overrides,
        child: TaskLanguageWrapper(taskId: task.meta.id),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TaskLanguageWidget), findsOneWidget);

    final widget = tester.firstWidget<TaskLanguageWidget>(
      find.byType(TaskLanguageWidget),
    );

    return (SupportedLanguage? language) async {
      await Future<void>.sync(() => widget.onLanguageChanged(language));
    };
  }

  testWidgets('triggers task summary refresh when language changes',
      (tester) async {
    when(() => mockJournalRepository.updateJournalEntity(any()))
        .thenAnswer((_) async => true);

    final callback = await pumpWrapper(tester, task: baseTask);

    await callback(SupportedLanguage.es);

    final updatedTask =
        verify(() => mockJournalRepository.updateJournalEntity(captureAny()))
            .captured
            .single as Task;

    expect(updatedTask.data.languageCode, 'es');
    verify(() =>
            mockSummaryController.requestTaskSummaryRefresh(baseTask.meta.id))
        .called(1);
  });

  testWidgets('does nothing when the selected language matches current value',
      (tester) async {
    final taskWithLanguage = baseTask.copyWith(
      data: baseTask.data.copyWith(languageCode: 'es'),
    );

    final callback = await pumpWrapper(tester, task: taskWithLanguage);

    await callback(SupportedLanguage.es);

    verifyNever(() => mockJournalRepository.updateJournalEntity(any()));
    verifyNever(() => mockSummaryController.requestTaskSummaryRefresh(any()));
  });

  testWidgets('skips summary refresh when task update fails', (tester) async {
    when(() => mockJournalRepository.updateJournalEntity(any()))
        .thenAnswer((_) async => false);

    final callback = await pumpWrapper(tester, task: baseTask);

    await callback(SupportedLanguage.fr);

    verify(() => mockJournalRepository.updateJournalEntity(any())).called(1);
    verifyNever(() => mockSummaryController.requestTaskSummaryRefresh(any()));
  });
}
