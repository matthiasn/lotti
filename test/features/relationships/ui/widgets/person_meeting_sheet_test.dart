import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/calendar_pickers/design_system_date_picker_modal.dart';
import 'package:lotti/features/design_system/components/time_pickers/design_system_picker_wheels.dart';
import 'package:lotti/features/relationships/repository/person_timeline_repository.dart';
import 'package:lotti/features/relationships/state/check_in_duration_suggestions_controller.dart';
import 'package:lotti/features/relationships/ui/widgets/person_meeting_sheet.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

/// Serves a fixed ranking, so the duration sheet needs no database.
class _FixedSuggestions extends CheckInDurationSuggestionsController {
  @override
  Future<List<Duration>> build() async => const [
    Duration(minutes: 30),
    Duration(minutes: 90),
  ];
}

void main() {
  // Thursday 13 Aug 2026, 10:20: a new meeting starts Friday at 11:00.
  final now = DateTime(2026, 8, 13, 10, 20);
  final defaultStart = DateTime(2026, 8, 14, 11);
  late MockPersonTimelineRepository repository;
  late MockDomainLogger logger;

  final pip = RelationshipEntry(
    meta: Metadata(
      id: 'pip',
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now,
    ),
    data: RelationshipData(
      title: 'Commander Pip Frostbeak',
      nickname: 'Pip',
      status: RelationshipStatus.active(id: 's', createdAt: now, utcOffset: 0),
    ),
  );

  final planned =
      JournalEntity.event(
            meta: Metadata(
              id: 'meeting-1',
              createdAt: now,
              updatedAt: now,
              dateFrom: defaultStart,
              dateTo: defaultStart.add(const Duration(hours: 1)),
            ),
            data: const EventData(
              title: 'Meet Pip',
              stars: 0,
              status: EventStatus.planned,
            ),
          )
          as JournalEvent;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    repository = MockPersonTimelineRepository();
    logger = MockDomainLogger();
    when(
      () => logger.error(
        any<LogDomain>(),
        any<Object>(),
        stackTrace: any<StackTrace?>(named: 'stackTrace'),
        subDomain: any<String>(named: 'subDomain'),
        message: any<String>(named: 'message'),
      ),
    ).thenAnswer((_) async {});
  });

  void answer(Future<JournalEvent?> Function() result) => when(
    () => repository.createMeeting(
      person: any(named: 'person'),
      title: any(named: 'title'),
      start: any(named: 'start'),
      duration: any(named: 'duration'),
    ),
  ).thenAnswer((_) => result());

  ({String title, DateTime start, Duration duration}) saved() {
    final call = verify(
      () => repository.createMeeting(
        person: pip,
        title: captureAny(named: 'title'),
        start: captureAny(named: 'start'),
        duration: captureAny(named: 'duration'),
      ),
    ).captured;
    return (
      title: call[0] as String,
      start: call[1] as DateTime,
      duration: call[2] as Duration,
    );
  }

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Builder(
          builder: (context) => TextButton(
            key: const ValueKey('open'),
            onPressed: () =>
                showPersonMeetingSheet(context: context, person: pip),
            child: const Text('open'),
          ),
        ),
        overrides: [
          personTimelineRepositoryProvider.overrideWithValue(repository),
          domainLoggerProvider.overrideWithValue(logger),
          checkInDurationSuggestionsControllerProvider.overrideWith(
            _FixedSuggestions.new,
          ),
        ],
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pumpAndSettle();
  }

  Finder titleField() => find.descendant(
    of: find.byKey(const ValueKey('person-meeting-title')),
    matching: find.byType(EditableText),
  );

  DesignSystemButton save(WidgetTester tester) =>
      tester.widget(find.byKey(const ValueKey('person-meeting-save')));

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('person-meeting-save')));
    await tester.pumpAndSettle();
  }

  group('PersonMeetingForm.defaultStart', () {
    test('is tomorrow at the next full hour', () {
      expect(
        PersonMeetingForm.defaultStart(DateTime(2026, 8, 13, 10, 20)),
        DateTime(2026, 8, 14, 11),
      );
    });

    test('moves an hour already full on, so it is never now', () {
      expect(
        PersonMeetingForm.defaultStart(DateTime(2026, 8, 13, 10)),
        DateTime(2026, 8, 14, 11),
      );
    });

    test("late in the evening it is tomorrow's midnight, not a day "
        'further', () {
      expect(
        PersonMeetingForm.defaultStart(DateTime(2026, 8, 13, 23, 20)),
        DateTime(2026, 8, 14),
      );
    });
  });

  testWidgets('opens on "Meet Pip", tomorrow at the next hour, for an hour, '
      'and planning it writes exactly that and closes the sheet', (
    tester,
  ) async {
    answer(() async => planned);
    await withClock(Clock.fixed(now), () async {
      await open(tester);

      expect(find.text('Plan a meeting with Pip'), findsOneWidget);
      expect(find.text('Meet Pip'), findsOneWidget);
      expect(find.text('Fri 14 Aug · 11:00'), findsOneWidget);
      expect(find.text('1 h'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Starts: Fri 14 Aug · 11:00. Change'),
        findsOneWidget,
      );

      await tapSave(tester);
    });

    expect(saved(), (
      title: 'Meet Pip',
      start: defaultStart,
      duration: const Duration(hours: 1),
    ));
    expect(find.byType(PersonMeetingForm), findsNothing);
  });

  testWidgets('a blank title holds Plan meeting', (tester) async {
    await withClock(Clock.fixed(now), () async {
      await open(tester);
      expect(save(tester).onPressed, isNotNull);

      await tester.enterText(titleField(), '   ');
      await tester.pump();

      expect(save(tester).onPressed, isNull);
    });
  });

  testWidgets('submitting the title from the keyboard plans the meeting', (
    tester,
  ) async {
    answer(() async => planned);
    await withClock(Clock.fixed(now), () async {
      await open(tester);
      await tester.enterText(titleField(), 'Coffee with Pip');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
    });

    expect(saved().title, 'Coffee with Pip');
    expect(find.byType(PersonMeetingForm), findsNothing);
  });

  testWidgets('the start picker looks ahead from today and moves both the '
      'day and the time', (tester) async {
    answer(() async => planned);
    await withClock(Clock.fixed(now), () async {
      await open(tester);

      await tester.tap(find.byKey(const ValueKey('person-meeting-start')));
      await tester.pumpAndSettle();
      expect(find.text('Starts'), findsOneWidget);
      final calendar = tester.widget<DesignSystemCalendarPicker>(
        find.byType(DesignSystemCalendarPicker),
      );
      expect(calendar.firstDate, DateTime(2026, 8, 13));
      calendar.onDateChanged(DateTime(2026, 8, 16));
      // The action bar's Done rebuilds on the new day before it is read.
      await tester.pump();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      final wheel = tester.widget<DesignSystemTimeWheel>(
        find.byKey(const ValueKey('meeting-time-picker')),
      );
      expect(wheel.initialDateTime, DateTime(2026, 8, 16, 11));
      expect(wheel.semanticsLabel, 'Starts');
      wheel.onDateTimeChanged(DateTime(2026, 8, 16, 15, 30));
      await tester.tap(find.byKey(const ValueKey('check-in-time-done')));
      await tester.pumpAndSettle();

      expect(find.text('Sun 16 Aug · 15:30'), findsOneWidget);
      await tapSave(tester);
    });

    expect(saved().start, DateTime(2026, 8, 16, 15, 30));
  });

  testWidgets('a time today that has already passed moves to the next full '
      'hour — a planned meeting never lands in history', (tester) async {
    answer(() async => planned);
    await withClock(Clock.fixed(now), () async {
      await open(tester);

      await tester.tap(find.byKey(const ValueKey('person-meeting-start')));
      await tester.pumpAndSettle();
      tester
          .widget<DesignSystemCalendarPicker>(
            find.byType(DesignSystemCalendarPicker),
          )
          .onDateChanged(DateTime(2026, 8, 13));
      await tester.pump();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      tester
          .widget<DesignSystemTimeWheel>(
            find.byKey(const ValueKey('meeting-time-picker')),
          )
          .onDateTimeChanged(DateTime(2026, 8, 13, 8));
      await tester.tap(find.byKey(const ValueKey('check-in-time-done')));
      await tester.pumpAndSettle();

      expect(find.text('Thu 13 Aug · 11:00'), findsOneWidget);
      await tapSave(tester);
    });

    expect(saved().start, DateTime(2026, 8, 13, 11));
  });

  testWidgets('a dismissed time keeps the picked day at the old time', (
    tester,
  ) async {
    await withClock(Clock.fixed(now), () async {
      await open(tester);

      await tester.tap(find.byKey(const ValueKey('person-meeting-start')));
      await tester.pumpAndSettle();
      tester
          .widget<DesignSystemCalendarPicker>(
            find.byType(DesignSystemCalendarPicker),
          )
          .onDateChanged(DateTime(2026, 8, 16));
      await tester.pump();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('meeting-time-picker')),
        findsOneWidget,
      );
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.text('Sun 16 Aug · 11:00'), findsOneWidget);
    });
  });

  testWidgets('a dismissed day picker keeps the start', (tester) async {
    await withClock(Clock.fixed(now), () async {
      await open(tester);

      await tester.tap(find.byKey(const ValueKey('person-meeting-start')));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.byType(DesignSystemCalendarPicker), findsNothing);
      expect(find.text('Fri 14 Aug · 11:00'), findsOneWidget);
    });
  });

  testWidgets('the duration picker sets the length; Clear keeps the last '
      'one, since a meeting always runs for a while', (tester) async {
    answer(() async => planned);
    await withClock(Clock.fixed(now), () async {
      await open(tester);

      await tester.tap(find.byKey(const ValueKey('person-meeting-duration')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('check-in-duration-pick-90')));
      await tester.pumpAndSettle();
      expect(find.text('1 h 30'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('person-meeting-duration')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();
      expect(find.text('1 h 30'), findsOneWidget);

      await tapSave(tester);
    });

    expect(saved().duration, const Duration(minutes: 90));
  });

  testWidgets('a meeting that could not be planned keeps the sheet open and '
      'says so under the title; typing clears it', (tester) async {
    answer(() async => null);
    await withClock(Clock.fixed(now), () async {
      await open(tester);
      await tapSave(tester);

      expect(find.byType(PersonMeetingForm), findsOneWidget);
      expect(find.text('Could not plan the meeting.'), findsOneWidget);
      expect(save(tester).onPressed, isNotNull);

      await tester.enterText(titleField(), 'Coffee');
      await tester.pump();
      expect(find.text('Could not plan the meeting.'), findsNothing);
    });
  });

  testWidgets('a write that throws is logged and reads as a failed one', (
    tester,
  ) async {
    answer(() async => throw StateError('database locked'));
    await withClock(Clock.fixed(now), () async {
      await open(tester);
      await tapSave(tester);
    });

    expect(find.text('Could not plan the meeting.'), findsOneWidget);
    verify(
      () => logger.error(
        LogDomain.general,
        any<Object>(),
        stackTrace: any<StackTrace?>(named: 'stackTrace'),
        subDomain: 'PersonMeetingSheet',
        message: any<String>(named: 'message'),
      ),
    ).called(1);
  });

  testWidgets('while the meeting is being written the sheet holds: Cancel '
      'is off and the close keeps it open until the write lands', (
    tester,
  ) async {
    final write = Completer<JournalEvent?>();
    answer(() => write.future);
    await withClock(Clock.fixed(now), () async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('person-meeting-save')));
      await tester.pump();

      expect(
        tester
            .widget<DesignSystemButton>(
              find.byKey(const ValueKey('person-meeting-cancel')),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(PersonMeetingForm), findsOneWidget);

      write.complete(planned);
      await tester.pumpAndSettle();
    });

    expect(find.byType(PersonMeetingForm), findsNothing);
  });

  testWidgets('Cancel closes the sheet without writing', (tester) async {
    await withClock(Clock.fixed(now), () async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('person-meeting-cancel')));
      await tester.pumpAndSettle();
    });

    expect(find.byType(PersonMeetingForm), findsNothing);
    verifyNever(
      () => repository.createMeeting(
        person: any(named: 'person'),
        title: any(named: 'title'),
        start: any(named: 'start'),
        duration: any(named: 'duration'),
      ),
    );
  });
}
