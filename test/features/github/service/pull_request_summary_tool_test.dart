import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/github/domain/pull_request_summary.dart';
import 'package:lotti/features/github/service/pull_request_summary_tool.dart';
import 'package:openai_dart/openai_dart.dart';

import '../pull_request_fixtures.dart';

void main() {
  String rejection(List<ChatCompletionMessageToolCall> calls) {
    try {
      parsePullRequestSummaryToolCall(calls);
    } on PullRequestSummaryToolException catch (e) {
      return e.reason;
    }
    fail('the call was accepted');
  }

  test('reads both tiers, trimmed, and ignores a duplicate call', () {
    expect(
      parsePullRequestSummaryToolCall([
        summaryToolCall(oneLiner: ' One line. ', tldr: ' A paragraph. '),
        summaryToolCall(oneLiner: 'Second.', tldr: 'Ignored.'),
      ]),
      const PullRequestSummary(oneLiner: 'One line.', tldr: 'A paragraph.'),
    );
  });

  test('says what was wrong, never what was written', () {
    expect(rejection([]), 'no $pullRequestSummaryToolName call');
    expect(
      rejection([summaryToolCall(name: 'something_else')]),
      'no $pullRequestSummaryToolName call',
    );
    expect(
      rejection([summaryToolCall(arguments: 'not json')]),
      'arguments are not JSON',
    );
    expect(
      rejection([summaryToolCall(arguments: '[1]')]),
      'arguments are not an object',
    );
    expect(
      rejection([summaryToolCall(oneLiner: '  ')]),
      'oneLiner is missing or empty',
    );
    expect(
      rejection([summaryToolCall(arguments: '{"oneLiner": "One."}')]),
      'tldr is missing or empty',
    );
    expect(
      rejection([
        summaryToolCall(oneLiner: 'x' * (pullRequestOneLinerMaxChars + 1)),
      ]),
      'oneLiner is longer than $pullRequestOneLinerMaxChars characters',
    );
    expect(
      rejection([summaryToolCall(tldr: 'x' * (pullRequestTldrMaxChars + 1))]),
      'tldr is longer than $pullRequestTldrMaxChars characters',
    );
  });

  test('the exception reads as its reason in a log', () {
    expect(
      const PullRequestSummaryToolException(
        'tldr is missing or empty',
      ).toString(),
      'PullRequestSummaryToolException: tldr is missing or empty',
    );
  });

  test('the tool asks for exactly the two tiers', () {
    final parameters = pullRequestSummaryTool.function.parameters!;
    expect(parameters['required'], ['oneLiner', 'tldr']);
    expect(parameters['additionalProperties'], isFalse);
  });

  test('pins the tool, except for a model that answers a pin in prose', () {
    expect(pullRequestSummaryToolChoiceFor('gpt-5'), isNotNull);
    expect(pullRequestSummaryToolChoiceFor('deepseek-v4.1-flash'), isNull);
  });
}
