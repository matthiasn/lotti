import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_runtime_registry.dart';
import 'package:lotti/features/front_agent/service/front_chat_service.dart';
import 'package:lotti/services/domain_logging.dart';

/// Startup and pre-scan maintenance for the front agent (the
/// [AgentRuntimeMaintenance] contract): the one repair it owns is the
/// recovery of an unanswered turn (ADR 0069) — arm the record a dead author
/// never wrote, or the next window after a recovery that did not answer.
///
/// Contained, like every contributor: a failing repair is logged and never
/// stops the scan or the other features' maintenance.
class FrontRuntimeMaintenance implements AgentRuntimeMaintenance {
  const FrontRuntimeMaintenance({
    required FrontChatService chatService,
    DomainLogger? domainLogger,
  }) : this._(chatService, domainLogger);

  const FrontRuntimeMaintenance._(this._chatService, this._domainLogger);

  final FrontChatService _chatService;
  final DomainLogger? _domainLogger;

  @override
  Future<void> beforeWakeScan() => _restore('beforeWakeScan');

  @override
  Future<void> restoreSubscriptions() => _restore('restoreSubscriptions');

  /// A front identity syncing in from another device may bring turns that
  /// device never answered.
  @override
  Future<void> onIdentityReceived(AgentIdentityEntity identity) async {
    if (identity.kind != AgentKinds.frontAgent) return;
    await _restore('onIdentityReceived');
  }

  Future<void> _restore(String hook) async {
    try {
      await _chatService.restoreOldestPendingMessage();
    } catch (error, stackTrace) {
      _domainLogger?.error(
        LogDomain.agentWorkflow,
        error,
        stackTrace: stackTrace,
        subDomain: 'FrontRuntimeMaintenance',
        message: '$hook: restoring the oldest pending front turn failed',
      );
    }
  }
}
