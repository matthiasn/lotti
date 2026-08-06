import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/agent_runtime_registry.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_service.dart';
import 'package:lotti/features/daily_os_next/agents/state/day_agent_providers.dart';
import 'package:lotti/services/domain_logging.dart';

/// Daily OS's contribution to the shared agent runtime's lifecycle.
///
/// Both repairs below must land before a wake scan reads what is due, and both
/// are independently optional: a repair that cannot run must not stop the wakes
/// that are already due, so each is contained here rather than at the call
/// site. That containment is why the runtime's own handler only logs what
/// escapes.
class DailyOsRuntimeMaintenance implements AgentRuntimeMaintenance {
  /// Wraps the [DayAgentService] the repairs run against.
  DailyOsRuntimeMaintenance({required this.dayAgents, this.domainLogger});

  /// The Daily OS agent service owning day retirement and the digest wake.
  final DayAgentService dayAgents;

  /// Optional structured logger for contained repair failures.
  final DomainLogger? domainLogger;

  @override
  Future<void> beforeWakeScan() async {
    // Retirement decides which agents may still wake — a day agent whose day is
    // over stays `active` until it runs, so its overdue wake would otherwise
    // fire once per cold start and once per hourly tick thereafter.
    try {
      await dayAgents.retirePastDayAgents();
    } catch (e, s) {
      domainLogger?.error(
        LogDomain.agentRuntime,
        e,
        message: 'failed to retire past day agents before wake scan',
        stackTrace: s,
      );
    }
    // The digest bootstrap can arm a record for an already-past slot when a run
    // was interrupted, which only fires promptly if it exists before the scan.
    try {
      await dayAgents.ensureCoordinatorDigestWake();
    } catch (e, s) {
      domainLogger?.error(
        LogDomain.agentRuntime,
        e,
        message: 'failed to repair coordinator digest before wake scan',
        stackTrace: s,
      );
    }
  }

  @override
  Future<void> restoreSubscriptions() => dayAgents.restoreSubscriptions();
}

/// Daily OS's entry in [agentRuntimeMaintenanceProvider].
///
/// Still lazy in the sense the runtime needs: the wake manager reads the
/// registry only when a pass runs, so nothing here is built to *construct* the
/// manager.
///
/// `watch`, not `read`, on both dependencies. [dayAgentServiceProvider] is not a
/// leaf — it watches the orchestrator, repository, sync and template services —
/// so it genuinely rebuilds, and a captured instance would leave the pre-scan
/// repairs running against a stale orchestrator. Watching propagates the rebuild
/// through [agentRuntimeMaintenanceProvider] so the next pass resolves the
/// current service.
final dailyOsRuntimeMaintenanceProvider =
    Provider<List<AgentRuntimeMaintenance>>(
      (ref) => <AgentRuntimeMaintenance>[
        DailyOsRuntimeMaintenance(
          dayAgents: ref.watch(dayAgentServiceProvider),
          domainLogger: ref.watch(domainLoggerProvider),
        ),
      ],
      name: 'dailyOsRuntimeMaintenanceProvider',
    );
