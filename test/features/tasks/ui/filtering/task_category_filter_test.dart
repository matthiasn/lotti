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

    testWidgets('shows multiple selected categories', (tester) async {
      // Update state to have multiple categories selected
      final stateWithMultiple = JournalPageState(
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
        selectedCategoryIds: {'cat1', 'cat2'},
      );

      when(() => mockCubit.state).thenReturn(stateWithMultiple);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Find selected chips
      final selectedChips = tester
          .widgetList<FilterChoiceChip>(find.byType(FilterChoiceChip))
          .where((chip) => chip.isSelected)
          .toList();

      // Should have 2 selected (Work and Personal)
      expect(selectedChips.length, 2);
    });

    testWidgets('displays category colors correctly', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Find the Work category chip
      final workChip = find.byWidgetPredicate(
        (widget) => widget is FilterChoiceChip && widget.label == 'Work',
      );

      expect(workChip, findsOneWidget);

      // Verify the color is set correctly (red from #FF0000)
      final chip = tester.widget<FilterChoiceChip>(workChip);
      expect(chip.selectedColor, equals(const Color(0xFFFF0000)));
    });

    testWidgets('shows only favorite and selected categories by default',
        (tester) async {
      // Create a non-favorite, non-selected category
      final allCategories = [
        ...mockCategories,
        CategoryDefinition(
          id: 'cat4',
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023),
          name: 'Hidden',
          vectorClock: null,
          private: false,
          active: true,
          favorite: false, // Not favorite
          color: '#FFFF00',
        ),
      ];

      when(() => mockEntitiesCacheService.sortedCategories)
          .thenReturn(allCategories);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Should not find the Hidden category
      expect(
        find.byWidgetPredicate(
          (widget) => widget is FilterChoiceChip && widget.label == 'Hidden',
        ),
        findsNothing,
      );
    });

    testWidgets('all chip shows correct selection state', (tester) async {
      // First state - some categories selected
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      var allChip = find.byWidgetPredicate(
        (widget) =>
            widget is FilterChoiceChip &&
            widget.label.toLowerCase().contains('all'),
      );

      // All chip should not be selected when categories are selected
      expect(
          tester.widget<FilterChoiceChip>(allChip).isSelected, equals(false));

      // Update state to no categories selected
      final stateNoneSelected = JournalPageState(
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
        selectedCategoryIds: {},
      );

      // Create a new mock cubit with the new state
      final mockCubitNoSelection = MockJournalPageCubit();
      when(() => mockCubitNoSelection.state).thenReturn(stateNoneSelected);

      // Rebuild with new cubit
      await tester.pumpWidget(
        WidgetTestBench(
          child: BlocProvider<JournalPageCubit>.value(
            value: mockCubitNoSelection,
            child: const TaskCategoryFilter(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      allChip = find.byWidgetPredicate(
        (widget) =>
            widget is FilterChoiceChip &&
            widget.label.toLowerCase().contains('all'),
      );

      // All chip should be selected when no categories are selected
      expect(tester.widget<FilterChoiceChip>(allChip).isSelected, equals(true));
    });

    testWidgets('ellipsis chip is not shown when all categories visible',
        (tester) async {
      // Use only 2 categories (both favorites, so all visible)
      final fewCategories =
          mockCategories.where((c) => c.favorite ?? false).toList();

      when(() => mockEntitiesCacheService.sortedCategories)
          .thenReturn(fewCategories);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Toggle to show all
      final ellipsisChip = find.byWidgetPredicate(
        (widget) => widget is FilterChoiceChip && widget.label == '...',
      );

      await tester.tap(ellipsisChip);
      await tester.pumpAndSettle();

      // Should not find ellipsis since all categories are already visible
      expect(
        find.byWidgetPredicate(
          (widget) => widget is FilterChoiceChip && widget.label == '...',
        ),
        findsNothing,
      );
    });
  });
}
