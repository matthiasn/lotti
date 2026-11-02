import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/front_agent/model/front_chat_thread.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_door.dart';
import 'package:lotti/features/front_agent/state/front_voice_providers.dart';

void main() {
  test("her voice in a conversation is that conversation's own", () {
    expect(frontVoiceSourceId('c-1'), 'front-chat:c-1');
    expect(frontVoiceSourceId('c-1'), isNot(frontVoiceSourceId('c-2')));
  });

  test('a spoken turn is marked with its conversation and moment, and '
      'settles', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final at = DateTime(2026, 10, 31, 9);

    expect(container.read(frontSpokenTurnProvider), isNull);
    withClock(Clock.fixed(at), () {
      container.read(frontSpokenTurnProvider.notifier).spoke('c-1');
    });
    expect(container.read(frontSpokenTurnProvider), (
      conversationId: 'c-1',
      spokenAt: at,
    ));

    container.read(frontSpokenTurnProvider.notifier).settle();
    expect(container.read(frontSpokenTurnProvider), isNull);
  });

  group('frontSpokenAnswer', () {
    final at = DateTime(2026, 10, 31, 9);
    const turnId = 'u-1';
    final turn = (conversationId: 'c-1', spokenAt: at);

    AgentChatMessage message(String id, AgentChatRole role, String text) =>
        AgentChatMessage(
          id: id,
          role: role,
          text: text,
          createdAt: at.add(const Duration(seconds: 1)),
        );

    FrontDoorEntry door(
      FrontDoorOutcome? outcome, {
      FrontDoorStatus status = FrontDoorStatus.done,
      String? specialistReply,
    }) => FrontDoorEntry(
      doorId: 'door-${outcome.runtimeType}',
      record: FrontDoorRecord(
        segmentIndex: 0,
        text: 'What did I do in October?',
        kind: FrontDestinationKind.journal,
        status: status,
        claimedAt: at,
        outcome: outcome,
      ),
      specialistReply: specialistReply,
    );

    FrontDoorAnswer answer(String text, {bool private = false}) =>
        FrontDoorAnswer(
          text: text,
          summaryBased: false,
          incomplete: false,
          fromJournal: true,
          private: private,
        );

    FrontChatThread thread({
      String? reply,
      List<FrontDoorEntry> doors = const [],
    }) => FrontChatThread(
      messages: [
        message(turnId, AgentChatRole.user, 'What did I do in October?'),
        if (reply != null) message('a-1', AgentChatRole.agent, reply),
      ],
      doorsByMessageId: {if (doors.isNotEmpty) turnId: doors},
    );

    test('nothing has landed while the turn has no reply and no door', () {
      expect(frontSpokenAnswer(thread(), turn).landed, isFalse);
    });

    test('a journal answer in a door is said, though she wrote no reply, '
        'with its citation numbers left out', () {
      final spoken = frontSpokenAnswer(
        thread(doors: [door(answer('You fixed the feeder [1] twice [2].'))]),
        turn,
      );
      expect(spoken.landed, isTrue);
      expect(spoken.text, 'You fixed the feeder twice.');
    });

    test('a task she links is said by its title, and Markdown as its '
        'words', () {
      final spoken = frontSpokenAnswer(
        thread(
          reply:
              'Due today:\n- [Feed the penguins](lotti://task/t-1)\n'
              '- **Count** the rookery',
        ),
        turn,
      );
      expect(spoken.landed, isTrue);
      expect(spoken.text, 'Due today:\nFeed the penguins\nCount the rookery');
    });

    test('her reply comes first, then the answers of her doors', () {
      final spoken = frontSpokenAnswer(
        thread(
          reply: 'Let me look.',
          doors: [door(answer('Three tasks.'))],
        ),
        turn,
      );
      expect(spoken.text, 'Let me look.\n\nThree tasks.');
    });

    test('waits while a door is still being walked', () {
      final spoken = frontSpokenAnswer(
        thread(
          reply: 'Let me look.',
          doors: [door(null, status: FrontDoorStatus.claimed)],
        ),
        turn,
      );
      expect(spoken.landed, isFalse);
    });

    test('an answer shown only with private entries is not said aloud', () {
      final spoken = frontSpokenAnswer(
        thread(doors: [door(answer('A secret.', private: true))]),
        turn,
      );
      expect(spoken.landed, isTrue);
      expect(spoken.text, isEmpty);
    });

    test("a specialist's mirrored reply is said; a door with nothing to "
        'say is silent', () {
      final spoken = frontSpokenAnswer(
        thread(
          doors: [
            door(
              const FrontDoorSkipped(FrontDoorSkipReason.inferenceUnavailable),
            ),
            door(null, specialistReply: 'Pip says Friday works.'),
          ],
        ),
        turn,
      );
      expect(spoken.landed, isTrue);
      expect(spoken.text, 'Pip says Friday works.');
    });

    test('waits for a goal or person the words were handed to: that door '
        'is done before they reply', () {
      const handed = FrontDoorChatTurn(
        specialistAgentId: 'goal-1',
        specialistMessageId: 'm-1',
      );
      final waiting = frontSpokenAnswer(
        thread(reply: 'Asking your goal.', doors: [door(handed)]),
        turn,
      );
      expect(waiting.landed, isFalse);

      final replied = frontSpokenAnswer(
        thread(
          reply: 'Asking your goal.',
          doors: [door(handed, specialistReply: 'Two runs left this week.')],
        ),
        turn,
      );
      expect(replied.landed, isTrue);
      expect(replied.text, 'Asking your goal.\n\nTwo runs left this week.');
    });

    test('a reply from before the turn is not its answer', () {
      final old = FrontChatThread(
        messages: [
          AgentChatMessage(
            id: 'a-0',
            role: AgentChatRole.agent,
            text: 'Earlier.',
            createdAt: at.subtract(const Duration(days: 1)),
          ),
        ],
      );
      expect(frontSpokenAnswer(old, turn).landed, isFalse);
    });
  });
}
