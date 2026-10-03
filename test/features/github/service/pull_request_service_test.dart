import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/pull_request_data.dart';
import 'package:lotti/features/github/api/github_client.dart';
import 'package:lotti/features/github/domain/pull_request_ref.dart';
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

  setUpAll(() {
    registerFallbackValue(ref);
    registerFallbackValue(prSnapshot());
  });

  setUp(() {
    client = MockGitHubClient();
    tokens = MockGitHubTokenStorage();
    repository = MockPullRequestRepository();
    service = PullRequestService(
      client: client,
      tokenStorage: tokens,
      repository: repository,
    );
    when(tokens.readToken).thenAnswer((_) async => token);
    when(
      () => repository.isLinked(
        taskId: taskId,
        ref: any(named: 'ref'),
      ),
    ).thenAnswer((_) async => false);
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
        ).thenAnswer((_) async => entry);

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
      when(
        () => repository.isLinked(taskId: taskId, ref: ref),
      ).thenAnswer((_) async => true);

      final result = await service.linkPasted(taskId: taskId, input: url);

      expect(result, isA<PullRequestAlreadyLinked>());
      verifyZeroInteractions(client);
    });

    test('a link racing another is reported as already linked', () async {
      answers(prSnapshot());
      when(
        () => repository.link(
          taskId: taskId,
          ref: ref,
          snapshot: any(named: 'snapshot'),
        ),
      ).thenAnswer((_) async => null);

      expect(
        await service.linkPasted(taskId: taskId, input: url),
        isA<PullRequestAlreadyLinked>(),
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
}
