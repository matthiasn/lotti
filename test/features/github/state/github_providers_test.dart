import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/github/api/github_client.dart';
import 'package:lotti/features/github/service/pull_request_service.dart';
import 'package:lotti/features/github/state/github_providers.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../pull_request_fixtures.dart';

void main() {
  late MockGitHubClient client;
  late MockGitHubTokenStorage tokens;
  late MockPullRequestService service;

  setUpAll(() {
    registerFallbackValue(prEntry(clock: {'a': 1}));
  });

  setUp(() {
    client = MockGitHubClient();
    tokens = MockGitHubTokenStorage();
    service = MockPullRequestService();
  });

  ProviderContainer container({List<JournalEntity> linked = const []}) {
    final c = ProviderContainer(
      overrides: [
        gitHubClientProvider.overrideWithValue(client),
        gitHubTokenStorageProvider.overrideWithValue(tokens),
        pullRequestServiceProvider.overrideWithValue(service),
        resolvedOutgoingLinkedEntriesProvider.overrideWith(
          (ref, taskId) => linked,
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('GitHubAccountController', () {
    test('reads the stored login, or none without a token', () async {
      when(tokens.readToken).thenAnswer((_) async => 'ghp_secret');
      when(tokens.readLogin).thenAnswer((_) async => 'pingu');
      expect(
        await container().read(gitHubAccountControllerProvider.future),
        'pingu',
      );

      when(tokens.readToken).thenAnswer((_) async => null);
      expect(
        await container().read(gitHubAccountControllerProvider.future),
        isNull,
      );
    });

    test('stores a token only after GitHub accepts it', () async {
      when(tokens.readToken).thenAnswer((_) async => null);
      when(
        () => client.fetchViewerLogin('ghp_secret'),
      ).thenAnswer((_) async => 'pingu');
      when(
        () => tokens.save(token: 'ghp_secret', login: 'pingu'),
      ).thenAnswer((_) async {});
      final c = container();
      await c.read(gitHubAccountControllerProvider.future);

      final failure = await c
          .read(gitHubAccountControllerProvider.notifier)
          .connect('  ghp_secret \n');

      expect(failure, isNull);
      expect(c.read(gitHubAccountControllerProvider).value, 'pingu');
      verify(() => tokens.save(token: 'ghp_secret', login: 'pingu')).called(1);
    });

    test('a refused token is not stored, and says why', () async {
      when(tokens.readToken).thenAnswer((_) async => null);
      when(() => client.fetchViewerLogin(any())).thenThrow(
        const GitHubException(GitHubFailureKind.unauthorized),
      );
      final c = container();
      await c.read(gitHubAccountControllerProvider.future);
      final notifier = c.read(gitHubAccountControllerProvider.notifier);

      expect(await notifier.connect('ghp_bad'), GitHubFailureKind.unauthorized);
      expect(await notifier.connect('   '), GitHubFailureKind.noToken);
      expect(c.read(gitHubAccountControllerProvider).value, isNull);
      verifyNever(
        () => tokens.save(
          token: any(named: 'token'),
          login: any(named: 'login'),
        ),
      );
    });

    test('disconnect forgets the token', () async {
      when(tokens.readToken).thenAnswer((_) async => 'ghp_secret');
      when(tokens.readLogin).thenAnswer((_) async => 'pingu');
      when(tokens.clear).thenAnswer((_) async {});
      final c = container();
      await c.read(gitHubAccountControllerProvider.future);

      await c.read(gitHubAccountControllerProvider.notifier).disconnect();

      expect(c.read(gitHubAccountControllerProvider).value, isNull);
      verify(tokens.clear).called(1);
    });
  });

  group('PullRequestRefreshController', () {
    final entry = prEntry(clock: {'a': 1}, snapshot: prSnapshot());

    PullRequestRefreshController controllerIn(ProviderContainer c) {
      // Keep the auto-disposed family alive for the test.
      c.listen(pullRequestRefreshControllerProvider(entry.id), (_, _) {});
      return c.read(pullRequestRefreshControllerProvider(entry.id).notifier);
    }

    PullRequestRefreshState stateIn(ProviderContainer c) =>
        c.read(pullRequestRefreshControllerProvider(entry.id));

    test(
      'a success keeps what was read, so an unchanged pull request that '
      'was not written still shows its new age',
      () async {
        final now = prSnapshot(second: 600);
        when(
          () => service.refresh(entry),
        ).thenAnswer((_) async => PullRequestRefreshed(now));
        final c = container();

        await controllerIn(c).refresh(entry);

        expect(stateIn(c).refreshing, isFalse);
        expect(stateIn(c).failure, isNull);
        expect(stateIn(c).latest(entry.data.snapshot), now);
      },
    );

    test('a failure is kept on the device and shows the stored age', () async {
      when(() => service.refresh(entry)).thenAnswer(
        (_) async => const PullRequestRefreshFailed(GitHubFailureKind.offline),
      );
      final c = container();

      await controllerIn(c).refresh(entry);

      expect(stateIn(c).failure?.kind, GitHubFailureKind.offline);
      expect(stateIn(c).latest(entry.data.snapshot), entry.data.snapshot);
    });

    test('a second refresh while one runs is ignored', () async {
      final gate = Completer<PullRequestRefresh>();
      when(() => service.refresh(entry)).thenAnswer((_) => gate.future);
      final c = container();
      final controller = controllerIn(c);

      final first = controller.refresh(entry);
      expect(stateIn(c).refreshing, isTrue);
      await controller.refresh(entry);
      gate.complete(PullRequestRefreshed(prSnapshot(second: 1)));
      await first;

      verify(() => service.refresh(entry)).called(1);
    });

    test('opening a task refreshes only what is stale, and only once after '
        'a failure', () async {
      when(() => service.refresh(any())).thenAnswer(
        (_) async => const PullRequestRefreshFailed(GitHubFailureKind.offline),
      );
      final observedAt = entry.data.snapshot!.observedAt;
      final c = container();
      final controller = controllerIn(c);

      await withClock(
        Clock.fixed(observedAt.add(const Duration(minutes: 1))),
        () => controller.refreshIfStale(entry),
      );
      verifyNever(() => service.refresh(any()));

      await withClock(
        Clock.fixed(observedAt.add(const Duration(minutes: 6))),
        () async {
          await controller.refreshIfStale(entry);
          await controller.refreshIfStale(entry);
        },
      );
      verify(() => service.refresh(entry)).called(1);
    });

    test('a never-observed pull request is refreshed when opened', () async {
      final unobserved = prEntry(clock: {'a': 1});
      when(() => service.refresh(unobserved)).thenAnswer(
        (_) async => PullRequestRefreshed(prSnapshot()),
      );
      final provider = pullRequestRefreshControllerProvider(unobserved.id);
      final c = container()..listen(provider, (_, _) {});

      await c.read(provider.notifier).refreshIfStale(unobserved);

      verify(() => service.refresh(unobserved)).called(1);
    });
  });

  test('taskPullRequestsProvider shows a duplicate pull request once', () {
    final c = container(
      linked: [
        prEntry(clock: {'a': 1}, id: 'b-entry'),
        prEntry(clock: {'b': 1}, id: 'a-entry'),
      ],
    );
    expect(
      c.read(taskPullRequestsProvider('task')).map((e) => e.id),
      ['a-entry'],
    );
  });

  test('taskPullRequestsProvider lists only live pull requests, by number', () {
    PullRequestEntry pr(String id, int number, {bool deleted = false}) {
      final e = prEntry(clock: {'a': 1}, id: id, deleted: deleted);
      return e.copyWith(data: e.data.copyWith(number: number));
    }

    final c = container(
      linked: [
        pr('b', 9),
        testTextEntry,
        pr('a', 3),
        pr('gone', 1, deleted: true),
      ],
    );

    expect(
      c.read(taskPullRequestsProvider('task')).map((e) => e.data.number),
      [3, 9],
    );
  });
}
