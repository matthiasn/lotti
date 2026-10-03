import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/github/api/github_client.dart';
import 'package:lotti/features/github/domain/github_repository.dart';
import 'package:lotti/features/github/domain/pull_request_ref.dart';
import 'package:lotti/features/github/repository/github_account_sync.dart';
import 'package:lotti/features/github/repository/github_token_storage.dart';
import 'package:lotti/features/github/service/pull_request_service.dart';
import 'package:lotti/features/github/state/github_providers.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/profiles/model/profile.dart';
import 'package:lotti/features/profiles/model/profile_context.dart';
import 'package:lotti/features/profiles/state/profile_providers.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/model/sync_secret.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/secure_storage.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../../widget_test_utils.dart';
import '../in_memory_keychain.dart';
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
    late Map<String, String> keychain;
    late GitHubTokenStorage storage;
    late List<SyncMessage> sent;
    late int rescans;
    late bool outboxRefuses;
    late StreamController<Set<String>> updates;

    setUp(() async {
      outboxRefuses = false;
      keychain = {};
      storage = GitHubTokenStorage(
        inMemoryKeychain(keychain),
        namespace: 'real',
      );
      sent = [];
      rescans = 0;
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

    ProviderContainer account() {
      final c = ProviderContainer(
        overrides: [
          gitHubClientProvider.overrideWithValue(client),
          gitHubTokenStorageProvider.overrideWithValue(storage),
          gitHubAccountSyncProvider.overrideWithValue(
            GitHubAccountSync(
              storage: storage,
              enqueueOrThrow: (message) async {
                if (outboxRefuses) throw Exception('no outbox row');
                sent.add(message);
              },
              rescan: () async => rescans++,
            ),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    // A token another device sent, not checked here yet.
    Future<void> received(String token) => storage.applyIfNewer(
      GitHubAccountRecord(token: token, login: 'pingu', updatedAt: 1),
    );

    test('reads the stored login, or none without a token', () async {
      expect(
        await account().read(gitHubAccountControllerProvider.future),
        isNull,
      );

      await storage.save(token: 'ghp_secret', login: 'pingu');
      expect(
        await account().read(gitHubAccountControllerProvider.future),
        'pingu',
      );
      verifyNever(() => client.fetchViewerLogin(any()));
    });

    test(
      'stores a token only after GitHub accepts it, and sends it to the '
      "user's other devices",
      () async {
        when(
          () => client.fetchViewerLogin('ghp_secret'),
        ).thenAnswer((_) async => 'pingu');
        final c = account();
        await c.read(gitHubAccountControllerProvider.future);

        final failure = await c
            .read(gitHubAccountControllerProvider.notifier)
            .connect('  ghp_secret \n');

        expect(failure, isNull);
        expect(c.read(gitHubAccountControllerProvider).value, 'pingu');
        expect(await storage.readToken(), 'ghp_secret');
        final message = sent.single as SyncGitHubAccount;
        expect(message.token, const SyncSecret('ghp_secret'));
        expect(message.login, 'pingu');
        expect(message.updatedAt, (await storage.read())!.updatedAt);
      },
    );

    test('a refused token is not stored or sent, and says why', () async {
      when(() => client.fetchViewerLogin(any())).thenThrow(
        const GitHubException(GitHubFailureKind.unauthorized),
      );
      final c = account();
      await c.read(gitHubAccountControllerProvider.future);
      final notifier = c.read(gitHubAccountControllerProvider.notifier);

      expect(await notifier.connect('ghp_bad'), GitHubFailureKind.unauthorized);
      expect(await notifier.connect('   '), GitHubFailureKind.noToken);
      expect(c.read(gitHubAccountControllerProvider).value, isNull);
      expect(await storage.read(), isNull);
      expect(sent, isEmpty);
    });

    test(
      'disconnect forgets the token here and on the other devices',
      () async {
        await storage.save(token: 'ghp_secret', login: 'pingu');
        final c = account();
        await c.read(gitHubAccountControllerProvider.future);

        await c.read(gitHubAccountControllerProvider.notifier).disconnect();

        expect(c.read(gitHubAccountControllerProvider).value, isNull);
        expect(await storage.readToken(), isNull);
        final message = sent.single as SyncGitHubAccount;
        expect(message.token, isNull);
      },
    );

    test(
      'a token from another device is checked with GitHub before it shows '
      'as connected (VerifyReceived)',
      () async {
        await received('ghp_synced');
        when(
          () => client.fetchViewerLogin('ghp_synced'),
        ).thenAnswer((_) async => 'pingu');

        expect(
          await account().read(gitHubAccountControllerProvider.future),
          'pingu',
        );
        verify(() => client.fetchViewerLogin('ghp_synced')).called(1);
        expect((await storage.read())!.verified, isTrue);

        // Checked once: the next read does not ask again.
        await account().read(gitHubAccountControllerProvider.future);
        verifyNever(() => client.fetchViewerLogin('ghp_synced'));
      },
    );

    test(
      'a token from another device that GitHub rejects is reported, not '
      'shown as connected',
      () async {
        await received('ghp_revoked');
        when(() => client.fetchViewerLogin('ghp_revoked')).thenThrow(
          const GitHubException(GitHubFailureKind.unauthorized),
        );
        final c = account();

        await expectLater(
          c.read(gitHubAccountControllerProvider.future),
          throwsA(
            isA<GitHubException>().having(
              (e) => e.kind,
              'kind',
              GitHubFailureKind.unauthorized,
            ),
          ),
        );
        expect((await storage.read())!.verified, isFalse);
      },
    );

    test(
      'one this device cannot check yet is not shown under the login it came '
      'with: the failure is reported, and checking again succeeds later',
      () async {
        await received('ghp_synced');
        when(() => client.fetchViewerLogin('ghp_synced')).thenThrow(
          const GitHubException(GitHubFailureKind.offline),
        );
        final c = account();

        await expectLater(
          c.read(gitHubAccountControllerProvider.future),
          throwsA(
            isA<GitHubException>().having(
              (e) => e.kind,
              'kind',
              GitHubFailureKind.offline,
            ),
          ),
        );
        expect(c.read(gitHubAccountControllerProvider).value, isNull);
        expect((await storage.read())!.verified, isFalse);

        when(
          () => client.fetchViewerLogin('ghp_synced'),
        ).thenAnswer((_) async => 'pingu');
        await c
            .read(gitHubAccountControllerProvider.notifier)
            .checkOtherDevices();
        expect(c.read(gitHubAccountControllerProvider).value, 'pingu');
      },
    );

    test(
      'a token that arrives while the page is open is read at once',
      () async {
        when(
          () => client.fetchViewerLogin('ghp_synced'),
        ).thenAnswer((_) async => 'pingu');
        final c = account();
        final seen = <String?>[];
        c.listen(
          gitHubAccountControllerProvider,
          (_, next) => next.whenData(seen.add),
          fireImmediately: true,
        );
        await pumpEventQueue();

        await received('ghp_synced');
        updates.add({'unrelated'});
        await pumpEventQueue();
        expect(seen, [null]);
        updates.add({gitHubAccountNotification});
        await pumpEventQueue();

        expect(seen.last, 'pingu');
      },
    );

    test(
      'sending to the other devices sends the held version, with its own '
      'stamp, and nothing when there is no token',
      () async {
        final c = account();
        final notifier = c.read(gitHubAccountControllerProvider.notifier);
        expect(await notifier.sendToOtherDevices(), isNull);
        expect(sent, isEmpty);

        final held = await storage.save(token: 'ghp_secret', login: 'pingu');
        expect(await notifier.sendToOtherDevices(), isTrue);

        final message = sent.single as SyncGitHubAccount;
        expect(message.updatedAt, held.updatedAt);
        expect(message.token, const SyncSecret('ghp_secret'));
      },
    );

    test(
      'a change the outbox refused stays owed, says so, and is sent by the '
      'next flush (RetryOwed)',
      () async {
        when(
          () => client.fetchViewerLogin('ghp_secret'),
        ).thenAnswer((_) async => 'pingu');
        outboxRefuses = true;
        final c = account();
        await c.read(gitHubAccountControllerProvider.future);
        final notifier = c.read(gitHubAccountControllerProvider.notifier);

        expect(await notifier.connect('ghp_secret'), isNull);
        expect(c.read(gitHubAccountControllerProvider).value, 'pingu');
        expect(sent, isEmpty);
        expect(await notifier.changeOwed(), isTrue);

        outboxRefuses = false;
        await c.read(gitHubAccountSyncProvider).flushOwed();
        expect(sent, hasLength(1));
        expect(await notifier.changeOwed(), isFalse);
      },
    );

    test(
      'a token that arrives while another is being checked is checked on '
      "its own, never shown under the first one's check "
      '(VerifyMatchesVersion)',
      () async {
        await received('ghp_a');
        final answerA = Completer<String>();
        when(
          () => client.fetchViewerLogin('ghp_a'),
        ).thenAnswer((_) => answerA.future);
        when(
          () => client.fetchViewerLogin('ghp_b'),
        ).thenAnswer((_) async => 'emperor');
        final c = account();
        final login = c.read(gitHubAccountControllerProvider.future);
        await pumpEventQueue();

        // ghp_b arrives while GitHub is still answering about ghp_a.
        await storage.applyIfNewer(
          const GitHubAccountRecord(
            token: 'ghp_b',
            login: 'emperor',
            updatedAt: 2,
          ),
        );
        answerA.complete('pingu');

        expect(await login, 'emperor');
        verify(() => client.fetchViewerLogin('ghp_b')).called(1);
        final held = await storage.read();
        expect(held!.token, 'ghp_b');
        expect(held.login, 'emperor');
        expect(held.verified, isTrue);
      },
    );

    test(
      'checking the other devices asks sync to catch up, then reads again',
      () async {
        when(
          () => client.fetchViewerLogin('ghp_synced'),
        ).thenAnswer((_) async => 'pingu');
        final c = account();
        expect(await c.read(gitHubAccountControllerProvider.future), isNull);
        await received('ghp_synced');

        await c
            .read(gitHubAccountControllerProvider.notifier)
            .checkOtherDevices();

        expect(rescans, 1);
        expect(c.read(gitHubAccountControllerProvider).value, 'pingu');
      },
    );
  });

  group('the default account providers', () {
    late Map<String, String> keychain;
    late MockOutboxService outbox;
    late MockMatrixService matrix;

    setUpAll(() {
      registerFallbackValue(
        const SyncMessage.gitHubAccount(
          updatedAt: 0,
          status: SyncEntryStatus.update,
        ),
      );
    });

    setUp(() async {
      keychain = {};
      outbox = MockOutboxService();
      matrix = MockMatrixService();
      when(() => outbox.enqueueMessageOrThrow(any())).thenAnswer((_) async {});
      when(matrix.forceRescan).thenAnswer((_) async {});
      await setUpTestGetIt(
        additionalSetup: () {
          getIt
            ..registerSingleton<SecureStorage>(inMemoryKeychain(keychain))
            ..registerSingleton<OutboxService>(outbox)
            ..registerSingleton<MatrixService>(matrix);
        },
      );
      addTearDown(tearDownTestGetIt);
    });

    ProviderContainer world(ProfileType type) {
      final c = ProviderContainer(
        overrides: [
          profileContextProvider.overrideWithValue(
            ProfileContext.forProfile(
              profile: Profile(
                id: type == ProfileType.real ? Profile.realProfileId : 'g1',
                type: type,
                name: 'world',
                dirName: type == ProfileType.real ? '' : 'guest_profiles/g1',
                createdAt: DateTime(2026),
              ),
              root: Directory('/data/lotti'),
            ),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test(
      "the token lives under the profile's id, and an owed change goes to "
      "the outbox's failure-reporting path",
      () async {
        final c = world(ProfileType.real);

        await c
            .read(gitHubTokenStorageProvider)
            .save(token: 'ghp_secret', login: 'pingu');
        expect(await c.read(gitHubAccountSyncProvider).flushOwed(), isTrue);

        expect(keychain.keys, ['github_account:${Profile.realProfileId}']);
        verify(() => outbox.enqueueMessageOrThrow(any())).called(1);
      },
    );

    test(
      'a syncing world can ask its other devices; a guest world cannot',
      () async {
        final real = world(ProfileType.real).read(gitHubAccountSyncProvider);
        expect(real.canCheckOtherDevices, isTrue);
        await real.checkOtherDevices();
        verify(matrix.forceRescan).called(1);

        expect(
          world(
            ProfileType.guest,
          ).read(gitHubAccountSyncProvider).canCheckOtherDevices,
          isFalse,
        );
      },
    );
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
