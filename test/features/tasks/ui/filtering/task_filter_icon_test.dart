// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_activator.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_controller.dart';
import 'package:lotti/features/tasks/ui/filtering/task_filter_icon.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_helper.dart';
import '../../../../test_utils/fake_journal_page_controller.dart';

void main() {
  late FakeJournalPageController fakeController;
  late JournalPageState mockState;
  late MockPagingController mockPagingController;
  late MockEntitiesCacheService mockEntitiesCacheService;
  late MockJournalDb mockJournalDb;

  final mockCategories = [
    CategoryDefinition(
      id: 'cat1',
      createdAt: DateTime(2023),
      updatedAt: DateTime(2023),
      name: 'Work',
      vectorClock: null,
      private: false,
      active: true,
      favorite: true,
      color: '#FF0000',
    ),
  ];
  final mockLabels = [
    LabelDefinition(
      id: 'label1',
      name: 'Urgent',
      color: '#FF0000',
      createdAt: DateTime(2023),
      updatedAt: DateTime(2023),
      vectorClock: null,
      private: false,
    ),
  ];

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
          MethodCall methodCall,
        ) async {
          return null;
        });

    mockPagingController = MockPagingController();
    mockEntitiesCacheService = MockEntitiesCacheService();
    mockJournalDb = MockJournalDb();

    mockState = JournalPageState(
      match: '',
      filters: {},
      showPrivateEntries: false,
      selectedEntryTypes: const [],
      fullTextMatches: {},
      showTasks: true,
      pagingController: mockPagingController,
      taskStatuses: const ['OPEN', 'GROOMED', 'IN PROGRESS'],
      selectedTaskStatuses: {'OPEN'},
      selectedCategoryIds: {'cat1'},
      selectedLabelIds: const {},
    );

    when(
      () => mockEntitiesCacheService.sortedCategories,
    ).thenReturn(mockCategories);
    when(() => mockEntitiesCacheService.sortedLabels).thenReturn(mockLabels);
    when(
      () => mockJournalDb.getProjectsForCategory(any()),
    ).thenAnswer((_) async => <ProjectEntry>[]);

    getIt.allowReassignment = true;
    final mockSettingsDb = MockSettingsDb();
    when(() => mockSettingsDb.itemByKey(any())).thenAnswer((_) async => null);
    when(
      () => mockSettingsDb.saveSettingsItem(any(), any()),
    ).thenAnswer((_) async => 1);
    getIt
      ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<SettingsDb>(mockSettingsDb);
  });

  tearDown(getIt.reset);

  group('TaskFilterIcon', () {
    Widget buildSubject() {
      fakeController = FakeJournalPageController(mockState);

      return WidgetTestBench(
        child: ProviderScope(
          overrides: [
            journalPageScopeProvider.overrideWithValue(true),
            journalPageControllerProvider(
              true,
            ).overrideWith(() => fakeController),
            savedTaskFiltersControllerProvider.overrideWith(
              () => _StubSavedTaskFiltersController(const []),
            ),
            currentSavedTaskFilterIdProvider.overrideWith((ref) => null),
            tasksFilterHasUnsavedClausesProvider.overrideWith((ref) => false),
            liveTasksFilterProvider.overrideWith(
              (ref) => const TasksFilter(),
            ),
          ],
          child: const Scaffold(
            body: TaskFilterIcon(),
          ),
        ),
      );
    }

    testWidgets('renders correctly', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.byType(TaskFilterIcon), findsOneWidget);
      expect(find.byIcon(MdiIcons.filterVariant), findsOneWidget);
    });

    testWidgets('opens design system filter modal when tapped', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(MdiIcons.filterVariant));
      await tester.pumpAndSettle();

      // The new design system filter sheet is shown
      expect(find.text('Tasks Filter'), findsOneWidget);
      expect(find.text('Sort by'), findsOneWidget);
    });

    testWidgets('modal contains design system filter sheet', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(MdiIcons.filterVariant));
      await tester.pumpAndSettle();

      expect(find.byType(DesignSystemTaskFilterSheet), findsOneWidget);
      expect(find.text('Tasks Filter'), findsOneWidget);
      expect(find.text('Clear all'), findsOneWidget);
      expect(find.text('Apply'), findsOneWidget);
    });

    testWidgets('modal can be dismissed', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(MdiIcons.filterVariant));
      await tester.pumpAndSettle();

      expect(find.text('Tasks Filter'), findsOneWidget);

      // Tap barrier to dismiss
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.text('Tasks Filter'), findsNothing);
    });
  });
}

class _StubSavedTaskFiltersController extends SavedTaskFiltersController {
  _StubSavedTaskFiltersController(this._seed);
  final List<SavedTaskFilter> _seed;

  @override
  Future<List<SavedTaskFilter>> build() async => _seed;
}
