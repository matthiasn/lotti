import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/relationships/model/person_timeline.dart';

import '../../../test_data/test_data.dart';

void main() {
  // Thursday 15 October 2026, 18:00 on the device.
  final now = DateTime(2026, 10, 15, 18);

  Metadata meta(String id, DateTime at, {bool? starred}) => Metadata(
    id: id,
    createdAt: at,
    updatedAt: at,
    dateFrom: at,
    dateTo: at,
    starred: starred,
  );

  CheckInEntry checkIn(String id, DateTime at) => CheckInEntry(
    meta: meta(id, at),
    data: const CheckInData(
      relationshipId: 'pip',
      interactionType: CheckInInteractionType.call,
    ),
  );

  JournalEntity note(String id, DateTime at, {bool pinned = false}) =>
      JournalEntity.journalEntry(
        meta: meta(id, at, starred: pinned),
        entryText: EntryText(plainText: 'note $id'),
      );

  JournalEntity voice(String id, DateTime at) =>
      testAudioEntry.copyWith(meta: meta(id, at));

  JournalEntity photo(String id, DateTime at) =>
      testImageEntry.copyWith(meta: meta(id, at));

  JournalEntity meeting(
    String id,
    DateTime at, {
    EventStatus status = EventStatus.planned,
  }) => JournalEntity.event(
    meta: meta(id, at),
    data: EventData(title: 'Coffee', stars: 0, status: status),
  );

  Task task(
    String id,
    DateTime at, {
    DateTime? due,
    bool done = false,
    DateTime? closedAt,
  }) => testTask.copyWith(
    meta: meta(id, at),
    data: testTask.data.copyWith(
      due: due,
      status: done
          ? TaskStatus.done(id: 's', createdAt: closedAt ?? at, utcOffset: 0)
          : TaskStatus.open(id: 's', createdAt: at, utcOffset: 0),
    ),
  );

  /// Each section as `kind month: ids`, so a whole timeline compares as
  /// strings — records holding lists compare those lists by identity.
  String describe(PersonTimelineSection s) {
    final month = s.month == null ? '' : ' ${s.month!.year}-${s.month!.month}';
    return '${s.kind.name}$month: ${s.items.map((i) => i.id).join(', ')}';
  }

  List<String> shape(PersonTimeline timeline) =>
      timeline.sections.map(describe).toList();

  test('an empty person has an empty timeline', () {
    final timeline = buildPersonTimeline(
      now: now,
      checkIns: const [],
      entries: const [],
      tasks: const [],
    );

    expect(timeline.isEmpty, isTrue);
    expect(timeline.sections, isEmpty);
  });

  test('cuts the past into today, this week and calendar months, newest '
      'first, and puts what is ahead under upcoming, soonest first', () {
    final timeline = buildPersonTimeline(
      now: now,
      checkIns: [
        checkIn('today-call', DateTime(2026, 10, 15, 9)),
        checkIn('monday-call', DateTime(2026, 10, 12, 12)),
        checkIn('august-call', DateTime(2026, 8, 1, 12)),
      ],
      entries: [
        note('last-week-note', DateTime(2026, 10, 8, 8)),
        note('early-oct-note', DateTime(2026, 10, 2, 8)),
        meeting('sunday-coffee', DateTime(2026, 10, 18, 15)),
        meeting('next-month', DateTime(2026, 11, 2, 10)),
      ],
      tasks: [
        task(
          'send-draft',
          DateTime(2026, 10),
          due: DateTime(2026, 10, 16),
        ),
      ],
    );

    expect(shape(timeline), [
      'upcoming: send-draft, sunday-coffee, next-month',
      'today: today-call',
      'thisWeek: monday-call',
      'month 2026-10: last-week-note, early-oct-note',
      'month 2026-8: august-call',
    ]);
  });

  test('a day exactly a week ago is no longer this week', () {
    final timeline = buildPersonTimeline(
      now: now,
      checkIns: [
        checkIn('six-days', DateTime(2026, 10, 9, 23, 59)),
        checkIn('seven-days', DateTime(2026, 10, 8)),
      ],
      entries: const [],
      tasks: const [],
    );

    expect(shape(timeline), [
      'thisWeek: six-days',
      'month 2026-10: seven-days',
    ]);
  });

  test(
    'an overdue open task stays upcoming; a done task, a task without a '
    'due date, a meeting already started and a cancelled meeting are past',
    () {
      final timeline = buildPersonTimeline(
        now: now,
        checkIns: const [],
        entries: [
          meeting('started', DateTime(2026, 10, 15, 17)),
          meeting(
            'cancelled',
            DateTime(2026, 10, 20, 15),
            status: EventStatus.cancelled,
          ),
        ],
        tasks: [
          task('overdue', DateTime(2026, 9), due: DateTime(2026, 10)),
          task(
            'done',
            DateTime(2026, 10, 14),
            due: DateTime(2026, 10, 20),
            done: true,
          ),
          task('no-due', DateTime(2026, 10, 14)),
        ],
      );

      final upcoming = timeline.sections.first;
      expect(upcoming.kind, PersonTimelineSectionKind.upcoming);
      expect([for (final i in upcoming.items) i.id], ['overdue']);
      final past = [
        for (final s in timeline.sections.skip(1))
          for (final i in s.items) i.id,
      ];
      expect(past, containsAll(['started', 'cancelled', 'done', 'no-due']));
    },
  );

  test('a done task sits at when it was closed — the moment its row reports '
      '— an open one at its due date, or when it was written', () {
    final written = DateTime(2026, 10);
    final due = DateTime(2026, 10, 30);
    final closed = DateTime(2026, 10, 14, 11, 20);
    expect(TimelineTask(task('t', written, due: due)).at, due);
    expect(TimelineTask(task('t', written)).at, written);
    expect(
      TimelineTask(
        task('t', written, due: due, done: true, closedAt: closed),
      ).at,
      closed,
    );
  });

  test('a meeting called off before it came sits under its own month, not '
      'under Today — Today is only today', () {
    final timeline = buildPersonTimeline(
      now: now,
      checkIns: [checkIn('today-call', DateTime(2026, 10, 15, 9))],
      entries: [
        meeting(
          'off-next-week',
          DateTime(2026, 10, 22, 15),
          status: EventStatus.cancelled,
        ),
        meeting(
          'off-next-month',
          DateTime(2026, 11, 5, 15),
          status: EventStatus.cancelled,
        ),
      ],
      tasks: const [],
    );

    expect(shape(timeline), [
      'month 2026-11: off-next-month',
      'month 2026-10: off-next-week',
      'today: today-call',
    ]);
  });

  test("photos taken on one day become one row, newest first; another day's "
      'photos another row', () {
    final timeline = buildPersonTimeline(
      now: now,
      checkIns: const [],
      entries: [
        photo('morning', DateTime(2026, 10, 2, 9)),
        photo('evening', DateTime(2026, 10, 2, 21)),
        photo('next-day', DateTime(2026, 10, 3, 9)),
      ],
      tasks: const [],
    );

    final rows = timeline.sections.single.items.cast<TimelinePhotos>();
    expect(
      [for (final r in rows) r.photos.map((p) => p.id).toList()],
      [
        ['next-day'],
        ['evening', 'morning'],
      ],
    );
    expect(timeline.itemCount, 2);
  });

  test('pinned notes go under About, newest first, and are not repeated on '
      'the timeline', () {
    final timeline = buildPersonTimeline(
      now: now,
      checkIns: const [],
      entries: [
        note('where-we-met', DateTime(2026), pinned: true),
        note('gift-idea', DateTime(2026, 9), pinned: true),
        note('loose-thought', DateTime(2026, 10)),
      ],
      tasks: const [],
    );

    expect(
      [for (final n in timeline.pinned) n.id],
      [
        'gift-idea',
        'where-we-met',
      ],
    );
    expect(
      [
        for (final s in timeline.sections)
          for (final i in s.items) i.id,
      ],
      ['loose-thought'],
    );
    expect(timeline.isEmpty, isFalse);
  });

  test('a check-in carries what it holds', () {
    final timeline = buildPersonTimeline(
      now: now,
      checkIns: [checkIn('call', DateTime(2026, 10, 15, 9))],
      entries: const [],
      tasks: const [],
      checkInEntries: {
        'call': [voice('take', DateTime(2026, 10, 15, 9, 5))],
      },
    );

    final row = timeline.sections.single.items.single as TimelineCheckIn;
    expect(row.entries.map((e) => e.id), ['take']);
  });

  group('filters', () {
    // Enough rows that the filters are offered, and so apply.
    final rows = (
      checkIns: [
        checkIn('call', DateTime(2026, 10, 14)),
        checkIn('call-2', DateTime(2026, 9, 2)),
        checkIn('call-3', DateTime(2026, 8, 3)),
      ],
      entries: <JournalEntity>[
        note('note', DateTime(2026, 10, 13)),
        voice('voice', DateTime(2026, 10, 12)),
        photo('photo', DateTime(2026, 10, 11)),
        meeting('coffee', DateTime(2026, 10, 18)),
      ],
      tasks: [task('task', DateTime(2026, 10, 10))],
    );

    final cases = {
      PersonTimelineFilter.all: {
        'call',
        'call-2',
        'call-3',
        'note',
        'voice',
        'photo',
        'coffee',
        'task',
      },
      PersonTimelineFilter.checkIns: {'call', 'call-2', 'call-3'},
      PersonTimelineFilter.notes: {'note', 'voice'},
      PersonTimelineFilter.tasks: {'task'},
      PersonTimelineFilter.photos: {'photo'},
      PersonTimelineFilter.meetings: {'coffee'},
    };

    for (final MapEntry(key: filter, value: expected) in cases.entries) {
      test('${filter.name} shows ${expected.join(', ')}', () {
        final timeline = buildPersonTimeline(
          now: now,
          checkIns: rows.checkIns,
          entries: rows.entries,
          tasks: rows.tasks,
          filter: filter,
        );

        expect({
          for (final s in timeline.sections)
            for (final i in s.items) i.id,
        }, expected);
        // The count is the unfiltered timeline's, so the filter bar does not
        // vanish under the user once a narrow filter is on.
        expect(timeline.itemCount, 8);
      });
    }
  });

  test('a filter holds only while there is enough to filter: below that the '
      'whole history shows, so no hidden filter can strand the reader', () {
    final timeline = buildPersonTimeline(
      now: now,
      checkIns: [checkIn('call', DateTime(2026, 10, 14))],
      entries: [note('note', DateTime(2026, 10, 13))],
      tasks: const [],
      filter: PersonTimelineFilter.photos,
    );

    expect(timeline.itemCount, lessThan(personTimelineFiltersFrom));
    expect(shape(timeline), ['thisWeek: call, note']);
  });
}
