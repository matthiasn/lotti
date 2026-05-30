import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/agents/state/agent_providers.dart'
    show wakeOrchestratorProvider;
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/services/skill_inference_runner.dart';
import 'package:lotti/features/ai/state/profile_automation_providers.dart';
import 'package:lotti/features/sync/model/sync_node_profile.dart';
import 'package:lotti/features/sync/repository/sync_node_profile_repository.dart';
import 'package:lotti/features/sync/services/synced_audio_inference_dispatcher.dart';
import 'package:lotti/features/sync/services/synced_audio_inference_listener.dart';
import 'package:lotti/features/sync/state/synced_audio_inference_providers.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart' show journalDbProvider;
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

/// Verifies the two stream providers that drive the pinning UI and the
/// sync-node settings page: `knownSyncNodes` and `localSyncNodeSelf`. Both
/// must emit the current snapshot immediately, then forward repository
/// updates. The dispatcher and listener providers depend on a full Riverpod
/// graph (journalDb, VC service, agents, etc.) — covered indirectly through
/// the dispatcher/listener unit tests, not here.
void main() {
  late bool previousDontWarnMultipleDatabases;
  late SettingsDb settingsDb;
  late SyncNodeProfileRepository repo;
  late ProviderContainer container;

  final t0 = DateTime.utc(2026, 3, 15, 12);
  final t1 = DateTime.utc(2026, 3, 15, 13);

  SyncNodeProfile makeProfile({
    required String hostId,
    DateTime? updatedAt,
    String displayName = 'Node',
  }) {
    return SyncNodeProfile(
      hostId: hostId,
      displayName: displayName,
      platform: 'macos',
      capabilities: const [NodeCapability.mlxAudio],
      updatedAt: updatedAt ?? t0,
    );
  }

  setUpAll(() {
    // Capture the global Drift option so later tests don't inherit the
    // relaxed "multiple databases" warning suppression.
    previousDontWarnMultipleDatabases =
        driftRuntimeOptions.dontWarnAboutMultipleDatabases;
  });

  tearDownAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases =
        previousDontWarnMultipleDatabases;
  });

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    settingsDb = SettingsDb(inMemoryDatabase: true);
    repo = SyncNodeProfileRepository(settingsDb: settingsDb);
    container = ProviderContainer(
      overrides: [
        // Inject the in-memory repository so we don't need a real get_it.
        syncNodeProfileRepositoryProvider.overrideWithValue(repo),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await repo.dispose();
    await settingsDb.close();
  });

  group('knownSyncNodesProvider', () {
    test(
      'emits the current directory immediately, then forwards upserts',
      () async {
        await repo.upsertNode(makeProfile(hostId: 'seed-host'));

        final emissions = <List<SyncNodeProfile>>[];
        final subscription = container.listen(
          knownSyncNodesProvider,
          (_, next) {
            next.whenData(emissions.add);
          },
          fireImmediately: true,
        );
        addTearDown(subscription.close);

        // Wait for the initial async listKnownNodes() to settle.
        await Future<void>.microtask(() {});
        await Future<void>.microtask(() {});

        expect(emissions, isNotEmpty);
        expect(emissions.first.map((p) => p.hostId), ['seed-host']);

        // Subsequent upsert forwards through watchKnownNodes.
        await repo.upsertNode(makeProfile(hostId: 'late-host', updatedAt: t1));
        await pumpEventQueue();

        expect(
          emissions.last.map((p) => p.hostId).toSet(),
          {'seed-host', 'late-host'},
        );
      },
    );
  });

  group('localSyncNodeSelfProvider', () {
    test(
      'emits the current self profile, then re-reads on every directory '
      'change so display-name edits / re-probes surface to the UI',
      () async {
        await repo.setSelf(makeProfile(hostId: 'self-host'));

        final emissions = <SyncNodeProfile?>[];
        final subscription = container.listen(
          localSyncNodeSelfProvider,
          (_, next) {
            next.whenData(emissions.add);
          },
          fireImmediately: true,
        );
        addTearDown(subscription.close);

        await pumpEventQueue();
        expect(emissions, isNotEmpty);
        expect(emissions.first?.hostId, 'self-host');

        // Update self, then push any directory upsert (the trigger the
        // provider re-reads on) and verify the new self surfaces.
        await repo.setSelf(
          makeProfile(
            hostId: 'self-host',
            displayName: 'Renamed',
            updatedAt: t1,
          ),
        );
        await repo.upsertNode(makeProfile(hostId: 'peer-host', updatedAt: t1));
        await pumpEventQueue();

        expect(emissions.last?.displayName, 'Renamed');
      },
    );
  });

  group('syncedAudioInferenceDispatcherProvider', () {
    // The dispatcher provider's builder reads `getIt<VectorClockService>()`
    // and a graph of upstream Riverpod providers. We override every upstream
    // provider with a mock so the test exercises the builder body itself
    // (lines 45-59 of the file) without dragging in agents/journal/AI
    // singletons.
    test(
      'constructs a SyncedAudioInferenceDispatcher from the overridden '
      'upstream providers',
      () async {
        await setUpTestGetIt(
          additionalSetup: () {
            getIt.registerSingleton<VectorClockService>(
              MockVectorClockService(),
            );
            // setUpTestGetIt already registers a DomainLogger, which exercises
            // the `getIt.isRegistered<DomainLogger>() ? getIt<...>() : null`
            // true-branch in the dispatcher builder.
          },
        );
        addTearDown(tearDownTestGetIt);

        final wiringContainer = ProviderContainer(
          overrides: [
            journalDbProvider.overrideWithValue(MockJournalDb()),
            profileAutomationResolverProvider.overrideWith(
              (_) => MockProfileAutomationResolver(),
            ),
            profileResolverProvider.overrideWith(
              (_) => MockProfileResolver(),
            ),
            aiConfigRepositoryProvider.overrideWithValue(
              MockAiConfigRepository(),
            ),
            skillInferenceRunnerProvider.overrideWith(
              (_) => MockSkillInferenceRunner(),
            ),
            taskAgentServiceProvider.overrideWith(
              (_) => MockTaskAgentService(),
            ),
            wakeOrchestratorProvider.overrideWith(
              (_) => MockWakeOrchestrator(),
            ),
          ],
        );
        addTearDown(wiringContainer.dispose);

        final dispatcher = wiringContainer.read(
          syncedAudioInferenceDispatcherProvider,
        );

        // The builder returned a wired dispatcher; that's the load-bearing
        // assertion — every `ref.watch` resolved against the overrides
        // without throwing. We don't dispatch here because the underlying
        // mocks would error on uncalled stubs; the dispatcher's own test
        // file exercises the dispatch path.
        expect(dispatcher, isA<SyncedAudioInferenceDispatcher>());
      },
    );
  });

  group('syncedAudioInferenceListenerProvider', () {
    test(
      'eagerly constructs the listener, starts the subscription, and '
      'registers a dispose hook',
      () async {
        // Fresh UpdateNotifications so we control the syncUpdateStream
        // emission timing. The shared setUpTestGetIt would install a
        // MockUpdateNotifications without a sync-stream stub, so we register
        // a real instance directly.
        final notifications = UpdateNotifications();
        addTearDown(notifications.dispose);

        await getIt.reset();
        getIt
          ..registerSingleton<UpdateNotifications>(notifications)
          // Exercises the DomainLogger true-branch in the listener builder.
          ..registerSingleton<DomainLogger>(MockDomainLogger());
        addTearDown(getIt.reset);

        final mockDispatcher = MockSyncedAudioInferenceDispatcher();
        when(
          () => mockDispatcher.maybeDispatch(any()),
        ).thenAnswer((_) async {});

        final wiringContainer = ProviderContainer(
          overrides: [
            syncedAudioInferenceDispatcherProvider.overrideWithValue(
              mockDispatcher,
            ),
          ],
        );

        // Reading the provider should construct the listener, call start(),
        // and register the dispose hook on the ref.
        final listener = wiringContainer.read(
          syncedAudioInferenceListenerProvider,
        );
        expect(listener, isA<SyncedAudioInferenceListener>());

        // Push a sync notification; the listener's started subscription
        // must forward it to the dispatcher.
        notifications.notify({'audio-via-provider'}, fromSync: true);
        await Future<void>.delayed(
          const Duration(seconds: 1, milliseconds: 50),
        );

        verify(
          () => mockDispatcher.maybeDispatch('audio-via-provider'),
        ).called(1);

        // Disposing the container fires ref.onDispose → listener.dispose,
        // so subsequent emissions must NOT reach the mock.
        wiringContainer.dispose();
        await pumpEventQueue();

        notifications.notify({'audio-after-dispose'}, fromSync: true);
        await Future<void>.delayed(
          const Duration(seconds: 1, milliseconds: 50),
        );

        verifyNever(
          () => mockDispatcher.maybeDispatch('audio-after-dispose'),
        );
      },
      // Uses real time because UpdateNotifications batches sync emissions
      // on a 1s real-clock Timer; fakeAsync can't intercept it here.
      timeout: const Timeout(Duration(seconds: 10)),
    );
  });
}

class MockSyncedAudioInferenceDispatcher extends Mock
    implements SyncedAudioInferenceDispatcher {}
