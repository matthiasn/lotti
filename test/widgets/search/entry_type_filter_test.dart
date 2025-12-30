// ignore_for_file: avoid_redundant_argument_values

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/widgets/search/entry_type_filter.dart';
import 'package:mocktail/mocktail.dart';

import '../../widget_test_utils.dart';

class MockJournalDb extends Mock implements JournalDb {}

/// Mock controller for testing
class MockJournalPageController extends JournalPageController {
  @override
  JournalPageState build(bool showTasks) {
    return const JournalPageState(
      selectedEntryTypes: [],
      match: '',
      tagIds: {},
      filters: {},
      showPrivateEntries: true,
      showTasks: false,
      fullTextMatches: {},
      pagingController: null,
      taskStatuses: [],
      selectedTaskStatuses: {},
      selectedCategoryIds: {},
      selectedLabelIds: {},
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockJournalDb mockDb;

  setUp(() {
    mockDb = MockJournalDb();
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
          const EntryTypeFilter(),
          overrides: [
            journalDbProvider.overrideWithValue(mockDb),
            journalPageScopeProvider.overrideWithValue(false),
            journalPageControllerProvider(false)
                .overrideWith(MockJournalPageController.new),
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
          const EntryTypeFilter(),
          overrides: [
            journalDbProvider.overrideWithValue(mockDb),
            journalPageScopeProvider.overrideWithValue(false),
            journalPageControllerProvider(false)
                .overrideWith(MockJournalPageController.new),
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
          const EntryTypeFilter(),
          overrides: [
            journalDbProvider.overrideWithValue(mockDb),
            journalPageScopeProvider.overrideWithValue(false),
            journalPageControllerProvider(false)
                .overrideWith(MockJournalPageController.new),
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
          const EntryTypeFilter(),
          overrides: [
            journalDbProvider.overrideWithValue(mockDb),
            journalPageScopeProvider.overrideWithValue(false),
            journalPageControllerProvider(false)
                .overrideWith(MockJournalPageController.new),
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
          const EntryTypeFilter(),
          overrides: [
            journalDbProvider.overrideWithValue(mockDb),
            journalPageScopeProvider.overrideWithValue(false),
            journalPageControllerProvider(false)
                .overrideWith(MockJournalPageController.new),
          ],
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
          const EntryTypeFilter(),
          overrides: [
            journalDbProvider.overrideWithValue(mockDb),
            journalPageScopeProvider.overrideWithValue(false),
            journalPageControllerProvider(false)
                .overrideWith(MockJournalPageController.new),
          ],
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
          const EntryTypeFilter(),
          overrides: [
            journalDbProvider.overrideWithValue(mockDb),
            journalPageScopeProvider.overrideWithValue(false),
            journalPageControllerProvider(false)
                .overrideWith(MockJournalPageController.new),
          ],
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
          const EntryTypeFilter(),
          overrides: [
            journalDbProvider.overrideWithValue(mockDb),
            journalPageScopeProvider.overrideWithValue(false),
            journalPageControllerProvider(false)
                .overrideWith(MockJournalPageController.new),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Assert: Measured and Health chips are visible
      expect(find.text('Measured'), findsOneWidget);
      expect(find.text('Health'), findsOneWidget);
    });

    testWidgets('keeps previous value during loading state', (tester) async {
      final flagController = StreamController<Set<ConfigFlag>>.broadcast();

      when(() => mockDb.watchConfigFlags()).thenAnswer(
        (_) => flagController.stream,
      );

      GetIt.I.registerSingleton<JournalDb>(mockDb);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const EntryTypeFilter(),
          overrides: [
            journalDbProvider.overrideWithValue(mockDb),
            journalPageScopeProvider.overrideWithValue(false),
            journalPageControllerProvider(false)
                .overrideWith(MockJournalPageController.new),
          ],
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

      // Use pump() with duration instead of pumpAndSettle() to avoid timeout
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Assert: Event chip is visible
      expect(find.text('Event'), findsOneWidget);

      // Don't emit new value - unwrapPrevious should keep the previous value
      // Just pump to allow any potential rebuilds
      await tester.pump(const Duration(milliseconds: 50));

      // Assert: Event chip still visible (previous value retained)
      expect(find.text('Event'), findsOneWidget);

      await flagController.close();
    });

    testWidgets('defaults to false on error', (tester) async {
      // Mock stream that emits a value first, then an error
      // unwrapPrevious should keep the previous value even on error
      final flagController = StreamController<Set<ConfigFlag>>.broadcast();

      when(() => mockDb.watchConfigFlags()).thenAnswer(
        (_) => flagController.stream,
      );

      GetIt.I.registerSingleton<JournalDb>(mockDb);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const EntryTypeFilter(),
          overrides: [
            journalDbProvider.overrideWithValue(mockDb),
            journalPageScopeProvider.overrideWithValue(false),
            journalPageControllerProvider(false)
                .overrideWith(MockJournalPageController.new),
          ],
        ),
      );

      // Emit initial value (empty = flags disabled)
      flagController.add(<ConfigFlag>{});

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Assert: Event chip is hidden (flag not in set, defaults to false)
      expect(find.text('Event'), findsNothing);
      // Assert: Other non-gated chips are still visible
      expect(find.text('Task'), findsOneWidget);

      // Now emit an error - unwrapPrevious should keep previous value
      flagController.addError(Exception('Test error'));
      await tester.pump(const Duration(milliseconds: 50));

      // Assert: Event still hidden (previous value retained despite error)
      expect(find.text('Event'), findsNothing);
      expect(find.text('Task'), findsOneWidget);

      await flagController.close();
    });

    testWidgets('handles all flags loading simultaneously', (tester) async {
      // Mock all flags with empty set (no flags active)
      when(() => mockDb.watchConfigFlags()).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([{}]),
      );

      GetIt.I.registerSingleton<JournalDb>(mockDb);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const EntryTypeFilter(),
          overrides: [
            journalDbProvider.overrideWithValue(mockDb),
            journalPageScopeProvider.overrideWithValue(false),
            journalPageControllerProvider(false)
                .overrideWith(MockJournalPageController.new),
          ],
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
          const EntryTypeFilter(),
          overrides: [
            journalDbProvider.overrideWithValue(mockDb),
            journalPageScopeProvider.overrideWithValue(false),
            journalPageControllerProvider(false)
                .overrideWith(MockJournalPageController.new),
          ],
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
      final flagController = StreamController<Set<ConfigFlag>>.broadcast();

      when(() => mockDb.watchConfigFlags()).thenAnswer(
        (_) => flagController.stream,
      );

      GetIt.I.registerSingleton<JournalDb>(mockDb);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const EntryTypeFilter(),
          overrides: [
            journalDbProvider.overrideWithValue(mockDb),
            journalPageScopeProvider.overrideWithValue(false),
            journalPageControllerProvider(false)
                .overrideWith(MockJournalPageController.new),
          ],
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

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
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

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Assert: Final state correct, no errors
      expect(find.text('Event'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await flagController.close();
    });
  });
}
