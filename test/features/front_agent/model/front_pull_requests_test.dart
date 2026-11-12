import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/front_agent/model/front_pull_requests.dart';
import 'package:lotti/features/front_agent/model/front_routing_index.dart';
import 'package:lotti/features/insights/logic/time_bucketing.dart';
import 'package:lotti/features/insights/model/insights_models.dart';

import '../front_pull_request_test_data.dart';

void main() {
  // Sunday 2026-11-08, mid-afternoon.
  final now = DateTime(2026, 11, 8, 15);
  final today = epochDay(now);

  FrontPullRequest pr(
    String key, {
    required DateTime? createdAt,
    DateTime? mergedAt,
    int additions = 0,
    int deletions = 0,
  }) => FrontPullRequest(
    key: key,
    title: 'Title of $key',
    createdAt: createdAt,
    mergedAt: mergedAt,
    additions: additions,
    deletions: deletions,
  );

  group('frontPullRequestQuery', () {
    test('a named period is resolved later, on the first weekday', () {
      expect(frontPullRequestQuery({'period': 'this_week'}, now), (
        period: FrontTimePeriod.thisWeek,
        range: null,
      ));
    });

    test('the past N days end today, 14.0 read as 14', () {
      const expected = 14;
      for (final days in [14, 14.0]) {
        final query = frontPullRequestQuery({'pastDays': days}, now)!;
        expect(query.period, isNull);
        expect(
          query.range,
          InsightsRange(
            startDay: today - expected + 1,
            endDayExclusive: today + 1,
          ),
        );
      }
    });

    test('a first and last day include both — this weekend', () {
      final query = frontPullRequestQuery({
        'from': '2026-11-07',
        'through': '2026-11-08',
      }, now)!;
      expect(
        query.range,
        InsightsRange(
          startDay: epochDay(DateTime(2026, 11, 7)),
          endDayExclusive: today + 1,
        ),
      );
    });

    test('refuses no window, two windows, and ones it cannot read', () {
      for (final args in <Map<String, dynamic>>[
        {},
        {'period': 'past_7_days', 'pastDays': 7},
        {'pastDays': 7, 'from': '2026-11-01', 'through': '2026-11-02'},
        {'period': 'fortnight'},
        {'pastDays': 0},
        {'pastDays': frontPullRequestMaxDays + 1},
        {'pastDays': 2.5},
        {'pastDays': '14'},
        {'from': '2026-11-01'},
        {'from': '2026-11-02', 'through': '2026-11-01'},
        {'from': '2026-02-30', 'through': '2026-03-01'},
        {'from': '1 Nov', 'through': '2026-11-02'},
        // 32 days.
        {'from': '2026-09-01', 'through': '2026-10-02'},
      ]) {
        expect(frontPullRequestQuery(args, now), isNull, reason: '$args');
      }
      // The longest window allowed.
      expect(
        frontPullRequestQuery({'pastDays': frontPullRequestMaxDays}, now),
        isNotNull,
      );
    });

    test('a caller may allow a longer window, and still no longer', () {
      const year = {'from': '2025-11-03', 'through': '2026-11-02'};
      expect(frontPullRequestQuery(year, now), isNull);
      expect(
        frontPullRequestQuery(year, now, maxDays: 365)?.range?.dayCount,
        365,
      );
      expect(frontPullRequestQuery(year, now, maxDays: 364), isNull);
      expect(
        frontPullRequestQuery({'pastDays': 365}, now, maxDays: 365)?.range,
        InsightsRange(startDay: today - 364, endDayExclusive: today + 1),
      );
    });
  });

  group('frontPullRequestDays', () {
    test('sums each pull request on the local day it was opened, with all '
        'its lines; an empty day is zero', () {
      final range = InsightsRange(
        startDay: today - 2,
        endDayExclusive: today + 1,
      );
      final days = frontPullRequestDays([
        pr(
          'a#1',
          createdAt: DateTime(2026, 11, 6, 9),
          additions: 10,
          deletions: 2,
        ),
        pr(
          'a#2',
          createdAt: DateTime(2026, 11, 6, 23),
          additions: 5,
          deletions: 1,
        ),
        pr('a#3', createdAt: DateTime(2026, 11, 8, 8), additions: 7),
        // Opening never stored: no day can count it.
        pr('a#5', createdAt: null, mergedAt: DateTime(2026, 11, 7)),
        // Opened before the days: merged inside them counts for nothing here.
        pr(
          'a#4',
          createdAt: DateTime(2026, 11),
          mergedAt: DateTime(2026, 11, 7),
          additions: 1000,
        ),
      ], range);

      expect(days.days, [
        DateTime(2026, 11, 6),
        DateTime(2026, 11, 7),
        DateTime(2026, 11, 8),
      ]);
      expect(days.opened, [2, 0, 1]);
      expect(days.additions, [15, 0, 7]);
      expect(days.deletions, [3, 0, 0]);
      expect(days.isEmpty, isFalse);
      expect(frontPullRequestDays(const [], range).isEmpty, isTrue);
    });
  });

  group('FrontPullRequestChart', () {
    final range = InsightsRange(
      startDay: today - 13,
      endDayExclusive: today + 1,
    );

    test('stores the days, the scope and the login, and reads them back', () {
      final chart = FrontPullRequestChart(
        range: range,
        categoryIds: const {'work', 'colony'},
        authorLogin: 'pingu',
      );
      final json = chart.toJson();
      expect(json['categoryIds'], ['colony', 'work']);
      expect(json['authorLogin'], 'pingu');
      expect(FrontPullRequestChart.fromJson(json), chart);
      expect(FrontPullRequestChart.fromJson(json).hashCode, chart.hashCode);

      final anyone = FrontPullRequestChart(range: range, categoryIds: const {});
      expect(anyone.toJson().containsKey('authorLogin'), isFalse);
      expect(FrontPullRequestChart.fromJson(anyone.toJson()), anyone);
      expect(anyone == chart, isFalse);
    });

    test('reads null for nothing or a shape this build does not know', () {
      for (final json in <Object?>[
        null,
        'chart',
        {'startDay': 5, 'endDayExclusive': 5, 'categoryIds': <String>[]},
        {'startDay': 1, 'endDayExclusive': 5},
        {
          'startDay': 1,
          'endDayExclusive': 5,
          'categoryIds': <String>[],
          'authorLogin': 7,
        },
      ]) {
        expect(FrontPullRequestChart.fromJson(json), isNull, reason: '$json');
      }
    });
  });

  group('FrontPullRequests.render', () {
    final range = InsightsRange(
      startDay: today - 13,
      endDayExclusive: today + 1,
    );
    final chart = FrontPullRequestChart(range: range, categoryIds: const {});

    test('totals what was opened and what was merged, then each', () {
      final summary = FrontPullRequests(
        chart: chart,
        pullRequests: [
          pr(
            'penguin/colony#12',
            createdAt: DateTime(2026, 11, 7, 10),
            mergedAt: DateTime(2026, 11, 8, 9),
            additions: 1200,
            deletions: 300,
          ),
          pr(
            'penguin/colony#11',
            createdAt: DateTime(2026, 11, 2, 10),
            additions: 250,
            deletions: 20,
          ),
          // Opening never stored, merged inside the days: shipped.
          pr(
            'penguin/ice#1',
            createdAt: null,
            mergedAt: DateTime(2026, 11, 4),
            additions: 2,
            deletions: 1,
          ),
          // Opened before the days, merged inside them: shipped, not opened.
          pr(
            'penguin/ice#3',
            createdAt: DateTime(2026, 10),
            mergedAt: DateTime(2026, 11, 3),
            additions: 40,
            deletions: 4,
          ),
        ],
      );

      expect(summary.opened.map((p) => p.key), [
        'penguin/colony#12',
        'penguin/colony#11',
      ]);
      expect(summary.merged.map((p) => p.key), [
        'penguin/colony#12',
        'penguin/ice#1',
        'penguin/ice#3',
      ]);
      expect(summary.hasChart, isTrue);
      expect(
        summary.render(),
        'Pull requests 2026-10-26 through 2026-11-08:\n'
        '- opened: 2, +1450 -320 lines\n'
        '- merged: 3, +1242 -305 lines\n'
        'Each, newest opened first:\n'
        '- penguin/colony#12 | Title of penguin/colony#12 | opened '
        '2026-11-07 | merged 2026-11-08 | +1200 -300\n'
        '- penguin/colony#11 | Title of penguin/colony#11 | opened '
        '2026-11-02 | +250 -20\n'
        '- penguin/ice#1 | Title of penguin/ice#1 | opened unknown | '
        'merged 2026-11-04 | +2 -1\n'
        '- penguin/ice#3 | Title of penguin/ice#3 | opened 2026-10-01 | '
        'merged 2026-11-03 | +40 -4',
      );
    });

    test('names a period, says when none were, and what it could not '
        'count', () {
      final summary = FrontPullRequests(
        period: FrontTimePeriod.past7Days,
        chart: FrontPullRequestChart(
          range: InsightsRange(startDay: today - 6, endDayExclusive: today + 1),
          categoryIds: const {},
        ),
        pullRequests: const [],
        undated: 2,
      );
      expect(summary.hasChart, isFalse);
      expect(
        summary.render(),
        'None: no pull request opened or merged past 7 days '
        '(2026-11-02 through 2026-11-08).\n'
        '2 linked pull requests were never refreshed, so when they were '
        'opened is not known and they are not counted.',
      );
    });

    test('a single day is one date; a list longer than the cap says how '
        'many are not shown', () {
      final summary = FrontPullRequests(
        chart: FrontPullRequestChart(
          range: InsightsRange(startDay: today, endDayExclusive: today + 1),
          categoryIds: const {},
        ),
        pullRequests: [
          for (var i = 0; i < frontPullRequestListLimit + 2; i++)
            pr('a#$i', createdAt: DateTime(2026, 11, 8, 9)),
        ],
        undated: 1,
      );
      final text = summary.render();
      expect(text, startsWith('Pull requests 2026-11-08:\n'));
      expect(text, contains('Each, newest opened first (+2 not shown):'));
      expect(
        RegExp('^- a#', multiLine: true).allMatches(text),
        hasLength(frontPullRequestListLimit),
      );
      expect(
        text,
        endsWith(
          '1 linked pull request was never refreshed, so when it was opened '
          'is not known and it is not counted.',
        ),
      );
    });
  });

  group('pull request cards', () {
    test('a card is stored as its key and task, and read back so', () {
      const card = (key: 'penguin/colony#7', taskId: 'ledger');
      expect(frontPullRequestCardToJson(card), {
        'key': 'penguin/colony#7',
        'taskId': 'ledger',
      });
      expect(
        frontPullRequestCardsFromJson([
          frontPullRequestCardToJson(card),
        ]),
        [card],
      );
    });

    test('what this build cannot read is skipped, never thrown on', () {
      expect(frontPullRequestCardsFromJson(null), isEmpty);
      expect(frontPullRequestCardsFromJson('cards'), isEmpty);
      expect(
        frontPullRequestCardsFromJson([
          {'key': 'penguin/colony#1'},
          {'key': 7, 'taskId': 'ledger'},
          {'key': 'penguin/colony#2', 'taskId': 'ledger'},
        ]),
        [(key: 'penguin/colony#2', taskId: 'ledger')],
      );
    });
  });

  group('FrontFoundPullRequest', () {
    test('one line names its key, title, days, task and summary', () {
      final pr = foundPullRequest(
        7,
        title: 'Fish\n  ledger',
        taskTitle: 'Count the fish',
        oneLiner: 'Adds the ledger the colony counts fish in.',
        createdAt: DateTime(2026, 11, 2, 10),
        mergedAt: DateTime(2026, 11, 3, 15),
      );
      expect(
        pr.render(),
        'penguin/colony#7 | Fish ledger | opened 2026-11-02 | '
        'merged 2026-11-03 | task:ledger (Count the fish) | '
        'Adds the ledger the colony counts fish in.',
      );
      expect(pr.card, (key: 'penguin/colony#7', taskId: 'ledger'));
    });

    test(
      'an unknown opening, no merge and no summary are said or left out',
      () {
        expect(
          foundPullRequest(8, oneLiner: '  ').render(),
          'penguin/colony#8 | Pull request 8 | opened unknown | '
          'task:ledger (Task ledger)',
        );
      },
    );
  });

  group('renderFrontFoundPullRequests', () {
    final range = InsightsRange(
      startDay: epochDay(DateTime(2026, 11, 2)),
      endDayExclusive: epochDay(DateTime(2026, 11, 9)),
    );

    test('lists what the filter kept, with how many it searched', () {
      final text = renderFrontFoundPullRequests(
        topic: 'fish ledger',
        range: range,
        searched: 40,
        found: [foundPullRequest(7), foundPullRequest(9)],
      );
      expect(
        text,
        'Pull requests about "fish ledger", 2026-11-02 through 2026-11-08 '
        '(40 searched), each as id | title | opened | merged | task | '
        'summary:\n'
        '- penguin/colony#7 | Pull request 7 | opened unknown | '
        'task:ledger (Task ledger)\n'
        '- penguin/colony#9 | Pull request 9 | opened unknown | '
        'task:ledger (Task ledger)',
      );
    });

    test('says plainly when none was about it, on one day', () {
      expect(
        renderFrontFoundPullRequests(
          topic: 'igloo',
          range: InsightsRange(
            startDay: range.startDay,
            endDayExclusive: range.startDay + 1,
          ),
          searched: 3,
          found: const [],
        ),
        'None of the 3 pull requests opened or merged 2026-11-02 is about '
        '"igloo".',
      );
    });
  });
}
