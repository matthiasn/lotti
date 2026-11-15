import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/github/github_repository.dart';
import 'package:lotti/classes/github/pull_request_ref.dart';
import 'package:lotti/features/design_system/components/inputs/design_system_text_input.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/github/api/github_client.dart';
import 'package:lotti/features/github/domain/open_pull_request.dart';
import 'package:lotti/features/github/service/pull_request_service.dart';
import 'package:lotti/features/github/state/github_providers.dart';
import 'package:lotti/features/github/ui/link_pull_request_modal.dart';
import 'package:lotti/features/github/ui/pull_request_glyph.dart';
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
    Stream<GitHubRepository?>? repositories,
    Future<OpenPullRequestsResult> Function()? listing,
    Map<String, String> visibleTitles = const {},
    Map<int, PullRequestSize> sizes = const {},
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
          ).overrideWith((ref) => repositories ?? Stream.value(repo)),
          openPullRequestsProvider(repository).overrideWith(
            (ref) =>
                listing?.call() ??
                Future.value(const OpenPullRequestsListed([])),
          ),
          openPullRequestSizesProvider(
            repository,
          ).overrideWith((ref) async => sizes),
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

  testWidgets(
    'the Link action appears in the field once something is pasted, and '
    'stays inert while that links',
    (tester) async {
      final pending = Completer<PullRequestLinkResult>();
      when(
        () => service.linkPasted(
          taskId: taskId,
          input: any(named: 'input'),
        ),
      ).thenAnswer((_) => pending.future);
      await open(tester);

      // Nothing to link yet: no action waiting disabled under the list.
      expect(find.byKey(LinkPullRequestKeys.linkButton), findsNothing);

      await submit(tester, url);
      // The action gives way to progress in its own slot: nothing to tap a
      // second time, and no line of text arriving to reflow the sheet.
      expect(find.bySemanticsLabel('Linking pull request'), findsOneWidget);
      expect(find.text('Linking pull request'), findsNothing);
      expect(find.byKey(LinkPullRequestKeys.linkButton), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(LinkPullRequestKeys.urlField),
          matching: find.byType(DesignSystemSpinner),
        ),
        findsOneWidget,
      );

      verify(() => service.linkPasted(taskId: taskId, input: url)).called(1);
      pending.complete(const PullRequestLinkNotStored());
      await tester.pump();
    },
  );

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
      "without a repository on the task's category, the field's one hint "
      'says how to get one',
      (tester) async {
        await open(tester);

        final field = find.byKey(LinkPullRequestKeys.urlField);
        final hint = find.text(
          "Assign a GitHub repository to this task's category to pick from "
          'its open pull requests.',
        );
        // The label says what the field takes, so no helper repeats it.
        expect(find.text('URL or owner/repo#123'), findsOneWidget);
        expect(
          tester.widget<DesignSystemTextInput>(field).helperText,
          isNull,
        );
        expect(
          tester.getTopLeft(hint).dy - tester.getBottomLeft(field).dy,
          tester.element(field).designTokens.spacing.step3,
          reason: 'with the field it is about, not a section of its own',
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

        // The heading is the instruction: the rows are the other way in.
        expect(find.text('Or pick one from penguin/colony'), findsOneWidget);
        expect(find.text('#12 Waddle 12'), findsOneWidget);
        // As a linked row's title: room to tell two pull requests apart.
        expect(
          tester
              .widgetList<PullRequestTitle>(find.byType(PullRequestTitle))
              .map((title) => title.maxLines),
          [3, 3],
        );
        // A draft says so first, as a linked pull request's state does.
        expect(
          find.textContaining('Draft ·\u00A0@pingu', findRichText: true),
          findsOneWidget,
        );

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
          listing: () async => OpenPullRequestsListed([
            openPr(12),
            openPr(15),
          ]),
        );
        bool tinted(int number) => tester
            .widget<DesignSystemListItem>(
              find.byKey(LinkPullRequestKeys.openPullRequest(number)),
            )
            .activated;

        await tester.tap(find.byKey(LinkPullRequestKeys.openPullRequest(12)));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // The question names no pull request: the row it is about says
        // which, and only that row.
        expect(tinted(12), isTrue);
        expect(tinted(15), isFalse);
        // The other task is private and hidden: it is counted, not named.
        final question = find.text(
          'This pull request is already linked to another task. Link it '
          'to this task as well?',
        );
        expect(question, findsOneWidget);
        expect(find.byKey(LinkPullRequestKeys.urlField), findsOneWidget);
        // Asked at the row it is about, not up at the field.
        expect(
          tester.getTopLeft(question).dy,
          inExclusiveRange(
            tester
                .getBottomLeft(
                  find.byKey(LinkPullRequestKeys.openPullRequest(12)),
                )
                .dy,
            tester
                .getTopLeft(
                  find.byKey(LinkPullRequestKeys.openPullRequest(15)),
                )
                .dy,
          ),
        );

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
        bool fieldActionLeads() => tester
            .widget<DesignSystemTextInput>(
              find.byKey(LinkPullRequestKeys.urlField),
            )
            .emphasizeTrailingIcon;

        await tester.enterText(find.byKey(LinkPullRequestKeys.urlField), url);
        await tester.pump();
        expect(fieldActionLeads(), isTrue);

        await submit(tester, url);

        // One primary at a time: the answer leads, the field's action waits.
        expect(fieldActionLeads(), isFalse);
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
        expect(fieldActionLeads(), isTrue);
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
        final reason = find.text('The link could not be saved. Try again.');
        expect(reason, findsOneWidget);
        // Said under the row that was picked, which stays marked — not as
        // an error on a field nobody typed in.
        expect(
          tester.getTopLeft(reason).dy,
          greaterThan(tester.getBottomLeft(row).dy),
        );
        expect(tester.widget<DesignSystemListItem>(row).activated, isTrue);
        expect(
          tester
              .widget<DesignSystemTextInput>(
                find.byKey(LinkPullRequestKeys.urlField),
              )
              .errorText,
          isNull,
        );
        expect(
          tester.getSemantics(reason),
          matchesSemantics(
            label: 'The link could not be saved. Try again.',
            isLiveRegion: true,
          ),
        );

        await tester.tap(row);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(calls, 2);
        expect(find.byKey(LinkPullRequestKeys.urlField), findsNothing);
      },
    );

    testWidgets(
      'answering the question a paste raised links with progress in the '
      'field, where it was asked',
      (tester) async {
        const pr = PullRequestRef(
          owner: 'matthiasn',
          repo: 'lotti',
          number: 42,
        );
        final pending = Completer<PullRequestLinkResult>();
        when(
          () => service.linkPasted(taskId: taskId, input: url),
        ).thenAnswer(
          (_) async => const PullRequestLinkedElsewhere({'other'}, pr),
        );
        when(
          () => service.link(taskId: taskId, ref: pr, alsoElsewhere: true),
        ).thenAnswer((_) => pending.future);
        await open(tester);

        await submit(tester, url);
        await tester.tap(find.byKey(LinkPullRequestKeys.linkHereToo));
        await tester.pump();

        expect(
          find.descendant(
            of: find.byKey(LinkPullRequestKeys.urlField),
            matching: find.byType(DesignSystemSpinner),
          ),
          findsOneWidget,
        );

        pending.complete(PullRequestLinked(prEntry(clock: {'a': 1})));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(find.byKey(LinkPullRequestKeys.urlField), findsNothing);
      },
    );

    testWidgets(
      'a question about a row the list no longer shows is still asked, '
      'above the list',
      (tester) async {
        final pr = openPr(12).ref;
        when(
          () => service.link(taskId: taskId, ref: pr),
        ).thenAnswer((_) async => PullRequestLinkedElsewhere({'other'}, pr));
        var listings = 0;
        await open(
          tester,
          repo: repository,
          listing: () async => OpenPullRequestsListed([
            if (listings++ == 0) openPr(12) else openPr(15),
          ]),
        );

        await tester.tap(find.byKey(LinkPullRequestKeys.openPullRequest(12)));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        ProviderScope.containerOf(
          tester.element(find.byKey(LinkPullRequestKeys.urlField)),
        ).invalidate(openPullRequestsProvider(repository));
        await tester.pump();
        await tester.pump();

        expect(
          find.byKey(LinkPullRequestKeys.openPullRequest(12)),
          findsNothing,
        );
        expect(
          tester.getTopLeft(find.byKey(LinkPullRequestKeys.linkHereToo)).dy,
          lessThan(
            tester.getTopLeft(find.text('Or pick one from penguin/colony')).dy,
          ),
        );
        // No row left to say which one: the question names it, so it is
        // not read as being about the row now under it.
        expect(find.text('penguin/colony#12'), findsOneWidget);
      },
    );

    testWidgets(
      "a question about a pick outlives the category's repository: asked "
      'under the field, named, and still answerable',
      (tester) async {
        final pr = openPr(12).ref;
        when(
          () => service.link(taskId: taskId, ref: pr),
        ).thenAnswer((_) async => PullRequestLinkedElsewhere({'other'}, pr));
        when(
          () => service.link(taskId: taskId, ref: pr, alsoElsewhere: true),
        ).thenAnswer((_) async => PullRequestLinked(prEntry(clock: {'a': 1})));
        final repositories = StreamController<GitHubRepository?>();
        addTearDown(repositories.close);
        repositories.add(repository);
        await open(
          tester,
          repositories: repositories.stream,
          listing: () async => OpenPullRequestsListed([openPr(12)]),
        );
        await tester.tap(find.byKey(LinkPullRequestKeys.openPullRequest(12)));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // A sync removes the repository from the category: the picker goes.
        repositories.add(null);
        await tester.pump();
        await tester.pump();

        expect(
          find.byKey(LinkPullRequestKeys.openPullRequest(12)),
          findsNothing,
        );
        expect(find.text('penguin/colony#12'), findsOneWidget);

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
      "a failed pick outlives the category's repository too: its reason "
      'is said under the field, named',
      (tester) async {
        final pr = openPr(12).ref;
        when(
          () => service.link(taskId: taskId, ref: pr),
        ).thenAnswer((_) async => const PullRequestLinkNotStored());
        final repositories = StreamController<GitHubRepository?>();
        addTearDown(repositories.close);
        repositories.add(repository);
        await open(
          tester,
          repositories: repositories.stream,
          listing: () async => OpenPullRequestsListed([openPr(12)]),
        );
        await tester.tap(find.byKey(LinkPullRequestKeys.openPullRequest(12)));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        repositories.add(null);
        await tester.pump();
        await tester.pump();

        final reason = find.text('The link could not be saved. Try again.');
        expect(reason, findsOneWidget);
        expect(
          tester.getTopLeft(reason).dy,
          greaterThan(tester.getBottomLeft(find.text('penguin/colony#12')).dy),
        );
      },
    );

    testWidgets('says when nothing is left to link', (tester) async {
      await open(tester, repo: repository);

      expect(
        find.text('No open pull request in penguin/colony is left to link.'),
        findsOneWidget,
      );
      // No heading inviting a pick from a list that is not there.
      expect(find.text('Or pick one from penguin/colony'), findsNothing);
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

      // Rows in outline, not a spinner: the list's shape arrives first.
      expect(find.byType(DesignSystemSkeleton), findsWidgets);
      expect(
        find.bySemanticsLabel('Loading open pull requests'),
        findsOneWidget,
      );
      pending.complete(const OpenPullRequestsListed([]));
      await tester.pump();
    });

    testWidgets('a pull request shows its size once it is known', (
      tester,
    ) async {
      await open(
        tester,
        repo: repository,
        listing: () async => OpenPullRequestsListed([openPr(12), openPr(15)]),
        sizes: const {12: (additions: 86, deletions: 12)},
      );
      await tester.pump();

      // As a screen reader hears it: the size's spoken label stands in for
      // its signs. #15's size is not known: its line ends at its age.
      expect(
        find.textContaining('86 lines added, 12 removed', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('lines added', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets(
      'the row being linked keeps its strength and shows progress, while '
      'the others step back',
      (tester) async {
        final ref12 = openPr(12).ref;
        when(
          () => service.link(taskId: taskId, ref: ref12),
        ).thenAnswer((_) => Completer<PullRequestLinkResult>().future);
        await open(
          tester,
          repo: repository,
          listing: () async => OpenPullRequestsListed([openPr(12), openPr(15)]),
        );

        await tester.tap(find.byKey(LinkPullRequestKeys.openPullRequest(12)));
        await tester.pump();

        DesignSystemListItem row(int number) => tester.widget(
          find.byKey(LinkPullRequestKeys.openPullRequest(number)),
        );
        expect(row(12).activated, isTrue);
        expect(row(12).onTap, isNotNull, reason: 'not faded as disabled');
        expect(row(15).onTap, isNull);
        expect(
          find.descendant(
            of: find.byKey(LinkPullRequestKeys.openPullRequest(12)),
            matching: find.byType(DesignSystemSpinner),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'while what was pasted links, every row steps back instead of looking '
      'live',
      (tester) async {
        when(
          () => service.linkPasted(
            taskId: taskId,
            input: any(named: 'input'),
          ),
        ).thenAnswer((_) => Completer<PullRequestLinkResult>().future);
        await open(
          tester,
          repo: repository,
          listing: () async => OpenPullRequestsListed([openPr(12), openPr(15)]),
        );

        await submit(tester, url);

        for (final number in [12, 15]) {
          final row = tester.widget<DesignSystemListItem>(
            find.byKey(LinkPullRequestKeys.openPullRequest(number)),
          );
          expect(row.onTap, isNull, reason: '#$number');
          expect(row.activated, isFalse, reason: '#$number');
        }
      },
    );

    testWidgets(
      'a row says a tap links in the action ink, and steps back with the '
      'rows while something else links',
      (tester) async {
        final pending = Completer<PullRequestLinkResult>();
        when(
          () => service.linkPasted(taskId: taskId, input: url),
        ).thenAnswer((_) => pending.future);
        await open(
          tester,
          repo: repository,
          listing: () async => OpenPullRequestsListed([openPr(12)]),
        );
        final row = find.byKey(LinkPullRequestKeys.openPullRequest(12));
        final colors = tester.element(row).designTokens.colors;
        Color? glyph() => tester
            .widget<Icon>(
              find.descendant(of: row, matching: find.byIcon(LottiIcons.link)),
            )
            .color;

        // At rest, not on hover: a phone has no pointer to light it.
        expect(glyph(), colors.interactive.enabled);

        await submit(tester, url);
        expect(glyph(), colors.text.lowEmphasis);

        pending.complete(const PullRequestLinkNotStored());
        await tester.pump();
        expect(glyph(), colors.interactive.enabled);
      },
    );
  });
}
