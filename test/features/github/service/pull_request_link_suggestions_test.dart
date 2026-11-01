import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/github/github_repository.dart';
import 'package:lotti/classes/github/pull_request_ref.dart';
import 'package:lotti/features/agents/model/pull_request_link_source.dart';
import 'package:lotti/features/github/api/github_client.dart';
import 'package:lotti/features/github/domain/open_pull_request.dart';
import 'package:lotti/features/github/service/pull_request_link_suggestions.dart';
import 'package:lotti/features/github/service/pull_request_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../pull_request_fixtures.dart';

void main() {
  const taskId = 'task-1';
  const colony = GitHubRepository(owner: 'penguin', repo: 'colony');
  const ref = PullRequestRef(owner: 'penguin', repo: 'colony', number: 7);
  late MockPullRequestRepository entries;
  late MockPullRequestService service;
  late bool hasToken;

  setUpAll(() {
    registerFallbackValue(colony);
    registerFallbackValue(ref);
  });

  setUp(() {
    entries = MockPullRequestRepository();
    service = MockPullRequestService();
    hasToken = true;
    when(
      () => entries.repositoryOfTask(taskId),
    ).thenAnswer((_) async => colony);
  });

  PullRequestLinkSuggestions subject() => PullRequestLinkSuggestions(
    repository: entries,
    service: service,
    hasToken: () async => hasToken,
  );

  group('canListFor', () {
    test('needs a token and a repository, and asks GitHub nothing', () async {
      expect(await subject().canListFor(taskId), isTrue);

      when(
        () => entries.repositoryOfTask(taskId),
      ).thenAnswer((_) async => null);
      expect(await subject().canListFor(taskId), isFalse);

      hasToken = false;
      expect(await subject().canListFor(taskId), isFalse);
      verifyZeroInteractions(service);
    });
  });

  group('unlinkedFor', () {
    test("lists the picker's pull requests with what the agent matches "
        'on', () async {
      final opened = DateTime.utc(2026, 10, 30);
      when(() => service.openPullRequests(colony)).thenAnswer(
        (_) async => OpenPullRequestsListed([
          OpenPullRequest(
            ref: ref,
            title: 'Count igloos',
            createdAt: opened,
            authorLogin: 'pingu',
            draft: true,
            body: 'Walks the floe.',
            labels: const ['ice'],
            headRef: 'feat/igloos',
          ),
        ]),
      );

      final result = await subject().unlinkedFor(taskId);

      final listed = result as UnlinkedPullRequestsListed;
      expect(listed.repository, 'penguin/colony');
      final pr = listed.pullRequests.single;
      expect(
        (
          pr.owner,
          pr.repo,
          pr.number,
          pr.title,
          pr.createdAt,
          pr.body,
          pr.headRef,
          pr.authorLogin,
          pr.draft,
        ),
        (
          'penguin',
          'colony',
          7,
          'Count igloos',
          opened,
          'Walks the floe.',
          'feat/igloos',
          'pingu',
          true,
        ),
      );
      expect(pr.labels, ['ice']);
    });

    test('says so when the category names no repository', () async {
      when(
        () => entries.repositoryOfTask(taskId),
      ).thenAnswer((_) async => null);

      final result = await subject().unlinkedFor(taskId);

      expect(
        (result as UnlinkedPullRequestsUnavailable).reason,
        contains('no GitHub repository'),
      );
      verifyZeroInteractions(service);
    });

    final retryAt = DateTime.utc(2026, 11, 1, 12);
    for (final (kind, expected) in [
      (GitHubFailureKind.noToken, 'holds no GitHub token'),
      (GitHubFailureKind.offline, 'cannot be reached'),
      (GitHubFailureKind.unauthorized, 'rejected the token'),
      (GitHubFailureKind.forbidden, 'may not read this repository'),
      (GitHubFailureKind.rateLimited, 'until 2026-11-01T12:00:00.000Z'),
      (GitHubFailureKind.notFound, 'was not found'),
      (GitHubFailureKind.server, 'server error'),
      (GitHubFailureKind.invalidResponse, 'unreadable'),
    ]) {
      test('a failed listing says why: ${kind.name}', () async {
        when(() => service.openPullRequests(colony)).thenAnswer(
          (_) async => OpenPullRequestsFailed(kind, retryAt: retryAt),
        );

        final result = await subject().unlinkedFor(taskId);

        expect(
          (result as UnlinkedPullRequestsUnavailable).reason,
          contains(expected),
        );
      });
    }

    test('a rate limit without a reset time says no time', () async {
      when(() => service.openPullRequests(colony)).thenAnswer(
        (_) async =>
            const OpenPullRequestsFailed(GitHubFailureKind.rateLimited),
      );

      expect(
        ((await subject().unlinkedFor(taskId))
                as UnlinkedPullRequestsUnavailable)
            .reason,
        'GitHub rate-limited this device.',
      );
    });
  });

  group('link', () {
    void links(PullRequestLinkResult result) => when(
      () => service.link(taskId: taskId, ref: ref),
    ).thenAnswer((_) async => result);

    Future<PullRequestLinkConfirmation> confirm() => subject().link(
      taskId: taskId,
      owner: 'penguin',
      repo: 'colony',
      number: 7,
    );

    test('links through the service the picker uses', () async {
      links(PullRequestLinked(prEntry(clock: {'a': 1})));

      final result = await confirm();

      expect(result, isA<PullRequestLinkSucceeded>());
      expect((result as PullRequestLinkSucceeded).alreadyLinked, isFalse);
      verify(() => service.link(taskId: taskId, ref: ref)).called(1);
    });

    test('one this task holds already is linked, as wanted', () async {
      links(const PullRequestAlreadyLinked());

      final result = await confirm();

      expect((result as PullRequestLinkSucceeded).alreadyLinked, isTrue);
    });

    test('one another task took meanwhile is refused, never linked '
        'twice', () async {
      links(const PullRequestLinkedElsewhere({'other-task'}, ref));

      final result = await confirm();

      expect(
        (result as PullRequestLinkRefused).reason,
        contains('penguin/colony#7 is linked to another task'),
      );
      verifyNever(
        () => service.link(
          taskId: any(named: 'taskId'),
          ref: any(named: 'ref'),
          alsoElsewhere: true,
        ),
      );
    });

    test('a GitHub failure is refused with its reason', () async {
      links(const PullRequestLinkFailed(GitHubFailureKind.notFound));

      expect(
        ((await confirm()) as PullRequestLinkRefused).reason,
        contains('was not found'),
      );
    });

    test('an entry that could not be stored is refused', () async {
      links(const PullRequestLinkNotStored());

      expect(
        ((await confirm()) as PullRequestLinkRefused).reason,
        'penguin/colony#7 could not be linked.',
      );
    });
  });
}
