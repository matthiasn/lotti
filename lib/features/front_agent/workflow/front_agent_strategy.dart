import 'dart:convert';

import 'package:lotti/database/logging_types.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/workflow/agent_message_recording.dart';
import 'package:lotti/features/agents/workflow/agent_tool_arg_parsing.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_routing_index.dart';
import 'package:lotti/features/front_agent/workflow/front_agent_contract.dart';
import 'package:lotti/features/front_agent/workflow/front_dispatch_validator.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:openai_dart/openai_dart.dart';

/// Finds open tasks for a phrase the index does not show; the rows it
/// returns become valid destinations for the rest of the turn.
typedef FrontCorpusMatcher =
    Future<List<FrontIndexRow>> Function(String phrase);

/// One candidate offered by `ask_user`.
typedef FrontAskOption = ({FrontDestinationKind kind, String id, String label});

/// The clarifying question a turn ended with.
typedef FrontAskUser = ({String question, List<FrontAskOption> options});

/// [ConversationStrategy] for a front-agent turn (the goal-strategy shape):
/// every tool call is validated and ACCUMULATED; nothing is persisted
/// mid-conversation. The workflow reads the accumulators after the loop and
/// writes the outputs in one transaction.
///
/// Three calls end the turn — `dispatch`, `ask_user`, `reply_to_user` — and
/// the two lookups are capped by count, not by removing them from the list:
/// a shrinking tool list changes the request prefix and voids the provider's
/// cache, which a routing turn exists to keep warm.
class FrontAgentStrategy extends ConversationStrategy
    with AgentMessageRecording {
  FrontAgentStrategy({
    required this.syncService,
    required this.domainLogger,
    required this.agentId,
    required this.threadId,
    required this.runKey,
    required this.input,
    required this.index,
    this.corpusMatcher,
  });

  @override
  final AgentSyncService syncService;
  @override
  final DomainLogger domainLogger;
  @override
  final String agentId;
  @override
  final String threadId;
  @override
  final String runKey;

  /// The pending user message, exactly as the spans index into it.
  final String input;
  final FrontRoutingIndex index;

  /// Null when no FTS is wired (tests, evals without a journal): the tool
  /// then answers that it is unavailable.
  final FrontCorpusMatcher? corpusMatcher;

  FrontDispatch? _dispatch;
  FrontAskUser? _askUser;
  String? _replyToUser;
  int _tldrReads = 0;
  int _corpusMatches = 0;
  int _rejectedDispatches = 0;
  final _lookupRows = <FrontIndexRow>[];

  FrontDispatch? get dispatch => _dispatch;
  FrontAskUser? get askUser => _askUser;
  String? get replyToUser => _replyToUser;

  /// Whether the model ended the turn with one of the three terminal calls.
  bool get hasTerminalOutput =>
      _dispatch != null || _askUser != null || _replyToUser != null;

  /// How many `dispatch` calls failed validation this turn.
  int get rejectedDispatches => _rejectedDispatches;

  /// How many lookup calls ran (refused ones excluded).
  int get lookupCalls => _tldrReads + _corpusMatches;

  @override
  Future<ConversationAction> processToolCalls({
    required List<ChatCompletionMessageToolCall> toolCalls,
    required ConversationManager manager,
  }) async {
    await recordAssistantMessage();

    for (final call in toolCalls) {
      final toolName = call.function.name;
      Map<String, dynamic> args;
      try {
        args = parseAgentToolArguments(call.function.arguments);
      } catch (e) {
        domainLogger.log(
          LogDomain.agentWorkflow,
          'Failed to parse tool call arguments for $toolName '
          '(rawBytes=${utf8.encode(call.function.arguments).length}, '
          'errorType=${e.runtimeType})',
          subDomain: 'FrontAgentStrategy',
          level: InsightLevel.warn,
        );
        await _reject(
          call,
          manager,
          'Error: invalid arguments format — expected a JSON object. '
          'Detail: ${e.runtimeType}',
        );
        continue;
      }

      await recordActionMessage(toolName: toolName);

      switch (toolName) {
        case FrontAgentToolNames.dispatch:
          await _handleDispatch(call, args, manager);
        case FrontAgentToolNames.readTldr:
          await _handleReadTldr(call, args, manager);
        case FrontAgentToolNames.matchToCorpus:
          await _handleMatchToCorpus(call, args, manager);
        case FrontAgentToolNames.askUser:
          await _handleAskUser(call, args, manager);
        case FrontAgentToolNames.replyToUser:
          await _handleReplyToUser(call, args, manager);
        default:
          await _reject(call, manager, 'Error: unknown tool "$toolName".');
      }
    }

    return hasTerminalOutput
        ? ConversationAction.complete
        : ConversationAction.continueConversation;
  }

  @override
  bool shouldContinue(ConversationManager manager) =>
      !hasTerminalOutput && manager.canContinue();

  /// The turn is bounded by the repair instruction the workflow sends, not
  /// by a nag here.
  @override
  String? getContinuationPrompt(ConversationManager manager) => null;

  bool _destinationExists(FrontDestinationKind kind, String id) =>
      index.contains(kind, id) ||
      _lookupRows.any((row) => row.kind == kind && row.id == id);

  Future<void> _handleDispatch(
    ChatCompletionMessageToolCall call,
    Map<String, dynamic> args,
    ConversationManager manager,
  ) async {
    if (_dispatch != null) {
      await _reject(
        call,
        manager,
        'Error: dispatch may be called at most once per turn.',
      );
      return;
    }
    if (_askUser != null) {
      await _reject(
        call,
        manager,
        'Error: the turn already ended with ask_user; do not dispatch and '
        'ask in the same turn.',
      );
      return;
    }
    final (:dispatch, :error) = validateFrontDispatch(
      args: args,
      input: input,
      destinationExists: _destinationExists,
    );
    if (dispatch == null) {
      _rejectedDispatches++;
      await _reject(call, manager, error!);
      return;
    }
    _dispatch = dispatch;
    await _accept(
      call,
      manager,
      'Dispatched ${dispatch.segments.length} '
      'segment(s).',
    );
  }

  Future<void> _handleReadTldr(
    ChatCompletionMessageToolCall call,
    Map<String, dynamic> args,
    ConversationManager manager,
  ) async {
    if (_tldrReads >= frontTldrReadsPerTurn) {
      await _reject(call, manager, frontTldrExhaustedAnswer);
      return;
    }
    final raw = args['ids'];
    final ids = raw is List
        ? raw.whereType<String>().toList()
        : const <String>[];
    if (ids.isEmpty || ids.length > frontTldrIdsPerRead) {
      await _reject(
        call,
        manager,
        'Error: read_tldr needs 1 to $frontTldrIdsPerRead ids as listed, '
        'e.g. "task:<id>".',
      );
      return;
    }
    _tldrReads++;
    final buffer = StringBuffer();
    for (final ref in ids) {
      final row = _rowByRef(ref);
      buffer
        ..write(ref)
        ..write(': ');
      if (row == null) {
        buffer.writeln('not listed');
      } else {
        final tldr = row.tldr?.trim();
        buffer.writeln(tldr == null || tldr.isEmpty ? 'no TL;DR yet' : tldr);
      }
    }
    await _accept(call, manager, buffer.toString().trimRight());
  }

  /// A listed row by its `kind:id` reference, or null.
  FrontIndexRow? _rowByRef(String ref) {
    final colon = ref.indexOf(':');
    if (colon <= 0) return null;
    final kind = FrontDestinationKind.fromWireName(ref.substring(0, colon));
    if (kind == null) return null;
    final id = ref.substring(colon + 1);
    return index.row(kind, id) ??
        _lookupRows
            .where((row) => row.kind == kind && row.id == id)
            .firstOrNull;
  }

  Future<void> _handleMatchToCorpus(
    ChatCompletionMessageToolCall call,
    Map<String, dynamic> args,
    ConversationManager manager,
  ) async {
    if (_corpusMatches >= frontCorpusMatchesPerTurn) {
      await _reject(call, manager, frontCorpusMatchExhaustedAnswer);
      return;
    }
    final phrase = _trimmed(args['phrase']);
    if (phrase.isEmpty) {
      await _reject(call, manager, 'Error: match_to_corpus needs a phrase.');
      return;
    }
    final matcher = corpusMatcher;
    if (matcher == null) {
      await _reject(
        call,
        manager,
        'Corpus matching is unavailable this turn; decide from the index '
        'or ask the user.',
      );
      return;
    }
    _corpusMatches++;
    final rows = await matcher(phrase);
    _lookupRows.addAll(rows);
    if (rows.isEmpty) {
      await _accept(call, manager, 'No open task matches "$phrase".');
      return;
    }
    final buffer = StringBuffer();
    for (final row in rows) {
      buffer
        ..write(row.kind.wireName)
        ..write(':')
        ..write(row.id)
        ..write(' | ')
        ..write(row.title);
      if (row.status != null) buffer.write(' | ${row.status}');
      buffer.writeln();
    }
    await _accept(call, manager, buffer.toString().trimRight());
  }

  Future<void> _handleAskUser(
    ChatCompletionMessageToolCall call,
    Map<String, dynamic> args,
    ConversationManager manager,
  ) async {
    if (_askUser != null) {
      await _reject(
        call,
        manager,
        'Error: ask_user may be called at most once per turn.',
      );
      return;
    }
    if (_dispatch != null) {
      await _reject(
        call,
        manager,
        'Error: the turn already ended with dispatch; do not dispatch and '
        'ask in the same turn.',
      );
      return;
    }
    final question = _trimmed(args['question']);
    if (question.isEmpty) {
      await _reject(call, manager, 'Error: ask_user needs a question.');
      return;
    }
    final rawOptions = args['options'];
    final options = <FrontAskOption>[];
    if (rawOptions is List) {
      for (final item in rawOptions) {
        if (item is! Map) continue;
        final kind = FrontDestinationKind.fromWireName(item['kind']);
        final id = _trimmed(item['id']);
        final label = _trimmed(item['label']);
        if (kind == null || !kind.needsId || id.isEmpty || label.isEmpty) {
          await _reject(
            call,
            manager,
            'Error: every ask_user option needs a kind '
            '(task|project|goal|person), a listed id and a label.',
          );
          return;
        }
        if (!_destinationExists(kind, id)) {
          await _reject(
            call,
            manager,
            'Error: option ${kind.wireName}:$id is not in <routing_index> or '
            'a lookup result this turn.',
          );
          return;
        }
        options.add((kind: kind, id: id, label: label));
      }
    }
    if (options.length > frontAskUserMaxOptions) {
      await _reject(
        call,
        manager,
        'Error: ask_user offers at most $frontAskUserMaxOptions options.',
      );
      return;
    }
    _askUser = (question: question, options: options);
    await _accept(call, manager, 'Question delivered.');
  }

  Future<void> _handleReplyToUser(
    ChatCompletionMessageToolCall call,
    Map<String, dynamic> args,
    ConversationManager manager,
  ) async {
    final message = _trimmed(args['message']);
    if (message.isEmpty) {
      await _reject(
        call,
        manager,
        'Error: reply_to_user needs a non-empty message.',
      );
      return;
    }
    if (_replyToUser != null) {
      await _reject(
        call,
        manager,
        'Error: reply_to_user may be called at most once per turn.',
      );
      return;
    }
    _replyToUser = message;
    await _accept(call, manager, 'Reply delivered.');
  }

  String _trimmed(Object? value) => value is String ? value.trim() : '';

  Future<void> _accept(
    ChatCompletionMessageToolCall call,
    ConversationManager manager,
    String response,
  ) async {
    manager.addToolResponse(toolCallId: call.id, response: response);
    await recordToolResultMessage(toolName: call.function.name);
  }

  Future<void> _reject(
    ChatCompletionMessageToolCall call,
    ConversationManager manager,
    String error,
  ) async {
    manager.addToolResponse(toolCallId: call.id, response: error);
    await recordToolResultMessage(
      toolName: call.function.name,
      errorMessage: error,
    );
  }
}
