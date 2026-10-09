import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/features/relationships/model/check_in_dictation_facts.dart';
import 'package:lotti/features/relationships/model/check_in_dictation_lexicon.dart';
import 'package:lotti/features/relationships/model/check_in_dictation_lexicon_de.dart';

CheckInDictationReading _read(String words) =>
    germanCheckInLexicon.read(normalizeCheckInDictation(words));

void main() {
  test('reads "um", "Uhr" and the half and quarter hours', () {
    expect(_read('um 15 Uhr').clocks, [const CheckInClockMention(15)]);
    expect(_read('um 9:30').clocks, [
      const CheckInClockMention(9, minute: 30),
    ]);
    expect(_read('15 Uhr 30').clocks, [
      const CheckInClockMention(15, minute: 30),
    ]);
    expect(_read('um drei').clocks, [const CheckInClockMention(3)]);
    expect(_read('halb drei').clocks, [
      const CheckInClockMention(2, minute: 30),
    ]);
    expect(_read('halb eins').clocks, [
      const CheckInClockMention(12, minute: 30),
    ]);
    expect(_read('viertel nach vier').clocks, [
      const CheckInClockMention(4, minute: 15),
    ]);
    expect(_read('viertel vor zwölf').clocks, [
      const CheckInClockMention(11, minute: 45),
    ]);
    expect(_read('um Mitternacht').clocks, [
      const CheckInClockMention(0, twentyFourHour: true),
    ]);
  });

  test('a number of things is no clock', () {
    expect(_read('um 5 Minuten verspätet').clocks, isEmpty);
    expect(_read('um 3 Leute').clocks, isEmpty);
  });

  test('a range is one range', () {
    final reading = _read('zwischen 9 und 10:30 Uhr');
    expect(reading.clocks, isEmpty);
    expect(
      reading.ranges.single.end,
      const CheckInClockMention(
        10,
        minute: 30,
      ),
    );
  });

  test('"heute morgen" is this morning; "morgen" alone is tomorrow', () {
    expect(_read('heute morgen').dayOffsets, {0});
    expect(_read('heute morgen').periods, {CheckInDayPeriod.morning});
    expect(_read('gestern abend').dayOffsets, {1});
    expect(_read('gestern abend').periods, {CheckInDayPeriod.evening});
    expect(_read('vorgestern').dayOffsets, {2});
    expect(_read('morgen früh').dayOffsets, {-1});
    expect(_read('guten Morgen').dayOffsets, isEmpty);
  });

  test('lengths that say when are set aside', () {
    expect(_read('nach einer halben Stunde').durations, isEmpty);
    expect(_read('zehn Minuten zu spät').durations, isEmpty);
    expect(_read('eine Viertelstunde').durations, [
      const Duration(minutes: 15),
    ]);
  });

  test('"Videoanruf" names one channel, never also "Anruf"', () {
    expect(_read('ein Videoanruf').channels, [
      CheckInInteractionType.videoCall,
    ]);
    expect(_read('beim Mittagessen').channels, [
      CheckInInteractionType.inPerson,
    ]);
    expect(_read('am Telefon').channels, [CheckInInteractionType.call]);
  });
}
