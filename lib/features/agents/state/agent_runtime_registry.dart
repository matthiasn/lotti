/// How an owning feature plugs its agent kind into the shared agent runtime.
///
/// The runtime — wake scanning, wake dispatch, startup restoration — lives in
/// `features/agents`, while each agent *kind* is owned by the feature that
/// models it. Without a registry the runtime would have to import every owning
/// feature, which is the cycle this file exists to prevent: the dependency
/// points from the owning feature inward to the runtime, never back out.
///
/// Each registry below defaults to empty, so a bare `ProviderContainer` in a
/// test exercises the runtime with no kinds registered. Production wiring is a
/// single set of overrides in the composition root
/// (`buildProviderOverrides`), which is the only place that may see both sides.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/workflow/wake_result.dart';

/// Runs one wake for a single agent kind.
///
/// Mirrors the `execute` signature every agent workflow already shares, so an
/// owning feature contributes a tear-off rather than an adapter.
typedef AgentWakeRunner =
    Future<WakeResult> Function({
      required AgentIdentityEntity agentIdentity,
      required String runKey,
      required Set<String> triggerTokens,
      required String threadId,
    });

/// [AgentWakeRunner]s by `AgentKinds` value.
///
/// `wireWakeExecutor` consults this **after** the four kinds it names inline
/// (`templateImprover`, `projectAgent`, `eventAgent`) and **before** the
/// task-agent fallback. So a contributed runner adds a new kind, and overrides
/// only the task-agent default — a runner registered for one of the three
/// inline kinds is silently unreachable.
///
/// That asymmetry is deliberate for now: the inline kinds are owned by this
/// feature and their dispatch is not a plug point. Making them overridable
/// would mean moving this lookup above them, which changes what a contributed
/// runner can do.
final agentWakeRunnersProvider = Provider<Map<String, AgentWakeRunner>>(
  (ref) => const <String, AgentWakeRunner>{},
  name: 'agentWakeRunnersProvider',
);

/// Repairs and restoration an owning feature contributes to the runtime's
/// lifecycle.
///
/// Both hooks are called for their effect only and must contain their own
/// failures where a failure should not abort the caller — the runtime reports
/// what escapes but cannot know which of a feature's repairs are optional.
abstract class AgentRuntimeMaintenance {
  /// Repairs that must land *before* a wake scan reads what is due.
  ///
  /// A scan that runs first would see stale state — an agent whose window has
  /// closed still looking `active`, or a digest slot not yet armed — so this
  /// runs on every pass, not only at startup.
  Future<void> beforeWakeScan();

  /// Restores durable subscriptions during startup restoration.
  ///
  /// Runs concurrently with the runtime's own restoration; throwing aborts the
  /// restoration pass, which Riverpod can then retry as a provider failure.
  Future<void> restoreSubscriptions();

  /// Reacts to an agent identity applied FROM SYNC mid-session, so an
  /// agent created on another device is live here without a restart —
  /// the runtime-plug-in generalization of the hard-coded task/project
  /// branches in the sync processor. Default: nothing to mirror.
  ///
  /// Called after the identity row is persisted; implementations must
  /// contain their own failures (a bad identity from one feature must not
  /// stop the sync apply loop).
  Future<void> onIdentityReceived(AgentIdentityEntity identity) async {}
}

/// The [AgentRuntimeMaintenance] contributors, in no guaranteed order.
final agentRuntimeMaintenanceProvider = Provider<List<AgentRuntimeMaintenance>>(
  (ref) => const <AgentRuntimeMaintenance>[],
  name: 'agentRuntimeMaintenanceProvider',
);

/// Opens an owning feature's inference-setup surface from a runtime screen.
///
/// A callback rather than a widget so `features/agents` need not import the
/// sheet it opens. Null when the owning feature is not wired, in which case
/// the entry point that would open it stays disabled.
typedef AgentSetupSheetLauncher = void Function(BuildContext context);

/// Launcher for the Daily OS inference-setup sheet, or null when unwired.
final dailyOsSetupSheetLauncherProvider = Provider<AgentSetupSheetLauncher?>(
  (ref) => null,
  name: 'dailyOsSetupSheetLauncherProvider',
);
