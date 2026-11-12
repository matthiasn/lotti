import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/front_agent/model/front_pull_requests.dart';
import 'package:lotti/features/front_agent/workflow/front_pull_request_filter.dart';

import '../front_pull_request_test_data.dart';

void main() {
  final candidates = [
    foundPullRequest(1, title: 'Fish ledger', oneLiner: 'Counts fish.'),
    foundPullRequest(2, title: 'Igloo heating', taskId: 'igloo'),
    foundPullRequest(3, title: 'Fish ledger totals'),
  ];
  final keys = {for (final pr in candidates) pr.key};

  group('parseFrontPullRequestFilter', () {
    test('keeps the keys it names in its order, each once', () {
      expect(
        parseFrontPullRequestFilter(
          'penguin/colony#3\n- penguin/colony#1\npenguin/colony#3',
          keys,
        ),
        ['penguin/colony#3', 'penguin/colony#1'],
      );
    });

    test('never keeps a key it made up, and reads NONE as none', () {
      expect(
        parseFrontPullRequestFilter('penguin/colony#99, penguin/igloo#1', keys),
        isEmpty,
      );
      expect(parseFrontPullRequestFilter('NONE', keys), isEmpty);
    });

    test('keeps at most frontPullRequestsFoundMax', () {
      final many = {
        for (var n = 1; n <= frontPullRequestsFoundMax + 2; n++)
          'penguin/colony#$n',
      };
      expect(
        parseFrontPullRequestFilter(many.join('\n'), many),
        many.take(frontPullRequestsFoundMax),
      );
    });
  });

  test('the prompt carries the topic and each candidate on one line', () {
    expect(
      frontPullRequestFilterPrompt('the fish ledger', candidates),
      'Topic: the fish ledger\n'
      '\n'
      'Pull requests, each as id | title | opened | merged | task | summary:\n'
      '- ${candidates[0].render()}\n'
      '- ${candidates[1].render()}\n'
      '- ${candidates[2].render()}',
    );
  });

  test('the filter asks once, under its own system message, and keeps only '
      'candidates it names', () async {
    final asked = <(String, String)>[];
    final filter = frontPullRequestFilter(({
      required systemMessage,
      required prompt,
    }) async {
      asked.add((systemMessage, prompt));
      return 'penguin/colony#3\npenguin/colony#7\npenguin/colony#1';
    });

    final kept = await filter('the fish ledger', candidates);

    expect(kept, ['penguin/colony#3', 'penguin/colony#1']);
    expect(asked, [
      (
        frontPullRequestFilterSystemMessage,
        frontPullRequestFilterPrompt('the fish ledger', candidates),
      ),
    ]);
    expect(
      frontPullRequestFilterSystemMessage,
      contains('at most $frontPullRequestsFoundMax'),
    );
  });

  test('no answer keeps none', () async {
    final filter = frontPullRequestFilter(
      ({required systemMessage, required prompt}) async => null,
    );
    expect(await filter('fish', candidates), isEmpty);
  });
}
