import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_slots.dart';
import 'package:lotti/features/daily_os_next/agents/state/day_agent_providers.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_interface.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/logic/mock_day_agent.dart';
import 'package:lotti/features/daily_os_next/logic/real_day_agent.dart';
import 'package:lotti/providers/service_providers.dart';

/// Resolves the [DayAgentInterface] the UI talks to.
///
/// Returns a [RealDayAgent] that delegates seven methods to the real
/// agent layer: the six phase-2 capture/reconcile tools
/// (`submitCapture`, `parseCaptureToItems`, `surfacePendingDecisions`,
/// `applyTriage`, `linkCapturePhraseToTask`, `breakCaptureLink`) plus
/// `summarizeRecentPatterns` from the phase-3 plan service. All other
/// methods — `draftDayPlan`, refine, commit, shutdown, tasks — still
/// delegate to a held [MockDayAgent] fallback until their phases ship
/// (or in the case of `draftDayPlan`, until the drafting wake trigger
/// lands).
///
/// Tests override this provider with their own implementation via
/// `ProviderScope(overrides: [...])` (typically with a fresh
/// [MockDayAgent] so they stay deterministic + don't touch the
/// agent layer).
final dayAgentProvider = Provider<DayAgentInterface>((ref) {
  return RealDayAgent(
    captureService: ref.watch(dayAgentCaptureServiceProvider),
    planService: ref.watch(dayAgentPlanServiceProvider),
    dayAgentService: ref.watch(dayAgentServiceProvider),
    journalDb: ref.watch(journalDbProvider),
    mockFallback: MockDayAgent(),
  );
});

/// Currently persisted `DraftPlan` for the given date, if any. Re-runs
/// whenever the underlying day-agent emits an update (parsed items,
/// drafted plan, etc.) so the routing layer flips from Capture → Day
/// the instant the wake completes.
// ignore: specify_nonobvious_property_types
final currentDraftPlanProvider = FutureProvider.autoDispose
    .family<DraftPlan?, DateTime>((ref, date) async {
      final agent = ref.watch(dayAgentProvider);
      // Re-runs whenever entities under this day-agent change.
      ref.watch(agentUpdateStreamProvider(dayAgentIdForDate(date)));
      return agent.currentPlanForDate(date);
    });
