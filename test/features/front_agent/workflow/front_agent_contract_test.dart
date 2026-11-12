import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/features/companion/model/companion_reaction.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_pull_requests.dart';
import 'package:lotti/features/front_agent/model/front_routing_index.dart';
import 'package:lotti/features/front_agent/workflow/front_agent_contract.dart';
import 'package:lotti/features/front_agent/workflow/front_reply_reader.dart';
import 'package:lotti/features/front_agent/workflow/front_reply_stream.dart';

void main() {
  test(
    'ten tools, never one, in a fixed order; her answer is not one of them',
    () {
      // A single tool makes DeepSeek rewrite tool_choice; the list is fixed
      // so the request prefix stays byte-stable across turns.
      expect(frontAgentTools.map((t) => t.name), [
        FrontAgentToolNames.dispatch,
        FrontAgentToolNames.readTldr,
        FrontAgentToolNames.matchToCorpus,
        FrontAgentToolNames.listDueTasks,
        FrontAgentToolNames.summarizeLoggedTime,
        FrontAgentToolNames.listClosedTasks,
        FrontAgentToolNames.summarizePullRequests,
        FrontAgentToolNames.findPullRequests,
        FrontAgentToolNames.readPullRequests,
        FrontAgentToolNames.askUser,
      ]);
    },
  );

  test('a stored answer keeps the shared reply record name', () {
    expect(
      FrontAgentToolNames.replyToUser,
      AgentConversationToolNames.replyToUser,
    );
  });

  test('the prompt has her answer as the message she writes: UI first, '
      'prose always, cards by id', () {
    expect(frontAgentSystemPrompt, contains('never a tool call'));
    expect(
      frontAgentSystemPrompt,
      contains('The prose is required in every answer'),
    );
    expect(frontAgentSystemPrompt, contains('never by title'));
    expect(
      frontAgentSystemPrompt,
      contains('overdue and due as two `TaskCards`'),
    );
    expect(frontAgentSystemPrompt, contains("each task's time in `notes`"));
    expect(
      frontAgentSystemPrompt,
      contains('up to $frontQuickRepliesMax short replies the user can tap'),
    );
    expect(frontAgentSystemPrompt, contains('never read aloud'));
    expect(frontAgentSystemPrompt, isNot(contains('reply_to_user')));
    expect(frontDispatchRepairInstruction, contains('write your answer now'));
    // A turn that looked something up is asked for its answer; one that has
    // not is asked to route.
    expect(
      frontContinuationInstruction(answerLookups: 1, rejectedDispatches: 0),
      frontAnswerInstruction,
    );
    expect(
      frontContinuationInstruction(answerLookups: 0, rejectedDispatches: 0),
      frontDispatchRepairInstruction,
    );
    // A rejected dispatch meant to route: it is repaired even after a
    // lookup, never told not to dispatch.
    expect(
      frontContinuationInstruction(answerLookups: 1, rejectedDispatches: 1),
      frontDispatchRepairInstruction,
    );
    expect(frontAnswerInstruction, contains('Do not dispatch'));
  });

  test('the system message is the contract, then how to write UI, then her '
      'manner last, so only the tail changes with her setting', () {
    final warm = frontAgentSystemMessage(CompanionSass.warm);
    final sassy = frontAgentSystemMessage(CompanionSass.sassy);

    final contract = warm.indexOf(frontAgentSystemPrompt);
    final snippet = warm.indexOf(frontReplyPromptSnippet);
    final manner = warm.indexOf(frontAgentPersonality(CompanionSass.warm));
    expect(contract, 0);
    expect(snippet, greaterThan(contract));
    expect(manner, greaterThan(snippet));
    expect(warm, endsWith(frontAgentPersonality(CompanionSass.warm)));
    // The cached prefix is the same whatever her manner.
    expect(sassy.substring(0, manner), warm.substring(0, manner));
    expect(warm, contains('## Writing UI'));
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

  test('summarize_logged_time asks for a period by the names the strategy '
      'reads, the past N days up to the cap, or a first and last day, and the '
      'prompt sends a time question there, never to a door', () {
    final summarize = frontAgentTools[4];
    final properties = summarize.parameters['properties'] as Map;
    expect(
      (properties['period'] as Map)['enum'],
      [for (final period in FrontTimePeriod.values) period.wireName],
    );
    expect((properties['pastDays'] as Map)['maximum'], frontLoggedTimeMaxDays);
    expect((properties['from'] as Map)['type'], 'string');
    expect((properties['through'] as Map)['type'], 'string');
    // The task list is opt-in: a summary is the default answer.
    expect((properties['tasks'] as Map)['type'], 'boolean');
    // Picked before the cap, so the project or task asked about is listed.
    expect((properties['projectId'] as Map)['type'], 'string');
    expect((properties['taskId'] as Map)['type'], 'string');
    expect(frontAgentSystemPrompt, contains('with `projectId` for a project'));
    // Exactly one window form, checked by the strategy, so none required.
    expect(summarize.parameters.containsKey('required'), isFalse);
    expect(frontAgentSystemPrompt, contains('call `summarize_logged_time`'));
    expect(
      frontAgentSystemPrompt,
      contains('"what did I work on?" alone is answered with the summary'),
    );
    expect(frontAgentSystemPrompt, contains('read aloud in under thirty'));
    expect(
      frontAgentSystemPrompt,
      contains('end by offering to break them down'),
    );
    expect(
      frontAgentSystemPrompt,
      isNot(contains('list every task the summary gives')),
    );
    expect(frontAgentSystemPrompt, contains('at most 366 days'));
    expect(
      frontAgentSystemPrompt,
      isNot(contains('say which periods you can sum')),
    );
    expect(
      frontAgentSystemPrompt,
      contains('"the past month" is `past_30_days`'),
    );
    expect(frontTimeSummariesPerTurn, 1);
    expect(
      frontTimeSummaryExhaustedAnswer,
      contains('$frontTimeSummariesPerTurn used'),
    );
  });

  test('list_closed_tasks asks for a period by the names the strategy reads '
      'or the days themselves, and the prompt sends a what-did-I-complete '
      'question there, by when the task closed, its tasks left to the '
      'cards', () {
    final list = frontAgentTools[5];
    final properties = list.parameters['properties'] as Map;
    expect(
      (properties['period'] as Map)['enum'],
      [for (final period in FrontTimePeriod.values) period.wireName],
    );
    expect((properties['categoryIds'] as Map)['type'], 'array');
    expect((properties['pastDays'] as Map)['type'], 'integer');
    expect((properties['from'] as Map)['type'], 'string');
    expect((properties['through'] as Map)['type'], 'string');
    // Exactly one window form, checked by the strategy, so none required.
    expect(list.parameters.containsKey('required'), isFalse);
    expect(frontAgentSystemPrompt, contains('call `list_closed_tasks`'));
    expect(frontAgentSystemPrompt, contains('"closed" asks for both'));
    expect(
      frontAgentSystemPrompt,
      contains('never list, link or name the tasks yourself'),
    );
    expect(
      frontAgentSystemPrompt,
      contains('never the day it was created'),
    );
    expect(frontClosedListsPerTurn, 1);
    expect(
      frontClosedListExhaustedAnswer,
      contains('$frontClosedListsPerTurn used'),
    );
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
    final askUser = frontAgentTools[9];
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
    expect(
      frontPullRequestSummaryExhaustedAnswer,
      contains('$frontPullRequestSummariesPerTurn used'),
    );
  });

  test('summarize_pull_requests offers the periods, the past N days up to '
      'the cap, and a first and last day, none of them required', () {
    final tool = frontAgentTools.singleWhere(
      (t) => t.name == FrontAgentToolNames.summarizePullRequests,
    );
    final properties = tool.parameters['properties'] as Map;
    expect((properties['period'] as Map)['enum'], [
      for (final period in FrontTimePeriod.values) period.wireName,
    ]);
    expect((properties['pastDays'] as Map)['maximum'], frontPullRequestMaxDays);
    expect(properties.keys, containsAll(['from', 'through']));
    expect(tool.parameters.containsKey('required'), isFalse);
    expect(frontAgentSystemPrompt, contains('call `summarize_pull_requests`'));
    expect(frontAgentSystemPrompt, contains('at most 31 days'));
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

  test('a new task the user put in no category gets the one the work and '
      'the conversation point to, named in her reply', () {
    expect(
      frontAgentSystemPrompt,
      contains(
        'the categories of <conversation_tasks> and what '
        '<recent_turns> were about',
      ),
    );
    expect(
      frontAgentSystemPrompt,
      contains('left out only when the evidence points two ways or nowhere'),
    );
    expect(
      frontAgentSystemPrompt,
      contains(
        'the category by name when you chose it without the user '
        'naming it',
      ),
    );
    expect(
      frontAgentSystemPrompt,
      isNot(contains('left out when unsure')),
    );
  });

  test('what the user says about a task they ask for stays in its one '
      'segment, even as a sentence of its own', () {
    expect(
      frontAgentSystemPrompt,
      contains(
        'is part of that one segment even when it is a sentence of its own',
      ),
    );
    expect(
      frontAgentSystemPrompt,
      contains('never a segment or a task of its own'),
    );
  });

  test('in progress is a status that starts no timer; only a start the '
      'user asks for or names starts one', () {
    expect(
      frontAgentSystemPrompt,
      contains('a status, which starts no timer'),
    );
    expect(
      frontAgentSystemPrompt,
      contains(
        '"make it in progress" alone is `inProgress`, never '
        '`startedMinutesAgo`',
      ),
    );
    final task =
        ((((frontAgentTools.first.parameters['properties'] as Map)['segments']
                        as Map)['items']
                    as Map)['properties']
                as Map)['task']
            as Map;
    final fields = task['properties'] as Map;
    expect((fields['inProgress'] as Map)['type'], 'boolean');
    expect(
      (fields['startedMinutesAgo'] as Map)['description'],
      contains('Starts a timer.'),
    );
  });

  test('dates are written as the tools give them, and a misheard name '
      'as listed', () {
    expect(frontAgentSystemPrompt, contains('`YYYY-MM-DD`'));
    expect(
      frontAgentSystemPrompt,
      contains('write its name exactly as listed, never as it was heard'),
    );
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

  test('every date-window rule reads "last weekend" the same way: asked on '
      'a Monday, the two days just past', () {
    const rule =
        '"last weekend" is the latest Saturday and Sunday that are both '
        'before today — asked on a Monday, the two days just past';
    // Logged time, closed tasks and pull requests.
    expect(rule.allMatches(frontAgentSystemPrompt), hasLength(3));
    for (final tool in [
      'summarize_logged_time',
      'list_closed_tasks',
      'summarize_pull_requests',
    ]) {
      final at = frontAgentSystemPrompt.indexOf('call `$tool`');
      final ruleEnd = frontAgentSystemPrompt.indexOf('\n', at);
      expect(
        frontAgentSystemPrompt.substring(at, ruleEnd),
        contains(rule),
        reason: tool,
      );
    }
  });

  group('finding and reading pull requests', () {
    Map<Object?, Object?> properties(String name) =>
        frontAgentTools
                .singleWhere((t) => t.name == name)
                .parameters['properties']
            as Map;

    test('find_pull_requests takes a topic and the window '
        'summarize_pull_requests takes', () {
      final find = frontAgentTools.singleWhere(
        (t) => t.name == FrontAgentToolNames.findPullRequests,
      );
      expect(find.parameters['required'], ['topic']);
      expect(properties(FrontAgentToolNames.findPullRequests).keys, [
        'topic',
        ...properties(FrontAgentToolNames.summarizePullRequests).keys,
      ]);
      expect(find.description, contains('at most $frontPullRequestsFoundMax'));
    });

    test('read_pull_requests names a few by key', () {
      expect(
        (properties(FrontAgentToolNames.readPullRequests)['ids']!
            as Map)['maxItems'],
        frontPullRequestIdsPerRead,
      );
    });

    test('the prompt routes the which-task question to find_pull_requests, '
        'a follow-up to read_pull_requests, and teaches the cards', () {
      expect(
        frontAgentSystemPrompt,
        contains('call `find_pull_requests` with `topic`'),
      );
      expect(
        frontAgentSystemPrompt,
        contains('Call `read_pull_requests` with its id'),
      );
      expect(
        frontAgentSystemPrompt,
        contains('- `<conversation_pull_requests>`:'),
      );
      expect(frontAgentSystemPrompt, contains('`PullRequestCards` shows'));
      expect(
        frontAgentSystemPrompt,
        contains(
          'one `find_pull_requests` and one `read_pull_requests` per '
          'turn at most',
        ),
      );
    });

    test('the refusals name the cap they enforce', () {
      expect(
        frontPullRequestFindExhaustedAnswer,
        contains('$frontPullRequestFindsPerTurn used'),
      );
      expect(
        frontPullRequestReadExhaustedAnswer,
        contains('$frontPullRequestReadsPerTurn used'),
      );
    });
  });
}
