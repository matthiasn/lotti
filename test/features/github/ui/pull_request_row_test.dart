import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/pull_request_data.dart';
import 'package:lotti/features/github/api/github_client.dart';
import 'package:lotti/features/github/service/pull_request_service.dart';
import 'package:lotti/features/github/state/github_providers.dart';
import 'package:lotti/features/github/ui/pull_request_row.dart';
import 'package:lotti/l10n/app_localizations_en.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

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
      'an open pull request: status, checks, mergeability, reviews, age',
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
          '2 checks failing',
          'Merge conflicts',
          'Changes requested',
          '3 min ago',
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
        ('Checks passing', PullRequestTone.good),
        ('Behind base branch', PullRequestTone.attention),
        ('Approved', PullRequestTone.good),
        ('3 min ago', PullRequestTone.neutral),
      ]);
    });

    test('a draft, with checks running, blocked, awaiting review', () {
      final snapshot = prSnapshot().copyWith(
        draft: true,
        mergeability: PullRequestMergeability.blocked,
        reviews: const PullRequestReviews(
          decision: PullRequestReviewDecision.pending,
        ),
      );
      expect(words(snapshot), [
        'Draft',
        'Checks running',
        'Blocked by branch rules',
        'Review requested',
        '3 min ago',
      ]);
    });

    test('merged and closed pull requests show only their state and age', () {
      final merged = prSnapshot(
        status: PullRequestStatus.merged,
        checks: PullRequestCheckRollup.failing,
      ).copyWith(mergeability: PullRequestMergeability.conflicting);
      expect(words(merged), ['Merged', '3 min ago']);
      expect(
        words(prSnapshot(status: PullRequestStatus.closed)),
        ['Closed', '3 min ago'],
      );
    });

    test('a failed refresh says so, and still shows how old the data is', () {
      expect(
        words(
          prSnapshot(status: PullRequestStatus.closed),
          failure: const PullRequestRefreshFailed(GitHubFailureKind.offline),
        ),
        ['Closed', 'Could not refresh', '3 min ago'],
      );
    });

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

    Future<void> pump(WidgetTester tester, PullRequestEntry entry) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          PullRequestRow(entry: entry),
          overrides: [
            pullRequestServiceProvider.overrideWithValue(service),
            pullRequestRepositoryProvider.overrideWithValue(repository),
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
          await tester.tap(
            find.byKey(ValueKey('pull-request-refresh-${entry.id}')),
          );
          await tester.pump();
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

    testWidgets('unlink from the menu unlinks the entry', (tester) async {
      final entry = prEntry(clock: {'a': 1}, snapshot: prSnapshot());
      when(() => repository.unlink(entry.id)).thenAnswer((_) async => true);

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

      verify(() => repository.unlink(entry.id)).called(1);
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
