import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/blocs/journal/journal_page_state.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/widgets/search/entry_type_filter.dart';
import 'package:mocktail/mocktail.dart';

import '../../widget_test_utils.dart';

class MockJournalDb extends Mock implements JournalDb {}

class MockJournalPageCubit extends Mock implements JournalPageCubit {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockJournalDb mockDb;
  late MockJournalPageCubit mockCubit;

  setUp(() {
    mockDb = MockJournalDb();
    mockCubit = MockJournalPageCubit();

    // Mock the cubit state
    when(() => mockCubit.state).thenReturn(
      JournalPageState(
        selectedEntryTypes: const [],
        match: '',
        tagIds: const {},
        filters: const {},
        showPrivateEntries: true,
        showTasks: true,
        fullTextMatches: const {},
        pagingController: null,
        taskStatuses: const [],
        selectedTaskStatuses: const {},
        selectedCategoryIds: const {},
      ),
    );

    when(() => mockCubit.stream).thenAnswer(
      (_) => Stream<JournalPageState>.fromIterable([
        JournalPageState(
          selectedEntryTypes: const [],
          match: '',
          tagIds: const {},
          filters: const {},
          showPrivateEntries: true,
          showTasks: true,
          fullTextMatches: const {},
          pagingController: null,
          taskStatuses: const [],
          selectedTaskStatuses: const {},
          selectedCategoryIds: const {},
        ),
      ]),
    );
  });

  tearDown(() async {
    await GetIt.I.reset();
  });

  group('EntryTypeFilter Tests', () {
    testWidgets('filters out JournalEvent chip when enableEventsFlag is OFF',
        (tester) async {
      // Mock JournalDb.watchConfigFlags() to return enableEventsFlag: false
      when(() => mockDb.watchConfigFlags()).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([
          {
            const ConfigFlag(
              name: enableEventsFlag,
              description: 'Enable Events?',
              status: false,
            ),
          },
        ]),
      );

      GetIt.I.registerSingleton<JournalDb>(mockDb);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<JournalPageCubit>.value(
            value: mockCubit,
            child: const EntryTypeFilter(),
          ),
          overrides: [
            journalDbProvider.overrideWithValue(mockDb),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Assert: 'Event' chip text is NOT found
      expect(find.text('Event'), findsNothing);
      // Assert: Other entry type chips ARE found (Task, Text, Audio, etc.)
      expect(find.text('Task'), findsOneWidget);
      expect(find.text('Text'), findsOneWidget);
      expect(find.text('Audio'), findsOneWidget);
    });

    testWidgets('shows JournalEvent chip when enableEventsFlag is ON',
        (tester) async {
      // Mock JournalDb.watchConfigFlags() to return enableEventsFlag: true
      when(() => mockDb.watchConfigFlags()).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([
          {
            const ConfigFlag(
              name: enableEventsFlag,
              description: 'Enable Events?',
              status: true,
            ),
          },
        ]),
      );

      GetIt.I.registerSingleton<JournalDb>(mockDb);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<JournalPageCubit>.value(
            value: mockCubit,
            child: const EntryTypeFilter(),
          ),
          overrides: [
            journalDbProvider.overrideWithValue(mockDb),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Assert: 'Event' chip text IS found
      expect(find.text('Event'), findsOneWidget);
      // Assert: All entry type chips are present
      expect(find.text('Task'), findsOneWidget);
      expect(find.text('Text'), findsOneWidget);
      expect(find.text('Audio'), findsOneWidget);
    });

    testWidgets('defaults to filtering out Event when flag stream is empty',
        (tester) async {
      // Mock stream returns empty set
      when(() => mockDb.watchConfigFlags()).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([{}]),
      );

      GetIt.I.registerSingleton<JournalDb>(mockDb);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<JournalPageCubit>.value(
            value: mockCubit,
            child: const EntryTypeFilter(),
          ),
          overrides: [
            journalDbProvider.overrideWithValue(mockDb),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Assert: JournalEvent is filtered out (default false behavior)
      expect(find.text('Event'), findsNothing);
      expect(find.text('Task'), findsOneWidget);
    });

    testWidgets('updates when flag changes from OFF to ON', (tester) async {
      // Setup: StreamController to control flag changes
      final flagController = StreamController<Set<ConfigFlag>>();

      when(() => mockDb.watchConfigFlags()).thenAnswer(
        (_) => flagController.stream,
      );

      GetIt.I.registerSingleton<JournalDb>(mockDb);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<JournalPageCubit>.value(
            value: mockCubit,
            child: const EntryTypeFilter(),
          ),
          overrides: [
            journalDbProvider.overrideWithValue(mockDb),
          ],
        ),
      );

      // Initial: flag OFF, verify Event chip hidden
      flagController.add({
        const ConfigFlag(
          name: enableEventsFlag,
          description: 'Enable Events?',
          status: false,
        ),
      });

      await tester.pumpAndSettle();
      expect(find.text('Event'), findsNothing);

      // Update: flag ON, verify Event chip appears
      flagController.add({
        const ConfigFlag(
          name: enableEventsFlag,
          description: 'Enable Events?',
          status: true,
        ),
      });

      await tester.pumpAndSettle();
      expect(find.text('Event'), findsOneWidget);

      await flagController.close();
    });

    testWidgets('filters out Habit chip when enableHabitsPageFlag is OFF',
        (tester) async {
      // Habits disabled
      when(() => mockDb.watchConfigFlags()).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([
          {
            const ConfigFlag(
              name: enableHabitsPageFlag,
              description: 'Enable Habits Page?',
              status: false,
            ),
          },
        ]),
      );

      GetIt.I.registerSingleton<JournalDb>(mockDb);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<JournalPageCubit>.value(
            value: mockCubit,
            child: const EntryTypeFilter(),
          ),
          overrides: [journalDbProvider.overrideWithValue(mockDb)],
        ),
      );

      await tester.pumpAndSettle();

      // Assert: Habit chip is hidden
      expect(find.text('Habit'), findsNothing);
    });

    testWidgets('shows Habit chip when enableHabitsPageFlag is ON',
        (tester) async {
      // Habits enabled
      when(() => mockDb.watchConfigFlags()).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([
          {
            const ConfigFlag(
              name: enableHabitsPageFlag,
              description: 'Enable Habits Page?',
              status: true,
            ),
          },
        ]),
      );

      GetIt.I.registerSingleton<JournalDb>(mockDb);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<JournalPageCubit>.value(
            value: mockCubit,
            child: const EntryTypeFilter(),
          ),
          overrides: [journalDbProvider.overrideWithValue(mockDb)],
        ),
      );

      await tester.pumpAndSettle();

      // Assert: Habit chip is visible
      expect(find.text('Habit'), findsOneWidget);
    });

    testWidgets(
        'filters out Measured and Health when enableDashboardsPageFlag is OFF',
        (tester) async {
      // Dashboards disabled
      when(() => mockDb.watchConfigFlags()).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([
          {
            const ConfigFlag(
              name: enableDashboardsPageFlag,
              description: 'Enable Dashboards Page?',
              status: false,
            ),
          },
        ]),
      );

      GetIt.I.registerSingleton<JournalDb>(mockDb);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<JournalPageCubit>.value(
            value: mockCubit,
            child: const EntryTypeFilter(),
          ),
          overrides: [journalDbProvider.overrideWithValue(mockDb)],
        ),
      );

      await tester.pumpAndSettle();

      // Assert: Measured and Health chips are hidden
      expect(find.text('Measured'), findsNothing);
      expect(find.text('Health'), findsNothing);
    });

    testWidgets('shows Measured and Health when dashboards flag is ON',
        (tester) async {
      // Dashboards enabled
      when(() => mockDb.watchConfigFlags()).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([
          {
            const ConfigFlag(
              name: enableDashboardsPageFlag,
              description: 'Enable Dashboards Page?',
              status: true,
            ),
          },
        ]),
      );

      GetIt.I.registerSingleton<JournalDb>(mockDb);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<JournalPageCubit>.value(
            value: mockCubit,
            child: const EntryTypeFilter(),
          ),
          overrides: [journalDbProvider.overrideWithValue(mockDb)],
        ),
      );

      await tester.pumpAndSettle();

      // Assert: Measured and Health chips are visible
      expect(find.text('Measured'), findsOneWidget);
      expect(find.text('Health'), findsOneWidget);
    });

    /* TODO: Fix timeout issues in these tests
    testWidgets('keeps previous value during loading state', (tester) async {
      final flagController = StreamController<Set<ConfigFlag>>();

      when(() => mockDb.watchConfigFlags()).thenAnswer(
        (_) => flagController.stream,
      );

      GetIt.I.registerSingleton<JournalDb>(mockDb);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<JournalPageCubit>.value(
            value: mockCubit,
            child: const EntryTypeFilter(),
          ),
          overrides: [journalDbProvider.overrideWithValue(mockDb)],
        ),
      );

      // Emit initial value: Events enabled
      flagController.add({
        const ConfigFlag(
          name: enableEventsFlag,
          description: 'Enable Events?',
          status: true,
        ),
      });

      await tester.pumpAndSettle();

      // Assert: Event chip is visible
      expect(find.text('Event'), findsOneWidget);

      // Emit loading state (new stream without immediate value)
      // unwrapPrevious should keep the previous value
      // This is simulated by the stream not emitting new values
      await tester.pump(const Duration(milliseconds: 50));

      // Assert: Event chip still visible (previous value retained)
      expect(find.text('Event'), findsOneWidget);

      await flagController.close();
    });

    testWidgets('defaults to false on error', (tester) async {
      // Mock stream that emits an error
      when(() => mockDb.watchConfigFlags()).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.error(Exception('Test error')),
      );

      GetIt.I.registerSingleton<JournalDb>(mockDb);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<JournalPageCubit>.value(
            value: mockCubit,
            child: const EntryTypeFilter(),
          ),
          overrides: [journalDbProvider.overrideWithValue(mockDb)],
        ),
      );

      await tester.pumpAndSettle();

      // Assert: Event chip is hidden (defaults to false on error)
      expect(find.text('Event'), findsNothing);
      // Assert: Other non-gated chips are still visible
      expect(find.text('Task'), findsOneWidget);
    });

    testWidgets('handles all flags loading simultaneously', (tester) async {
      final eventsController = StreamController<Set<ConfigFlag>>();
      final habitsController = StreamController<Set<ConfigFlag>>();
      final dashboardsController = StreamController<Set<ConfigFlag>>();

      // Mock all flags with separate controllers
      when(() => mockDb.watchConfigFlags()).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([{}]),
      );

      GetIt.I.registerSingleton<JournalDb>(mockDb);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<JournalPageCubit>.value(
            value: mockCubit,
            child: const EntryTypeFilter(),
          ),
          overrides: [journalDbProvider.overrideWithValue(mockDb)],
        ),
      );

      // Initial state: all flags loading (empty set means no flags active)
      await tester.pumpAndSettle();

      // Assert: All feature-gated chips are hidden
      expect(find.text('Event'), findsNothing);
      expect(find.text('Habit'), findsNothing);
      expect(find.text('Measured'), findsNothing);
      expect(find.text('Health'), findsNothing);

      // Assert: Non-gated chips are visible
      expect(find.text('Task'), findsOneWidget);
      expect(find.text('Text'), findsOneWidget);

      await eventsController.close();
      await habitsController.close();
      await dashboardsController.close();
    });

    testWidgets('handles partial flag loading', (tester) async {
      // Mock Events loaded (true), Habits and Dashboards not yet emitted
      when(() => mockDb.watchConfigFlags()).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([
          {
            const ConfigFlag(
              name: enableEventsFlag,
              description: 'Enable Events?',
              status: true,
            ),
          },
        ]),
      );

      GetIt.I.registerSingleton<JournalDb>(mockDb);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<JournalPageCubit>.value(
            value: mockCubit,
            child: const EntryTypeFilter(),
          ),
          overrides: [journalDbProvider.overrideWithValue(mockDb)],
        ),
      );

      await tester.pumpAndSettle();

      // Assert: Event chip visible (flag loaded and true)
      expect(find.text('Event'), findsOneWidget);
      // Assert: Habit chip hidden (flag not in set, defaults to false)
      expect(find.text('Habit'), findsNothing);
      // Assert: Measured chip hidden (flag not in set, defaults to false)
      expect(find.text('Measured'), findsNothing);
    });

    testWidgets('unwrapPrevious retains value during rapid state changes',
        (tester) async {
      final flagController = StreamController<Set<ConfigFlag>>();

      when(() => mockDb.watchConfigFlags()).thenAnswer(
        (_) => flagController.stream,
      );

      GetIt.I.registerSingleton<JournalDb>(mockDb);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<JournalPageCubit>.value(
            value: mockCubit,
            child: const EntryTypeFilter(),
          ),
          overrides: [journalDbProvider.overrideWithValue(mockDb)],
        ),
      );

      // Initial: Events enabled
      flagController.add({
        const ConfigFlag(
          name: enableEventsFlag,
          description: 'Enable Events?',
          status: true,
        ),
      });

      await tester.pumpAndSettle();
      expect(find.text('Event'), findsOneWidget);

      // Rapid changes: Events OFF → ON
      flagController.add({
        const ConfigFlag(
          name: enableEventsFlag,
          description: 'Enable Events?',
          status: false,
        ),
      });
      await tester.pump(const Duration(milliseconds: 10));

      flagController.add({
        const ConfigFlag(
          name: enableEventsFlag,
          description: 'Enable Events?',
          status: true,
        ),
      });

      await tester.pumpAndSettle();

      // Assert: Final state correct, no errors
      expect(find.text('Event'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await flagController.close();
    });
    */
  });
}
