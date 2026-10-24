import 'package:lotti/classes/agents/agent_config.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/features/agents/service/agent_service.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';

/// Creates and finds the one front agent (the `getOrCreatePlannerAgent`
/// shape): a fixed id so every device converges on the same row, created
/// lazily on first use, re-checked inside the transaction so two devices
/// racing the first creation still end with one identity.
class FrontAgentService {
  const FrontAgentService({
    required AgentService agentService,
    required AgentSyncService syncService,
  }) : this._(agentService, syncService);

  const FrontAgentService._(this._agentService, this._syncService);

  final AgentService _agentService;
  final AgentSyncService _syncService;

  /// The front agent, created with [allowedCategoryIds] when it does not
  /// exist yet. The allow-list is the privacy boundary of everything the
  /// routing index shows; it starts as narrow as the caller says
  /// (decision 4) and widens only through the identity's own settings.
  Future<AgentIdentityEntity> getOrCreate({
    Set<String> allowedCategoryIds = const {},
  }) async {
    final existing = await _agentService.getAgent(frontAgentId);
    if (existing != null) return existing;
    return _syncService.runInTransaction(() async {
      final duplicate = await _agentService.getAgent(frontAgentId);
      if (duplicate != null) return duplicate;
      return _agentService.createAgent(
        agentId: frontAgentId,
        kind: AgentKinds.frontAgent,
        displayName: 'Companion',
        config: const AgentConfig(),
        allowedCategoryIds: allowedCategoryIds,
      );
    });
  }
}
