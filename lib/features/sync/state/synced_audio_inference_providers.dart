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
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart' show journalDbProvider;
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'synced_audio_inference_providers.g.dart';

/// Live, sorted list of known peer node profiles plus the local node's own
/// snapshot.
///
/// Emits the current directory immediately, then forwards every directory
/// change from `SyncNodeProfileRepository.watchKnownNodes()`. Consumers
/// (the pinning selector, the sync-node settings page) listen here to see
/// remote-published profiles arrive without manual refresh.
@Riverpod(keepAlive: true)
Stream<List<SyncNodeProfile>> knownSyncNodes(Ref ref) async* {
  final repo = ref.watch(syncNodeProfileRepositoryProvider);
  yield await repo.listKnownNodes();
  yield* repo.watchKnownNodes();
}

/// The local node's currently-persisted self profile, refreshed on every
/// directory change (covers display-name edits + capability re-probes).
@Riverpod(keepAlive: true)
Stream<SyncNodeProfile?> localSyncNodeSelf(Ref ref) async* {
  final repo = ref.watch(syncNodeProfileRepositoryProvider);
  yield await repo.getSelf();
  await for (final _ in repo.watchKnownNodes()) {
    yield await repo.getSelf();
  }
}

@Riverpod(keepAlive: true)
SyncedAudioInferenceDispatcher syncedAudioInferenceDispatcher(Ref ref) {
  return SyncedAudioInferenceDispatcher(
    journalDb: ref.watch(journalDbProvider),
    vectorClockService: getIt<VectorClockService>(),
    profileAutomationResolver: ref.watch(profileAutomationResolverProvider),
    profileResolver: ref.watch(profileResolverProvider),
    aiConfigRepository: ref.watch(aiConfigRepositoryProvider),
    skillInferenceRunner: ref.watch(skillInferenceRunnerProvider),
    taskAgentService: ref.watch(taskAgentServiceProvider),
    wakeOrchestrator: ref.watch(wakeOrchestratorProvider),
    domainLogger: getIt.isRegistered<DomainLogger>()
        ? getIt<DomainLogger>()
        : null,
  );
}

/// Eagerly-constructed sync-only listener.
///
/// Watching this provider from `MyBeamerApp` calls `start()` so the
/// dispatcher fires on every `fromSync: true` batch from
/// `UpdateNotifications.syncUpdateStream`. The provider is `keepAlive` —
/// the subscription must survive the entire app lifetime.
@Riverpod(keepAlive: true)
SyncedAudioInferenceListener syncedAudioInferenceListener(Ref ref) {
  final listener = SyncedAudioInferenceListener(
    updateNotifications: getIt<UpdateNotifications>(),
    dispatcher: ref.watch(syncedAudioInferenceDispatcherProvider),
    domainLogger: getIt.isRegistered<DomainLogger>()
        ? getIt<DomainLogger>()
        : null,
  )..start();
  ref.onDispose(listener.dispose);
  return listener;
}
