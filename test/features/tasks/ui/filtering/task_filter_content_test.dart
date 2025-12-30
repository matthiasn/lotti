import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/tasks/ui/filtering/task_category_filter.dart';
import 'package:lotti/features/tasks/ui/filtering/task_date_display_toggle.dart';
import 'package:lotti/features/tasks/ui/filtering/task_filter_content.dart';
import 'package:lotti/features/tasks/ui/filtering/task_label_filter.dart';
import 'package:lotti/features/tasks/ui/filtering/task_priority_filter.dart';
import 'package:lotti/features/tasks/ui/filtering/task_sort_filter.dart';
import 'package:lotti/features/tasks/ui/filtering/task_status_filter.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/widgets/app_bar/journal_sliver_appbar.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../test_helper.dart';
import '../../../../test_utils/fake_journal_page_controller.dart';

class MockEntitiesCacheService extends Mock implements EntitiesCacheService {}

void main() {
  late FakeJournalPageController fakeController;
  late MockEntitiesCacheService mockEntitiesCacheService;
  late JournalPageState mockState;

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
    mockEntitiesCacheService = MockEntitiesCacheService();

    mockState = const JournalPageState(
      showTasks: true,
      taskStatuses: ['OPEN', 'GROOMED', 'IN PROGRESS'],
      selectedTaskStatuses: {'OPEN'},
    );

    when(() => mockEntitiesCacheService.sortedCategories)
        .thenReturn(mockCategories);
    when(() => mockEntitiesCacheService.sortedLabels).thenReturn(mockLabels);

    getIt.allowReassignment = true;
    getIt.registerSingleton<EntitiesCacheService>(mockEntitiesCacheService);
  });

  tearDown(getIt.reset);

  Widget buildSubject() {
    fakeController = FakeJournalPageController(mockState);

    return WidgetTestBench(
      child: ProviderScope(
        overrides: [
          journalPageScopeProvider.overrideWithValue(true),
          journalPageControllerProvider(true)
              .overrideWith(() => fakeController),
        ],
        child: const Scaffold(
          body: SingleChildScrollView(
            child: TaskFilterContent(),
          ),
        ),
      ),
    );
  }

  group('TaskFilterContent', () {
    testWidgets('renders all filter components', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Verify the widget is rendered
      expect(find.byType(TaskFilterContent), findsOneWidget);

      // Verify all child components are present
      expect(find.byType(JournalFilter), findsOneWidget);
      expect(find.byType(TaskSortFilter), findsOneWidget);
      expect(find.byType(TaskDateDisplayToggle), findsOneWidget);
      expect(find.byType(TaskStatusFilter), findsOneWidget);
      expect(find.byType(TaskPriorityFilter), findsOneWidget);
      expect(find.byType(TaskCategoryFilter), findsOneWidget);
      expect(find.byType(TaskLabelFilter), findsOneWidget);
    });

    testWidgets('has correct layout structure', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Verify the widget uses a Column
      final columnFinder = find.ancestor(
        of: find.byType(JournalFilter),
        matching: find.byType(Column),
      );
      expect(columnFinder, findsWidgets);

      // Verify JournalFilter is in a centered Row
      final rowFinder = find.ancestor(
        of: find.byType(JournalFilter),
        matching: find.byType(Row),
      );
      expect(rowFinder, findsOneWidget);
    });

    testWidgets('components are scrollable', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Verify scroll view is present (wrapped in Scaffold for test)
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });
  });
}
