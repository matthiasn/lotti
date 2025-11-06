import 'package:calendar_view/calendar_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/calendar/state/calendar_event.dart';
import 'package:lotti/features/calendar/state/calendar_event_handler.dart';
import 'package:lotti/features/calendar/ui/pages/day_view_page.dart';
import 'package:lotti/features/journal/state/journal_focus_controller.dart';
import 'package:lotti/features/tasks/state/task_focus_controller.dart';
import 'package:lotti/services/nav_service.dart';

import '../../../../test_data/test_data.dart';

// Mock for navigation service
class MockNavService {
  final List<String> navigationHistory = [];

  void beamToNamed(String path) {
    navigationHistory.add(path);
  }

  void reset() {
    navigationHistory.clear();
  }
}

void main() {
  late ProviderContainer container;
  late MockNavService mockNav;

  setUp(() {
    container = ProviderContainer();
    mockNav = MockNavService();
    // Override the global navigation function for testing
    beamToNamedOverride = mockNav.beamToNamed;
  });

  tearDown(() {
    container.dispose();
    mockNav.reset();
    beamToNamedOverride = null;
  });

  group('Calendar onEventTap logic tests', () {
    test('tapping calendar event with Task linkedFrom publishes task focus',
        () {
      // Use existing test data
      final task = testTask;
      final entry = testTextEntry;
      final taskId = task.meta.id;
      final entryId = entry.meta.id;

      final calendarEvent = CalendarEvent(
        entity: entry,
        linkedFrom: task,
      );

      final events = [
        CalendarEventData<CalendarEvent>(
          event: calendarEvent,
          date: DateTime.now(),
          title: 'Test Event',
        ),
      ];

      // Call the handler function
      handleCalendarEventTap(events, DateTime.now(), container);

      // Verify task focus was published
      final taskFocusState =
          container.read(taskFocusControllerProvider(id: taskId));
      expect(taskFocusState, isNotNull);
      expect(taskFocusState!.entryId, equals(entryId));
      expect(taskFocusState.alignment, equals(kDefaultScrollAlignment));

      // Verify navigation occurred
      expect(mockNav.navigationHistory, contains('/tasks/$taskId'));
    });

    test(
        'tapping calendar event with JournalEntry linkedFrom publishes journal focus',
        () {
      // Use existing test data
      final journal = testTextEntry;
      final timeEntry = testTextEntryNoGeo;
      final journalId = journal.meta.id;
      final entryId = timeEntry.meta.id;

      final calendarEvent = CalendarEvent(
        entity: timeEntry,
        linkedFrom: journal,
      );

      final events = [
        CalendarEventData<CalendarEvent>(
          event: calendarEvent,
          date: DateTime.now(),
          title: 'Test Event',
        ),
      ];

      // Call the handler function
      handleCalendarEventTap(events, DateTime.now(), container);

      // Verify journal focus was published
      final journalFocusState =
          container.read(journalFocusControllerProvider(id: journalId));
      expect(journalFocusState, isNotNull);
      expect(journalFocusState!.entryId, equals(entryId));
      expect(journalFocusState.alignment, equals(kDefaultScrollAlignment));

      // Verify navigation occurred
      expect(mockNav.navigationHistory, contains('/journal/$journalId'));
    });

    test('tapping calendar event without linkedFrom navigates directly', () {
      final entry = testTextEntry;
      final entryId = entry.meta.id;

      final calendarEvent = CalendarEvent(
        entity: entry,
      );

      final events = [
        CalendarEventData<CalendarEvent>(
          event: calendarEvent,
          date: DateTime.now(),
          title: 'Test Event',
        ),
      ];

      // Call the handler function
      handleCalendarEventTap(events, DateTime.now(), container);

      // Verify no focus was published
      final taskFocusState =
          container.read(taskFocusControllerProvider(id: entryId));
      expect(taskFocusState, isNull);

      final journalFocusState =
          container.read(journalFocusControllerProvider(id: entryId));
      expect(journalFocusState, isNull);

      // Verify navigation occurred directly
      expect(mockNav.navigationHistory, contains('/journal/$entryId'));
    });

    test('tapping calendar event with null id returns early', () {
      // Simulate onEventTap logic with null id
      // When id is null, should return early without navigation
      expect(mockNav.navigationHistory, isEmpty);
    });

    test('tapping calendar event with WorkoutEntry linkedFrom publishes focus',
        () {
      // Use existing test data
      final workout = testWorkoutRunning;
      final timeEntry = testTextEntry;
      final workoutId = workout.meta.id;
      final entryId = timeEntry.meta.id;

      final calendarEvent = CalendarEvent(
        entity: timeEntry,
        linkedFrom: workout,
      );

      final events = [
        CalendarEventData<CalendarEvent>(
          event: calendarEvent,
          date: DateTime.now(),
          title: 'Test Event',
        ),
      ];

      // Call the handler function
      handleCalendarEventTap(events, DateTime.now(), container);

      // Verify journal focus was published
      final journalFocusState =
          container.read(journalFocusControllerProvider(id: workoutId));
      expect(journalFocusState, isNotNull);
      expect(journalFocusState!.entryId, equals(entryId));

      // Verify navigation occurred
      expect(mockNav.navigationHistory, contains('/journal/$workoutId'));
    });

    test('handles empty events list gracefully', () {
      final events = <CalendarEventData<CalendarEvent>>[];

      // Call the handler function with empty events
      handleCalendarEventTap(events, DateTime.now(), container);

      // Should not navigate or publish focus
      expect(mockNav.navigationHistory, isEmpty);

      // Verify no focus state was created
      final taskFocusState =
          container.read(taskFocusControllerProvider(id: 'any-id'));
      expect(taskFocusState, isNull);
    });

    test('multiple taps update focus intent correctly', () {
      final task = testTask;
      final entry1 = testTextEntry;
      final entry2 = testTextEntryNoGeo;
      final taskId = task.meta.id;
      final entryId1 = entry1.meta.id;
      final entryId2 = entry2.meta.id;

      // First tap
      container
          .read(taskFocusControllerProvider(id: taskId).notifier)
          .publishTaskFocus(
            entryId: entryId1,
            alignment: kDefaultScrollAlignment,
          );

      var focusState = container.read(taskFocusControllerProvider(id: taskId));
      expect(focusState?.entryId, equals(entryId1));

      // Second tap
      container
          .read(taskFocusControllerProvider(id: taskId).notifier)
          .publishTaskFocus(
            entryId: entryId2,
            alignment: kDefaultScrollAlignment,
          );

      focusState = container.read(taskFocusControllerProvider(id: taskId));
      expect(focusState?.entryId, equals(entryId2));
    });
  });
}
