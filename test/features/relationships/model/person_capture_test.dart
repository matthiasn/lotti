import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/features/relationships/model/person_capture.dart';

void main() {
  group('parsePersonCaptureLocalTime', () {
    test('reads a local wall-clock time, with or without seconds', () {
      expect(
        parsePersonCaptureLocalTime('2026-08-16T15:00'),
        DateTime(2026, 8, 16, 15),
      );
      expect(
        parsePersonCaptureLocalTime(' 2026-08-16T15:00:30 '),
        DateTime(2026, 8, 16, 15, 0, 30),
      );
    });

    test('refuses what would roll over, a zone, or anything else', () {
      for (final value in <Object?>[
        '2026-02-30T12:00',
        '2026-08-16T25:00',
        '2026-08-16T15:61',
        '2026-08-16T15:00Z',
        '2026-08-16T15:00+02:00',
        '2026-08-16',
        'Sunday at three',
        16,
        null,
      ]) {
        expect(parsePersonCaptureLocalTime(value), isNull, reason: '$value');
      }
    });
  });

  group('parsePersonCaptureDay', () {
    test('reads a calendar day at midnight', () {
      expect(parsePersonCaptureDay('2026-08-20'), DateTime(2026, 8, 20));
    });

    test('refuses a day that does not exist, or a time', () {
      for (final value in <Object?>[
        '2026-02-29',
        '2026-13-01',
        '2026-08-20T10:00',
        20260820,
      ]) {
        expect(parsePersonCaptureDay(value), isNull, reason: '$value');
      }
    });
  });

  group('parsePersonCaptureMinutes', () {
    test('reads whole minutes from one to twelve hours', () {
      expect(parsePersonCaptureMinutes(1), const Duration(minutes: 1));
      expect(parsePersonCaptureMinutes(45.0), const Duration(minutes: 45));
      expect(
        parsePersonCaptureMinutes(personCaptureMaxMinutes),
        const Duration(hours: 12),
      );
    });

    test('drops what is out of range or not whole', () {
      for (final value in <Object?>[0, -5, 721, 12.5, '30', null]) {
        expect(parsePersonCaptureMinutes(value), isNull, reason: '$value');
      }
    });
  });

  group('personMeetingDefaultStart', () {
    test('is tomorrow at the next full hour', () {
      expect(
        personMeetingDefaultStart(DateTime(2026, 8, 13, 10, 20)),
        DateTime(2026, 8, 14, 11),
      );
    });

    test('moves an hour already full on, so it is never now', () {
      expect(
        personMeetingDefaultStart(DateTime(2026, 8, 13, 10)),
        DateTime(2026, 8, 14, 11),
      );
    });

    test('nextFullHour is always ahead, across midnight', () {
      expect(
        nextFullHour(DateTime(2026, 8, 13, 14, 5)),
        DateTime(2026, 8, 13, 15),
      );
      expect(
        nextFullHour(DateTime(2026, 8, 13, 23, 20)),
        DateTime(2026, 8, 14),
      );
    });

    test("late in the evening it is tomorrow's midnight, not a day "
        'further', () {
      expect(
        personMeetingDefaultStart(DateTime(2026, 8, 13, 23, 20)),
        DateTime(2026, 8, 14),
      );
    });
  });

  test('copyWith moves only the fields the review edits', () {
    const checkIn = PersonCaptureCheckIn(
      interactionType: CheckInInteractionType.call,
      summary: 'Talked.',
      topics: ['launch'],
      bringUp: 'Krill.',
      avoid: 'Pad 3.',
    );
    final moved = checkIn.copyWith(
      interactionType: CheckInInteractionType.inPerson,
      startedAt: DateTime(2026, 8, 13, 9),
      duration: const Duration(minutes: 20),
    );
    expect(moved.interactionType, CheckInInteractionType.inPerson);
    expect(moved.startedAt, DateTime(2026, 8, 13, 9));
    expect(moved.duration, const Duration(minutes: 20));
    expect(moved.summary, 'Talked.');
    expect(moved.topics, ['launch']);
    expect(moved.bringUp, 'Krill.');
    expect(moved.avoid, 'Pad 3.');
    expect(checkIn.copyWith().interactionType, CheckInInteractionType.call);

    const meeting = PersonCaptureMeeting(title: 'Coffee');
    final planned = meeting.copyWith(
      start: DateTime(2026, 8, 16, 15),
      duration: const Duration(hours: 2),
    );
    expect(planned.title, 'Coffee');
    expect(planned.start, DateTime(2026, 8, 16, 15));
    expect(planned.duration, const Duration(hours: 2));
    expect(planned.copyWith().start, DateTime(2026, 8, 16, 15));
  });
}
