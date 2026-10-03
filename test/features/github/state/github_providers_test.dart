import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/pull_request_data.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/state/profile_automation_providers.dart';
import 'package:lotti/features/github/api/github_client.dart';
import 'package:lotti/features/github/context/pull_request_context_service.dart';
import 'package:lotti/features/github/domain/github_repository.dart';
import 'package:lotti/features/github/domain/pull_request_ref.dart';
import 'package:lotti/features/github/domain/pull_request_summary.dart';
import 'package:lotti/features/github/repository/github_account_sync.dart';
import 'package:lotti/features/github/repository/github_token_storage.dart';
import 'package:lotti/features/github/service/pull_request_service.dart';
import 'package:lotti/features/github/service/pull_request_summarizer.dart';
import 'package:lotti/features/github/service/pull_request_summary_tool.dart';
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
import 'package:lotti/services/editor_state_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../helpers/fake_entry_controller.dart';
import '../../../helpers/fallbacks.dart';
import '../../../helpers/test_get_it.dart';
import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../../widget_test_utils.dart';
import '../../agents/test_data/ai_config_factories.dart';
import '../../categories/test_utils.dart';
import '../in_memory_keychain.dart';
import '../pull_request_fixtures.dart';

void main() {
  late MockGitHubClient client;
  late MockGitHubTokenStorage tokens;
  late MockPullRequestService service;

  setUpAll(() {
    registerFallbackValue(prEntry(clock: {'a': 1}));
    registerFallbackValue(prSnapshot());
    registerFallbackValue(
      const PullRequestRef(owner: 'matthiasn', repo: 'lotti', number: 42),
    );
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
    late MockUpdateNotifications notifications;

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
      notifications = MockUpdateNotifications();
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
      'connecting and disconnecting announce the change to whoever follows '
      'the account, as a token received from another device does',
      () async {
        when(
          () => client.fetchViewerLogin('ghp_secret'),
        ).thenAnswer((_) async => 'pingu');
        final c = account();
        await c.read(gitHubAccountControllerProvider.future);
        final notifier = c.read(gitHubAccountControllerProvider.notifier);

        await notifier.connect('ghp_secret');
        verify(
          () => notifications.notify({gitHubAccountNotification}),
        ).called(1);

        await notifier.disconnect();
        verify(
          () => notifications.notify({gitHubAccountNotification}),
        ).called(1);
      },
    );

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

  group('GitHubTokenStatusController', () {
    late Map<String, String> keychain;
    late GitHubTokenStorage storage;
    late StreamController<Set<String>> updates;

    setUp(() async {
      keychain = {};
      storage = GitHubTokenStorage(
        inMemoryKeychain(keychain),
        namespace: 'real',
      );
      updates = StreamController<Set<String>>.broadcast();
      addTearDown(updates.close);
      final notifications = MockUpdateNotifications();
      when(() => notifications.updateStream).thenAnswer((_) => updates.stream);
      // What the account announces reaches its followers, as in the app.
      when(
        () => notifications.notify(any(), fromSync: any(named: 'fromSync')),
      ).thenAnswer(
        (invocation) =>
            updates.add(invocation.positionalArguments.first as Set<String>),
      );
      await setUpTestGetIt(
        additionalSetup: () {
          getIt
            ..unregister<UpdateNotifications>()
            ..registerSingleton<UpdateNotifications>(notifications);
        },
      );
      addTearDown(tearDownTestGetIt);
    });

    ProviderContainer status({List<Override> overrides = const []}) {
      final c = ProviderContainer(
        overrides: [
          gitHubClientProvider.overrideWithValue(client),
          gitHubTokenStorageProvider.overrideWithValue(storage),
          gitHubAccountSyncProvider.overrideWithValue(
            GitHubAccountSync(
              storage: storage,
              enqueueOrThrow: (_) async {},
            ),
          ),
          ...overrides,
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    GitHubTokenStatusController statusIn(ProviderContainer c) =>
        c.read(gitHubTokenStatusProvider.notifier);

    Future<GitHubTokenStatus> settled(ProviderContainer c) =>
        c.read(gitHubTokenStatusProvider.future);

    // A token another device sent, not checked here yet.
    Future<void> received(String token) => storage.applyIfNewer(
      GitHubAccountRecord(token: token, login: 'pingu', updatedAt: 1),
    );

    test('is none without a token, and offers no tracking', () async {
      final c = status();

      expect(await settled(c), GitHubTokenStatus.none);
      expect(c.read(gitHubTrackingAvailableProvider), isFalse);
    });

    test(
      'takes a token entered here as valid without asking GitHub again, and '
      'offers tracking',
      () async {
        await storage.save(token: 'ghp_secret', login: 'pingu');
        final c = status();

        expect(await settled(c), GitHubTokenStatus.valid);
        expect(c.read(gitHubTrackingAvailableProvider), isTrue);
        verifyZeroInteractions(client);
      },
    );

    test(
      'a token from another device is offered once GitHub accepts it here',
      () async {
        await received('ghp_synced');
        when(
          () => client.fetchViewerLogin('ghp_synced'),
        ).thenAnswer((_) async => 'pingu');
        final c = status();

        expect(await settled(c), GitHubTokenStatus.valid);
        expect(c.read(gitHubTrackingAvailableProvider), isTrue);
      },
    );

    test(
      'a token from another device that GitHub rejects here is not offered',
      () async {
        await received('ghp_revoked');
        when(
          () => client.fetchViewerLogin('ghp_revoked'),
        ).thenThrow(const GitHubException(GitHubFailureKind.unauthorized));
        final c = status();

        expect(await settled(c), GitHubTokenStatus.rejected);
        expect(c.read(gitHubTrackingAvailableProvider), isFalse);
      },
    );

    test(
      'a token that arrives from another device later is read again',
      () async {
        when(
          () => client.fetchViewerLogin('ghp_synced'),
        ).thenAnswer((_) async => 'pingu');
        final c = status()..listen(gitHubTokenStatusProvider, (_, _) {});
        expect(await settled(c), GitHubTokenStatus.none);

        await received('ghp_synced');
        updates.add({gitHubAccountNotification});
        await pumpEventQueue();

        expect(await settled(c), GitHubTokenStatus.valid);
        expect(c.read(gitHubTrackingAvailableProvider), isTrue);
      },
    );

    test(
      'a 401 on the held token withdraws tracking, and a later success '
      'restores it',
      () async {
        await storage.save(token: 'ghp_secret', login: 'pingu');
        final c = status();
        await settled(c);

        await statusIn(c).observe('ghp_secret', accepted: false);
        expect(
          c.read(gitHubTokenStatusProvider).value,
          GitHubTokenStatus.rejected,
        );
        expect(c.read(gitHubTrackingAvailableProvider), isFalse);

        await statusIn(c).observe('ghp_secret', accepted: true);
        expect(
          c.read(gitHubTokenStatusProvider).value,
          GitHubTokenStatus.valid,
        );
        expect(c.read(gitHubTrackingAvailableProvider), isTrue);
      },
    );

    test(
      'a 401 that arrives before the held token was read still rejects it',
      () async {
        await storage.save(token: 'ghp_secret', login: 'pingu');
        final c = status();

        // Nothing has read the status yet: this starts its read, and the
        // verdict must wait for it rather than be judged against no token.
        await statusIn(c).observe('ghp_secret', accepted: false);

        expect(
          c.read(gitHubTokenStatusProvider).value,
          GitHubTokenStatus.rejected,
        );
        expect(c.read(gitHubTrackingAvailableProvider), isFalse);
      },
    );

    test('a verdict on a token no longer held changes nothing', () async {
      await storage.save(token: 'ghp_new', login: 'pingu');
      final c = status();
      await settled(c);

      // A call made with the replaced token, answered after the swap.
      await statusIn(c).observe('ghp_old', accepted: false);

      expect(c.read(gitHubTokenStatusProvider).value, GitHubTokenStatus.valid);
    });

    test('connecting a token again clears a rejection', () async {
      await storage.save(token: 'ghp_secret', login: 'pingu');
      when(
        () => client.fetchViewerLogin('ghp_fresh'),
      ).thenAnswer((_) async => 'pingu');
      final c = status();
      await settled(c);
      await c.read(gitHubAccountControllerProvider.future);
      await statusIn(c).observe('ghp_secret', accepted: false);

      // Same account, fresh token: the login does not change.
      await c
          .read(gitHubAccountControllerProvider.notifier)
          .connect('ghp_fresh');
      await pumpEventQueue();

      expect(await settled(c), GitHubTokenStatus.valid);
      expect(c.read(gitHubTrackingAvailableProvider), isTrue);
    });

    test('disconnecting withdraws tracking', () async {
      await storage.save(token: 'ghp_secret', login: 'pingu');
      final c = status();
      await settled(c);
      await c.read(gitHubAccountControllerProvider.future);

      await c.read(gitHubAccountControllerProvider.notifier).disconnect();
      await pumpEventQueue();

      expect(await settled(c), GitHubTokenStatus.none);
      expect(c.read(gitHubTrackingAvailableProvider), isFalse);
    });

    test(
      'the pull request service reports what GitHub said of the token: a '
      '401 on a refresh rejects it, the next success accepts it again',
      () async {
        await storage.save(token: 'ghp_secret', login: 'pingu');
        final repository = MockPullRequestRepository();
        final entry = prEntry(clock: {'a': 1});
        when(
          () => repository.persistObservation(any(), any()),
        ).thenAnswer((_) async => true);
        // The summarizer each answered refresh asks finds nothing settled.
        when(() => repository.liveEntry(any())).thenAnswer((_) async => entry);
        // The real service, wired by its provider.
        final c = status(
          overrides: [
            pullRequestRepositoryProvider.overrideWithValue(repository),
          ],
        );
        await settled(c);

        when(
          () => client.fetchPullRequest(any(), token: 'ghp_secret'),
        ).thenThrow(const GitHubException(GitHubFailureKind.unauthorized));
        await c.read(pullRequestServiceProvider).refresh(entry);
        await pumpEventQueue();
        expect(
          c.read(gitHubTokenStatusProvider).value,
          GitHubTokenStatus.rejected,
        );

        when(
          () => client.fetchPullRequest(any(), token: 'ghp_secret'),
        ).thenAnswer((_) async => prSnapshot());
        await c.read(pullRequestServiceProvider).refresh(entry);
        await pumpEventQueue();
        expect(
          c.read(gitHubTokenStatusProvider).value,
          GitHubTokenStatus.valid,
        );
      },
    );
  });

  group('pullRequestContextServiceProvider', () {
    late MockPullRequestRepository repository;

    PullRequestContextService serviceIn() {
      final c = ProviderContainer(
        overrides: [
          gitHubTokenStorageProvider.overrideWithValue(tokens),
          pullRequestRepositoryProvider.overrideWithValue(repository),
          pullRequestServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(c.dispose);
      return c.read(pullRequestContextServiceProvider);
    }

    setUp(() {
      repository = MockPullRequestRepository();
      when(() => repository.forTask(any())).thenAnswer((_) async => []);
    });

    test(
      'is gated on the stored token: without one the task context asks '
      'for nothing',
      () async {
        when(tokens.hasToken).thenAnswer((_) async => false);

        expect(await serviceIn().forTask('task'), isEmpty);
        verifyNever(() => repository.forTask(any()));
        verifyZeroInteractions(service);
      },
    );

    test("with a stored token it reads the task's pull requests", () async {
      when(tokens.hasToken).thenAnswer((_) async => true);

      expect(await serviceIn().forTask('task'), isEmpty);
      verify(() => repository.forTask('task')).called(1);
    });
  });

  group('taskShowsPullRequestsProvider', () {
    setUp(() async {
      // The task's entry controller needs its editor service.
      await setUpTestGetIt(
        additionalSetup: () => getIt.registerSingleton<EditorStateService>(
          MockEditorStateService(),
        ),
      );
    });
    tearDown(tearDownTestGetIt);

    Future<bool> shows(
      Task task, {
      List<JournalEntity> linked = const [],
    }) async {
      final c = ProviderContainer(
        overrides: [
          entryControllerProvider(
            task.meta.id,
          ).overrideWith(() => FakeEntryController(task)),
          resolvedOutgoingLinkedEntriesProvider.overrideWith(
            (ref, taskId) => linked,
          ),
        ],
      );
      addTearDown(c.dispose);
      c.listen(taskShowsPullRequestsProvider(task.meta.id), (_, _) {});
      await c.read(entryControllerProvider(task.meta.id).future);
      return c.read(taskShowsPullRequestsProvider(task.meta.id));
    }

    test(
      'a task that never turned tracking on, with nothing linked, does not '
      'show the section',
      () async {
        expect(await shows(testTask), isFalse);
      },
    );

    test('a task that turned tracking on shows it with none linked', () async {
      final tracking = testTask.copyWith(
        data: testTask.data.copyWith(tracksPullRequests: true),
      );
      expect(await shows(tracking), isTrue);
    });

    test(
      'a task linked to a pull request before tracking was a choice shows '
      'it without being migrated',
      () async {
        expect(testTask.data.tracksPullRequests, isFalse);
        expect(
          await shows(
            testTask,
            linked: [
              prEntry(clock: {'a': 1}),
            ],
          ),
          isTrue,
        );
      },
    );
  });

  group('the default pull request summarizer', () {
    const taskId = 'task-with-pull-requests';

    final ref = prEntry(clock: {'a': 1}).data.ref;
    final merged = prEntry(
      clock: {'a': 1},
      snapshot: prSnapshot(status: PullRequestStatus.merged),
    );

    late MockJournalDb db;
    late MockPullRequestRepository entries;
    late MockProfileAutomationResolver resolver;
    late MockCloudInferenceRepository inference;
    late bool? automaticInference;

    // Any request to the model, by any arguments.
    Stream<CreateChatCompletionStreamResponse> generateCall() =>
        inference.generate(
          any(),
          model: any(named: 'model'),
          temperature: any(named: 'temperature'),
          baseUrl: any(named: 'baseUrl'),
          apiKey: any(named: 'apiKey'),
          systemMessage: any(named: 'systemMessage'),
          maxCompletionTokens: any(named: 'maxCompletionTokens'),
          provider: any(named: 'provider'),
          tools: any(named: 'tools'),
          toolChoice: any(named: 'toolChoice'),
          geminiThinkingMode: any(named: 'geminiThinkingMode'),
          reasoningEffort: any(named: 'reasoningEffort'),
          impactCollector: any(named: 'impactCollector'),
        );

    setUpAll(() {
      registerAllFallbackValues();
      registerFallbackValue(ref);
      registerFallbackValue(prSnapshot());
      registerFallbackValue(
        const AiResponseData(
          model: '',
          systemMessage: '',
          prompt: '',
          thoughts: '',
          response: '',
        ),
      );
    });

    setUp(() {
      db = MockJournalDb();
      entries = MockPullRequestRepository();
      resolver = MockProfileAutomationResolver();
      inference = MockCloudInferenceRepository();
      automaticInference = true;

      when(() => db.journalEntityById(taskId)).thenAnswer(
        (_) async => testTask.copyWith(
          meta: testTask.meta.copyWith(id: taskId, categoryId: 'colony'),
        ),
      );
      when(() => db.getCategoryById('colony')).thenAnswer(
        (_) async => CategoryTestUtils.createTestCategory(
          id: 'colony',
          name: 'Colony',
          automaticInferenceEnabled: automaticInference,
        ),
      );
      when(
        () => entries.liveEntry(merged.id),
      ).thenAnswer((_) async => merged);
      when(
        () => entries.summaryOf(any(), any()),
      ).thenAnswer((_) async => null);
      when(() => entries.holdersOf(any())).thenAnswer(
        (_) async => {
          ref.key: {taskId},
        },
      );
      when(
        () => entries.addSummary(any(), any(), start: any(named: 'start')),
      ).thenAnswer((_) async => true);
      when(() => resolver.resolveForSubject(taskId)).thenAnswer(
        (_) async => ResolvedProfile(
          thinkingModelId: 'thinking-model',
          thinkingProvider: testInferenceProvider(apiKey: 'k-1'),
        ),
      );
      when(generateCall).thenAnswer(
        (_) => Stream.value(
          CreateChatCompletionStreamResponse(
            id: 'chunk',
            object: 'chat.completion.chunk',
            created: 0,
            choices: [
              ChatCompletionStreamResponseChoice(
                index: 0,
                delta: ChatCompletionStreamResponseDelta(
                  toolCalls: [
                    ChatCompletionStreamMessageToolCallChunk(
                      index: 0,
                      id: 'call-1',
                      type:
                          ChatCompletionStreamMessageToolCallChunkType.function,
                      function: ChatCompletionStreamMessageFunctionCall(
                        name: pullRequestSummaryToolName,
                        arguments: summaryToolCall().function.arguments,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });

    ProviderContainer world() {
      final c = ProviderContainer(
        overrides: [
          gitHubClientProvider.overrideWithValue(client),
          gitHubTokenStorageProvider.overrideWithValue(tokens),
          journalDbProvider.overrideWithValue(db),
          pullRequestRepositoryProvider.overrideWithValue(entries),
          profileAutomationResolverProvider.overrideWithValue(resolver),
          cloudInferenceRepositoryProvider.overrideWithValue(inference),
          domainLoggerProvider.overrideWithValue(MockDomainLogger()),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    PullRequestSummarizer summarizer() =>
        world().read(pullRequestSummarizerProvider);

    test(
      'the default service hands a refresh GitHub answered to this '
      'summarizer',
      () async {
        when(tokens.readToken).thenAnswer((_) async => 'ghp_secret');
        when(
          () => client.fetchPullRequest(ref, token: 'ghp_secret'),
        ).thenAnswer((_) async => merged.data.snapshot!);
        when(
          () => entries.persistObservation(any(), any()),
        ).thenAnswer((_) async => false);
        final stored = Completer<void>();
        when(
          () => entries.addSummary(any(), any(), start: any(named: 'start')),
        ).thenAnswer((_) async {
          stored.complete();
          return true;
        });

        await world().read(pullRequestServiceProvider).refresh(merged);

        await stored.future;
        verify(
          () => entries.addSummary(merged, any(), start: any(named: 'start')),
        ).called(1);
      },
    );

    test(
      "summarises with the thinking model of the task's agent, offered only "
      'the summary tool, capped, where the category allows automatic '
      'inference',
      () async {
        expect(
          await summarizer().summarize(merged.id),
          PullRequestSummaryOutcome.stored,
        );

        verify(
          () => inference.generate(
            pullRequestSummaryInput(ref, merged.data.snapshot!),
            model: 'thinking-model',
            temperature: 0.2,
            baseUrl: any(named: 'baseUrl'),
            apiKey: 'k-1',
            systemMessage: pullRequestSummarySystemMessage,
            maxCompletionTokens: pullRequestSummaryMaxTokens,
            provider: any(named: 'provider'),
            tools: [pullRequestSummaryTool],
            toolChoice: pullRequestSummaryToolChoiceFor('thinking-model'),
            geminiThinkingMode: GeminiThinkingMode.minimal,
            reasoningEffort: ReasoningEffort.minimal,
            impactCollector: any(named: 'impactCollector'),
          ),
        ).called(1);
        final data =
            verify(
                  () => entries.addSummary(
                    merged,
                    captureAny(),
                    start: any(named: 'start'),
                  ),
                ).captured.single
                as AiResponseData;
        expect(data.model, 'thinking-model');
        expect(data.oneLiner, 'Tracks pull requests on tasks.');
      },
    );

    test(
      'asks nothing automatically where the category leaves automatic '
      'inference off or the task has no category, nor where no profile '
      'resolves',
      () async {
        automaticInference = false;
        expect(
          await summarizer().summarize(merged.id),
          PullRequestSummaryOutcome.notAllowed,
        );

        when(() => db.journalEntityById(taskId)).thenAnswer(
          (_) async => testTask.copyWith(
            meta: testTask.meta.copyWith(id: taskId, categoryId: null),
          ),
        );
        expect(
          await summarizer().summarize(merged.id),
          PullRequestSummaryOutcome.notAllowed,
        );

        when(
          () => resolver.resolveForSubject(taskId),
        ).thenAnswer((_) async => null);
        expect(
          await summarizer().summarize(merged.id, manual: true),
          PullRequestSummaryOutcome.noModel,
        );
        verifyNever(generateCall);
      },
    );

    test('the user may ask where the category leaves it off', () async {
      automaticInference = false;
      expect(
        await summarizer().summarize(merged.id, manual: true),
        PullRequestSummaryOutcome.stored,
      );
      verify(generateCall).called(1);
    });
  });

  group('pullRequestSummaryProvider', () {
    late StreamController<Set<String>> updates;
    late MockPullRequestRepository entries;
    final entry = prEntry(
      clock: {'a': 1},
      snapshot: prSnapshot(status: PullRequestStatus.merged),
    );
    final input = pullRequestSummaryInput(
      entry.data.ref,
      entry.data.snapshot!,
    );
    const first = PullRequestSummary(oneLiner: 'First.', tldr: 'First one.');
    const second = PullRequestSummary(oneLiner: 'Second.', tldr: 'Again.');

    setUp(() async {
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
      entries = MockPullRequestRepository();
      when(() => entries.liveEntry(entry.id)).thenAnswer((_) async => entry);
    });

    test(
      "reads the summary of the entry's current content, and again when the "
      'entry or a summary of it is announced — only then',
      () async {
        var reads = 0;
        when(() => entries.summaryOf(entry.id, input)).thenAnswer(
          (_) async => reads++ == 0 ? first : second,
        );
        final c = ProviderContainer(
          overrides: [pullRequestRepositoryProvider.overrideWithValue(entries)],
        );
        addTearDown(c.dispose);
        final seen = <PullRequestSummary?>[];
        c.listen(
          pullRequestSummaryProvider(entry.id),
          (_, next) => next.whenData(seen.add),
          fireImmediately: true,
        );
        await pumpEventQueue();
        expect(seen, [first]);

        updates.add({'another-entry'});
        await pumpEventQueue();
        expect(seen, [first]);

        updates.add({entry.id});
        await pumpEventQueue();
        expect(seen, [first, second]);
      },
    );

    test('an entry unlinked, or never read, has no summary', () async {
      for (final stored in [
        null,
        prEntry(clock: {'a': 1}),
      ]) {
        when(
          () => entries.liveEntry(entry.id),
        ).thenAnswer((_) async => stored);
        final c = ProviderContainer(
          overrides: [pullRequestRepositoryProvider.overrideWithValue(entries)],
        );
        addTearDown(c.dispose);
        // Watched, as a row watches it: an auto-disposed provider read only
        // for its future is gone before it answers.
        c.listen(pullRequestSummaryProvider(entry.id), (_, _) {});

        expect(
          await c.read(pullRequestSummaryProvider(entry.id).future),
          isNull,
        );
      }
      verifyNever(() => entries.summaryOf(any(), any()));
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
