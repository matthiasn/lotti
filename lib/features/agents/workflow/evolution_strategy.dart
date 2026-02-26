import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:openai_dart/openai_dart.dart';

/// Holds a pending directive proposal from the evolution agent.
class PendingProposal {
  const PendingProposal({
    required this.directives,
    required this.rationale,
  });

  final String directives;
  final String rationale;
}

/// Holds a pending evolution note from the evolution agent.
class PendingNote {
  const PendingNote({
    required this.kind,
    required this.content,
  });

  final EvolutionNoteKind kind;
  final String content;
}

/// Conversation strategy for evolution agent sessions.
///
/// Handles two tools locally:
/// - `propose_directives` — captures the proposal for user review
/// - `record_evolution_note` — accumulates notes for persistence
///
/// After each LLM turn, the strategy returns [ConversationAction.wait] to
/// hand control back to the user for the next message.
class EvolutionStrategy extends ConversationStrategy {
  final List<PendingNote> _pendingNotes = [];
  PendingProposal? _latestProposal;

  /// The most recent proposal from the evolution agent, if any.
  PendingProposal? get latestProposal => _latestProposal;

  /// All notes recorded during this session.
  List<PendingNote> get pendingNotes => List.unmodifiable(_pendingNotes);

  /// Clear the current proposal (e.g., after rejection).
  void clearProposal() {
    _latestProposal = null;
  }

  /// Removes and returns the first pending note.
  ///
  /// Used to drain notes one at a time during persistence, ensuring that
  /// already-persisted notes are removed even if a later write fails.
  PendingNote? removeFirstNote() {
    if (_pendingNotes.isEmpty) return null;
    return _pendingNotes.removeAt(0);
  }

  @override
  Future<ConversationAction> processToolCalls({
    required List<ChatCompletionMessageToolCall> toolCalls,
    required ConversationManager manager,
  }) async {
    for (final call in toolCalls) {
      final name = call.function.name;
      final args = _parseArgs(call.function.arguments);

      switch (name) {
        case 'propose_directives':
          _handleProposeDirectives(args, call.id, manager);
        case 'record_evolution_note':
          _handleRecordNote(args, call.id, manager);
        default:
          manager.addToolResponse(
            toolCallId: call.id,
            response: 'Unknown tool: $name',
          );
      }
    }

    // After processing tools, wait for user input.
    return ConversationAction.wait;
  }

  @override
  bool shouldContinue(ConversationManager manager) {
    return manager.canContinue();
  }

  @override
  String? getContinuationPrompt(ConversationManager manager) {
    // No automatic continuation — user drives the conversation.
    return null;
  }

  void _handleProposeDirectives(
    Map<String, dynamic> args,
    String callId,
    ConversationManager manager,
  ) {
    final directives = _readStringArg(args, 'directives');
    final rationale = _readStringArg(args, 'rationale');

    if (directives.trim().isEmpty) {
      manager.addToolResponse(
        toolCallId: callId,
        response: 'Error: directives cannot be empty.',
      );
      return;
    }

    _latestProposal = PendingProposal(
      directives: directives,
      rationale: rationale,
    );

    manager.addToolResponse(
      toolCallId: callId,
      response: 'Proposal recorded. Waiting for user review.',
    );
  }

  void _handleRecordNote(
    Map<String, dynamic> args,
    String callId,
    ConversationManager manager,
  ) {
    final kindStr = _readStringArg(args, 'kind');
    final content = _readStringArg(args, 'content');

    final kind =
        EvolutionNoteKind.values.firstWhereOrNull((k) => k.name == kindStr);
    if (kind == null) {
      manager.addToolResponse(
        toolCallId: callId,
        response: 'Error: invalid kind "$kindStr". '
            'Expected one of: ${EvolutionNoteKind.values.map((k) => k.name).join(", ")}.',
      );
      return;
    }

    if (content.trim().isEmpty) {
      manager.addToolResponse(
        toolCallId: callId,
        response: 'Error: content cannot be empty.',
      );
      return;
    }

    _pendingNotes.add(PendingNote(kind: kind, content: content));

    manager.addToolResponse(
      toolCallId: callId,
      response: 'Note recorded (${kind.name}).',
    );
  }

  /// Safely read a string argument, tolerating non-string JSON values.
  static String _readStringArg(Map<String, dynamic> args, String key) {
    final value = args[key];
    if (value is String) return value;
    return '';
  }

  Map<String, dynamic> _parseArgs(String arguments) {
    try {
      return jsonDecode(arguments) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }
}
