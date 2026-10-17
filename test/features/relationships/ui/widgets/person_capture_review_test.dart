import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/features/design_system/components/calendar_pickers/design_system_date_picker_modal.dart';
import 'package:lotti/features/design_system/components/time_pickers/design_system_picker_wheels.dart';
import 'package:lotti/features/design_system/components/toggles/design_system_toggle.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/model/person_capture.dart';
import 'package:lotti/features/relationships/model/person_capture_flow.dart';
import 'package:lotti/features/relationships/state/check_in_duration_suggestions_controller.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_meta_summary_line.dart';
import 'package:lotti/features/relationships/ui/widgets/person_capture_review.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

class _FixedSuggestions extends CheckInDurationSuggestionsController {
  @override
  Future<List<Duration>> build() async => const [
    Duration(minutes: 30),
    Duration(minutes: 90),
  ];
}

void main() {
  // Thursday 13 Aug 2026, 14:05.
  final now = DateTime(2026, 8, 13, 14, 5);
  const checkIn = PersonCaptureCheckIn(
    interactionType: CheckInInteractionType.call,
    summary: 'Talked about the launch.',
    bringUp: 'The krill contract.',
    avoid: 'Pad 3.',
  );
  final meeting = PersonCaptureMeeting(
    title: 'Coffee',
    start: DateTime(2026, 8, 16, 15),
  );
  const task = PersonCaptureTask(title: 'Send the draft');
  const note = PersonCaptureNote(text: 'Collects sextants.');

  late List<(int, PersonCaptureItem)> edits;
  late List<int> toggles;

  setUp(() {
    edits = [];
    toggles = [];
  });

  Future<void> pump(
    WidgetTester tester, {
    List<PersonCaptureReviewItem>? items,
    bool enabled = true,
    String? error,
  }) async {
    setTestSurfaceSize(tester, const Size(500, 1600));
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        SingleChildScrollView(
          child: PersonCaptureReviewView(
            review: PersonCaptureReview(
              'audio-1',
              'Called Pip about the launch.',
              items ??
                  [
                    const PersonCaptureReviewItem(checkIn),
                    PersonCaptureReviewItem(meeting),
                    const PersonCaptureReviewItem(task),
                    const PersonCaptureReviewItem(note),
                  ],
            ),
            now: now,
            enabled: enabled,
            error: error,
            onToggle: toggles.add,
            onEdit: (index, item) => edits.add((index, item)),
          ),
        ),
        overrides: [
          checkInDurationSuggestionsControllerProvider.overrideWith(
            _FixedSuggestions.new,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder inCard(int index, Finder finder) => find.descendant(
    of: find.byKey(ValueKey('person-capture-item-$index')),
    matching: finder,
  );

  testWidgets('heads with what was heard, then a card per item: what it '
      'would be filed as, its words, and its facts', (tester) async {
    await pump(tester);

    expect(find.text("Here's what I heard"), findsOneWidget);
    expect(find.text('Called Pip about the launch.'), findsOneWidget);
    expect(inCard(0, find.text('Log as a check-in')), findsOneWidget);
    expect(inCard(0, find.text('Talked about the launch.')), findsOneWidget);
    expect(
      inCard(0, find.text('Next time, pay attention to: The krill contract.')),
      findsOneWidget,
    );
    expect(inCard(0, find.text('Better to avoid: Pad 3.')), findsOneWidget);
    expect(inCard(0, find.text('Call')), findsOneWidget);
    expect(inCard(0, find.text('Today')), findsOneWidget);
    expect(inCard(1, find.text('Plan a meeting')), findsOneWidget);
    expect(inCard(1, find.text('Sun 16 Aug · 15:00')), findsOneWidget);
    expect(inCard(1, find.text('1 h')), findsOneWidget);
    expect(inCard(2, find.text('Add a task')), findsOneWidget);
    expect(inCard(2, find.text('No due date')), findsOneWidget);
    expect(inCard(3, find.text('Keep as a note')), findsOneWidget);
    expect(inCard(3, find.byType(FactTag)), findsNothing);
  });

  testWidgets("the item's words lead, a size above the rest of its card", (
    tester,
  ) async {
    await pump(tester);
    final tokens = tester
        .element(find.byType(PersonCaptureReviewView))
        .designTokens;

    final words = tester.widget<Text>(
      inCard(0, find.byKey(const ValueKey('person-capture-item-words'))),
    );
    expect(
      words.style?.fontSize,
      tokens.typography.styles.body.bodyLarge.fontSize,
    );
    expect(words.style?.color, tokens.colors.text.highEmphasis);
  });

  testWidgets('a set-aside item steps down and its facts take no tap; its '
      'toggle is how it comes back', (tester) async {
    await pump(
      tester,
      items: const [PersonCaptureReviewItem(checkIn, accepted: false)],
    );
    final tokens = tester
        .element(find.byType(PersonCaptureReviewView))
        .designTokens;

    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('person-capture-item-words')),
          )
          .style
          ?.color,
      tokens.colors.text.lowEmphasis,
    );
    expect(
      tester
          .widget<FactTag>(
            find.byKey(const ValueKey('person-capture-check-in-type')),
          )
          .onTap,
      isNull,
    );
    await tester.tap(find.byKey(const ValueKey('person-capture-item-toggle')));
    expect(toggles, [0]);
  });

  testWidgets('while filing, nothing takes a tap', (tester) async {
    await pump(tester, enabled: false);

    expect(
      tester
          .widget<DesignSystemToggle>(
            inCard(0, find.byKey(const ValueKey('person-capture-item-toggle'))),
          )
          .enabled,
      isFalse,
    );
    expect(
      tester
          .widget<FactTag>(
            find.byKey(const ValueKey('person-capture-meeting-start')),
          )
          .onTap,
      isNull,
    );
  });

  testWidgets('a filing error is said under the cards', (tester) async {
    await pump(tester, error: 'Some items could not be filed.');
    expect(find.text('Some items could not be filed.'), findsOneWidget);
  });

  testWidgets("a check-in's kind, start and length open the composer's own "
      'pickers', (tester) async {
    await pump(tester, items: const [PersonCaptureReviewItem(checkIn)]);

    await tester.tap(
      find.byKey(const ValueKey('person-capture-check-in-type')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('check-in-type-inPerson')));
    await tester.pumpAndSettle();
    expect(
      (edits.last.$2 as PersonCaptureCheckIn).interactionType,
      CheckInInteractionType.inPerson,
    );

    await withClock(Clock.fixed(now), () async {
      await tester.tap(
        find.byKey(const ValueKey('person-capture-check-in-start')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      tester
          .widget<DesignSystemTimeWheel>(
            find.byKey(const ValueKey('check-in-time-picker')),
          )
          .onDateTimeChanged(DateTime(2026, 8, 13, 12, 40));
      await tester.tap(find.byKey(const ValueKey('check-in-time-done')));
      await tester.pumpAndSettle();
    });
    expect(
      (edits.last.$2 as PersonCaptureCheckIn).startedAt,
      DateTime(2026, 8, 13, 12, 40),
    );

    await tester.tap(
      find.byKey(const ValueKey('person-capture-check-in-duration')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('check-in-duration-pick-30')));
    await tester.pumpAndSettle();
    expect(
      (edits.last.$2 as PersonCaptureCheckIn).duration,
      const Duration(minutes: 30),
    );
    expect(edits.map((edit) => edit.$1), [0, 0, 0]);
  });

  testWidgets('a timed check-in shows its day and time; a dismissed picker '
      'changes nothing', (tester) async {
    await pump(
      tester,
      items: [
        PersonCaptureReviewItem(
          checkIn.copyWith(
            startedAt: DateTime(2026, 8, 12, 9),
            duration: const Duration(minutes: 20),
          ),
        ),
      ],
    );
    expect(find.text('Wed 12 Aug · 09:00'), findsOneWidget);
    expect(find.text('20 min'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('person-capture-check-in-type')),
    );
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('person-capture-check-in-start')),
    );
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(edits, isEmpty);
  });

  testWidgets("a meeting's start and length open the meeting sheet's "
      'pickers; a length of none is ignored', (tester) async {
    await pump(tester, items: [PersonCaptureReviewItem(meeting)]);

    await withClock(Clock.fixed(now), () async {
      await tester.tap(
        find.byKey(const ValueKey('person-capture-meeting-start')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      tester
          .widget<DesignSystemTimeWheel>(
            find.byKey(const ValueKey('meeting-time-picker')),
          )
          .onDateTimeChanged(DateTime(2026, 8, 16, 17));
      await tester.tap(find.byKey(const ValueKey('check-in-time-done')));
      await tester.pumpAndSettle();
    });
    expect(
      (edits.last.$2 as PersonCaptureMeeting).start,
      DateTime(2026, 8, 16, 17),
    );

    await tester.tap(
      find.byKey(const ValueKey('person-capture-meeting-duration')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('check-in-duration-pick-90')));
    await tester.pumpAndSettle();
    expect(
      (edits.last.$2 as PersonCaptureMeeting).duration,
      const Duration(minutes: 90),
    );

    await tester.tap(
      find.byKey(const ValueKey('person-capture-meeting-duration')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(edits, hasLength(2));
  });

  testWidgets('an untimed meeting shows the default slot', (tester) async {
    await pump(
      tester,
      items: const [
        PersonCaptureReviewItem(PersonCaptureMeeting(title: 'Walk')),
      ],
    );
    expect(find.text('Fri 14 Aug · 15:00'), findsOneWidget);
  });

  testWidgets("a task's due day is set from the calendar, and cleared", (
    tester,
  ) async {
    await pump(tester, items: const [PersonCaptureReviewItem(task)]);

    await withClock(Clock.fixed(now), () async {
      await tester.tap(find.byKey(const ValueKey('person-capture-task-due')));
      await tester.pumpAndSettle();
      tester
          .widget<DesignSystemCalendarPicker>(
            find.byType(DesignSystemCalendarPicker),
          )
          .onDateChanged(DateTime(2026, 8, 20));
      await tester.pump();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
    });
    expect((edits.last.$2 as PersonCaptureTask).due, DateTime(2026, 8, 20));
    expect((edits.last.$2 as PersonCaptureTask).title, 'Send the draft');

    await pump(
      tester,
      items: [
        PersonCaptureReviewItem(
          PersonCaptureTask(title: 'Send it', due: DateTime(2026, 8, 20)),
        ),
      ],
    );
    expect(find.text('Due Thu 20 Aug'), findsOneWidget);
    await withClock(Clock.fixed(now), () async {
      await tester.tap(find.byKey(const ValueKey('person-capture-task-due')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();
    });
    expect((edits.last.$2 as PersonCaptureTask).due, isNull);

    final before = edits.length;
    await withClock(Clock.fixed(now), () async {
      await tester.tap(find.byKey(const ValueKey('person-capture-task-due')));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
    });
    expect(edits, hasLength(before));
  });
}
