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
  late List<bool> largestAsked;
  late List<bool> everyAsked;
  late List<(String, List<FrontFoundPullRequest>)> filtered;

  FrontPullRequestLookups lookups({
    Future<List<String>> Function(String topic)? keep,
    List<FrontFoundPullRequest> conversation = const [],
    void Function(Object error)? onFilterFailed,
    List<FrontFoundPullRequest>? pool,
    bool wired = true,
    bool withFilter = true,
  }) => FrontPullRequestLookups(
    now: now,
    finder: wired
        ? (query, {largest = false}) async {
            queries.add(query);
            largestAsked.add(largest);
            return (range: range, pullRequests: pool ?? candidates);
          }
        : null,
    filter: wired && withFilter
        ? (topic, pullRequests, {every = false}) async {
            everyAsked.add(every);
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
    largestAsked = [];
    everyAsked = [];
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
      expect(largestAsked, [false]);
      expect(everyAsked, [false]);
    });

    test('largest without a topic hands back the first '
        '$frontPullRequestsFoundMax the finder ranked, calling no filter — '
        'even when none is wired', () async {
      final pool = [
        for (var n = 1; n <= frontPullRequestsFoundMax + 2; n++)
          foundPullRequest(n, additions: 100 - n, deletions: 1),
      ];
      final pullRequests = lookups(pool: pool, withFilter: false);

      final answer = await pullRequests.find({
        'largest': true,
        'period': 'last_month',
      });

      expect(answer.accepted, isTrue);
      expect(largestAsked, [true]);
      expect(filtered, isEmpty);
      expect(pullRequests.found, pool.take(frontPullRequestsFoundMax));
      expect(
        answer.response,
        startsWith(
          'The $frontPullRequestsFoundMax largest of the '
          '${pool.length} pull requests opened',
        ),
      );
      expect(answer.response, contains('| +99 -1 |'));
      expect(answer.rows.map((row) => row.id), ['ledger']);
    });

    test('largest with a topic asks the filter for every match, then keeps '
        "the largest of them in the finder's size order", () async {
      // Ranked by size; the filter's relevance order is the reverse.
      final pool = [
        for (var n = 1; n <= frontPullRequestsFoundMax + 2; n++)
          foundPullRequest(n),
      ];
      final pullRequests = lookups(
        pool: pool,
        keep: (_) async => [
          for (final pr in pool.reversed) pr.key,
        ],
      );

      final answer = await pullRequests.find({
        'topic': 'fish',
        'largest': true,
        'pastDays': 14,
      });

      expect(largestAsked, [true]);
      expect(everyAsked, [true]);
      expect(filtered.single.$1, 'fish');
      // The largest match survives though relevance put it last.
      expect(pullRequests.found, pool.take(frontPullRequestsFoundMax));
      expect(answer.response, contains('largest first by lines changed'));
    });

    test('count cuts what is found, so her reply cannot draw more than was '
        'asked for', () async {
      final pool = [
        for (var n = 1; n <= frontPullRequestsFoundMax; n++)
          foundPullRequest(n),
      ];
      for (final (args, keys) in [
        (
          {'largest': true, 'count': 1, 'pastDays': 7},
          ['penguin/colony#1'],
        ),
        (
          {'largest': true, 'count': 2.0, 'pastDays': 7},
          ['penguin/colony#1', 'penguin/colony#2'],
        ),
      ]) {
        final pullRequests = lookups(pool: pool);
        final answer = await pullRequests.find(args);
        expect(pullRequests.found.map((pr) => pr.key), keys, reason: '$args');
        expect(answer.response, startsWith('The ${keys.length} largest'));
      }
    });

    test('largest says plainly when nothing was opened', () async {
      final answer = await lookups(
        pool: const [],
      ).find({'largest': true, 'pastDays': 7});
      expect(answer.accepted, isTrue);
      expect(answer.response, startsWith('No pull request was opened '));
    });

    test('a topic or largest, and one window, are required', () async {
      for (final args in [
        {'pastDays': 14},
        {'largest': false, 'pastDays': 14},
        {'largest': 'yes', 'pastDays': 14},
        {'largest': true},
        {'topic': '  ', 'pastDays': 14},
        {'topic': 'fish'},
        {'topic': 'fish', 'pastDays': 99},
        {'largest': true, 'pastDays': 7, 'count': 0},
        {
          'largest': true,
          'pastDays': 7,
          'count': frontPullRequestsFoundMax + 1,
        },
        {'largest': true, 'pastDays': 7, 'count': 2.5},
        {'largest': true, 'pastDays': 7, 'count': '3'},
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
      // A topic needs the filter, which a size ranking alone does not.
      final unfiltered = await lookups(
        withFilter: false,
      ).find({'topic': 'fish', 'pastDays': 7});
      expect(unfiltered.response, contains('cannot be searched'));
      expect(queries, isEmpty);
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
