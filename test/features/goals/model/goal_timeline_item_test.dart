import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/goals/model/goal_timeline_item.dart';

void main() {
  final start = DateTime(2026, 8, 18, 9);

  Metadata meta(String id, {required DateTime to}) => Metadata(
    id: id,
    createdAt: start,
    updatedAt: start,
    dateFrom: start,
    dateTo: to,
  );

  group('goalCheckInTimeSpent', () {
    test("is the entry's own span", () {
      final entry = JournalEntry(
        meta: meta('n', to: start.add(const Duration(minutes: 3, seconds: 20))),
        entryText: const EntryText(plainText: 'Walked.'),
      );
      expect(
        goalCheckInTimeSpent(entry),
        const Duration(minutes: 3, seconds: 20),
      );
    });

    test('a span stored backwards is no time, never negative', () {
      final entry = JournalEntry(
        meta: meta('n', to: start.subtract(const Duration(minutes: 2))),
        entryText: const EntryText(plainText: 'Walked.'),
      );
      expect(goalCheckInTimeSpent(entry), Duration.zero);
    });
  });

  test('spoken and written check-ins both report their span', () {
    final audio = JournalAudio(
      meta: meta('a', to: start.add(const Duration(seconds: 95))),
      data: AudioData(
        dateFrom: start,
        dateTo: start.add(const Duration(seconds: 95)),
        audioFile: 'a.m4a',
        audioDirectory: '/audio/',
        duration: const Duration(seconds: 95),
      ),
    );
    final text = JournalEntry(
      meta: meta('t', to: start.add(const Duration(minutes: 4))),
      entryText: const EntryText(plainText: 'Packed the gym bag.'),
    );

    final GoalCheckIn spoken = GoalAudioCheckIn(audio);
    final GoalCheckIn written = GoalTextCheckIn(text);

    expect(spoken.entity, same(audio));
    expect(spoken.timeSpent, const Duration(seconds: 95));
    expect(written.entity, same(text));
    expect(written.timeSpent, const Duration(minutes: 4));
  });
}
