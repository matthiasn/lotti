import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/features/companion/model/companion_reaction.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_routing_index.dart';
import 'package:lotti/features/front_agent/workflow/front_agent_contract.dart';

void main() {
  test('six tools, never one, in a fixed order', () {
    // A single tool makes DeepSeek rewrite tool_choice; the list is fixed
    // so the request prefix stays byte-stable across turns.
    expect(frontAgentTools.map((t) => t.name), [
      FrontAgentToolNames.dispatch,
      FrontAgentToolNames.readTldr,
      FrontAgentToolNames.matchToCorpus,
      FrontAgentToolNames.listDueTasks,
      FrontAgentToolNames.askUser,
      FrontAgentToolNames.replyToUser,
    ]);
  });

  test('reply_to_user is the shared conversation tool name', () {
    expect(
      FrontAgentToolNames.replyToUser,
      AgentConversationToolNames.replyToUser,
    );
  });

  test("the dispatch schema enumerates exactly the model's kinds", () {
    final dispatch = frontAgentTools.first;
    final segments =
        (dispatch.parameters['properties'] as Map)['segments'] as Map;
    expect(segments['maxItems'], frontMaxSegments);
    final item = segments['items'] as Map;
    expect(
      item['required'],
      ['start', 'end', 'text', 'intent', 'destination', 'confidence'],
    );
    final properties = item['properties'] as Map;
    expect(
      (properties['intent'] as Map)['enum'],
      ['question', 'statement', 'instruction'],
    );
    final destination = (properties['destination'] as Map)['properties'] as Map;
    expect(
      (destination['kind'] as Map)['enum'],
      [for (final kind in FrontDestinationKind.values) kind.wireName],
    );
    expect((destination['newKind'] as Map)['enum'], [
      'task',
      'goal',
      'project',
    ]);
  });

  test('list_due_tasks asks for one window by the names the strategy reads, '
      'and the prompt tells today from overdue', () {
    final properties =
        frontAgentTools[3].parameters['properties'] as Map<String, Object?>;
    expect(
      (properties['which']! as Map)['enum'],
      [for (final window in FrontDueWindow.values) window.name],
    );
    expect(frontAgentTools[3].parameters['required'], ['which']);
    expect((properties['categoryIds']! as Map)['type'], 'array');
    expect(frontAgentSystemPrompt, contains('`today` for due today (never'));
    expect(frontAgentSystemPrompt, contains('`overdue` for overdue (never'));
    expect(frontAgentSystemPrompt, contains('pass its id in `categoryIds`'));
  });

  test("lookup caps and the per-turn budget are the plan's", () {
    expect(frontProviderCallsPerTurn, 3);
    expect(frontTldrReadsPerTurn, 1);
    expect(frontCorpusMatchesPerTurn, 1);
    expect(frontTldrIdsPerRead, 5);
    expect(frontAskUserMaxOptions, 3);
    expect(frontDueListsPerTurn, 1);
    expect(frontDueMaxDaysAhead, 7);
    final listDue = frontAgentTools[3];
    final daysAhead =
        (listDue.parameters['properties'] as Map)['daysAhead'] as Map;
    expect(daysAhead['minimum'], 0);
    expect(daysAhead['maximum'], frontDueMaxDaysAhead);
    final readTldr = frontAgentTools[1];
    expect(
      ((readTldr.parameters['properties'] as Map)['ids'] as Map)['maxItems'],
      frontTldrIdsPerRead,
    );
    final askUser = frontAgentTools[4];
    expect(
      ((askUser.parameters['properties'] as Map)['options'] as Map)['maxItems'],
      frontAskUserMaxOptions,
    );
  });

  test('the refusal strings name the cap they enforce', () {
    expect(frontTldrExhaustedAnswer, contains('$frontTldrReadsPerTurn used'));
    expect(
      frontCorpusMatchExhaustedAnswer,
      contains('$frontCorpusMatchesPerTurn used'),
    );
    expect(frontDueListExhaustedAnswer, contains('$frontDueListsPerTurn used'));
  });

  test('a question about what is due is hers, answered from the due list, '
      'never the day door', () {
    expect(frontAgentSystemPrompt, contains('call `list_due_tasks`'));
    expect(frontAgentSystemPrompt, contains('never say you cannot answer it'));
    expect(
      frontAgentSystemPrompt,
      contains('A question about what is due is not the day'),
    );
  });

  test('her own words name tasks and projects as links, never bare ids', () {
    expect(frontAgentSystemPrompt, contains('[title](lotti://task/<id>)'));
    expect(frontAgentSystemPrompt, contains('[title](lotti://project/<id>)'));
    expect(frontAgentSystemPrompt, contains('Never write a bare id'));
  });

  test('her manner follows the sass the user set, and never touches the '
      'routing', () {
    final manners = {
      for (final sass in CompanionSass.values)
        sass: frontAgentPersonality(sass),
    };
    expect(manners.values.toSet(), hasLength(CompanionSass.values.length));
    expect(manners[CompanionSass.warm], contains('never tease'));
    expect(manners[CompanionSass.cheeky], contains('light tease'));
    expect(manners[CompanionSass.sassy], contains('eye-roll'));
    for (final manner in manners.values) {
      expect(manner, startsWith('## Your manner'));
      expect(manner, contains('never changes where something is routed'));
      expect(manner, contains('may be read aloud'));
    }
    // The contract itself carries no tone, so its cached prefix holds.
    expect(frontAgentSystemPrompt, isNot(contains('## Your manner')));
  });

  test('the system prompt states the thresholds it expects the model to use '
      'and says nothing about tone', () {
    expect(frontAgentSystemPrompt, contains('>= $frontStrongConfidence'));
    expect(frontAgentSystemPrompt, contains('below `$frontLowConfidence`'));
    expect(
      frontAgentSystemPrompt,
      contains('At most $frontMaxSegments segments'),
    );
    expect(
      frontAgentSystemPrompt,
      contains('Closed tasks are not destinations'),
    );
    // A question no single owner holds is hers, answered from the journal;
    // an owner's question stays the owner's.
    expect(frontAgentSystemPrompt, contains('you answer it from the journal'));
    expect(
      frontAgentSystemPrompt,
      contains("You never answer an owner's question yourself"),
    );
    expect(
      frontAgentSystemPrompt,
      contains('keep any category the user names'),
    );
    expect(frontAgentSystemPrompt, contains('<routing_index>'));
    expect(frontAgentSystemPrompt, contains('<recent_turns>'));
    expect(frontAgentSystemPrompt, contains(frontPendingUserMessageHeader));
    for (final word in ['sass', 'cheeky', 'warm', 'grandma', 'personality']) {
      expect(frontAgentSystemPrompt.toLowerCase(), isNot(contains(word)));
    }
  });
}
