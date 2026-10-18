import 'package:lotti/features/agents/memory/memory_search.dart';
import 'package:lotti/features/agents/projection/input_events.dart';
import 'package:lotti/features/agents/sync/agent_log_compactor.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/goals/model/goal_checkin_source.dart';
import 'package:lotti/features/goals/service/goal_chat_history_service.dart';
import 'package:lotti/services/domain_logging.dart';

/// How much of one recalled entry a keyword search shows: a long check-in is
/// cut, and pulling it up by id reads it whole, up to
/// [goalMemoryResultTokenBudget].
const int goalMemoryHitTokenBudget = 250;

/// How much one recall may add to a wake — about a fifth of the ≤8k a goal
/// wake targets (ADR 0057). Hits past it are counted, not listed.
const int goalMemoryResultTokenBudget = 1500;

/// How many recalls one wake may make. A wake that needs more is fishing.
const int goalMemorySearchesPerWake = 3;

/// The turn a wake takes after recalling: read the answer, finish the work.
const goalMemoryContinuationPrompt =
    'Continue with what you recalled: complete the calls this wake still '
    'needs. Search again only if a needed detail is still missing.';

/// The answer when a wake has no recall wired.
const goalMemoryUnavailableAnswer =
    'Memory recall is unavailable on this wake; work from FACTS.';

/// The answer once a wake has used its recalls.
const goalMemoryExhaustedAnswer =
    'No more memory searches this wake ($goalMemorySearchesPerWake used); '
    'work with what you recalled.';

/// The kinds a recalled goal entry reads as, beside the compactor's own
/// `observation`.
abstract final class GoalMemoryEntryTypes {
  /// A check-in the user recorded or wrote for the goal.
  static const checkIn = 'checkIn';

  /// Something the user said to the agent in chat.
  static const userMessage = 'userMessage';

  /// Something the agent said back.
  static const agentReply = 'agentReply';
}

/// What one recall answers: the text the model reads, and whether it is an
/// answer at all or a refusal it can act on.
typedef GoalMemoryRecall = ({bool ok, String text});

/// Runs one recall for a wake: the `search_goal_memory` tool call's
/// arguments in, what the model reads back out.
typedef GoalMemorySearcher =
    Future<GoalMemoryRecall> Function(Map<String, dynamic> args);

/// The goal's history beyond its agent log, as the memory log's inline
/// events: every check-in in the user's own words — never the compacted
/// summary, which is what the wake already has — and every chat turn. They
/// interleave with the agent's observations by when they happened.
List<InputEvent> goalMemoryEvents({
  required List<GoalCheckInSource> checkIns,
  required List<GoalChatHistoryEntry> dialogue,
}) => [
  for (final checkIn in checkIns)
    InputEvent.inline(
      position: EventPosition(
        at: checkIn.recordedAt,
        sourceAt: checkIn.recordedAt,
        key: 'checkin|${checkIn.entryId}',
      ),
      contentEntryId: checkIn.entryId,
      sourceCreatedAt: checkIn.recordedAt,
      inlineContent: {
        'entryType': GoalMemoryEntryTypes.checkIn,
        'text': checkIn.text,
      },
    ),
  for (final turn in dialogue)
    InputEvent.inline(
      position: EventPosition(
        at: turn.createdAt,
        sourceAt: turn.createdAt,
        key: 'chat|${turn.id}',
      ),
      contentEntryId: turn.id,
      sourceCreatedAt: turn.createdAt,
      inlineContent: {
        'entryType': turn.role == GoalChatHistoryRole.user
            ? GoalMemoryEntryTypes.userMessage
            : GoalMemoryEntryTypes.agentReply,
        'text': turn.text,
      },
    ),
];

/// A goal agent's memory recall (ADR 0057 decision 1): the shared
/// memory-search tool over everything the goal has heard — check-ins, chat,
/// and the agent's own observations — not only the bounded slice a wake
/// carries.
///
/// Each source is read when a recall runs, and each is contained: a source
/// that cannot be read costs the recall that source and is logged, never
/// the wake.
class GoalMemorySearch {
  GoalMemorySearch({
    required this._syncService,
    required this._chatHistory,
    required this._logger,
    this._checkInSourceReader,
  });

  final AgentSyncService _syncService;
  final GoalChatHistoryService _chatHistory;
  final DomainLogger _logger;
  final GoalCheckInSourceReader? _checkInSourceReader;

  /// [GoalMemorySearcher] for [agentId]'s wake.
  GoalMemorySearcher forAgent(String agentId) =>
      (args) => search(agentId, args);

  /// Runs the recall [args] ask for over [agentId]'s memory.
  Future<GoalMemoryRecall> search(
    String agentId,
    Map<String, dynamic> args,
  ) async {
    final request = parseMemorySearchRequest(args);
    if (request == null) {
      return (ok: false, text: memorySearchMissingTermsError);
    }

    final checkIns = await _read(
      'check-ins',
      () async =>
          await _checkInSourceReader?.call(agentId) ??
          const <GoalCheckInSource>[],
    );
    final dialogue = await _read(
      'chat',
      () => _chatHistory.allDialogue(agentId),
    );
    try {
      final compactor = AgentLogCompactor(
        syncService: _syncService,
        inlineEvents: goalMemoryEvents(
          checkIns: checkIns ?? const [],
          dialogue: dialogue ?? const [],
        ),
      );
      final hits = await runMemorySearch(compactor, agentId, request);
      return (
        ok: true,
        text: formatMemorySearchResult(
          request,
          hits,
          // By id is how a cut hit is read whole — the omission note and the
          // cut text both point there — so an id gets the recall's whole
          // budget rather than the keyword hit's slice it already showed.
          hitTokenBudget: request.ids.isNotEmpty
              ? goalMemoryResultTokenBudget
              : goalMemoryHitTokenBudget,
          totalTokenBudget: goalMemoryResultTokenBudget,
        ),
      );
    } catch (error, stackTrace) {
      _logger.error(
        LogDomain.agentWorkflow,
        error,
        stackTrace: stackTrace,
        subDomain: 'GoalMemorySearch',
        message: 'goal memory search failed',
      );
      return (ok: false, text: memorySearchFailedError);
    }
  }

  Future<T?> _read<T>(String source, Future<T> Function() read) async {
    try {
      return await read();
    } catch (error, stackTrace) {
      _logger.error(
        LogDomain.agentWorkflow,
        error,
        stackTrace: stackTrace,
        subDomain: 'GoalMemorySearch',
        message: 'goal memory search could not read its $source',
      );
      return null;
    }
  }
}
