import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/features/relationships/model/check_in_dictation_facts.dart';
import 'package:lotti/features/relationships/model/check_in_dictation_lexicon.dart';
import 'package:lotti/features/relationships/model/check_in_dictation_lexicon_en.dart';

CheckInDictationReading _read(String words) =>
    englishCheckInLexicon.read(normalizeCheckInDictation(words));

void main() {
  test('reads a clock, its meridiem and a 24-hour time', () {
    expect(_read('at 3 pm').clocks, [
      const CheckInClockMention(3, meridiem: CheckInMeridiem.pm),
    ]);
    expect(_read('around 7:45 a.m.').clocks, [
      const CheckInClockMention(7, minute: 45, meridiem: CheckInMeridiem.am),
    ]);
    expect(_read('at 08:30').clocks, [
      const CheckInClockMention(8, minute: 30, twentyFourHour: true),
    ]);
    expect(_read('at three pm').clocks, [
      const CheckInClockMention(3, meridiem: CheckInMeridiem.pm),
    ]);
    expect(_read('at midnight').clocks, [
      const CheckInClockMention(0, twentyFourHour: true),
    ]);
  });

  test('a range is one range, not two clocks', () {
    final reading = _read('between 10 and 11:30 am');
    expect(reading.clocks, isEmpty);
    expect(
      reading.ranges.single.start,
      const CheckInClockMention(
        10,
        meridiem: CheckInMeridiem.am,
      ),
    );
    expect(
      reading.ranges.single.end,
      const CheckInClockMention(
        11,
        minute: 30,
        meridiem: CheckInMeridiem.am,
      ),
    );
  });

  test('days and parts of the day', () {
    expect(_read('the day before yesterday').dayOffsets, {2});
    expect(_read('yesterday afternoon').dayOffsets, {1});
    expect(_read('yesterday afternoon').periods, {CheckInDayPeriod.afternoon});
    expect(_read('last night').dayOffsets, {1});
    expect(_read('last night').periods, {CheckInDayPeriod.evening});
    expect(_read('tonight').dayOffsets, {0});
    expect(_read('tomorrow').dayOffsets, {-1});
  });

  test('"an hour and a half" is one length, never also "an hour"', () {
    expect(_read('an hour and a half').durations, [
      const Duration(minutes: 90),
    ]);
  });

  test('a length that says when is read and set aside, not reread', () {
    // "an hour and a half ago" is claimed whole, so "an hour" is not read
    // from it either.
    expect(_read('an hour and a half ago').durations, isEmpty);
    expect(_read('every 2 hours').durations, isEmpty);
  });

  test('"video call" names one channel, and "a call" beside it another', () {
    expect(_read('a video call').channels, [CheckInInteractionType.videoCall]);
    expect(_read('a call, then video chatted').channels, [
      CheckInInteractionType.videoCall,
      CheckInInteractionType.call,
    ]);
  });
}
