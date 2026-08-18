import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/goals/logic/goal_user_voice.dart';
import 'package:lotti/features/goals/model/goal_checkin_summary.dart';

void main() {
  GoalCheckInSummary summary(
    String id,
    DateTime at, {
    String happened = 'Walked after lunch.',
    String? committed,
  }) => GoalCheckInSummary(
    id: id,
    sourceEntryId: 'entry-$id',
    recordedAt: at,
    whatHappened: happened,
    committedTo: committed,
  );

  final base = DateTime.utc(2026, 8, 18, 9);

  test('renders nothing when the user has said nothing', () {
    expect(goalUserVoiceEntries(const []), isEmpty);
  });

  test('reads toward the present — oldest first, newest last', () {
    final entries = goalUserVoiceEntries([
      summary('c', base.add(const Duration(hours: 2))),
      summary('a', base),
      summary('b', base.add(const Duration(hours: 1))),
    ]);

    expect(
      entries.map((e) => e['sourceEntryId']),
      ['entry-a', 'entry-b', 'entry-c'],
    );
  });

  test('keeps the date, which is what makes a commitment quotable', () {
    final entries = goalUserVoiceEntries([
      summary('a', base, committed: 'walk after lunch'),
    ]);

    // "You said on Tuesday you would walk after lunch" is only sayable if
    // both of these survive compaction.
    expect(entries.single['recordedAtLocal'], isNotNull);
    expect(entries.single['committedTo'], 'walk after lunch');
  });

  test('omits empty slots rather than emitting nulls into the prompt', () {
    final entries = goalUserVoiceEntries([summary('a', base)]);

    expect(entries.single.containsKey('committedTo'), isFalse);
    expect(entries.single.containsKey('blockers'), isFalse);
    expect(entries.single['whatHappened'], 'Walked after lunch.');
  });

  test('drops the oldest first when the budget binds', () {
    final long = List.filled(80, 'a rather long sentence about walking').join(
      ' ',
    );
    final entries = goalUserVoiceEntries([
      for (var i = 0; i < 6; i++)
        summary('s$i', base.add(Duration(hours: i)), happened: long),
    ], budget: 400);

    expect(entries.length, lessThan(6));
    // Whatever else falls away, the newest must not: a check-in recorded five
    // minutes ago is the one the agent most needs.
    expect(entries.last['sourceEntryId'], 'entry-s5');
  });

  test('the most recent survives even when it alone exceeds the budget', () {
    final huge = List.filled(400, 'words').join(' ');
    final entries = goalUserVoiceEntries([
      summary('old', base),
      summary('new', base.add(const Duration(hours: 1)), happened: huge),
    ], budget: 10);

    expect(entries, hasLength(1));
    expect(entries.single['sourceEntryId'], 'entry-new');
  });

  test('a larger budget never keeps less', () {
    final all = [
      for (var i = 0; i < 8; i++)
        summary('s$i', base.add(Duration(hours: i)), happened: 'a note here'),
    ];

    var previous = 0;
    for (final budget in [10, 50, 200, 1000, 5000]) {
      final kept = goalUserVoiceEntries(all, budget: budget).length;
      expect(kept, greaterThanOrEqualTo(previous));
      previous = kept;
    }
    expect(previous, 8);
  });

  test('the interpretation policy states what the voice may not do', () {
    // Without it, a model weighing "I felt great about it" against a measured
    // miss will sometimes pick the feeling.
    expect(
      goalUserVoiceInterpretationPolicy,
      contains('never override deterministic'),
    );
  });
}
