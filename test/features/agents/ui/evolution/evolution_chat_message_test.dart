import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/evolution/evolution_chat_message.dart';
import 'package:lotti/features/agents/workflow/evolution_strategy.dart';

void main() {
  final testDate = DateTime(2024, 3, 15, 10, 30);

  group('EvolutionChatMessage', () {
    test('user variant holds text and timestamp', () {
      final msg = EvolutionChatMessage.user(
        text: 'Hello',
        timestamp: testDate,
      );
      expect(msg, isA<EvolutionUserMessage>());
      expect((msg as EvolutionUserMessage).text, 'Hello');
      expect(msg.timestamp, testDate);
    });

    test('assistant variant holds text and timestamp', () {
      final msg = EvolutionChatMessage.assistant(
        text: 'Hi there',
        timestamp: testDate,
      );
      expect(msg, isA<EvolutionAssistantMessage>());
      expect((msg as EvolutionAssistantMessage).text, 'Hi there');
      expect(msg.timestamp, testDate);
    });

    test('system variant holds text and timestamp', () {
      final msg = EvolutionChatMessage.system(
        text: 'Session started',
        timestamp: testDate,
      );
      expect(msg, isA<EvolutionSystemMessage>());
      expect((msg as EvolutionSystemMessage).text, 'Session started');
      expect(msg.timestamp, testDate);
    });

    test('proposal variant holds PendingProposal and timestamp', () {
      const proposal = PendingProposal(
        directives: 'New directives',
        rationale: 'Improved performance',
      );
      final msg = EvolutionChatMessage.proposal(
        proposal: proposal,
        timestamp: testDate,
      );
      expect(msg, isA<EvolutionProposalMessage>());
      final proposalMsg = msg as EvolutionProposalMessage;
      expect(proposalMsg.proposal.directives, 'New directives');
      expect(proposalMsg.proposal.rationale, 'Improved performance');
      expect(proposalMsg.timestamp, testDate);
    });

    test('variants are distinguished by switch expression', () {
      final messages = <EvolutionChatMessage>[
        EvolutionChatMessage.user(text: 'u', timestamp: testDate),
        EvolutionChatMessage.assistant(text: 'a', timestamp: testDate),
        EvolutionChatMessage.system(text: 's', timestamp: testDate),
        EvolutionChatMessage.proposal(
          proposal: const PendingProposal(
            directives: 'd',
            rationale: 'r',
          ),
          timestamp: testDate,
        ),
      ];

      final labels = messages.map((m) {
        return switch (m) {
          EvolutionUserMessage() => 'user',
          EvolutionAssistantMessage() => 'assistant',
          EvolutionSystemMessage() => 'system',
          EvolutionProposalMessage() => 'proposal',
          EvolutionSurfaceMessage() => 'surface',
        };
      }).toList();

      expect(labels, ['user', 'assistant', 'system', 'proposal']);
    });

    test('surface variant holds surfaceId and timestamp', () {
      final msg = EvolutionChatMessage.surface(
        surfaceId: 'surface-42',
        timestamp: testDate,
      );
      expect(msg, isA<EvolutionSurfaceMessage>());
      expect((msg as EvolutionSurfaceMessage).surfaceId, 'surface-42');
      expect(msg.timestamp, testDate);
    });

    test('equality works for identical variants', () {
      final a = EvolutionChatMessage.user(text: 'Hi', timestamp: testDate);
      final b = EvolutionChatMessage.user(text: 'Hi', timestamp: testDate);
      expect(a, equals(b));
    });

    test('inequality works for different variants', () {
      final a = EvolutionChatMessage.user(text: 'Hi', timestamp: testDate);
      final b = EvolutionChatMessage.assistant(text: 'Hi', timestamp: testDate);
      expect(a, isNot(equals(b)));
    });
  });
}
