import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/tasks/ui/filtering/task_category_filter.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/widgets/app_bar/journal_sliver_appbar.dart';
import 'package:lotti/widgets/search/entry_type_filter.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:mocktail/mocktail.dart';

import '../../test_helper.dart';
import '../../test_utils/fake_journal_page_controller.dart';

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

  setUp(() {
    mockEntitiesCacheService = MockEntitiesCacheService();

    mockState = const JournalPageState(
      taskStatuses: ['OPEN', 'GROOMED', 'IN PROGRESS'],
      selectedTaskStatuses: {'OPEN'},
    );

    when(() => mockEntitiesCacheService.sortedCategories)
        .thenReturn(mockCategories);

    getIt.allowReassignment = true;
    getIt.registerSingleton<EntitiesCacheService>(mockEntitiesCacheService);
  });

  tearDown(getIt.reset);

  Widget buildSubject() {
    fakeController = FakeJournalPageController(mockState);

    return WidgetTestBench(
      child: ProviderScope(
        overrides: [
          journalPageScopeProvider.overrideWithValue(false),
          journalPageControllerProvider(false)
              .overrideWith(() => fakeController),
        ],
        child: const Scaffold(
          body: JournalFilterIcon(),
        ),
      ),
    );
  }

  group('JournalFilterIcon', () {
    testWidgets('renders filter icon', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.byType(JournalFilterIcon), findsOneWidget);
      expect(find.byIcon(MdiIcons.filterVariant), findsOneWidget);
    });

    testWidgets('opens modal when tapped', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Tap on the filter icon
      await tester.tap(find.byIcon(MdiIcons.filterVariant));
      await tester.pumpAndSettle();

      // Verify the modal contains expected components
      expect(find.byType(JournalFilter), findsOneWidget);
      expect(find.byType(EntryTypeFilter), findsOneWidget);
      expect(find.byType(TaskCategoryFilter), findsOneWidget);
    });

    testWidgets('modal can be closed by tapping outside', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Open modal
      await tester.tap(find.byIcon(MdiIcons.filterVariant));
      await tester.pumpAndSettle();

      // Verify modal is open
      expect(find.byType(JournalFilter), findsOneWidget);

      // Tap outside the modal (barrier)
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // Verify modal is closed
      expect(find.byType(JournalFilter), findsNothing);
    });

    testWidgets('is wrapped in Padding with correct spacing', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final paddingFinder = find.ancestor(
        of: find.byType(IconButton),
        matching: find.byType(Padding),
      );

      expect(paddingFinder, findsWidgets);
    });
  });
}
