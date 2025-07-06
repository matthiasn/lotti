import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/tasks/ui/pages/premium_task_details_page.dart';
import 'package:lotti/features/tasks/ui/widgets/collapsible_ai_summary_section.dart';
import 'package:lotti/features/tasks/ui/widgets/collapsible_checklists_section.dart';
import 'package:lotti/features/tasks/ui/widgets/collapsible_linked_entries_section.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/link_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../helpers/path_provider.dart';
import '../../../../mocks/mocks.dart';

class TestEntryController extends EntryController {
  TestEntryController(this._task);

  final Task? _task;

  @override
  Future<EntryState?> build({required String id}) async {
    if (_task != null) {
      final entryState = EntryState.saved(
        entryId: id,
        entry: _task as JournalEntity?,
        showMap: false,
        isFocused: false,
        shouldShowEditorToolBar: false,
      );
      state = AsyncValue.data(entryState);
      return entryState;
    }
    state = const AsyncValue.data(null);
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var mockJournalDb = MockJournalDb();
  var mockPersistenceLogic = MockPersistenceLogic();
  final mockUpdateNotifications = MockUpdateNotifications();
  final mockEntitiesCacheService = MockEntitiesCacheService();

  setUpAll(() {
    setFakeDocumentsPath();
    registerFallbackValue(FakeMeasurementData());
    registerFallbackValue(StackTrace.empty);
  });

  setUp(() async {
    mockJournalDb = mockJournalDbWithMeasurableTypes([]);
    mockPersistenceLogic = MockPersistenceLogic();

    final mockTagsService = mockTagsServiceWithTags([]);
    final mockTimeService = MockTimeService();
    final mockEditorStateService = MockEditorStateService();
    final mockHealthImport = MockHealthImport();

    getIt
      ..registerSingleton<Directory>(await getApplicationDocumentsDirectory())
      ..registerSingleton<UserActivityService>(UserActivityService())
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
      ..registerSingleton<LoggingDb>(MockLoggingDb())
      ..registerSingleton<EditorStateService>(mockEditorStateService)
      ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
      ..registerSingleton<LinkService>(MockLinkService())
      ..registerSingleton<TagsService>(mockTagsService)
      ..registerSingleton<HealthImport>(mockHealthImport)
      ..registerSingleton<TimeService>(mockTimeService)
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);

    when(() => mockEntitiesCacheService.sortedCategories).thenAnswer(
      (_) => [],
    );

    when(() => mockUpdateNotifications.updateStream).thenAnswer(
      (_) => Stream<Set<String>>.fromIterable([]),
    );

    when(mockTagsService.watchTags).thenAnswer(
      (_) => Stream<List<TagEntity>>.fromIterable([[]]),
    );

    when(() => mockTagsService.stream).thenAnswer(
      (_) => Stream<List<TagEntity>>.fromIterable([[]]),
    );

    when(() => mockJournalDb.watchConfigFlags()).thenAnswer(
      (_) => Stream<Set<ConfigFlag>>.fromIterable([<ConfigFlag>{}]),
    );

    when(
      () => mockEditorStateService.getUnsavedStream(
        any(),
        any(),
      ),
    ).thenAnswer(
      (_) => Stream<bool>.fromIterable([false]),
    );

    when(
      () => mockJournalDb.getLinkedEntities(any()),
    ).thenAnswer(
      (_) async => [],
    );

    when(mockTimeService.getStream)
        .thenAnswer((_) => Stream<JournalEntity>.fromIterable([]));

    // Mock checklist data - return null for non-existent checklists
    when(
      () => mockJournalDb.journalEntityById(any()),
    ).thenAnswer(
      (_) async => null,
    );
  });

  tearDown(getIt.reset);

  group('PremiumTaskDetailsPage', () {
    Widget createTestWidget({
      required String taskId,
      required List<Override> overrides,
    }) {
      return ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
          ],
          home: PremiumTaskDetailsPage(taskId: taskId),
        ),
      );
    }

    Task createTask(String id) {
      final now = DateTime.now();
      return Task(
        meta: Metadata(
          id: id,
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now,
        ),
        data: TaskData(
          title: 'Test Task',
          status: TaskStatus.open(
            id: 'status-id',
            createdAt: now,
            utcOffset: now.timeZoneOffset.inMinutes,
          ),
          dateFrom: now,
          dateTo: now,
          statusHistory: [],
          checklistIds: ['checklist-1', 'checklist-2'],
        ),
      );
    }

    testWidgets('shows empty scaffold when task not found', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          taskId: 'non-existent-task',
          overrides: [
            entryControllerProvider(id: 'non-existent-task').overrideWith(
              () => TestEntryController(null),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Should show empty scaffold with title
      expect(find.text('non-existent-task'), findsOneWidget);
    });

    testWidgets('shows all collapsible sections for a task', (tester) async {
      final task = createTask('test-task-id');

      await tester.pumpWidget(
        createTestWidget(
          taskId: 'test-task-id',
          overrides: [
            entryControllerProvider(id: 'test-task-id').overrideWith(
              () => TestEntryController(task),
            ),
          ],
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should show the task title (there will be multiple instances in header and form)
      expect(find.text('Test Task'), findsWidgets);

      // Should show all collapsible sections
      expect(find.byType(CollapsibleAiSummarySection), findsOneWidget);
      expect(find.byType(CollapsibleChecklistsSection), findsOneWidget);
      expect(find.byType(CollapsibleLinkedEntriesSection), findsOneWidget);
    });

    testWidgets('has proper spacing between sections', (tester) async {
      final task = createTask('test-task-id');

      await tester.pumpWidget(
        createTestWidget(
          taskId: 'test-task-id',
          overrides: [
            entryControllerProvider(id: 'test-task-id').overrideWith(
              () => TestEntryController(task),
            ),
          ],
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Check that sections are wrapped with proper padding
      final paddingWidgets = find.byWidgetPredicate(
        (widget) =>
            widget is Padding &&
            widget.padding ==
                const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
      );

      // Should have padding for AI summary, checklists, and linked entries
      expect(paddingWidgets, findsAtLeastNWidgets(3));
    });
  });
}
