import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/goals/model/goal_checkin_source.dart';

void main() {
  test('a check-in source carries the words and the moment they were said', () {
    final source = GoalCheckInSource(
      entryId: 'audio-1',
      recordedAt: DateTime.utc(2026, 8, 18, 14, 20),
      text: 'Skipped the lunch walk.',
    );

    // The moment matters as much as the words: the agent quotes commitments
    // back by date, so this is the instant the user spoke — not the instant
    // the summary was written.
    expect(source.entryId, 'audio-1');
    expect(source.recordedAt, DateTime.utc(2026, 8, 18, 14, 20));
    expect(source.text, 'Skipped the lunch walk.');
  });
}
