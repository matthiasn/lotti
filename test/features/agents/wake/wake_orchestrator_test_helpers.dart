import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/agents/wake/wake_queue.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

// ── AgentSubscription helpers ────────────────────────────────────────────────

/// Creates an [AgentSubscription] with concise defaults.
///
/// [id] defaults to `'sub-1'`, [agentId] to `'agent-1'`, and
/// [matchEntityIds] to `{'entity-1'}`.
AgentSubscription makeSub({
  String id = 'sub-1',
  String agentId = 'agent-1',
  Set<String> matchEntityIds = const {'entity-1'},
  bool Function(Set<String> tokens)? predicate,
}) {
  return AgentSubscription(
    id: id,
    agentId: agentId,
    matchEntityIds: matchEntityIds,
    predicate: predicate,
  );
}

// ── WakeJob helpers ──────────────────────────────────────────────────────────

/// Creates a [WakeJob] with concise defaults matching the test convention.
///
/// [runKey] defaults to `'rk-1'`, [agentId] to `'agent-1'`, [reason] to
/// `'subscription'`, [triggerTokens] to `{'tok-a'}`, and [createdAt] to
/// `DateTime(2024, 3, 15)`.
WakeJob makeJob({
  String runKey = 'rk-1',
  String agentId = 'agent-1',
  String reason = 'subscription',
  Set<String> triggerTokens = const {'tok-a'},
  String? reasonId,
  DateTime? createdAt,
}) {
  return WakeJob(
    runKey: runKey,
    agentId: agentId,
    reason: reason,
    triggerTokens: triggerTokens,
    reasonId: reasonId,
    createdAt: createdAt ?? DateTime(2024, 3, 15),
  );
}

// ── WakeExecutor helpers ─────────────────────────────────────────────────────

/// A no-op [WakeExecutor] that returns `null` (no mutations).
WakeExecutor get noOpExecutor =>
    (agentId, runKey, triggers, threadId) async => null;

// ── Mock stub helpers ────────────────────────────────────────────────────────

/// Re-stubs the core wake-run repository methods after
/// [clearInteractions].
///
/// This avoids repeating the same `when(...)` boilerplate in tests that
/// call `clearInteractions(mockRepository)` to isolate assertion windows.
void restubWakeRunMethods(MockAgentRepository repo) {
  when(
    () => repo.insertWakeRun(entry: any(named: 'entry')),
  ).thenAnswer((_) async {});
  when(
    () => repo.updateWakeRunStatus(
      any(),
      any(),
      completedAt: any(named: 'completedAt'),
      errorMessage: any(named: 'errorMessage'),
    ),
  ).thenAnswer((_) async {});
}

/// Stubs `insertWakeRun` on [repo] to capture entries into a list.
/// Returns the list for convenience.
List<WakeRunLogData> stubInsertCapture(MockAgentRepository repo) {
  final entries = <WakeRunLogData>[];
  when(
    () => repo.insertWakeRun(entry: any(named: 'entry')),
  ).thenAnswer((invocation) async {
    entries.add(invocation.namedArguments[#entry] as WakeRunLogData);
  });
  return entries;
}

// ── Verification helpers ─────────────────────────────────────────────────────

/// Captures and returns all [WakeRunLogData] entries passed to
/// [MockAgentRepository.insertWakeRun].
List<WakeRunLogData> captureWakeRuns(MockAgentRepository repo) {
  return verify(
    () => repo.insertWakeRun(entry: captureAny(named: 'entry')),
  ).captured.cast<WakeRunLogData>();
}

/// Captures and returns the single [WakeRunLogData] entry passed to
/// [MockAgentRepository.insertWakeRun].
WakeRunLogData captureSingleWakeRun(MockAgentRepository repo) {
  return verify(
        () => repo.insertWakeRun(entry: captureAny(named: 'entry')),
      ).captured.single
      as WakeRunLogData;
}
