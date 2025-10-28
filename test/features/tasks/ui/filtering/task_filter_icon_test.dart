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
import 'package:lotti/features/tasks/ui/filtering/task_filter_icon.dart';
import 'package:lotti/features/tasks/ui/filtering/task_priority_filter.dart';
import 'package:lotti/features/tasks/ui/filtering/task_status_filter.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/widgets/app_bar/journal_sliver_appbar.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
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
    LabelDefinition(
      id: 'label2',
      name: 'Nice to have',
      color: '#00FF00',
      createdAt: DateTime(2023),
      updatedAt: DateTime(2023),
      vectorClock: null,
      private: false,
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
      selectedLabelIds: const {},
    );

    when(() => mockCubit.state).thenReturn(mockState);

    // Set up EntitiesCacheService mock
    when(() => mockEntitiesCacheService.sortedCategories)
        .thenReturn(mockCategories);
    when(() => mockEntitiesCacheService.sortedLabels).thenReturn(mockLabels);

    // Register the mock with GetIt
    getIt.allowReassignment = true;
    getIt.registerSingleton<EntitiesCacheService>(mockEntitiesCacheService);
  });

  tearDown(getIt.reset);

  group('TaskFilterIcon', () {
    Widget buildSubject() {
      return WidgetTestBench(
        child: BlocProvider<JournalPageCubit>.value(
          value: mockCubit,
          child: const Scaffold(
            body: TaskFilterIcon(),
          ),
        ),
      );
    }

    testWidgets('renders correctly', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Verify the icon is rendered
      expect(find.byType(TaskFilterIcon), findsOneWidget);
      expect(find.byIcon(MdiIcons.filterVariant), findsOneWidget);
    });

    testWidgets('opens modal when tapped', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Tap on the filter icon
      await tester.tap(find.byIcon(MdiIcons.filterVariant));
      await tester.pumpAndSettle();

      // Verify the modal is shown
      expect(find.byType(IconButton), findsWidgets);
    });

    testWidgets('modal contains expected components', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Tap on the filter icon
      await tester.tap(find.byIcon(MdiIcons.filterVariant));
      await tester.pumpAndSettle();

      // Verify the modal contains the expected components
      expect(find.byType(JournalFilter), findsOneWidget);
      expect(find.byType(TaskStatusFilter), findsOneWidget);
      expect(find.byType(TaskCategoryFilter), findsOneWidget);
      expect(find.byType(TaskPriorityFilter), findsOneWidget);
    });

    testWidgets('modal can be closed by tapping outside', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Tap on the filter icon
      await tester.tap(find.byIcon(MdiIcons.filterVariant));
      await tester.pumpAndSettle();

      // Verify the modal is shown
      expect(find.byType(TaskStatusFilter), findsOneWidget);
      expect(find.byType(TaskCategoryFilter), findsOneWidget);

      // Tap outside the modal (barrier)
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // Verify components are no longer visible
      expect(find.byType(TaskStatusFilter), findsNothing);
      expect(find.byType(TaskCategoryFilter), findsNothing);
    });
  });
}
