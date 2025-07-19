import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/blocs/journal/journal_page_state.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/tasks/ui/filtering/task_category_filter.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/widgets/search/filter_choice_chip.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../test_helper.dart';

class MockJournalPageCubit extends MockCubit<JournalPageState>
    implements JournalPageCubit {}

class MockPagingController extends Mock
    implements PagingController<int, JournalEntity> {}

class MockEntitiesCacheService extends Mock implements EntitiesCacheService {}

void main() {
  late MockJournalPageCubit mockCubit;
  late JournalPageState mockState;
  late MockPagingController mockPagingController;
  late MockEntitiesCacheService mockEntitiesCacheService;

  // Mock categories
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
    CategoryDefinition(
      id: 'cat2',
      createdAt: DateTime(2023),
      updatedAt: DateTime(2023),
      name: 'Personal',
      vectorClock: null,
      private: false,
      active: true,
      favorite: false,
      color: '#00FF00',
    ),
    CategoryDefinition(
      id: 'cat3',
      createdAt: DateTime(2023),
      updatedAt: DateTime(2023),
      name: 'Health',
      vectorClock: null,
      private: false,
      active: true,
      favorite: true,
      color: '#0000FF',
    ),
  ];

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Register a mock for the HapticFeedback service
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform,
            (MethodCall methodCall) async {
      return null;
    });

    mockCubit = MockJournalPageCubit();
    mockPagingController = MockPagingController();
    mockEntitiesCacheService = MockEntitiesCacheService();

    // Set up mock state
    mockState = JournalPageState(
      match: '',
      tagIds: <String>{},
      filters: {},
      showPrivateEntries: false,
      selectedEntryTypes: const [],
      fullTextMatches: {},
      showTasks: true,
      pagingController: mockPagingController,
      taskStatuses: const ['OPEN', 'GROOMED', 'IN PROGRESS'],
      selectedTaskStatuses: {'OPEN'},
      selectedCategoryIds: {'cat1'},
    );

    when(() => mockCubit.state).thenReturn(mockState);

    // Set up EntitiesCacheService mock
    when(() => mockEntitiesCacheService.sortedCategories)
        .thenReturn(mockCategories);

    // Mock the getIt instance
    getIt.allowReassignment = true;
    getIt.registerSingleton<EntitiesCacheService>(mockEntitiesCacheService);
  });

  tearDown(getIt.reset);

  group('TaskCategoryFilter', () {
    Widget buildSubject() {
      return WidgetTestBench(
        child: BlocProvider<JournalPageCubit>.value(
          value: mockCubit,
          child: const TaskCategoryFilter(),
        ),
      );
    }

    testWidgets('renders correctly with categories', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Verify the widget is rendered
      expect(find.byType(TaskCategoryFilter), findsOneWidget);

      // Verify the title is displayed
      expect(find.byType(Text), findsWidgets);

      // By default, it should show only favorites and selected categories
      // So we should see 2 favorite categories + unassigned + all + "..." button = 5 chips
      expect(find.byType(FilterChoiceChip), findsNWidgets(5));

      // Verify the "All" chip is rendered
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is FilterChoiceChip &&
              widget.label.toLowerCase().contains('all'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('toggles between showing favorites and all categories',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Initially, we should see only favorites (2) + unassigned + all + "..." button = 5 chips
      expect(find.byType(FilterChoiceChip), findsNWidgets(5));

      // Find and tap the "..." chip to show all categories
      final ellipsisChip = find.byWidgetPredicate(
        (widget) => widget is FilterChoiceChip && widget.label == '...',
      );
      expect(ellipsisChip, findsOneWidget);

      await tester.tap(ellipsisChip);
      await tester.pumpAndSettle();

      // Now we should see all categories (3) + unassigned + all = 5 chips (no "..." button)
      expect(find.byType(FilterChoiceChip), findsNWidgets(5));
      expect(ellipsisChip, findsNothing);
    });

    testWidgets('calls toggleSelectedCategoryIds when category chip is tapped',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Find a category chip and tap it
      final workChip = find.byWidgetPredicate(
        (widget) => widget is FilterChoiceChip && widget.label == 'Work',
      );
      expect(workChip, findsOneWidget);

      // Set up the mock for toggleSelectedCategoryIds call
      when(() => mockCubit.toggleSelectedCategoryIds('cat1'))
          .thenAnswer((_) {});

      await tester.tap(workChip);
      await tester.pump();

      // Verify that toggleSelectedCategoryIds was called
      verify(() => mockCubit.toggleSelectedCategoryIds('cat1')).called(1);
    });

    testWidgets(
        'calls toggleSelectedCategoryIds when unassigned chip is tapped',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Find the unassigned chip by looking for an empty string ID
      when(() => mockCubit.toggleSelectedCategoryIds('')).thenAnswer((_) {});

      // Find the unassigned chip - it will be labeled "Unassigned" or similar
      // Since we don't know the exact translation, we'll find it by checking all chips
      final chips =
          tester.widgetList<FilterChoiceChip>(find.byType(FilterChoiceChip));

      // Find the unassigned chip (not "all" or "...")
      FilterChoiceChip? unassignedChip;
      for (final chip in chips) {
        if (chip.label != '...' &&
            !chip.label.toLowerCase().contains('all') &&
            !mockCategories.any((c) => c.name == chip.label)) {
          unassignedChip = chip;
          break;
        }
      }

      expect(unassignedChip, isNotNull);

      // Tap the unassigned chip
      await tester.tap(find.byWidget(unassignedChip!));
      await tester.pump();

      // Verify that toggleSelectedCategoryIds was called with empty string
      verify(() => mockCubit.toggleSelectedCategoryIds('')).called(1);
    });

    testWidgets('calls selectedAllCategories when all chip is tapped',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Set up the mock for selectedAllCategories call
      when(() => mockCubit.selectedAllCategories()).thenAnswer((_) {});

      // Find the "All" chip
      final allChip = find.byWidgetPredicate(
        (widget) =>
            widget is FilterChoiceChip &&
            widget.label.toLowerCase().contains('all'),
      );
      expect(allChip, findsOneWidget);

      await tester.tap(allChip);
      await tester.pump();

      // Verify that selectedAllCategories was called
      verify(() => mockCubit.selectedAllCategories()).called(1);
    });

    testWidgets('renders unassigned and all chips when no categories',
        (tester) async {
      // Set up EntitiesCacheService mock to return empty categories
      when(() => mockEntitiesCacheService.sortedCategories).thenReturn([]);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Verify that the widget is rendered
      expect(find.byType(TaskCategoryFilter), findsOneWidget);

      // Should show unassigned chip, all chip, and "..." button
      expect(find.byType(FilterChoiceChip), findsNWidgets(3));

      // Verify the "All" chip is rendered
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is FilterChoiceChip &&
              widget.label.toLowerCase().contains('all'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('selects unassigned by default when no categories exist',
        (tester) async {
      // Set up EntitiesCacheService mock to return empty categories
      when(() => mockEntitiesCacheService.sortedCategories).thenReturn([]);

      // Update the mock state to have unassigned selected by default
      final stateWithUnassigned = JournalPageState(
        match: '',
        tagIds: <String>{},
        filters: {},
        showPrivateEntries: false,
        selectedEntryTypes: const [],
        fullTextMatches: {},
        showTasks: true,
        pagingController: mockPagingController,
        taskStatuses: const ['OPEN', 'GROOMED', 'IN PROGRESS'],
        selectedTaskStatuses: {'OPEN'},
        selectedCategoryIds: {''}, // Unassigned is selected
      );

      when(() => mockCubit.state).thenReturn(stateWithUnassigned);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Find the unassigned chip
      final chips =
          tester.widgetList<FilterChoiceChip>(find.byType(FilterChoiceChip));

      FilterChoiceChip? unassignedChip;
      for (final chip in chips) {
        if (!chip.label.toLowerCase().contains('all')) {
          unassignedChip = chip;
          break;
        }
      }

      expect(unassignedChip, isNotNull);
      expect(unassignedChip!.isSelected, isTrue);
    });
  });
}
