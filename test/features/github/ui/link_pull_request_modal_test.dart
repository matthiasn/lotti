import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/github/github_repository.dart';
import 'package:lotti/classes/github/pull_request_ref.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/github/api/github_client.dart';
import 'package:lotti/features/github/domain/open_pull_request.dart';
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

  const repository = GitHubRepository(owner: 'penguin', repo: 'colony');

  OpenPullRequest openPr(int number, {bool draft = false}) => OpenPullRequest(
    ref: PullRequestRef(owner: 'penguin', repo: 'colony', number: number),
    title: 'Waddle $number',
    createdAt: DateTime.utc(2024, 3, 15),
    authorLogin: 'pingu',
    draft: draft,
  );

  Future<void> open(
    WidgetTester tester, {
    GitHubRepository? repo,
    Future<OpenPullRequestsResult> Function()? listing,
    Map<String, String> visibleTitles = const {},
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showLinkPullRequestModal(context, taskId: taskId),
            child: const Text('open'),
          ),
        ),
        overrides: [
          pullRequestServiceProvider.overrideWithValue(service),
          taskGitHubRepositoryProvider(
            taskId,
          ).overrideWith((ref) => Stream.value(repo)),
          openPullRequestsProvider(repository).overrideWith(
            (ref) =>
                listing?.call() ??
                Future.value(const OpenPullRequestsListed([])),
          ),
          pullRequestHolderTitleProvider.overrideWith(
            (ref, id) => Stream.value(visibleTitles[id]),
          ),
        ],
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    // The task's repository resolves first, then its listing: a frame each.
    await tester.pump();
    await tester.pump();
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

  testWidgets('submitting from the keyboard links the pasted text', (
    tester,
  ) async {
    answers(PullRequestLinked(prEntry(clock: {'a': 1})));
    await open(tester);

    await tester.enterText(find.byKey(LinkPullRequestKeys.urlField), url);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    verify(() => service.linkPasted(taskId: taskId, input: url)).called(1);
    expect(find.byKey(LinkPullRequestKeys.urlField), findsNothing);
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

  group('picker', () {
    testWidgets(
      "without a repository on the task's category, says how to get one",
      (tester) async {
        await open(tester);

        expect(
          find.text(
            "Assign a GitHub repository to this task's category to pick from "
            'its open pull requests.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'lists the open pull requests no task holds, and links the one tapped',
      (tester) async {
        when(
          () => service.link(taskId: taskId, ref: openPr(12).ref),
        ).thenAnswer(
          (_) async => PullRequestLinked(prEntry(clock: {'a': 1})),
        );
        await open(
          tester,
          repo: repository,
          listing: () async => OpenPullRequestsListed([
            openPr(12),
            openPr(15, draft: true),
          ]),
        );

        expect(
          find.text('Open pull requests in penguin/colony'),
          findsOneWidget,
        );
        expect(find.text('#12 Waddle 12'), findsOneWidget);
        expect(find.textContaining('@pingu · Draft'), findsOneWidget);

        await tester.tap(find.byKey(LinkPullRequestKeys.openPullRequest(12)));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        verify(
          () => service.link(taskId: taskId, ref: openPr(12).ref),
        ).called(1);
        expect(find.byKey(LinkPullRequestKeys.urlField), findsNothing);
      },
    );

    testWidgets(
      'a picked pull request another task took meanwhile is asked about, '
      'and linking it here too closes the modal',
      (tester) async {
        final pr = openPr(12).ref;
        when(
          () => service.link(taskId: taskId, ref: pr),
        ).thenAnswer((_) async => PullRequestLinkedElsewhere({'other'}, pr));
        when(
          () => service.link(taskId: taskId, ref: pr, alsoElsewhere: true),
        ).thenAnswer((_) async => PullRequestLinked(prEntry(clock: {'a': 1})));
        await open(
          tester,
          repo: repository,
          listing: () async => OpenPullRequestsListed([openPr(12)]),
        );

        await tester.tap(find.byKey(LinkPullRequestKeys.openPullRequest(12)));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // The other task is private and hidden: it is counted, not named.
        expect(
          find.text(
            'This pull request is already linked to another task. Link it '
            'to this task as well?',
          ),
          findsOneWidget,
        );
        expect(find.byKey(LinkPullRequestKeys.urlField), findsOneWidget);

        await tester.tap(find.byKey(LinkPullRequestKeys.linkHereToo));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        verify(
          () => service.link(taskId: taskId, ref: pr, alsoElsewhere: true),
        ).called(1);
        expect(find.byKey(LinkPullRequestKeys.urlField), findsNothing);
      },
    );

    testWidgets(
      'a pasted pull request a visible task holds names it; cancelling '
      'links nothing and leaves the modal open',
      (tester) async {
        const pr = PullRequestRef(
          owner: 'matthiasn',
          repo: 'lotti',
          number: 42,
        );
        when(
          () => service.linkPasted(taskId: taskId, input: url),
        ).thenAnswer(
          (_) async => const PullRequestLinkedElsewhere({'chicks'}, pr),
        );
        await open(tester, visibleTitles: {'chicks': 'Teach the chicks'});

        await submit(tester, url);

        expect(
          find.text(
            'This pull request is already linked to “Teach the chicks”. '
            'Link it to this task as well?',
          ),
          findsOneWidget,
        );

        await tester.tap(find.byKey(LinkPullRequestKeys.keepElsewhere));
        await tester.pump();

        expect(find.byKey(LinkPullRequestKeys.linkHereToo), findsNothing);
        expect(find.byKey(LinkPullRequestKeys.urlField), findsOneWidget);
        verifyNever(
          () => service.link(taskId: taskId, ref: pr, alsoElsewhere: true),
        );
      },
    );

    testWidgets(
      'held by two other tasks, the question counts them; editing the link '
      'withdraws it',
      (tester) async {
        const pr = PullRequestRef(
          owner: 'matthiasn',
          repo: 'lotti',
          number: 42,
        );
        when(
          () => service.linkPasted(taskId: taskId, input: url),
        ).thenAnswer(
          (_) async => const PullRequestLinkedElsewhere({'a', 'b'}, pr),
        );
        await open(tester, visibleTitles: {'a': 'Waddle', 'b': 'Swim'});

        await submit(tester, url);
        expect(
          find.text(
            'This pull request is already linked to 2 other tasks. Link it '
            'to this task as well?',
          ),
          findsOneWidget,
        );

        await tester.enterText(
          find.byKey(LinkPullRequestKeys.urlField),
          '$url/',
        );
        await tester.pump();

        expect(find.byKey(LinkPullRequestKeys.linkHereToo), findsNothing);
      },
    );

    testWidgets(
      'a link that throws says it was not saved and can be tried again',
      (tester) async {
        var calls = 0;
        when(
          () => service.link(taskId: taskId, ref: openPr(12).ref),
        ).thenAnswer((_) async {
          if (calls++ == 0) throw Exception('database is locked');
          return PullRequestLinked(prEntry(clock: {'a': 1}));
        });
        await open(
          tester,
          repo: repository,
          listing: () async => OpenPullRequestsListed([openPr(12)]),
        );
        final row = find.byKey(LinkPullRequestKeys.openPullRequest(12));

        await tester.tap(row);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(
          find.text('The link could not be saved. Try again.'),
          findsOneWidget,
        );

        await tester.tap(row);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(calls, 2);
        expect(find.byKey(LinkPullRequestKeys.urlField), findsNothing);
      },
    );

    testWidgets('says when nothing is left to link', (tester) async {
      await open(tester, repo: repository);

      expect(
        find.text('No open pull request in penguin/colony is left to link.'),
        findsOneWidget,
      );
    });

    testWidgets('says why GitHub could not list them', (tester) async {
      await open(
        tester,
        repo: repository,
        listing: () async =>
            const OpenPullRequestsFailed(GitHubFailureKind.notFound),
      );

      expect(
        find.text('Not found, or your token cannot see this repository.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'a listing that throws reads as a response Lotti could not read',
      (tester) async {
        await open(
          tester,
          repo: repository,
          listing: () => Future.error(StateError('boom')),
        );

        expect(
          find.text('GitHub sent a response Lotti could not read.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('shows progress while listing', (tester) async {
      final pending = Completer<OpenPullRequestsResult>();
      await open(tester, repo: repository, listing: () => pending.future);

      expect(find.byType(DesignSystemSpinner), findsOneWidget);
      pending.complete(const OpenPullRequestsListed([]));
      await tester.pump();
    });
  });

  testWidgets('Cancel closes without linking', (tester) async {
    await open(tester);

    await tester.tap(find.byKey(LinkPullRequestKeys.cancelButton));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byKey(LinkPullRequestKeys.urlField), findsNothing);
    verifyZeroInteractions(service);
  });
}
