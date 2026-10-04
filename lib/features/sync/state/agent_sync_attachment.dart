import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/agent_runtime_registry.dart';
import 'package:lotti/features/agents/wake/sync_lease_gate.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/state/matrix_service_provider.dart';
import 'package:lotti/providers/agent_repository_providers.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/utils/consts.dart';

/// Sync's [AgentSyncAttachment]: the [SyncEventProcessor] stores another
/// device's agents and hands their lifecycle changes to the wake runtime.
///
/// This is sync's only hard dependency on the agent feature. The repository
/// half needs nothing but the agent database, which is why the agent runtime
/// attaches it before it resolves any runtime provider.
class SyncEventProcessorAgentAttachment implements AgentSyncAttachment {
  const SyncEventProcessorAgentAttachment(this._processor);

  final SyncEventProcessor _processor;

  @override
  void attachRepository(Ref ref) {
    final repository = ref.read(agentRepositoryProvider);
    _processor.agentRepository = repository;
    _processor.backfillResponseHandler.agentRepository = repository;
    ref.onDispose(() {
      _processor.agentRepository = null;
      _processor.backfillResponseHandler.agentRepository = null;
    });
  }

  @override
  void attachRuntime(
    Ref ref,
    WakeOrchestrator orchestrator, {
    required Future<void> Function(String taskId) retireSupersededTaskAgents,
  }) {
    _processor
      ..wakeOrchestrator = orchestrator
      ..agentWakeCoordinator = ref.read(agentWakeCoordinatorProvider)
      // Feature-owned runtime mirrors (goal agents today): a synced-in
      // identity is offered to each contributor so subscriptions follow the
      // agent onto this device mid-session.
      ..runtimeMaintenance = ref.read(agentRuntimeMaintenanceProvider)
      ..retireSupersededTaskAgents = retireSupersededTaskAgents
      ..armProjectUpdate = armProjectUpdate(ref);
    ref.onDispose(() {
      _processor
        ..wakeOrchestrator = null
        ..agentWakeCoordinator = null
        ..runtimeMaintenance = const []
        ..retireSupersededTaskAgents = null
        ..armProjectUpdate = null;
    });
  }
}

/// The agent runtime's [SyncLeaseGate] over this device's Matrix sync: may
/// claim or fire a leased project update slot only while connected and with
/// its sync inbox drained. Wired into `syncLeaseGateProvider` by the
/// composition root, for a profile that syncs.
SyncLeaseGate buildSyncLeaseGate(Ref ref) {
  final matrixService = ref.watch(matrixServiceProvider);
  final journalDb = ref.watch(journalDbProvider);
  final gate = SyncLeaseGate(
    syncEnabled: () => journalDb.getConfigFlag(enableMatrixFlag),
    connected: matrixService.isLoggedIn,
    connectivityChanges: Connectivity().onConnectivityChanged
        .map(reachesSyncServer)
        .handleError((Object _) {}),
    currentlyOnline: () async =>
        reachesSyncServer(await Connectivity().checkConnectivity()),
    waitForInboxDrained: (timeout) => matrixService.queueCoordinator.queue
        .waitForDrainAtMostTo(0, timeout: timeout),
  );
  ref.onDispose(gate.dispose);
  return gate;
}
