import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/pull_request_data.dart';
import 'package:lotti/features/github/domain/pull_request_summary.dart';
import 'package:lotti/features/github/service/pull_request_summarizer.dart';
import 'package:lotti/features/github/state/github_providers.dart';
import 'package:lotti/features/github/ui/pull_request_details_modal.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../pull_request_fixtures.dart';

void main() {
  const taskId = 'task-1';
  final now = prFixtureEpoch.add(const Duration(minutes: 3));
  const summary = PullRequestSummary(
    oneLiner: 'Tracks pull requests on tasks.',
    tldr: 'Links pull requests to tasks. Merged after one review round.',
  );
  final entry = prEntry(
    clock: {'a': 1},
    snapshot: prSnapshot(status: PullRequestStatus.merged).copyWith(
      mergedAt: prFixtureEpoch,
      additions: 444,
      deletions: 221,
      body: '## Why\n\nTasks should know their pull requests.',
    ),
  );

  late MockPullRequestSummarizer summarizer;

  setUpAll(() {
    registerFallbackValue(FakeLaunchOptions());
  });

  setUp(() {
    summarizer = MockPullRequestSummarizer();
  });

  Future<void> pump(
    WidgetTester tester, {
    PullRequestEntry? shown,
    PullRequestSummary? summarized = summary,
    PullRequestSummaryOutcome? blocker,
  }) async {
    await withClock(Clock.fixed(now), () async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          SingleChildScrollView(
            child: PullRequestDetails(taskId: taskId, entry: shown ?? entry),
          ),
          overrides: [
            pullRequestSummaryProvider.overrideWith(
              (ref, id) => Stream.value(summarized),
            ),
            pullRequestSummarizerProvider.overrideWithValue(summarizer),
            pullRequestAutomaticSummaryBlockerProvider.overrideWith(
              (ref, id) => Stream.value(blocker),
            ),
            pullRequestHoldersProvider.overrideWith(
              (ref, pr) => Stream.value(const {taskId}),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();
    });
  }

  testWidgets(
    'shows the title, status with size, the one-liner, the TL;DR and the '
    'description',
    (tester) async {
      await pump(tester);

      expect(find.text('#42 Track pull requests'), findsOneWidget);
      expect(
        find.textContaining(
          // As a screen reader hears it: the size's spoken label stands in
          // for its signs.
          'Merged ·\u00A03 min ago ·\u00A0444 lines added, 221 removed',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(find.text(summary.oneLiner!), findsOneWidget);
      expect(find.text('TL;DR'), findsOneWidget);
      expect(find.text(summary.tldr), findsOneWidget);
      expect(find.text('Description'), findsOneWidget);
      expect(
        find.textContaining(
          'Tasks should know their pull requests.',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(find.text('Summarize again'), findsOneWidget);
    },
  );

  testWidgets(
    'without a summary or a description it says so, and offers to summarize',
    (tester) async {
      await pump(
        tester,
        summarized: null,
        shown: entry.copyWith(
          data: entry.data.copyWith(
            snapshot: entry.data.snapshot!.copyWith(body: null),
          ),
        ),
      );

      expect(find.text('Not summarized yet.'), findsOneWidget);
      expect(
        find.text('This pull request has no description.'),
        findsOneWidget,
      );
      expect(find.text('Summarize'), findsOneWidget);
    },
  );

  for (final (blocker, why) in [
    (
      PullRequestSummaryOutcome.notAllowed,
      "Automatic summaries are off for this task's category. Tap Summarize "
          'to write one.',
    ),
    (
      PullRequestSummaryOutcome.noModel,
      "There's no model set up for this task's agent, so nothing can write "
          'the summary.',
    ),
    (
      PullRequestSummaryOutcome.coolingDown,
      "The summary couldn't be written. Try again.",
    ),
    (
      null,
      'A summary is written the next time this pull request is refreshed, '
          'or summarize it now.',
    ),
  ]) {
    testWidgets(
      'without a summary it says why: ${blocker?.name ?? 'next refresh'}',
      (tester) async {
        await pump(tester, summarized: null, blocker: blocker);

        expect(find.text('Not summarized yet.'), findsOneWidget);
        expect(find.text(why), findsOneWidget);
      },
    );
  }

  testWidgets(
    'with a summary there is no reason to give',
    (tester) async {
      await pump(tester, blocker: PullRequestSummaryOutcome.notAllowed);
      expect(
        find.textContaining('Automatic summaries are off'),
        findsNothing,
      );
    },
  );

  testWidgets('a pull request gone says only that it is not summarized', (
    tester,
  ) async {
    await pump(
      tester,
      summarized: null,
      blocker: PullRequestSummaryOutcome.missing,
    );
    expect(find.text('Not summarized yet.'), findsOneWidget);
    expect(find.textContaining('summary'), findsNothing);
  });

  for (final (outcome, toast) in [
    (PullRequestSummaryOutcome.stored, null),
    (PullRequestSummaryOutcome.upToDate, null),
    (
      PullRequestSummaryOutcome.noModel,
      "There's no model set up for this task's agent, so nothing can write "
          'the summary.',
    ),
    (
      PullRequestSummaryOutcome.failed,
      "The summary couldn't be written. Try again.",
    ),
    (PullRequestSummaryOutcome.busy, 'A summary is already being written.'),
  ]) {
    testWidgets(
      'summarizing asks as the user; ${outcome.name} '
      '${toast == null ? 'says nothing' : 'is told'}',
      (tester) async {
        when(
          () => summarizer.summarize(entry.id, manual: true),
        ).thenAnswer((_) async => outcome);
        await pump(tester);

        await tester.tap(find.byKey(PullRequestDetailsKeys.summarize));
        await tester.pump();
        await tester.pump();

        verify(() => summarizer.summarize(entry.id, manual: true)).called(1);
        if (toast == null) {
          expect(find.textContaining('summary'), findsNothing);
        } else {
          expect(find.text(toast), findsOneWidget);
        }
      },
    );
  }

  testWidgets('the row opens the details, and they open the pull request', (
    tester,
  ) async {
    final launcher = MockUrlLauncher();
    final original = UrlLauncherPlatform.instance;
    UrlLauncherPlatform.instance = launcher;
    addTearDown(() => UrlLauncherPlatform.instance = original);
    when(() => launcher.launchUrl(any(), any())).thenAnswer((_) async => true);

    await withClock(Clock.fixed(now), () async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showPullRequestDetailsModal(
                context,
                taskId: taskId,
                entry: entry,
              ),
              child: const Text('open'),
            ),
          ),
          overrides: [
            pullRequestSummaryProvider.overrideWith(
              (ref, id) => Stream.value(summary),
            ),
            pullRequestSummarizerProvider.overrideWithValue(summarizer),
            pullRequestHoldersProvider.overrideWith(
              (ref, pr) => Stream.value(const {taskId}),
            ),
          ],
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    });

    // The bar names the repository; the number leads the title.
    expect(find.text('matthiasn/lotti'), findsOneWidget);
    await tester.tap(find.byKey(PullRequestDetailsKeys.openOnGitHub));
    await tester.pump();

    verify(
      () => launcher.launchUrl(
        'https://github.com/matthiasn/lotti/pull/42',
        any(),
      ),
    ).called(1);
  });

  test('a pull request never read is opened by its reference', () {
    expect(
      pullRequestWebUrl(prEntry(clock: {'a': 1})),
      'https://github.com/matthiasn/lotti/pull/42',
    );
  });
}
