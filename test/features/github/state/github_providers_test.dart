import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/github/api/github_client.dart';
import 'package:lotti/features/github/domain/github_repository.dart';
import 'package:lotti/features/github/domain/pull_request_ref.dart';
import 'package:lotti/features/github/service/pull_request_service.dart';
import 'package:lotti/features/github/state/github_providers.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../../widget_test_utils.dart';
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

  test(
    'taskPullRequestsProvider lists only live pull requests, newest first',
    () {
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
        [9, 3],
      );
    },
  );

  group('picker providers', () {
    const repository = GitHubRepository(owner: 'penguin', repo: 'colony');
    const pr = PullRequestRef(owner: 'penguin', repo: 'colony', number: 12);
    late MockJournalDb db;
    late MockPullRequestRepository entries;
    late StreamController<Set<String>> updates;

    setUp(() async {
      db = MockJournalDb();
      entries = MockPullRequestRepository();
      updates = StreamController<Set<String>>.broadcast();
      addTearDown(updates.close);
      final notifications = MockUpdateNotifications();
      when(() => notifications.updateStream).thenAnswer((_) => updates.stream);
      await setUpTestGetIt(
        additionalSetup: () {
          getIt
            ..unregister<UpdateNotifications>()
            ..registerSingleton<UpdateNotifications>(notifications);
        },
      );
      addTearDown(tearDownTestGetIt);
    });

    ProviderContainer pickerContainer() {
      final c = ProviderContainer(
        overrides: [
          journalDbProvider.overrideWithValue(db),
          pullRequestRepositoryProvider.overrideWithValue(entries),
          pullRequestServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    final categorized = testTask.copyWith(
      meta: testTask.meta.copyWith(categoryId: 'cat'),
    );

    CategoryDefinition category(String? repo) => CategoryDefinition(
      id: 'cat',
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
      name: 'Colony',
      vectorClock: null,
      private: false,
      active: true,
      githubRepository: repo,
    );

    test(
      "a task's repository is its category's, read again when the task or a "
      'category changes and not otherwise',
      () async {
        JournalEntity? task = categorized;
        when(
          () => db.journalEntityById(testTask.meta.id),
        ).thenAnswer((_) async => task);
        var repo = 'https://github.com/penguin/colony';
        when(
          () => db.getCategoryById('cat'),
        ).thenAnswer((_) async => category(repo));
        final c = pickerContainer();
        final seen = <GitHubRepository?>[];
        c.listen(
          taskGitHubRepositoryProvider(testTask.meta.id),
          (_, next) => next.whenData(seen.add),
          fireImmediately: true,
        );
        await pumpEventQueue();

        repo = 'penguin/igloo';
        updates.add({'unrelated'});
        await pumpEventQueue();
        updates.add({categoriesNotification});
        await pumpEventQueue();

        task = testTask;
        updates.add({testTask.meta.id});
        await pumpEventQueue();

        expect(seen, [
          repository,
          const GitHubRepository(owner: 'penguin', repo: 'igloo'),
          null,
        ]);
      },
    );

    test('a category without a repository gives none', () async {
      when(
        () => db.journalEntityById(testTask.meta.id),
      ).thenAnswer((_) async => categorized);
      when(
        () => db.getCategoryById('cat'),
      ).thenAnswer((_) async => category(null));

      final c = pickerContainer();
      final provider = taskGitHubRepositoryProvider(testTask.meta.id);
      c.listen(provider, (_, _) {});

      expect(await c.read(provider.future), isNull);
    });

    test(
      "another holder's title is named only while the viewer may see it, "
      'and read again when the task or private mode changes',
      () async {
        final journal = MockJournalRepository();
        var visible = <JournalEntity>[
          testTask.copyWith(data: testTask.data.copyWith(title: 'Waddle')),
        ];
        when(
          () => journal.getJournalEntitiesByIds({'other-task'}),
        ).thenAnswer((_) async => visible);
        final c = ProviderContainer(
          overrides: [journalRepositoryProvider.overrideWithValue(journal)],
        );
        addTearDown(c.dispose);
        final seen = <String?>[];
        c.listen(
          pullRequestHolderTitleProvider('other-task'),
          (_, next) => next.whenData(seen.add),
          fireImmediately: true,
        );
        await pumpEventQueue();

        visible = [
          testTask.copyWith(data: testTask.data.copyWith(title: 'Swim')),
        ];
        updates.add({'unrelated'});
        await pumpEventQueue();
        updates.add({'other-task'});
        await pumpEventQueue();
        // Private mode turned off, and the task is private: hidden.
        visible = [];
        updates.add({privateToggleNotification});
        await pumpEventQueue();

        expect(seen, ['Waddle', null, 'Swim', null]);
      },
    );

    test(
      'a private-mode change withdraws the title at once, before a read that '
      'may take its time',
      () async {
        final journal = MockJournalRepository();
        final pending = Completer<List<JournalEntity>>();
        var calls = 0;
        when(
          () => journal.getJournalEntitiesByIds({'other-task'}),
        ).thenAnswer((_) async {
          if (calls++ == 0) {
            return [
              testTask.copyWith(data: testTask.data.copyWith(title: 'Waddle')),
            ];
          }
          return pending.future;
        });
        final c = ProviderContainer(
          overrides: [journalRepositoryProvider.overrideWithValue(journal)],
        );
        addTearDown(c.dispose);
        final provider = pullRequestHolderTitleProvider('other-task');
        c.listen(provider, (_, _) {});
        await pumpEventQueue();
        expect(c.read(provider).value, 'Waddle');

        updates.add({privateToggleNotification});
        await pumpEventQueue();

        // The read has not answered, and the title is already gone.
        expect(c.read(provider).value, isNull);
        pending.complete(const []);
        await pumpEventQueue();
        expect(c.read(provider).value, isNull);
      },
    );

    test('the picker lists what the service offers', () async {
      const listed = OpenPullRequestsListed([]);
      when(
        () => service.openPullRequests(repository),
      ).thenAnswer((_) async => listed);

      expect(
        await pickerContainer().read(
          openPullRequestsProvider(repository).future,
        ),
        same(listed),
      );
    });

    test(
      'holders are read again when a link or a pull request entry changes, '
      'so a double assignment synced in shows up',
      () async {
        var holders = <String>{'task-1'};
        when(
          () => entries.holdersOf([pr]),
        ).thenAnswer((_) async => {pr.key: holders});
        final c = pickerContainer();
        final seen = <Set<String>>[];
        c.listen(
          pullRequestHoldersProvider(pr),
          (_, next) => next.whenData(seen.add),
          fireImmediately: true,
        );
        await pumpEventQueue();

        holders = {'task-1', 'task-2'};
        updates.add({'unrelated'});
        await pumpEventQueue();
        updates.add({linkNotification});
        await pumpEventQueue();

        expect(seen, [
          {'task-1'},
          {'task-1', 'task-2'},
        ]);
      },
    );
  });
}
