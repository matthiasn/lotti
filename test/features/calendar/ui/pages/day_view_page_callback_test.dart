import 'dart:io';

import 'package:calendar_view/calendar_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/features/calendar/state/calendar_event.dart';
import 'package:lotti/features/calendar/state/day_view_controller.dart';
import 'package:lotti/features/calendar/state/time_by_category_controller.dart';
import 'package:lotti/features/calendar/ui/pages/day_view_page.dart';
import 'package:lotti/features/journal/state/journal_focus_controller.dart';
import 'package:lotti/features/tasks/state/task_focus_controller.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/link_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../../helpers/path_provider.dart';
import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';

class MockNavServiceImpl extends Mock implements NavService {
  final List<String> navigationHistory = [];

  @override
  void beamToNamed(String path, {Object? data}) {
    navigationHistory.add(path);
  }

  void reset() {
    navigationHistory.clear();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var mockJournalDb = MockJournalDb();
  var mockPersistenceLogic = MockPersistenceLogic();
  final mockUpdateNotifications = MockUpdateNotifications();
  final mockEntitiesCacheService = MockEntitiesCacheService();
  late MockNavServiceImpl mockNav;

  group('DayViewPage onEventTap Callback Integration Tests - ', () {
    setUpAll(() {
      setFakeDocumentsPath();
      registerFallbackValue(FakeMeasurementData());
    });

    setUp(() async {
      mockJournalDb = mockJournalDbWithMeasurableTypes([
        measurableWater,
        measurableChocolate,
      ]);
      mockPersistenceLogic = MockPersistenceLogic();
      mockNav = MockNavServiceImpl();

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
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
        ..registerSingleton<NavService>(mockNav);

      when(() => mockEntitiesCacheService.sortedCategories).thenAnswer(
        (_) => [categoryMindfulness],
      );

      when(
        () => mockJournalDb
            .getMeasurableDataTypeById('83ebf58d-9cea-4c15-a034-89c84a8b8178'),
      ).thenAnswer((_) async => measurableWater);

      when(() => mockUpdateNotifications.updateStream).thenAnswer(
        (_) => Stream<Set<String>>.fromIterable([]),
      );

      when(mockTagsService.watchTags).thenAnswer(
        (_) => Stream<List<TagEntity>>.fromIterable([
          [testStoryTag1],
        ]),
      );

      when(() => mockTagsService.stream).thenAnswer(
        (_) => Stream<List<TagEntity>>.fromIterable([[]]),
      );

      when(() => mockJournalDb.watchConfigFlags()).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([
          <ConfigFlag>{
            const ConfigFlag(
              name: 'private',
              description: 'Show private entries?',
              status: true,
            ),
          }
        ]),
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
        () => mockHealthImport
            .fetchHealthDataDelta(testWeightEntry.data.dataType),
      ).thenAnswer((_) async {});

      when(mockTimeService.getStream)
          .thenAnswer((_) => Stream<JournalEntity>.fromIterable([]));

      when(
        () => mockJournalDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => []);

      when(
        () => mockJournalDb.linksForEntryIds(any()),
      ).thenAnswer((_) async => []);
    });

    tearDown(() {
      getIt.reset();
      mockNav.reset();
    });

    testWidgets(
        'DayViewWidget onEventTap with Task linkedFrom executes callback',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          dayViewControllerProvider.overrideWith(
            DayViewControllerOverride.new,
          ),
          timeByCategoryControllerProvider.overrideWith(
            TimeByCategoryControllerOverride.new,
          ),
          timeByDayChartProvider.overrideWith(
            (ref) async => <TimeByDayAndCategory>[],
          ),
          timeFrameControllerProvider.overrideWith(
            TimeFrameControllerOverride.new,
          ),
          daySelectionControllerProvider.overrideWith(
            DaySelectionControllerOverride.new,
          ),
          timeChartSelectedDataProvider.overrideWith(
            TimeChartSelectedDataOverride.new,
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: makeTestableWidgetWithScaffold(
            const DayViewPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final dayViewWidget = tester.widget<DayView<Object?>>(
        find.byType(DayView<Object?>),
      );

      expect(dayViewWidget.onEventTap, isNotNull);

      // Create test data
      final task = testTask;
      final entry = testTextEntry;
      final taskId = task.meta.id;
      final entryId = entry.meta.id;

      final calendarEvent = CalendarEvent(
        entity: entry,
        linkedFrom: task,
      );

      final events = [
        CalendarEventData<Object>(
          event: calendarEvent,
          date: DateTime.now(),
          title: 'Test Event',
        ),
      ];

      // Execute callback
      dayViewWidget.onEventTap!(events, DateTime.now());

      // Pump to process the callback
      await tester.pump();

      // Verify task focus was published
      final taskFocusState =
          container.read(taskFocusControllerProvider(id: taskId));
      expect(taskFocusState, isNotNull);
      expect(taskFocusState!.entryId, equals(entryId));
      expect(taskFocusState.alignment, equals(0.3));

      // Verify navigation occurred
      expect(mockNav.navigationHistory, contains('/tasks/$taskId'));

      // Advance test clock past VisibilityDetector timer (500ms)
      await tester.pump(const Duration(milliseconds: 600));

      // Clean up widget tree
      await tester.pumpWidget(Container());
      await tester.pump(const Duration(milliseconds: 600));

      container.dispose();
    });

    testWidgets(
        'DayViewWidget onEventTap with JournalEntry linkedFrom executes callback',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          dayViewControllerProvider.overrideWith(
            DayViewControllerOverride.new,
          ),
          timeByCategoryControllerProvider.overrideWith(
            TimeByCategoryControllerOverride.new,
          ),
          timeByDayChartProvider.overrideWith(
            (ref) async => <TimeByDayAndCategory>[],
          ),
          timeFrameControllerProvider.overrideWith(
            TimeFrameControllerOverride.new,
          ),
          daySelectionControllerProvider.overrideWith(
            DaySelectionControllerOverride.new,
          ),
          timeChartSelectedDataProvider.overrideWith(
            TimeChartSelectedDataOverride.new,
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: makeTestableWidgetWithScaffold(
            const DayViewPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final dayViewWidget = tester.widget<DayView<Object?>>(
        find.byType(DayView<Object?>),
      );

      // Create test data
      final journal = testTextEntry;
      final timeEntry = testTextEntryNoGeo;
      final journalId = journal.meta.id;
      final entryId = timeEntry.meta.id;

      final calendarEvent = CalendarEvent(
        entity: timeEntry,
        linkedFrom: journal,
      );

      final events = [
        CalendarEventData<Object>(
          event: calendarEvent,
          date: DateTime.now(),
          title: 'Test Event',
        ),
      ];

      // Execute callback
      dayViewWidget.onEventTap!(events, DateTime.now());
      await tester.pump();

      // Verify journal focus was published
      final journalFocusState =
          container.read(journalFocusControllerProvider(id: journalId));
      expect(journalFocusState, isNotNull);
      expect(journalFocusState!.entryId, equals(entryId));
      expect(journalFocusState.alignment, equals(0.3));

      // Verify navigation occurred
      expect(mockNav.navigationHistory, contains('/journal/$journalId'));

      // Advance test clock past VisibilityDetector timer
      await tester.pump(const Duration(milliseconds: 600));

      await tester.pumpWidget(Container());
      await tester.pump(const Duration(milliseconds: 600));

      container.dispose();
    });

    testWidgets(
        'DayViewWidget onEventTap without linkedFrom navigates directly',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          dayViewControllerProvider.overrideWith(
            DayViewControllerOverride.new,
          ),
          timeByCategoryControllerProvider.overrideWith(
            TimeByCategoryControllerOverride.new,
          ),
          timeByDayChartProvider.overrideWith(
            (ref) async => <TimeByDayAndCategory>[],
          ),
          timeFrameControllerProvider.overrideWith(
            TimeFrameControllerOverride.new,
          ),
          daySelectionControllerProvider.overrideWith(
            DaySelectionControllerOverride.new,
          ),
          timeChartSelectedDataProvider.overrideWith(
            TimeChartSelectedDataOverride.new,
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: makeTestableWidgetWithScaffold(
            const DayViewPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final dayViewWidget = tester.widget<DayView<Object?>>(
        find.byType(DayView<Object?>),
      );

      // Create test data
      final entry = testTextEntry;
      final entryId = entry.meta.id;

      final calendarEvent = CalendarEvent(
        entity: entry,
      );

      final events = [
        CalendarEventData<Object>(
          event: calendarEvent,
          date: DateTime.now(),
          title: 'Test Event',
        ),
      ];

      // Execute callback
      dayViewWidget.onEventTap!(events, DateTime.now());
      await tester.pump();

      // Verify navigation occurred directly
      expect(mockNav.navigationHistory, contains('/journal/$entryId'));

      // Verify no focus was published
      final taskFocusState =
          container.read(taskFocusControllerProvider(id: entryId));
      expect(taskFocusState, isNull);

      final journalFocusState =
          container.read(journalFocusControllerProvider(id: entryId));
      expect(journalFocusState, isNull);

      // Advance test clock past VisibilityDetector timer
      await tester.pump(const Duration(milliseconds: 600));

      await tester.pumpWidget(Container());
      await tester.pump(const Duration(milliseconds: 600));

      container.dispose();
    });

    testWidgets('DayViewWidget onEventTap with empty events list',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          dayViewControllerProvider.overrideWith(
            DayViewControllerOverride.new,
          ),
          timeByCategoryControllerProvider.overrideWith(
            TimeByCategoryControllerOverride.new,
          ),
          timeByDayChartProvider.overrideWith(
            (ref) async => <TimeByDayAndCategory>[],
          ),
          timeFrameControllerProvider.overrideWith(
            TimeFrameControllerOverride.new,
          ),
          daySelectionControllerProvider.overrideWith(
            DaySelectionControllerOverride.new,
          ),
          timeChartSelectedDataProvider.overrideWith(
            TimeChartSelectedDataOverride.new,
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: makeTestableWidgetWithScaffold(
            const DayViewPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final dayViewWidget = tester.widget<DayView<Object?>>(
        find.byType(DayView<Object?>),
      );

      // Execute with empty events list
      dayViewWidget.onEventTap!([], DateTime.now());
      await tester.pump();

      // Verify no navigation occurred
      expect(mockNav.navigationHistory, isEmpty);

      // Advance test clock past VisibilityDetector timer
      await tester.pump(const Duration(milliseconds: 600));

      await tester.pumpWidget(Container());
      await tester.pump(const Duration(milliseconds: 600));

      container.dispose();
    });

    testWidgets('DayViewWidget onEventTap with WorkoutEntry linkedFrom',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          dayViewControllerProvider.overrideWith(
            DayViewControllerOverride.new,
          ),
          timeByCategoryControllerProvider.overrideWith(
            TimeByCategoryControllerOverride.new,
          ),
          timeByDayChartProvider.overrideWith(
            (ref) async => <TimeByDayAndCategory>[],
          ),
          timeFrameControllerProvider.overrideWith(
            TimeFrameControllerOverride.new,
          ),
          daySelectionControllerProvider.overrideWith(
            DaySelectionControllerOverride.new,
          ),
          timeChartSelectedDataProvider.overrideWith(
            TimeChartSelectedDataOverride.new,
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: makeTestableWidgetWithScaffold(
            const DayViewPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final dayViewWidget = tester.widget<DayView<Object?>>(
        find.byType(DayView<Object?>),
      );

      // Create test data with WorkoutEntry
      final workout = testWorkoutRunning;
      final timeEntry = testTextEntry;
      final workoutId = workout.meta.id;
      final entryId = timeEntry.meta.id;

      final calendarEvent = CalendarEvent(
        entity: timeEntry,
        linkedFrom: workout,
      );

      final events = [
        CalendarEventData<Object>(
          event: calendarEvent,
          date: DateTime.now(),
          title: 'Test Event',
        ),
      ];

      // Execute callback
      dayViewWidget.onEventTap!(events, DateTime.now());
      await tester.pump();

      // Verify journal focus was published (WorkoutEntry is not a Task)
      final journalFocusState =
          container.read(journalFocusControllerProvider(id: workoutId));
      expect(journalFocusState, isNotNull);
      expect(journalFocusState!.entryId, equals(entryId));
      expect(journalFocusState.alignment, equals(0.3));

      // Verify navigation to journal (not tasks)
      expect(mockNav.navigationHistory, contains('/journal/$workoutId'));

      // Advance test clock past VisibilityDetector timer
      await tester.pump(const Duration(milliseconds: 600));

      await tester.pumpWidget(Container());
      await tester.pump(const Duration(milliseconds: 600));

      container.dispose();
    });
  });
}

// Override controllers for testing
class DayViewControllerOverride extends DayViewController {
  @override
  Future<List<CalendarEventData<CalendarEvent>>> build() async {
    return [];
  }

  @override
  void onVisibilityChanged(VisibilityInfo info) {
    // No-op to prevent fetching data during timer events
  }
}

class TimeByCategoryControllerOverride extends TimeByCategoryController {
  TimeByCategoryControllerOverride();

  @override
  Future<TimeByCategoryData> build() async => {};

  @override
  void onVisibilityChanged(VisibilityInfo info) {
    // No-op
  }
}

class TimeFrameControllerOverride extends TimeFrameController {
  TimeFrameControllerOverride();
}

class DaySelectionControllerOverride extends DaySelectionController {
  @override
  DateTime build() {
    return DateTime.now();
  }
}

class TimeChartSelectedDataOverride extends TimeChartSelectedData {
  @override
  Map<int, Map<String, dynamic>> build() {
    return {};
  }
}
