import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/front_agent/model/front_pull_requests.dart';
import 'package:lotti/features/front_agent/workflow/front_agent_contract.dart';
import 'package:lotti/features/front_agent/workflow/front_pull_request_lookups.dart';
import 'package:lotti/features/insights/logic/time_bucketing.dart';
import 'package:lotti/features/insights/model/insights_models.dart';

import '../front_pull_request_test_data.dart';

void main() {
  final now = DateTime(2026, 11, 8, 15);
  final range = InsightsRange(
    startDay: epochDay(now) - 13,
    endDayExclusive: epochDay(now) + 1,
  );
  final candidates = [
    foundPullRequest(1, taskTitle: 'Count the fish'),
    foundPullRequest(2, taskId: 'igloo', taskTitle: 'Warm the igloo'),
    foundPullRequest(3, taskTitle: 'Count the fish'),
  ];

  late List<FrontPullRequestQuery> queries;
  late List<(String, List<FrontFoundPullRequest>)> filtered;

  FrontPullRequestLookups lookups({
    Future<List<String>> Function(String topic)? keep,
    List<FrontFoundPullRequest> conversation = const [],
    void Function(Object error)? onFilterFailed,
    bool wired = true,
  }) => FrontPullRequestLookups(
    now: now,
    finder: wired
        ? (query) async {
            queries.add(query);
            return (range: range, pullRequests: candidates);
          }
        : null,
    filter: wired
        ? (topic, pullRequests) async {
            filtered.add((topic, pullRequests));
            return (keep ?? (_) async => ['penguin/colony#3'])(topic);
          }
        : null,
    reader: wired
        ? (pullRequests) async =>
              'details of ${pullRequests.map((pr) => pr.key).join(', ')}'
        : null,
    conversationPullRequests: conversation,
    onFilterFailed: onFilterFailed,
  );

  setUp(() {
    queries = [];
    filtered = [];
  });

  group('find', () {
    test('every candidate of the window goes to the filter; only what it '
        'keeps comes back, with its task', () async {
      final pullRequests = lookups();

      final answer = await pullRequests.find({
        'topic': ' fish ledger ',
        'pastDays': 14,
      });

      expect(answer.accepted, isTrue);
      expect(queries.single.range, range);
      expect(filtered.single.$1, 'fish ledger');
      expect(filtered.single.$2, candidates);
      expect(pullRequests.found, [candidates[2]]);
      expect(answer.rows.map((row) => row.id), ['ledger']);
      expect(answer.response, contains('penguin/colony#3'));
      expect(answer.response, contains('(3 searched)'));
      expect(answer.response, isNot(contains('penguin/colony#1')));
      expect(answer.response, isNot(contains('Warm the igloo')));
      expect(pullRequests.calls, 1);
      expect(pullRequests.shown.keys, ['penguin/colony#3']);
    });

    test('a topic and one window are required', () async {
      for (final args in [
        {'pastDays': 14},
        {'topic': '  ', 'pastDays': 14},
        {'topic': 'fish'},
        {'topic': 'fish', 'pastDays': 99},
      ]) {
        final answer = await lookups().find(args);
        expect(answer.accepted, isFalse, reason: '$args');
        expect(answer.response, startsWith('Error: find_pull_requests needs'));
      }
      expect(queries, isEmpty);
    });

    test('is unavailable when nothing is wired', () async {
      final answer = await lookups(wired: false).find({
        'topic': 'fish',
        'pastDays': 7,
      });
      expect(answer.accepted, isFalse);
      expect(answer.response, contains('cannot be searched'));
    });

    test('a failed filter call is reported, never an answer', () async {
      final failures = <Object>[];
      final pullRequests = lookups(
        keep: (_) => Future.error(StateError('provider down')),
        onFilterFailed: failures.add,
      );

      final answer = await pullRequests.find({'topic': 'fish', 'pastDays': 7});

      expect(answer.accepted, isFalse);
      expect(answer.response, contains('search failed'));
      expect(failures.single, isA<StateError>());
      expect(pullRequests.found, isEmpty);
    });

    test('runs once a turn', () async {
      final pullRequests = lookups();
      await pullRequests.find({'topic': 'fish', 'pastDays': 7});
      final again = await pullRequests.find({'topic': 'fish', 'pastDays': 7});
      expect(again.accepted, isFalse);
      expect(again.response, frontPullRequestFindExhaustedAnswer);
      expect(queries, hasLength(1));
    });
  });

  group('read', () {
    test('reads what the conversation showed or the turn found', () async {
      final shown = foundPullRequest(5, taskId: 'igloo');
      final pullRequests = lookups(conversation: [shown]);
      await pullRequests.find({'topic': 'fish', 'pastDays': 7});

      final answer = await pullRequests.read({
        'ids': [' penguin/colony#5', 'penguin/colony#3'],
      });

      expect(answer.accepted, isTrue);
      expect(answer.response, 'details of penguin/colony#5, penguin/colony#3');
      expect(answer.rows.map((row) => row.id), ['igloo', 'ledger']);
      expect(pullRequests.calls, 2);
    });

    test('refuses an id it was never shown, none, or too many', () async {
      final pullRequests = lookups(
        conversation: [
          for (var n = 1; n <= frontPullRequestIdsPerRead + 1; n++)
            foundPullRequest(n),
        ],
      );
      for (final ids in [
        ['penguin/colony#99'],
        <String>[],
        [
          for (var n = 1; n <= frontPullRequestIdsPerRead + 1; n++)
            'penguin/colony#$n',
        ],
        'penguin/colony#1',
      ]) {
        final answer = await pullRequests.read({'ids': ids});
        expect(answer.accepted, isFalse, reason: '$ids');
        expect(answer.response, startsWith('Error: ids names'));
      }
      expect(pullRequests.calls, 0);
    });

    test('is unavailable without a reader, and says when nothing is '
        'stored any more', () async {
      final shown = [foundPullRequest(1)];
      final unwired = FrontPullRequestLookups(
        now: now,
        conversationPullRequests: shown,
      );
      expect(
        (await unwired.read({
          'ids': ['penguin/colony#1'],
        })).response,
        contains('unavailable'),
      );

      final emptied = FrontPullRequestLookups(
        now: now,
        reader: (_) async => '',
        conversationPullRequests: shown,
      );
      final answer = await emptied.read({
        'ids': ['penguin/colony#1'],
      });
      expect(answer.accepted, isTrue);
      expect(answer.response, 'Nothing is stored for them any more.');
    });

    test('runs once a turn', () async {
      final pullRequests = lookups(conversation: [foundPullRequest(1)]);
      final args = {
        'ids': ['penguin/colony#1'],
      };
      await pullRequests.read(args);
      final again = await pullRequests.read(args);
      expect(again.response, frontPullRequestReadExhaustedAnswer);
    });
  });
}
