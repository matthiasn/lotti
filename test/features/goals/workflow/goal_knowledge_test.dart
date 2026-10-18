import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/features/agents/knowledge/agent_knowledge.dart';
import 'package:lotti/features/ai/service/text_chunker.dart';
import 'package:lotti/features/goals/workflow/goal_knowledge.dart';

void main() {
  PlannerKnowledgeEntity fact(String key, {String? statement, String? hook}) =>
      AgentDomainEntity.plannerKnowledge(
            id: 'fact-$key',
            agentId: 'goal-agent',
            key: key,
            hook: hook ?? 'hook of $key',
            statementText: statement ?? 'statement of $key',
            source: KnowledgeSource.userStated,
            status: KnowledgeStatus.confirmed,
            createdAt: DateTime(2026, 10),
            updatedAt: DateTime(2026, 10),
            vectorClock: null,
          )
          as PlannerKnowledgeEntity;

  group('parseGoalFactRequest', () {
    test('reads a fact, trimmed', () {
      final parsed = parseGoalFactRequest({
        'key': ' walks-after-dinner ',
        'hook': 'Walks after dinner',
        'statement': ' I walk after dinner, never before. ',
        'source': 'userStated',
      });

      expect(parsed.error, isNull);
      expect(parsed.request!.key, 'walks-after-dinner');
      expect(parsed.request!.statement, 'I walk after dinner, never before.');
      expect(parsed.request!.source, KnowledgeSource.userStated);
    });

    test("a missing source is the model's inference, never the user's "
        'word', () {
      final parsed = parseGoalFactRequest({
        'key': 'k',
        'hook': 'h',
        'statement': 's',
      });

      expect(parsed.request!.source, KnowledgeSource.agentInferred);
    });

    test('explains what is wrong so the model can correct it', () {
      expect(
        parseGoalFactRequest({'key': 'k', 'hook': ' ', 'statement': 's'}).error,
        contains('"key", "hook" and "statement"'),
      );
      expect(
        parseGoalFactRequest({
          'key': 'k',
          'hook': 'x' * (knowledgeHookMaxLength + 1),
          'statement': 's',
        }).error,
        contains('at most $knowledgeHookMaxLength'),
      );
      expect(
        parseGoalFactRequest({
          'key': 'k',
          'hook': 'h',
          'statement': 's',
          'source': 'theUser',
        }).error,
        contains('"source"'),
      );
    });
  });

  group('goalFactIsUserConfirmed', () {
    final stated = parseGoalFactRequest({
      'key': 'k',
      'hook': 'h',
      'statement': 's',
      'source': 'userStated',
    }).request!;
    final inferred = parseGoalFactRequest({
      'key': 'k',
      'hook': 'h',
      'statement': 's',
      'source': 'agentInferred',
    }).request!;

    test('only what the user states in the message being answered is '
        'kept', () {
      expect(goalFactIsUserConfirmed(stated, answeringUser: true), isTrue);
      // A briefing reading a transcript: the model's word, not the user's.
      expect(goalFactIsUserConfirmed(stated, answeringUser: false), isFalse);
      expect(goalFactIsUserConfirmed(inferred, answeringUser: true), isFalse);
      expect(goalFactIsUserConfirmed(inferred, answeringUser: false), isFalse);
    });
  });

  group('goalKnowledgeFacts', () {
    test('is null for a goal with nothing confirmed', () {
      expect(goalKnowledgeFacts(const []), isNull);
    });

    test('lists facts whole, in key order, with the policy that bounds '
        'them', () {
      final facts = goalKnowledgeFacts([fact('zeta'), fact('alpha')])!;

      expect(facts['entries'], [
        {'key': 'alpha', 'fact': 'statement of alpha'},
        {'key': 'zeta', 'fact': 'statement of zeta'},
      ]);
      expect(facts['interpretationPolicy'], goalKnowledgeInterpretationPolicy);
      expect(facts.containsKey('omittedFacts'), isFalse);
    });

    test('past the budget a fact reads as its hook, and past even that it '
        'is counted', () {
      final long = List.filled(40, 'krill').join(' ');
      final budget =
          TextChunker.estimateTokens(long) + TextChunker.estimateTokens('h b');
      final facts = goalKnowledgeFacts([
        fact('a', statement: long),
        fact('b', statement: long, hook: 'h b'),
        fact('c', statement: long, hook: List.filled(20, 'colony').join(' ')),
      ], budget: budget)!;

      expect(facts['entries'], [
        {'key': 'a', 'fact': long},
        {'key': 'b', 'hook': 'h b'},
      ]);
      expect(facts['omittedFacts'], 1);
    });
  });
}
