import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/pull_request_data.dart';
import 'package:lotti/features/github/api/github_client.dart';
import 'package:lotti/features/github/context/pull_request_context_renderer.dart';
import 'package:lotti/features/github/context/pull_request_context_service.dart';
import 'package:lotti/features/github/domain/pull_request_summary.dart';
import 'package:lotti/features/github/service/pull_request_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../pull_request_fixtures.dart';

void main() {
  const taskId = 'task-1';
  late MockPullRequestRepository repository;
  late MockPullRequestService service;
  late bool hasToken;

  final stored = prEntry(clock: {'a': 1}, snapshot: prSnapshot());

  setUpAll(() => registerFallbackValue(stored));

  setUp(() {
    repository = MockPullRequestRepository();
    service = MockPullRequestService();
    hasToken = true;
    when(() => repository.forTask(taskId)).thenAnswer((_) async => [stored]);
    when(() => repository.liveEntry(stored.id)).thenAnswer((_) async => stored);
    when(
      () => repository.summaryOf(any(), any()),
    ).thenAnswer((_) async => null);
  });

  PullRequestContextService subject() => PullRequestContextService(
    repository: repository,
    service: service,
    hasToken: () async => hasToken,
  );

  void refreshes(PullRequestRefresh result) =>
      when(() => service.refresh(stored)).thenAnswer((_) async => result);

  test('asks nothing of GitHub while this device holds no token', () async {
    hasToken = false;

    expect(await subject().forTask(taskId), isEmpty);
    verifyZeroInteractions(service);
    verifyNever(() => repository.forTask(any()));
  });

  test(
    'a successful refresh makes the item current, with what it read',
    () async {
      final read = prSnapshot(
        second: 60,
        checks: PullRequestCheckRollup.passing,
      );
      refreshes(PullRequestRefreshed(read));

      final [item] = await subject().forTask(taskId);

      expect(item.current, isTrue);
      expect(item.snapshot, read);
      expect(item.failure, isNull);
      expect(item.ref, stored.data.ref);
    },
  );

  test(
    'a stored observation from a later second, synced in during the '
    'refresh, wins over the read',
    () async {
      final read = prSnapshot(second: 60);
      final synced = prSnapshot(second: 61, status: PullRequestStatus.merged);
      refreshes(PullRequestRefreshed(read));
      when(() => repository.liveEntry(stored.id)).thenAnswer(
        (_) async => stored.copyWith(
          data: stored.data.copyWith(snapshot: synced),
        ),
      );

      final [item] = await subject().forTask(taskId);

      expect(item.snapshot, synced);
      expect(item.current, isTrue);
    },
  );

  test(
    'a stored observation from the same second is not provably later, so '
    'the read stands, whatever the digest says (PreferOwnRead)',
    () async {
      final read = prSnapshot(
        second: 60,
        checks: PullRequestCheckRollup.failing,
      );
      final sameSecond = prSnapshot(
        second: 60,
        checks: PullRequestCheckRollup.passing,
      );
      refreshes(PullRequestRefreshed(read));
      when(() => repository.liveEntry(stored.id)).thenAnswer(
        (_) async => stored.copyWith(
          data: stored.data.copyWith(snapshot: sameSecond),
        ),
      );

      final [item] = await subject().forTask(taskId);

      expect(item.snapshot, read);
    },
  );

  test('a failed refresh offers the stored snapshot, not current', () async {
    refreshes(const PullRequestRefreshFailed(GitHubFailureKind.unauthorized));

    final [item] = await subject().forTask(taskId);

    expect(item.current, isFalse);
    expect(item.failure, GitHubFailureKind.unauthorized);
    expect(item.snapshot, stored.data.snapshot);
  });

  test('a refresh that outlasts the timeout is not waited for', () {
    fakeAsync((async) {
      final pending = Completer<PullRequestRefresh>();
      when(() => service.refresh(stored)).thenAnswer((_) => pending.future);
      List<PullRequestContextItem>? items;
      subject().forTask(taskId).then((value) => items = value);

      async.elapse(const Duration(seconds: 7));
      expect(items, isNull);
      async.elapse(const Duration(seconds: 2));

      expect(items?.single.current, isFalse);
      expect(items?.single.failure, GitHubFailureKind.offline);
      pending.complete(PullRequestRefreshed(prSnapshot(second: 60)));
      async.flushMicrotasks();
    });
  });

  test('a pull request unlinked while it refreshed is left out', () async {
    refreshes(PullRequestRefreshed(prSnapshot(second: 60)));
    when(() => repository.liveEntry(stored.id)).thenAnswer((_) async => null);

    expect(await subject().forTask(taskId), isEmpty);

    refreshes(const PullRequestRefreshFailed(GitHubFailureKind.offline));
    expect(await subject().forTask(taskId), isEmpty);
  });

  test('contextFor renders the refreshed items for its audience', () async {
    refreshes(PullRequestRefreshed(prSnapshot(second: 60)));

    final text = await subject().contextFor(
      taskId,
      audience: PullRequestContextAudience.taskAgent,
    );

    expect(text, contains('### matthiasn/lotti#42 — Track pull requests'));
    expect(text, contains('- Current: observed 2026-03-15T12:01:00.000Z.'));
  });

  test('contextFor is empty for a task without pull requests', () async {
    when(() => repository.forTask(taskId)).thenAnswer((_) async => []);
    expect(
      await subject().contextFor(
        taskId,
        audience: PullRequestContextAudience.codingPrompt,
      ),
      isEmpty,
    );
  });

  group('summaries', () {
    const tracks = PullRequestSummary(
      oneLiner: 'Tracks pull requests.',
      tldr: 'Tracks pull requests on tasks.',
    );
    final merged = prSnapshot(
      second: 60,
      status: PullRequestStatus.merged,
    ).copyWith(body: 'Adds tracking.');

    test(
      'a merged pull request carries the summary of exactly what it read',
      () async {
        refreshes(PullRequestRefreshed(merged));
        when(
          () => repository.summaryOf(
            stored.id,
            pullRequestSummaryInput(stored.data.ref, merged),
          ),
        ).thenAnswer((_) async => tracks);

        final [item] = await subject().forTask(taskId);

        expect(item.summary, tracks);
      },
    );

    test('an open pull request carries its summary too', () async {
      final open = prSnapshot(second: 60);
      refreshes(PullRequestRefreshed(open));
      when(
        () => repository.summaryOf(
          stored.id,
          pullRequestSummaryInput(stored.data.ref, open),
        ),
      ).thenAnswer((_) async => tracks);

      final [item] = await subject().forTask(taskId);

      expect(item.summary, tracks);
    });

    test(
      'one that failed to refresh carries the summary of what is stored',
      () async {
        final storedMerged = stored.copyWith(
          data: stored.data.copyWith(snapshot: merged),
        );
        when(
          () => repository.liveEntry(stored.id),
        ).thenAnswer((_) async => storedMerged);
        refreshes(const PullRequestRefreshFailed(GitHubFailureKind.offline));
        when(
          () => repository.summaryOf(
            stored.id,
            pullRequestSummaryInput(stored.data.ref, merged),
          ),
        ).thenAnswer((_) async => tracks);

        final [item] = await subject().forTask(taskId);

        expect(item.current, isFalse);
        expect(item.summary, tracks);
      },
    );

    test('contextFor renders a merged pull request as its TL;DR', () async {
      refreshes(PullRequestRefreshed(merged));
      when(
        () => repository.summaryOf(any(), any()),
      ).thenAnswer((_) async => tracks);

      final text = await subject().contextFor(
        taskId,
        audience: PullRequestContextAudience.taskAgent,
      );

      expect(text, contains('- TL;DR: Tracks pull requests on tasks.'));
      expect(text, isNot(contains('Adds tracking.')));
    });
  });
}
