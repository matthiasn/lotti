// ignore_for_file: avoid_redundant_argument_values

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/widgets/search/filter_choice_chip.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mocks.dart';
import '../../test_utils/fake_journal_page_controller.dart';
import 'entry_type_filter_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() async {
    await GetIt.I.reset();
  });

  group('EntryTypeChip interaction tests', () {
    late FakeJournalPageController fakeController;
    late MockJournalDb mockDb;

    setUp(() {
      mockDb = MockJournalDb();
      // Enable all flags so all chips are visible
      when(() => mockDb.watchConfigFlags()).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([
          {
            const ConfigFlag(
              name: enableEventsFlag,
              description: 'Enable Events?',
              status: true,
            ),
            const ConfigFlag(
              name: enableHabitsPageFlag,
              description: 'Enable Habits Page?',
              status: true,
            ),
            const ConfigFlag(
              name: enableDashboardsPageFlag,
              description: 'Enable Dashboards Page?',
              status: true,
            ),
          },
        ]),
      );
    });

    tearDown(() async {
      await GetIt.I.reset();
    });

    testWidgets('tapping entry type chip calls toggleSelectedEntryTypes', (
      tester,
    ) async {
      const state = JournalPageState(
        taskStatuses: ['OPEN', 'GROOMED', 'IN PROGRESS'],
        selectedTaskStatuses: {'OPEN'},
        selectedEntryTypes: [],
      );
      fakeController = FakeJournalPageController(state);

      await hPumpFilter(
        tester,
        mockDb,
        controllerFactory: () => fakeController,
        pumpAfterMount: false,
      );

      await tester.pump();

      // Find and tap the Task chip
      await tester.tap(find.text('Task'));
      await tester.pump();

      // Verify toggleSelectedEntryTypes was called with 'Task'
      expect(fakeController.toggledEntryTypes, contains('Task'));
    });

    testWidgets('long pressing entry type chip calls selectSingleEntryType', (
      tester,
    ) async {
      const state = JournalPageState(
        taskStatuses: ['OPEN', 'GROOMED', 'IN PROGRESS'],
        selectedTaskStatuses: {'OPEN'},
        selectedEntryTypes: ['Task', 'JournalEntry'],
      );
      fakeController = FakeJournalPageController(state);

      await hPumpFilter(
        tester,
        mockDb,
        controllerFactory: () => fakeController,
        pumpAfterMount: false,
      );

      await tester.pump();

      // Long press the Text chip
      await tester.longPress(find.text('Text'));
      await tester.pump();

      // Verify selectSingleEntryType was called
      expect(fakeController.singleEntryTypeCalls, contains('JournalEntry'));
    });

    testWidgets('selected entry type chip shows selected state', (
      tester,
    ) async {
      const state = JournalPageState(
        taskStatuses: ['OPEN', 'GROOMED', 'IN PROGRESS'],
        selectedTaskStatuses: {'OPEN'},
        selectedEntryTypes: ['Task'],
      );
      fakeController = FakeJournalPageController(state);

      await hPumpFilter(
        tester,
        mockDb,
        controllerFactory: () => fakeController,
        pumpAfterMount: false,
      );

      await tester.pump();

      // Find the FilterChoiceChip for Task - it should be selected
      final taskChipFinder = find.ancestor(
        of: find.text('Task'),
        matching: find.byType(FilterChoiceChip),
      );
      expect(taskChipFinder, findsOneWidget);

      final taskChip = tester.widget<FilterChoiceChip>(taskChipFinder);
      expect(taskChip.isSelected, isTrue);

      // Find the FilterChoiceChip for Text - it should NOT be selected
      final textChipFinder = find.ancestor(
        of: find.text('Text'),
        matching: find.byType(FilterChoiceChip),
      );
      expect(textChipFinder, findsOneWidget);

      final textChip = tester.widget<FilterChoiceChip>(textChipFinder);
      expect(textChip.isSelected, isFalse);
    });

    testWidgets('displays correct labels for all entry types', (tester) async {
      const state = JournalPageState(
        taskStatuses: ['OPEN', 'GROOMED', 'IN PROGRESS'],
        selectedTaskStatuses: {'OPEN'},
        selectedEntryTypes: [],
      );
      fakeController = FakeJournalPageController(state);

      await hPumpFilter(
        tester,
        mockDb,
        controllerFactory: () => fakeController,
        pumpAfterMount: false,
      );

      await tester.pump();

      // Verify all entry type labels are present
      // Labels come from app_en.arb localization
      expect(find.text('Task'), findsOneWidget);
      expect(find.text('Text'), findsOneWidget); // JournalEntry
      expect(find.text('Audio'), findsOneWidget); // JournalAudio
      expect(find.text('Photo'), findsOneWidget); // JournalImage
      expect(find.text('Event'), findsOneWidget); // JournalEvent
      expect(find.text('Habit'), findsOneWidget); // HabitCompletionEntry
      expect(find.text('Measured'), findsOneWidget); // MeasurementEntry
      expect(find.text('Health'), findsOneWidget); // QuantitativeEntry
      expect(find.text('Survey'), findsOneWidget); // SurveyEntry
      expect(find.text('Workout'), findsOneWidget); // WorkoutEntry
      expect(find.text('Checklist'), findsOneWidget); // Checklist
      expect(find.text('To Do'), findsOneWidget); // ChecklistItem
      expect(find.text('AI Response'), findsOneWidget); // AiResponse
      // The "All" chip should also be present
      expect(find.text('All'), findsOneWidget);
    });
  });

  group('EntryTypeAllChip interaction tests', () {
    late FakeJournalPageController fakeController;
    late MockJournalDb mockDb;

    setUp(() {
      mockDb = MockJournalDb();
      // Enable all flags so all chips are visible
      when(() => mockDb.watchConfigFlags()).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([
          {
            const ConfigFlag(
              name: enableEventsFlag,
              description: 'Enable Events?',
              status: true,
            ),
            const ConfigFlag(
              name: enableHabitsPageFlag,
              description: 'Enable Habits Page?',
              status: true,
            ),
            const ConfigFlag(
              name: enableDashboardsPageFlag,
              description: 'Enable Dashboards Page?',
              status: true,
            ),
          },
        ]),
      );
    });

    tearDown(() async {
      await GetIt.I.reset();
    });

    testWidgets(
      'tapping All chip when not all selected calls selectAllEntryTypes',
      (tester) async {
        const state = JournalPageState(
          taskStatuses: ['OPEN', 'GROOMED', 'IN PROGRESS'],
          selectedTaskStatuses: {'OPEN'},
          selectedEntryTypes: ['Task'], // Only one selected, not all
        );
        fakeController = FakeJournalPageController(state);

        await hPumpFilter(
          tester,
          mockDb,
          controllerFactory: () => fakeController,
          pumpAfterMount: false,
        );

        await tester.pump();

        // Tap the "All" chip
        await tester.tap(find.text('All'));
        await tester.pump();

        // Verify selectAllEntryTypes was called
        expect(fakeController.selectAllEntryTypesCalled, equals(1));
      },
    );

    testWidgets(
      'tapping All chip when all selected calls clearSelectedEntryTypes',
      (tester) async {
        // All entry types that are enabled by the flags
        final allEntryTypes = [
          'Task',
          'JournalEntry',
          'JournalEvent',
          'JournalAudio',
          'JournalImage',
          'MeasurementEntry',
          'SurveyEntry',
          'WorkoutEntry',
          'HabitCompletionEntry',
          'QuantitativeEntry',
          'Checklist',
          'ChecklistItem',
          'AiResponse',
        ];

        final state = JournalPageState(
          taskStatuses: const ['OPEN', 'GROOMED', 'IN PROGRESS'],
          selectedTaskStatuses: const {'OPEN'},
          selectedEntryTypes: allEntryTypes,
        );
        fakeController = FakeJournalPageController(state);

        await hPumpFilter(
          tester,
          mockDb,
          controllerFactory: () => fakeController,
          pumpAfterMount: false,
        );

        await tester.pump();

        // Tap the "All" chip
        await tester.tap(find.text('All'));
        await tester.pump();

        // Verify clearSelectedEntryTypes was called
        expect(fakeController.clearSelectedEntryTypesCalled, equals(1));
      },
    );

    testWidgets('All chip shows selected state when all types are selected', (
      tester,
    ) async {
      // All entry types that are enabled by the flags
      final allEntryTypes = [
        'Task',
        'JournalEntry',
        'JournalEvent',
        'JournalAudio',
        'JournalImage',
        'MeasurementEntry',
        'SurveyEntry',
        'WorkoutEntry',
        'HabitCompletionEntry',
        'QuantitativeEntry',
        'Checklist',
        'ChecklistItem',
        'AiResponse',
      ];

      final state = JournalPageState(
        taskStatuses: const ['OPEN', 'GROOMED', 'IN PROGRESS'],
        selectedTaskStatuses: const {'OPEN'},
        selectedEntryTypes: allEntryTypes,
      );
      fakeController = FakeJournalPageController(state);

      await hPumpFilter(
        tester,
        mockDb,
        controllerFactory: () => fakeController,
        pumpAfterMount: false,
      );

      await tester.pump();

      // Find the "All" FilterChoiceChip
      final allChipFinder = find.ancestor(
        of: find.text('All'),
        matching: find.byType(FilterChoiceChip),
      );
      expect(allChipFinder, findsOneWidget);

      final allChip = tester.widget<FilterChoiceChip>(allChipFinder);
      expect(allChip.isSelected, isTrue);
    });

    testWidgets(
      'All chip shows unselected state when not all types are selected',
      (tester) async {
        const state = JournalPageState(
          taskStatuses: ['OPEN', 'GROOMED', 'IN PROGRESS'],
          selectedTaskStatuses: {'OPEN'},
          selectedEntryTypes: ['Task', 'JournalEntry'], // Only some selected
        );
        fakeController = FakeJournalPageController(state);

        await hPumpFilter(
          tester,
          mockDb,
          controllerFactory: () => fakeController,
          pumpAfterMount: false,
        );

        await tester.pump();

        // Find the "All" FilterChoiceChip
        final allChipFinder = find.ancestor(
          of: find.text('All'),
          matching: find.byType(FilterChoiceChip),
        );
        expect(allChipFinder, findsOneWidget);

        final allChip = tester.widget<FilterChoiceChip>(allChipFinder);
        expect(allChip.isSelected, isFalse);
      },
    );
  });
}
