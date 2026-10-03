import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/github/api/github_client.dart';
import 'package:lotti/features/github/domain/pull_request_ref.dart';
import 'package:lotti/features/github/service/pull_request_service.dart';
import 'package:lotti/features/github/state/github_providers.dart';
import 'package:lotti/features/github/ui/link_pull_request_modal.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../pull_request_fixtures.dart';

void main() {
  const taskId = 'task-1';
  const url = 'https://github.com/matthiasn/lotti/pull/42';
  late MockPullRequestService service;

  setUp(() => service = MockPullRequestService());

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showLinkPullRequestModal(context, taskId: taskId),
            child: const Text('open'),
          ),
        ),
        overrides: [pullRequestServiceProvider.overrideWithValue(service)],
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> submit(WidgetTester tester, String input) async {
    await tester.enterText(find.byKey(LinkPullRequestKeys.urlField), input);
    await tester.pump();
    await tester.tap(find.byKey(LinkPullRequestKeys.linkButton));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  void answers(PullRequestLinkResult result) => when(
    () => service.linkPasted(
      taskId: taskId,
      input: any(named: 'input'),
    ),
  ).thenAnswer((_) async => result);

  testWidgets('Link stays disabled until something is pasted', (tester) async {
    await open(tester);

    expect(
      tester
          .widget<DesignSystemButton>(
            find.byKey(LinkPullRequestKeys.linkButton),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('a linked pull request closes the modal', (tester) async {
    answers(PullRequestLinked(prEntry(clock: {'a': 1})));
    await open(tester);

    await submit(tester, url);

    verify(() => service.linkPasted(taskId: taskId, input: url)).called(1);
    expect(find.byKey(LinkPullRequestKeys.urlField), findsNothing);
  });

  for (final (result, message) in [
    (
      const PullRequestAlreadyLinked(),
      'This pull request is already linked to this task.',
    ),
    (
      const PullRequestLinkRejected(PullRequestRefRejection.notGitHub),
      'That is not a link to github.com.',
    ),
    (
      const PullRequestLinkRejected(PullRequestRefRejection.notAPullRequest),
      'That is not a pull request.',
    ),
    (
      const PullRequestLinkFailed(GitHubFailureKind.notFound),
      'Not found, or your token cannot see this repository.',
    ),
  ]) {
    testWidgets('stays open and says: $message', (tester) async {
      answers(result);
      await open(tester);

      await submit(tester, url);

      expect(find.byKey(LinkPullRequestKeys.urlField), findsOneWidget);
      expect(find.text(message), findsOneWidget);
    });
  }

  testWidgets('Cancel closes without linking', (tester) async {
    await open(tester);

    await tester.tap(find.byKey(LinkPullRequestKeys.cancelButton));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byKey(LinkPullRequestKeys.urlField), findsNothing);
    verifyZeroInteractions(service);
  });
}
