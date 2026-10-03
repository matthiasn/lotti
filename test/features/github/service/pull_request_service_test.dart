import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/pull_request_data.dart';
import 'package:lotti/features/github/api/github_client.dart';
import 'package:lotti/features/github/domain/github_repository.dart';
import 'package:lotti/features/github/domain/open_pull_request.dart';
import 'package:lotti/features/github/domain/pull_request_ref.dart';
import 'package:lotti/features/github/repository/pull_request_repository.dart';
import 'package:lotti/features/github/service/pull_request_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../pull_request_fixtures.dart';

void main() {
  const token = 'ghp_secret';
  const ref = PullRequestRef(owner: 'matthiasn', repo: 'lotti', number: 42);
  const url = 'https://github.com/matthiasn/lotti/pull/42';
  const taskId = 'task-1';

  late MockGitHubClient client;
  late MockGitHubTokenStorage tokens;
  late MockPullRequestRepository repository;
  late PullRequestService service;

  /// What the service told the token status about the stored token, in
  /// order: true for accepted, false for rejected.
  late List<(String, bool)> verdicts;

  setUpAll(() {
    registerFallbackValue(ref);
    registerFallbackValue(<PullRequestRef>[]);
    registerFallbackValue(prSnapshot());
  });

  setUp(() {
    client = MockGitHubClient();
    tokens = MockGitHubTokenStorage();
    repository = MockPullRequestRepository();
    verdicts = [];
    service = PullRequestService(
      client: client,
      tokenStorage: tokens,
      repository: repository,
      onTokenVerdict: (token, {required accepted}) =>
          verdicts.add((token, accepted)),
    );
    when(tokens.readToken).thenAnswer((_) async => token);
    // No task holds anything unless a case says so.
    when(() => repository.holdersOf(any())).thenAnswer((_) async => {});
  });

  void answers(PullRequestSnapshot snapshot) => when(
    () => client.fetchPullRequest(any(), token: any(named: 'token')),
  ).thenAnswer((_) async => snapshot);

  void fails(GitHubException exception) => when(
    () => client.fetchPullRequest(any(), token: any(named: 'token')),
  ).thenThrow(exception);

  group('linkPasted', () {
    test(
      'reads the pull request, then links it with that observation',
      () async {
        final entry = prEntry(clock: {'a': 1}, snapshot: prSnapshot());
        answers(prSnapshot());
        when(
          () => repository.link(
            taskId: taskId,
            ref: ref,
            snapshot: prSnapshot(),
          ),
        ).thenAnswer((_) async => PullRequestLinkAttempt(linked: entry));

        final result = await service.linkPasted(taskId: taskId, input: url);

        expect(result, isA<PullRequestLinked>());
        expect((result as PullRequestLinked).entry, entry);
        verify(() => client.fetchPullRequest(ref, token: token)).called(1);
      },
    );

    test('text that is not a pull request is rejected without asking '
        'GitHub', () async {
      final result = await service.linkPasted(
        taskId: taskId,
        input: 'https://github.com/matthiasn/lotti/issues/42',
      );

      expect(
        (result as PullRequestLinkRejected).reason,
        PullRequestRefRejection.notAPullRequest,
      );
      verifyZeroInteractions(client);
    });

    test('a pull request already on the task is not fetched again', () async {
      when(() => repository.holdersOf(any())).thenAnswer(
        (_) async => {
          ref.key: {taskId},
        },
      );

      final result = await service.linkPasted(taskId: taskId, input: url);

      expect(result, isA<PullRequestAlreadyLinked>());
      verifyZeroInteractions(client);
    });

    test(
      'a pull request another task holds is asked about before GitHub is '
      'asked, carrying what to link if the user confirms',
      () async {
        when(() => repository.holdersOf(any())).thenAnswer(
          (_) async => {
            ref.key: {'other-task'},
          },
        );

        final result = await service.link(taskId: taskId, ref: ref);

        final asked = result as PullRequestLinkedElsewhere;
        expect(asked.taskIds, {'other-task'});
        expect(asked.ref, ref);
        verifyZeroInteractions(client);
      },
    );

    test(
      'confirmed, a pull request another task holds is read and linked here '
      'too',
      () async {
        final entry = prEntry(clock: {'a': 1}, snapshot: prSnapshot());
        when(() => repository.holdersOf(any())).thenAnswer(
          (_) async => {
            ref.key: {'other-task'},
          },
        );
        answers(prSnapshot());
        when(
          () => repository.link(
            taskId: taskId,
            ref: ref,
            snapshot: prSnapshot(),
            alsoElsewhere: true,
          ),
        ).thenAnswer((_) async => PullRequestLinkAttempt(linked: entry));

        final result = await service.link(
          taskId: taskId,
          ref: ref,
          alsoElsewhere: true,
        );

        expect((result as PullRequestLinked).entry, entry);
        verify(() => client.fetchPullRequest(ref, token: token)).called(1);
      },
    );

    test(
      'confirmed or not, a pull request this task holds is refused, even '
      'when another task holds it too',
      () async {
        when(() => repository.holdersOf(any())).thenAnswer(
          (_) async => {
            ref.key: {taskId, 'other-task'},
          },
        );

        for (final alsoElsewhere in [false, true]) {
          expect(
            await service.link(
              taskId: taskId,
              ref: ref,
              alsoElsewhere: alsoElsewhere,
            ),
            isA<PullRequestAlreadyLinked>(),
          );
        }
        verifyZeroInteractions(client);
      },
    );

    test(
      'a link that loses the race says which task won: this one or another',
      () async {
        answers(prSnapshot());
        void heldBy(Set<String> tasks) => when(
          () => repository.link(
            taskId: taskId,
            ref: ref,
            snapshot: any(named: 'snapshot'),
          ),
        ).thenAnswer((_) async => PullRequestLinkAttempt(heldBy: tasks));

        heldBy({taskId});
        expect(
          await service.link(taskId: taskId, ref: ref),
          isA<PullRequestAlreadyLinked>(),
        );

        heldBy({'other-task'});
        final asked = await service.link(taskId: taskId, ref: ref);
        expect((asked as PullRequestLinkedElsewhere).taskIds, {'other-task'});
        expect(asked.ref, ref);
      },
    );

    test('an entry that could not be stored is not reported linked', () async {
      answers(prSnapshot());
      when(
        () => repository.link(
          taskId: taskId,
          ref: ref,
          snapshot: any(named: 'snapshot'),
        ),
      ).thenAnswer((_) async => const PullRequestLinkAttempt());

      expect(
        await service.link(taskId: taskId, ref: ref),
        isA<PullRequestLinkNotStored>(),
      );
    });

    test('a failed read links nothing and says why', () async {
      final retryAt = DateTime.utc(2024, 3, 15, 13);
      fails(GitHubException(GitHubFailureKind.rateLimited, retryAt: retryAt));

      final result = await service.linkPasted(taskId: taskId, input: url);

      expect(
        (result as PullRequestLinkFailed).kind,
        GitHubFailureKind.rateLimited,
      );
      expect(result.retryAt, retryAt);
      verifyNever(
        () => repository.link(
          taskId: any(named: 'taskId'),
          ref: any(named: 'ref'),
          snapshot: any(named: 'snapshot'),
        ),
      );
    });

    test('without a token nothing is asked or linked', () async {
      when(tokens.readToken).thenAnswer((_) async => null);

      final result = await service.linkPasted(taskId: taskId, input: url);

      expect((result as PullRequestLinkFailed).kind, GitHubFailureKind.noToken);
      verifyZeroInteractions(client);
    });
  });

  group('openPullRequests', () {
    const repository_ = GitHubRepository(owner: 'matthiasn', repo: 'lotti');
    OpenPullRequest open(int number, {int day = 15}) => OpenPullRequest(
      ref: PullRequestRef(owner: 'matthiasn', repo: 'lotti', number: number),
      title: 'PR $number',
      createdAt: DateTime.utc(2024, 3, day),
    );

    test('lists the open pull requests no task holds', () async {
      when(
        () => client.listOpenPullRequests(repository_, token: token),
      ).thenAnswer((_) async => [open(1), open(2), open(3)]);
      when(() => repository.holdersOf(any())).thenAnswer(
        (_) async => {
          open(2).ref.key: {'some-task'},
        },
      );

      final result = await service.openPullRequests(repository_);

      expect(
        (result as OpenPullRequestsListed).available.map((pr) => pr.ref.number),
        [3, 1],
      );
    });

    test(
      'lists the newest first, as GitHub does, whatever order the pages '
      'came in; the same opening second goes by number',
      () async {
        when(
          () => client.listOpenPullRequests(repository_, token: token),
        ).thenAnswer(
          (_) async => [
            open(4, day: 3),
            open(9, day: 12),
            open(2, day: 1),
            open(7, day: 12),
            open(5, day: 8),
          ],
        );
        when(() => repository.holdersOf(any())).thenAnswer((_) async => {});

        final result = await service.openPullRequests(repository_);

        expect(
          (result as OpenPullRequestsListed).available.map(
            (pr) => pr.ref.number,
          ),
          [9, 7, 5, 4, 2],
        );
      },
    );

    test('says why GitHub could not list them', () async {
      when(
        () => client.listOpenPullRequests(repository_, token: token),
      ).thenThrow(const GitHubException(GitHubFailureKind.notFound));

      final result = await service.openPullRequests(repository_);

      expect(
        (result as OpenPullRequestsFailed).kind,
        GitHubFailureKind.notFound,
      );
    });

    test('without a token GitHub is not asked', () async {
      when(tokens.readToken).thenAnswer((_) async => null);

      final result = await service.openPullRequests(repository_);

      expect(
        (result as OpenPullRequestsFailed).kind,
        GitHubFailureKind.noToken,
      );
      verifyZeroInteractions(client);
    });
  });

  group('refresh', () {
    final entry = prEntry(clock: {'a': 1}, snapshot: prSnapshot());

    test(
      'returns what GitHub reported as current, and offers it to the '
      'repository, which decides whether it is stored',
      () async {
        final now = prSnapshot(second: 30);
        answers(now);
        when(
          () => repository.persistObservation(entry.id, now),
        ).thenAnswer((_) async => false);

        final result = await service.refresh(entry);

        expect((result as PullRequestRefreshed).observation, now);
        verify(() => repository.persistObservation(entry.id, now)).called(1);
      },
    );

    test('a failure writes nothing', () async {
      fails(const GitHubException(GitHubFailureKind.offline));

      final result = await service.refresh(entry);

      expect(
        (result as PullRequestRefreshFailed).kind,
        GitHubFailureKind.offline,
      );
      verifyNever(() => repository.persistObservation(any(), any()));
    });

    test('an empty token counts as none', () async {
      when(tokens.readToken).thenAnswer((_) async => '');

      final result = await service.refresh(entry);

      expect(
        (result as PullRequestRefreshFailed).kind,
        GitHubFailureKind.noToken,
      );
      verifyZeroInteractions(client);
    });
  });

  group('token verdicts', () {
    final entry = prEntry(clock: {'a': 1}, snapshot: prSnapshot());
    const repository_ = GitHubRepository(owner: 'matthiasn', repo: 'lotti');

    test(
      'a refresh GitHub answers says the stored token is accepted',
      () async {
        answers(prSnapshot(second: 30));
        when(
          () => repository.persistObservation(any(), any()),
        ).thenAnswer((_) async => false);

        await service.refresh(entry);

        expect(verdicts, [(token, true)]);
      },
    );

    test('a 401 says the stored token is rejected', () async {
      fails(const GitHubException(GitHubFailureKind.unauthorized));

      await service.refresh(entry);

      expect(verdicts, [(token, false)]);
    });

    test(
      'a failure that says nothing about the token gives no verdict',
      () async {
        for (final kind in [
          GitHubFailureKind.offline,
          GitHubFailureKind.forbidden,
          GitHubFailureKind.notFound,
          GitHubFailureKind.rateLimited,
          GitHubFailureKind.server,
        ]) {
          fails(GitHubException(kind));
          await service.refresh(entry);
        }

        expect(verdicts, isEmpty);
      },
    );

    test('the picker reports a verdict too', () async {
      when(
        () => client.listOpenPullRequests(repository_, token: token),
      ).thenThrow(const GitHubException(GitHubFailureKind.unauthorized));
      await service.openPullRequests(repository_);

      when(
        () => client.listOpenPullRequests(repository_, token: token),
      ).thenAnswer((_) async => []);
      await service.openPullRequests(repository_);

      expect(verdicts, [(token, false), (token, true)]);
    });

    test('without a token there is nothing to judge', () async {
      when(tokens.readToken).thenAnswer((_) async => null);

      await service.refresh(entry);

      expect(verdicts, isEmpty);
    });
  });

  group('summaries', () {
    late MockPullRequestSummarizer summarizer;
    final entry = prEntry(clock: {'a': 1}, snapshot: prSnapshot());

    setUp(() {
      summarizer = MockPullRequestSummarizer();
      when(() => summarizer.summarize(any())).thenAnswer((_) async => false);
      service = PullRequestService(
        client: client,
        tokenStorage: tokens,
        repository: repository,
        summarizer: summarizer,
      );
    });

    test(
      'a refresh GitHub answered asks for a summary once its observation is '
      'offered, written or not, so a pull request merged long ago is '
      'summarised too',
      () async {
        answers(prSnapshot(second: 30));
        when(
          () => repository.persistObservation(any(), any()),
        ).thenAnswer((_) async => false);

        await service.refresh(entry);

        verifyInOrder([
          () => repository.persistObservation(entry.id, any()),
          () => summarizer.summarize(entry.id),
        ]);
      },
    );

    test('a failed refresh asks for nothing', () async {
      fails(const GitHubException(GitHubFailureKind.offline));

      await service.refresh(entry);

      verifyNever(() => summarizer.summarize(any()));
    });

    test('a refresh does not wait for the summary', () async {
      answers(prSnapshot(second: 30));
      when(
        () => repository.persistObservation(any(), any()),
      ).thenAnswer((_) async => true);
      when(
        () => summarizer.summarize(any()),
      ).thenAnswer((_) => Completer<bool>().future);

      final result = await service.refresh(entry);

      expect(result, isA<PullRequestRefreshed>());
    });

    test('a link asks for a summary of the new entry', () async {
      answers(prSnapshot());
      when(
        () => repository.link(
          taskId: taskId,
          ref: ref,
          snapshot: prSnapshot(),
        ),
      ).thenAnswer((_) async => PullRequestLinkAttempt(linked: entry));

      await service.link(taskId: taskId, ref: ref);

      verify(() => summarizer.summarize(entry.id)).called(1);
    });
  });
}
