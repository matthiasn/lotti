import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/projection/input_capture.dart';
import 'package:lotti/features/agents/projection/input_events.dart';
import 'package:lotti/features/agents/service/agent_log_llm_summarizer.dart';
import 'package:lotti/features/agents/sync/agent_input_capture_service.dart';
import 'package:lotti/features/agents/sync/agent_log_compactor.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/consts.dart';

/// The read-flip outcome of one wake's memory pipeline (capture → flag →
/// fold → assemble), as consumed by a workflow's prompt assembly.
class WakeMemoryView {
  /// Wraps a pipeline result.
  const WakeMemoryView({
    required this.captureSucceeded,
    required this.compactionOn,
    required this.compactedLog,
    required this.useCompactedLog,
    this.activeSummaryId,
    this.lastEventPosition,
  });

  /// Whether THIS wake's capture refreshed the input frontier. The read-flip
  /// only trusts the captured substrate when true — otherwise capture failed
  /// (or didn't run) and the frontier may predate the current journal.
  final bool captureSucceeded;

  /// Whether the `enable_agent_compaction` flag (or test override) was on.
  final bool compactionOn;

  /// The assembled `active summary + event tail` block, or null when
  /// compaction is off or assembly failed.
  final String? compactedLog;

  /// True when the prompt should use [compactedLog] instead of the legacy
  /// inline context: compaction on, capture succeeded, and a non-empty
  /// replacement exists.
  final bool useCompactedLog;

  /// Reconstruction marker (ADR 0020 v2 prompt records): the active
  /// checkpoint's summary-message id at assembly time, or null.
  final String? activeSummaryId;

  /// Reconstruction marker: position of the last rendered tail event, or
  /// null when the tail was empty.
  final EventPosition? lastEventPosition;
}

/// The shared per-wake memory pipeline (ADR 0016/0017/0020), one instance per
/// workflow: captures the wake's rendered sources into the append-only log,
/// reads the `enable_agent_compaction` flag fresh each wake, folds the oldest
/// events past the trigger watermark into an LLM-distilled summary checkpoint
/// using the wake's own model, and assembles the compacted log block.
///
/// Every step is non-fatal and degrades to the legacy inline context: capture
/// failures, flag-read failures, summarizer failures and assembly failures
/// are logged and absorbed — memory is an optimization, never a correctness
/// requirement for a wake.
class AgentWakeMemory {
  /// Creates the pipeline. [compactionEnabled] non-null overrides the config
  /// flag (tests); production passes null so the flag is consulted at each
  /// wake (the wake executor captures workflow instances at initialization,
  /// so a provider-rebuild-based read would never reach them).
  AgentWakeMemory({
    required this.journalDb,
    required this.syncService,
    this.inputCaptureService,
    this.logSummarizer,
    this.compactionEnabled,
    this.domainLogger,
    this.logDomain = LogDomain.agentWorkflow,
  });

  /// Journal DB for the per-wake config-flag read. When null (a workflow
  /// without DB access), the flag cannot be consulted and compaction stays
  /// off unless [compactionEnabled] overrides it.
  final JournalDb? journalDb;

  /// Sync-aware writes + repository reads for the compactor.
  final AgentSyncService syncService;

  /// Capture service (ADR 0020); when null, capture is skipped and the
  /// read-flip never engages.
  final AgentInputCaptureService? inputCaptureService;

  /// The LLM edge for folds; when null, tails grow unbounded but reads still
  /// flip (no summarization).
  final AgentLogLlmSummarizer? logSummarizer;

  /// Test override for the `enable_agent_compaction` flag; null = consult it.
  final bool? compactionEnabled;

  /// Optional structured logger.
  final DomainLogger? domainLogger;

  /// Domain for diagnostics (workflows share `agentWorkflow`).
  final LogDomain logDomain;

  void _log(String message) {
    domainLogger?.log(logDomain, message, subDomain: 'compaction');
  }

  void _logError(String message, {Object? error}) {
    if (error != null) {
      domainLogger?.error(logDomain, error, message: message);
    }
  }

  /// Step 1a — capture this wake's rendered [sources] into the log
  /// (per-source, content-addressed, BEFORE assembly so the input frontier
  /// reflects the latest content). Returns whether capture succeeded;
  /// failures are logged and absorbed.
  Future<bool> capture({
    required String agentId,
    required List<RenderedSource> sources,
    required DateTime at,
    required String threadId,
    required String runKey,
  }) async {
    final captureService = inputCaptureService;
    if (captureService == null) return false;
    try {
      await captureService.captureWakeInputs(
        agentId: agentId,
        sources: sources,
        at: at,
        threadId: threadId,
        runKey: runKey,
      );
      return true;
    } catch (e) {
      _logError('failed to capture wake inputs', error: e);
      return false;
    }
  }

  /// Step 1b — read the flag, fold past the [budget] watermark (down to
  /// [retainTokens]) with the wake's resolved [model]/[provider], assemble
  /// the compacted log, and evaluate the read-flip gates.
  ///
  /// [inlineEvents] join the substrate (e.g. resolved proposal verdicts via
  /// `decisionEventsFromLedger`); [captureSucceeded] is [capture]'s result.
  Future<WakeMemoryView> compactAndAssemble({
    required String agentId,
    required bool captureSucceeded,
    required String model,
    required AiConfigInferenceProvider provider,
    required DateTime at,
    required String threadId,
    required String runKey,
    int budget = 50000,
    int retainTokens = 20000,
    List<InputEvent> inlineEvents = const [],
  }) async {
    var compactionOn = compactionEnabled ?? false;
    final flagDb = journalDb;
    if (compactionEnabled == null && flagDb != null) {
      try {
        compactionOn = await flagDb.getConfigFlag(
          enableAgentCompactionFlag,
        );
      } catch (e) {
        // Non-fatal: a failed flag read degrades the wake to the legacy
        // inline context, never aborts it.
        _logError(
          'failed to read $enableAgentCompactionFlag — compaction off '
          'this wake',
          error: e,
        );
      }
    }
    if (!compactionOn) {
      return const WakeMemoryView(
        captureSucceeded: false,
        compactionOn: false,
        compactedLog: null,
        useCompactedLog: false,
      );
    }

    final compactor = AgentLogCompactor(
      syncService: syncService,
      inlineEvents: inlineEvents,
    );

    final summarizerService = logSummarizer;
    if (summarizerService != null) {
      try {
        await compactor.maybeCompact(
          agentId: agentId,
          budget: budget,
          retainTokens: retainTokens,
          summarize: ({required sources, priorSummary}) =>
              summarizerService.summarize(
                sources: sources,
                priorSummary: priorSummary,
                model: model,
                provider: provider,
              ),
          at: at,
          threadId: threadId,
          runKey: runKey,
        );
      } catch (e) {
        _logError('failed to compact agent log', error: e);
      }
    }

    // Only flip the read when a real compacted replacement exists: capture/
    // compaction are optional and non-fatal, so if nothing was captured
    // (empty assembly) the wake falls back to the full inline context rather
    // than losing its log.
    AssembledLog? assembled;
    try {
      assembled = await compactor.assembleContextDetailed(agentId);
    } catch (e) {
      // Non-fatal: a read-side bug degrades to the legacy inline context
      // (and logs loudly) instead of killing the wake.
      _logError('failed to assemble compacted task log', error: e);
    }
    final compactedLog = assembled?.text;
    final useCompactedLog =
        captureSucceeded &&
        compactedLog != null &&
        compactedLog.trim().isNotEmpty;
    // PII-safe read-flip diagnostics: which gate kept the inline context?
    _log(
      'compaction read-flip: capture=$captureSucceeded '
      'assembledChars=${compactedLog?.length ?? -1} '
      'useCompactedLog=$useCompactedLog',
    );
    return WakeMemoryView(
      captureSucceeded: captureSucceeded,
      compactionOn: true,
      compactedLog: compactedLog,
      useCompactedLog: useCompactedLog,
      activeSummaryId: assembled?.activeSummaryId,
      lastEventPosition: assembled?.lastEventPosition,
    );
  }
}
