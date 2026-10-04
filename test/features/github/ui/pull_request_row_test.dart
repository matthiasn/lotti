import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/pull_request_data.dart';
import 'package:lotti/features/github/api/github_client.dart';
import 'package:lotti/features/github/domain/pull_request_summary.dart';
import 'package:lotti/features/github/service/pull_request_service.dart';
import 'package:lotti/features/github/state/github_providers.dart';
import 'package:lotti/features/github/ui/pull_request_details_modal.dart';
import 'package:lotti/features/github/ui/pull_request_row.dart';
import 'package:lotti/l10n/app_localizations_en.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../pull_request_fixtures.dart';

void main() {
  final messages = AppLocalizationsEn();
  final now = prFixtureEpoch.add(const Duration(minutes: 3));

  List<String> words(
    PullRequestSnapshot? snapshot, {
    PullRequestRefreshFailed? failure,
  }) => [
    for (final (word, _) in pullRequestStatusParts(
      messages,
      snapshot: snapshot,
      failure: failure,
      now: now,
    ))
      word,
  ];

  group('pullRequestStatusParts', () {
    test(
      'an open pull request: status and its age first, so a narrow row '
      'never cuts the age off, then checks, mergeability and reviews',
      () {
        final snapshot = prSnapshot(checks: PullRequestCheckRollup.failing)
            .copyWith(
              checks: const PullRequestChecks(
                rollup: PullRequestCheckRollup.failing,
                failed: 2,
              ),
              mergeability: PullRequestMergeability.conflicting,
              reviews: const PullRequestReviews(
                decision: PullRequestReviewDecision.changesRequested,
              ),
            );
        expect(words(snapshot), [
          'Open',
          '3 min ago',
          '2 checks failing',
          'Merge conflicts',
          'Changes requested',
        ]);
      },
    );

    test('tones back up the words: good, attention and bad', () {
      final parts = pullRequestStatusParts(
        messages,
        snapshot: prSnapshot(checks: PullRequestCheckRollup.passing).copyWith(
          mergeability: PullRequestMergeability.behind,
          reviews: const PullRequestReviews(
            decision: PullRequestReviewDecision.approved,
          ),
        ),
        failure: null,
        now: now,
      );
      expect(parts, [
        ('Open', PullRequestTone.neutral),
        ('3 min ago', PullRequestTone.neutral),
        ('Checks passing', PullRequestTone.neutral),
        ('Behind base branch', PullRequestTone.attention),
        ('Approved', PullRequestTone.neutral),
      ]);
    });

    test(
      'check runs the token cannot read are flagged on an open pull request, '
      'and passing statuses alone never read as passing',
      () {
        const hidden = PullRequestChecks(
          total: 1,
          passed: 1,
          checkRunsHidden: true,
        );
        final parts = pullRequestStatusParts(
          messages,
          snapshot: prSnapshot().copyWith(checks: hidden),
          failure: null,
          now: now,
        );
        expect(parts, [
          ('Open', PullRequestTone.neutral),
          ('3 min ago', PullRequestTone.neutral),
          (
            'CI may be incomplete: the token cannot read checks',
            PullRequestTone.attention,
          ),
        ]);

        final merged = prSnapshot().copyWith(
          status: PullRequestStatus.merged,
          checks: hidden,
        );
        expect(
          words(merged),
          isNot(contains('CI may be incomplete: the token cannot read checks')),
        );
      },
    );

    test(
      'a draft, with checks running and a review requested: "blocked" is '
      'not shown, since it only repeats the missing review or check',
      () {
        final snapshot = prSnapshot().copyWith(
          draft: true,
          mergeability: PullRequestMergeability.blocked,
          reviews: const PullRequestReviews(
            decision: PullRequestReviewDecision.pending,
          ),
        );
        expect(words(snapshot), [
          'Draft',
          '3 min ago',
          'Checks running',
          'Review requested',
        ]);
      },
    );

    test(
      '"blocked" shows when checks pass and the review is settled: then a '
      'branch rule the line cannot name is in the way, and it is the only '
      'sign of it',
      () {
        final snapshot = prSnapshot(checks: PullRequestCheckRollup.passing)
            .copyWith(
              mergeability: PullRequestMergeability.blocked,
              reviews: const PullRequestReviews(
                decision: PullRequestReviewDecision.approved,
              ),
            );
        expect(
          pullRequestStatusParts(
            messages,
            snapshot: snapshot,
            failure: null,
            now: now,
          ),
          [
            ('Open', PullRequestTone.neutral),
            ('3 min ago', PullRequestTone.neutral),
            ('Checks passing', PullRequestTone.neutral),
            ('Blocked by branch rules', PullRequestTone.attention),
            ('Approved', PullRequestTone.neutral),
          ],
        );
        // No checks reported and no review asked for explain nothing either.
        expect(
          words(
            snapshot.copyWith(
              checks: const PullRequestChecks(),
              reviews: const PullRequestReviews(),
            ),
          ),
          contains('Blocked by branch rules'),
        );
        // Failing checks explain it, as running checks and an outstanding
        // review do.
        expect(
          words(
            snapshot.copyWith(
              checks: const PullRequestChecks(
                rollup: PullRequestCheckRollup.failing,
                failed: 1,
              ),
            ),
          ),
          isNot(contains('Blocked by branch rules')),
        );
        expect(
          words(
            snapshot.copyWith(
              reviews: const PullRequestReviews(
                decision: PullRequestReviewDecision.changesRequested,
              ),
            ),
          ),
          isNot(contains('Blocked by branch rules')),
        );
      },
    );

    test(
      'two pull requests read at the same moment show when each was opened, '
      'not when they were linked or read',
      () {
        final yesterday = prSnapshot(
          createdAt: now.subtract(const Duration(days: 1, hours: 2)),
        );
        final thisMorning = prSnapshot(
          createdAt: now.subtract(const Duration(hours: 5)),
        );
        expect(yesterday.observedAt, thisMorning.observedAt);

        expect(words(yesterday).take(2), ['Open', '1 day ago']);
        expect(words(thisMorning).take(2), ['Open', '5 h ago']);
      },
    );

    test(
      'a pull request opened over a week ago names the weekday and date '
      'instead',
      () async {
        await initializeDateFormatting('en');
        final opened = now.subtract(const Duration(days: 30));
        expect(
          words(prSnapshot(createdAt: opened))[1],
          DateFormat.MMMEd('en').format(opened.toLocal()),
        );
      },
    );

    test(
      'merged and closed pull requests show only their state and when they '
      'entered it',
      () {
        final merged =
            prSnapshot(
              status: PullRequestStatus.merged,
              checks: PullRequestCheckRollup.failing,
            ).copyWith(
              mergeability: PullRequestMergeability.conflicting,
              mergedAt: now.subtract(const Duration(hours: 2)),
            );
        expect(words(merged), ['Merged', '2 h ago']);
        expect(
          words(
            prSnapshot(status: PullRequestStatus.closed).copyWith(
              closedAt: now.subtract(const Duration(days: 2)),
            ),
          ),
          ['Closed', '2 days ago'],
        );
      },
    );

    test(
      'a snapshot stored before it carried the opening shows no age until '
      'its next refresh',
      () {
        expect(words(prSnapshot().copyWith(createdAt: null)), [
          'Open',
          'Checks running',
        ]);
        expect(words(prSnapshot(status: PullRequestStatus.merged)), [
          'Merged',
        ]);
      },
    );

    test(
      'the size follows the age, its two halves added and removed, on '
      'every state; none before GitHub reported it',
      () {
        for (final status in PullRequestStatus.values) {
          final parts = pullRequestStatusParts(
            messages,
            snapshot: prSnapshot(status: status).copyWith(
              additions: 444,
              deletions: 221,
              mergedAt: prFixtureEpoch,
              closedAt: prFixtureEpoch,
            ),
            failure: null,
            now: now,
          );
          expect(parts.sublist(1, 4), [
            ('3 min ago', PullRequestTone.neutral),
            ('+444', PullRequestTone.added),
            ('−221', PullRequestTone.removed),
          ], reason: status.name);
        }
        expect(words(prSnapshot()), isNot(contains(startsWith('+'))));
      },
    );

    test('a failed refresh says so, after the age', () {
      expect(
        words(
          prSnapshot(status: PullRequestStatus.closed).copyWith(
            closedAt: now.subtract(const Duration(minutes: 3)),
          ),
          failure: const PullRequestRefreshFailed(GitHubFailureKind.offline),
        ),
        ['Closed', '3 min ago', 'Could not refresh'],
      );
    });

    test(
      'other tasks holding the pull request lead the line, observed or not, '
      'as something to look at rather than an error',
      () {
        List<(String, PullRequestTone)> flagged(
          PullRequestSnapshot? snapshot,
          List<String?> alsoLinkedTo,
        ) => pullRequestStatusParts(
          messages,
          snapshot: snapshot,
          failure: null,
          now: now,
          alsoLinkedTo: alsoLinkedTo,
        );

        expect(
          flagged(prSnapshot(), ['Teach the chicks']).first,
          ('Also linked to “Teach the chicks”', PullRequestTone.attention),
        );
        // A task private mode hides is counted, never named.
        expect(
          flagged(prSnapshot(), [null]).first,
          ('Also linked to another task', PullRequestTone.attention),
        );
        expect(
          flagged(prSnapshot(), ['Teach the chicks', null]).first.$1,
          'Also linked to 2 other tasks',
        );
        expect(
          [
            for (final (word, _) in flagged(null, [null])) word,
          ],
          [
            'Also linked to another task',
            'Not refreshed yet',
          ],
        );
      },
    );

    test('before any observation there is nothing to claim', () {
      expect(words(null), ['Not refreshed yet']);
      expect(
        words(
          null,
          failure: const PullRequestRefreshFailed(GitHubFailureKind.offline),
        ),
        ['Could not refresh'],
      );
    });
  });

  group('PullRequestRow', () {
    late MockPullRequestService service;
    late MockPullRequestRepository repository;

    setUpAll(() {
      registerFallbackValue(prEntry(clock: {'a': 1}));
    });

    setUp(() {
      service = MockPullRequestService();
      repository = MockPullRequestRepository();
    });

    Future<void> pump(
      WidgetTester tester,
      PullRequestEntry entry, {
      Set<String> holders = const {'task-1'},
      Map<String, String> titles = const {},
      PullRequestSummary? summary,
    }) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          PullRequestRow(taskId: 'task-1', entry: entry),
          overrides: [
            pullRequestServiceProvider.overrideWithValue(service),
            pullRequestRepositoryProvider.overrideWithValue(repository),
            pullRequestHoldersProvider.overrideWith(
              (ref, pr) => Stream.value(holders),
            ),
            pullRequestHolderTitleProvider.overrideWith(
              (ref, id) => Stream.value(titles[id]),
            ),
            pullRequestSummaryProvider.overrideWith(
              (ref, id) => Stream.value(summary),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets(
      'shows number, title and status, and leaves a fresh pull request alone',
      (tester) async {
        final entry = prEntry(clock: {'a': 1}, snapshot: prSnapshot());
        await withClock(Clock.fixed(now), () => pump(tester, entry));

        expect(find.text('#42 Track pull requests'), findsOneWidget);
        expect(
          find.textContaining('Checks running', findRichText: true),
          findsOneWidget,
        );
        expect(
          find.textContaining('3 min ago', findRichText: true),
          findsOneWidget,
        );
        verifyNever(() => service.refresh(any()));
      },
    );

    testWidgets(
      'the age moves on by itself, with nothing refreshed or re-linked',
      (tester) async {
        final opened = clock.now().subtract(const Duration(seconds: 50));
        final entry = prEntry(
          clock: {'a': 1},
          snapshot: prSnapshot(
            createdAt: opened,
          ).copyWith(observedAt: clock.now()),
        );
        await pump(tester, entry);
        expect(
          find.textContaining('just now', findRichText: true),
          findsOneWidget,
        );

        await tester.pump(const Duration(seconds: 15));

        expect(
          find.textContaining('1 min ago', findRichText: true),
          findsOneWidget,
        );
        verifyNever(() => service.refresh(any()));
      },
    );

    testWidgets(
      'opening a stale pull request refreshes it, and shows what GitHub '
      'reported even when nothing had to be written',
      (tester) async {
        final entry = prEntry(clock: {'a': 1}, snapshot: prSnapshot());
        final later = now.add(const Duration(hours: 1));
        when(() => service.refresh(entry)).thenAnswer(
          (_) async => PullRequestRefreshed(
            prSnapshot(
              second: 3600 + 170,
              status: PullRequestStatus.merged,
            ).copyWith(
              mergedAt: prFixtureEpoch.add(const Duration(seconds: 3600 + 160)),
            ),
          ),
        );

        await withClock(Clock.fixed(later), () => pump(tester, entry));

        verify(() => service.refresh(entry)).called(1);
        expect(
          find.textContaining('Merged', findRichText: true),
          findsOneWidget,
        );
        expect(
          find.textContaining('just now', findRichText: true),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'a manual refresh that fails says why, and the row says it is not '
      'current',
      (tester) async {
        final entry = prEntry(clock: {'a': 1}, snapshot: prSnapshot());
        when(() => service.refresh(entry)).thenAnswer(
          (_) async =>
              const PullRequestRefreshFailed(GitHubFailureKind.unauthorized),
        );

        await withClock(Clock.fixed(now), () async {
          await pump(tester, entry);
          // Refresh lives in the row's menu.
          await tester.tap(
            find.byKey(ValueKey('pull-request-menu-${entry.id}')),
          );
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
          await tester.tap(find.text('Refresh pull request'));
          await tester.pump(const Duration(seconds: 1));
          await tester.pump();
        });

        expect(
          find.text(
            'GitHub rejected the token. It may have expired or been revoked.',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining('Could not refresh', findRichText: true),
          findsOneWidget,
        );
        // Let the toast's countdown run out on fake time.
        await tester.pump(const Duration(seconds: 10));
      },
    );

    testWidgets(
      'a pull request another task holds too is flagged, first in the line',
      (tester) async {
        final entry = prEntry(clock: {'a': 1}, snapshot: prSnapshot());

        await withClock(
          Clock.fixed(now),
          () => pump(tester, entry, holders: {'task-1', 'task-2'}),
        );

        final flagged = find.textContaining(
          'Also linked to another task ·\u00A0Open',
          findRichText: true,
        );
        expect(flagged, findsOneWidget);
      },
    );

    testWidgets(
      'the other task is named when the viewer may see it, whether the user '
      'linked it there on purpose or another device did',
      (tester) async {
        final entry = prEntry(clock: {'a': 1}, snapshot: prSnapshot());

        await withClock(
          Clock.fixed(now),
          () => pump(
            tester,
            entry,
            holders: {'task-1', 'task-2'},
            titles: {'task-2': 'Teach the chicks'},
          ),
        );

        expect(
          find.textContaining(
            'Also linked to “Teach the chicks” ·\u00A0Open',
            findRichText: true,
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('a pull request only this task holds is not flagged', (
      tester,
    ) async {
      final entry = prEntry(clock: {'a': 1}, snapshot: prSnapshot());

      await withClock(Clock.fixed(now), () => pump(tester, entry));

      expect(
        find.textContaining('Also linked to another task', findRichText: true),
        findsNothing,
      );
    });

    testWidgets('unlink from the menu unlinks the entry', (tester) async {
      final entry = prEntry(clock: {'a': 1}, snapshot: prSnapshot());
      when(
        () => repository.unlink(taskId: 'task-1', ref: entry.data.ref),
      ).thenAnswer((_) async => true);

      await withClock(Clock.fixed(now), () async {
        await pump(tester, entry);
        await tester.tap(find.byKey(ValueKey('pull-request-menu-${entry.id}')));
        // The menu ignores taps until it has finished opening.
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Unlink pull request'), findsOneWidget);
        await tester.tap(find.text('Unlink pull request'));
        // onSelected runs once the menu's close animation has finished.
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      });

      verify(
        () => repository.unlink(taskId: 'task-1', ref: entry.data.ref),
      ).called(1);
    });

    testWidgets(
      'the one-liner of its summary is the subtitle, above the status line '
      'with its size, which reads as one',
      (tester) async {
        final entry = prEntry(
          clock: {'a': 1},
          snapshot: prSnapshot().copyWith(additions: 444, deletions: 221),
        );
        await withClock(
          Clock.fixed(now),
          () => pump(
            tester,
            entry,
            summary: const PullRequestSummary(
              oneLiner: 'Tracks pull requests on tasks.',
              tldr: 'More.',
            ),
          ),
        );

        final line = tester
            .widgetList<RichText>(find.byType(RichText))
            .map((r) => r.text.toPlainText(includeSemanticsLabels: false))
            .firstWhere((text) => text.contains('Open'));
        expect(
          line,
          'Tracks pull requests on tasks.\n'
          // Each dot bound to the part it introduces, and the size to
          // itself: a wrapping line never ends on a dot or splits the size.
          // The size ends the first line; checks and reviews start the next.
          'Open ·\u00A03 min ago ·\u00A0+444\u00A0−221\nChecks running',
        );
        expect(
          find.textContaining(
            '444 lines added, 221 removed',
            findRichText: true,
          ),
          findsOneWidget,
          reason: 'a screen reader says what the signs mean',
        );
      },
    );

    testWidgets('no subtitle before a summary is written', (tester) async {
      final entry = prEntry(clock: {'a': 1}, snapshot: prSnapshot());
      await withClock(Clock.fixed(now), () => pump(tester, entry));

      final line = tester
          .widgetList<RichText>(find.byType(RichText))
          .map((r) => r.text.toPlainText(includeSemanticsLabels: false))
          .firstWhere((text) => text.contains('Open'));
      expect(line, 'Open ·\u00A03 min ago ·\u00A0Checks running');
    });

    testWidgets('the menu opens the pull request on GitHub', (tester) async {
      final launcher = MockUrlLauncher();
      final original = UrlLauncherPlatform.instance;
      UrlLauncherPlatform.instance = launcher;
      addTearDown(() => UrlLauncherPlatform.instance = original);
      registerFallbackValue(FakeLaunchOptions());
      when(
        () => launcher.launchUrl(any(), any()),
      ).thenAnswer((_) async => true);
      final entry = prEntry(clock: {'a': 1}, snapshot: prSnapshot());
      await withClock(Clock.fixed(now), () async {
        await pump(tester, entry);
        await tester.tap(find.byKey(ValueKey('pull-request-menu-${entry.id}')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open on GitHub'));
        await tester.pumpAndSettle();
      });

      verify(
        () => launcher.launchUrl(
          'https://github.com/matthiasn/lotti/pull/42',
          any(),
        ),
      ).called(1);
    });

    testWidgets('tapping the row opens its details', (tester) async {
      final entry = prEntry(clock: {'a': 1}, snapshot: prSnapshot());
      await withClock(Clock.fixed(now), () async {
        await pump(tester, entry);
        await tester.tap(find.text('#42 Track pull requests'));
        await tester.pumpAndSettle();
      });

      expect(find.byType(PullRequestDetails), findsOneWidget);
      expect(find.text('matthiasn/lotti'), findsOneWidget);
    });

    testWidgets(
      'before the first observation the row names the pull request by '
      'its reference',
      (tester) async {
        final entry = prEntry(clock: {'a': 1});
        when(() => service.refresh(entry)).thenAnswer(
          (_) async =>
              const PullRequestRefreshFailed(GitHubFailureKind.offline),
        );

        await withClock(Clock.fixed(now), () => pump(tester, entry));

        expect(find.text('matthiasn/lotti#42'), findsOneWidget);
        expect(
          find.textContaining('Could not refresh', findRichText: true),
          findsOneWidget,
        );
      },
    );
  });
}
