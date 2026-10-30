import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/goals/service/goal_chat_history_service.dart';
import 'package:lotti/features/goals/workflow/goal_chat_check_ins.dart';

void main() {
  final at = DateTime(2026, 8, 12, 19, 30);

  GoalChatHistoryEntry turn(
    String id,
    String text, {
    GoalChatHistoryRole role = GoalChatHistoryRole.user,
  }) => (id: id, role: role, text: text, createdAt: at);

  group('goalChatCheckInSources', () {
    test('keeps the user turns with substance, keyed by message id', () {
      const substance =
          'The physio said no steep routes for two weeks, so the ridge '
          'scout moves to the shore path.';
      final sources = goalChatCheckInSources([
        turn('m1', substance),
        turn('m2', 'Thanks, that helps.'),
      ]);

      expect(sources, hasLength(1));
      expect(sources.single.entryId, 'm1');
      expect(sources.single.recordedAt, at);
      expect(sources.single.text, substance);
    });

    test('the threshold is the word count, inclusive', () {
      final eleven = List.filled(goalChatCheckInMinWords - 1, 'word').join(' ');
      expect(goalChatCheckInSources([turn('m1', eleven)]), isEmpty);
      expect(
        goalChatCheckInSources([turn('m2', '$eleven more')]).single.entryId,
        'm2',
      );
    });

    test("the agent's own replies are never the user's voice", () {
      expect(
        goalChatCheckInSources([
          turn(
            'r1',
            List.filled(goalChatCheckInMinWords * 2, 'reply').join(' '),
            role: GoalChatHistoryRole.assistant,
          ),
        ]),
        isEmpty,
      );
    });
  });

  test('goalMarkChatVoice marks only the entries distilled from chat', () {
    final marked = goalMarkChatVoice(
      [
        {'sourceEntryId': 'm1', 'whatHappened': 'Moved the scout.'},
        {'sourceEntryId': 'entry-1', 'whatHappened': 'Wrote ten minutes.'},
        {'span': '2026-07', 'digest': 'A month of entries.'},
      ],
      {'m1'},
    );

    expect(marked, [
      {
        'sourceEntryId': 'm1',
        'whatHappened': 'Moved the scout.',
        'via': 'chat',
      },
      {'sourceEntryId': 'entry-1', 'whatHappened': 'Wrote ten minutes.'},
      {'span': '2026-07', 'digest': 'A month of entries.'},
    ]);
  });
}
