import 'dart:convert';
import 'dart:developer' as developer;

import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_nudge_models.dart';
import 'package:lotti/features/agents/model/observation_record.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/workflow/agent_message_recording.dart';
import 'package:lotti/features/agents/workflow/agent_tool_arg_parsing.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/goals/workflow/goal_agent_contract.dart';
import 'package:openai_dart/openai_dart.dart';

/// A banner brief accumulated from one `create_goal_ad` call.
typedef GoalAdRequest = ({GoalNudgeBrief brief, String? reasonSummary});

/// A retire/rerun request accumulated during the conversation.
typedef GoalAdAction = ({String adId, String reason});

/// A revision proposal accumulated from `propose_goal_revision`.
typedef GoalRevisionProposal = ({
  Map<String, dynamic> changes,
  String rationale,
});

/// [ConversationStrategy] for the goal agent's Phase B wake.
///
/// Every tool of the contract is validated and ACCUMULATED here; nothing
/// is persisted mid-conversation. The workflow reads the accumulators
/// after the loop and writes all outputs in one transaction — so a wake
/// that dies halfway leaves no half-applied ad state behind.
///
/// A wake with zero tool calls is a legal outcome (policy row P2): the
/// continuation prompt never nags for a report, unlike the task/event
/// strategies.
class GoalAgentStrategy extends ConversationStrategy
    with ObservationRecordParsing, AgentMessageRecording {
  GoalAgentStrategy({
    required this.syncService,
    required this.agentId,
    required this.threadId,
    required this.runKey,
    required this._knownAdIds,
    this.expectedStatus,
  });

  @override
  final AgentSyncService syncService;
  @override
  final String agentId;
  @override
  final String threadId;
  @override
  final String runKey;

  /// Ad ids that exist in this wake's FACTS — the only ids retire/rerun
  /// may reference, so a hallucinated id fails in-conversation instead of
  /// corrupting the library.
  final Set<String> _knownAdIds;

  /// The deterministic track status of this wake's FACTS. The contract
  /// declares it authoritative, so a report claiming any other status is
  /// rejected in-conversation instead of publishing a contradiction.
  final GoalTrackStatus? expectedStatus;

  GoalTrackStatus? _reportStatus;
  String? _reportOneLiner;
  String? _reportTldr;
  String? _reportContent;
  String? _finalResponse;
  String? _replyToUser;
  final _createdAds = <GoalAdRequest>[];
  final _rerunRequests = <GoalAdAction>[];
  final _retireRequests = <GoalAdAction>[];
  final _revisionProposals = <GoalRevisionProposal>[];
  final _observations = <ObservationRecord>[];

  GoalTrackStatus? get reportStatus => _reportStatus;
  String? get reportOneLiner => _reportOneLiner;
  String? get reportTldr => _reportTldr;
  String? get reportContent => _reportContent;
  String? get finalResponse => _finalResponse;
  String? get replyToUser => _replyToUser;
  bool get hasReport => _reportStatus != null;
  List<GoalAdRequest> get createdAds => List.unmodifiable(_createdAds);
  List<GoalAdAction> get rerunRequests => List.unmodifiable(_rerunRequests);
  List<GoalAdAction> get retireRequests => List.unmodifiable(_retireRequests);
  List<GoalRevisionProposal> get revisionProposals =>
      List.unmodifiable(_revisionProposals);
  List<ObservationRecord> get observations => List.unmodifiable(_observations);

  /// Called by the workflow after the loop with the last assistant text.
  void recordFinalResponse(String? content) {
    if (content != null && content.isNotEmpty) _finalResponse = content;
  }

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
        developer.log(
          'Failed to parse tool call arguments for $toolName '
          '(rawBytes=${utf8.encode(call.function.arguments).length}, '
          'errorType=${e.runtimeType})',
          name: 'GoalAgentStrategy',
        );
        await _reject(
          call: call,
          manager: manager,
          error:
              'Error: invalid arguments format — expected a JSON object. '
              'Detail: ${e.runtimeType}',
        );
        continue;
      }

      await recordActionMessage(toolName: toolName);

      switch (toolName) {
        case GoalAgentToolNames.replyToUser:
          await _handleReplyToUser(call, args, manager);
        case GoalAgentToolNames.updateGoalReport:
          await _handleUpdateReport(call, args, manager);
        case GoalAgentToolNames.createGoalAd:
          await _handleCreateAd(call, args, manager);
        case GoalAgentToolNames.rerunGoalAd:
          await _handleAdAction(call, args, manager, _rerunRequests, 'rerun');
        case GoalAgentToolNames.retireGoalAd:
          await _handleAdAction(call, args, manager, _retireRequests, 'retire');
        case GoalAgentToolNames.proposeGoalRevision:
          await _handleProposeRevision(call, args, manager);
        case GoalAgentToolNames.recordGoalObservation:
          await _handleObservation(call, args, manager);
        default:
          await _reject(
            call: call,
            manager: manager,
            error: 'Error: unknown tool "$toolName".',
          );
      }
    }

    return ConversationAction.continueConversation;
  }

  @override
  bool shouldContinue(ConversationManager manager) => manager.canContinue();

  /// Never nags: "nothing material changed → no tools" is the contract's
  /// cheapest and most important behaviour, and a continuation prompt
  /// demanding output would train churn back in.
  @override
  String? getContinuationPrompt(ConversationManager manager) => null;

  Future<void> _handleUpdateReport(
    ChatCompletionMessageToolCall call,
    Map<String, dynamic> args,
    ConversationManager manager,
  ) async {
    final statusRaw = args['status'];
    final status = GoalTrackStatus.values
        .where((s) => s.name == statusRaw)
        .firstOrNull;
    final oneLiner = _trimmed(args['oneLiner']);
    final tldr = _trimmed(args['tldr']);
    if (status == null || oneLiner.isEmpty || tldr.isEmpty) {
      await _reject(
        call: call,
        manager: manager,
        error:
            'Error: update_goal_report needs status (one of '
            '${goalTrackStatusNames.join('|')}), a non-empty oneLiner and '
            'a non-empty tldr.',
      );
      return;
    }
    if (expectedStatus != null && status != expectedStatus) {
      await _reject(
        call: call,
        manager: manager,
        error:
            'Error: the FACTS trackStatus is "${expectedStatus!.name}" and '
            'it is authoritative — use it verbatim.',
      );
      return;
    }
    _reportStatus = status;
    _reportOneLiner = oneLiner;
    _reportTldr = tldr;
    final content = _trimmed(args['content']);
    _reportContent = content.isEmpty ? null : content;
    await _accept(call, manager, 'Goal report updated.');
  }

  Future<void> _handleReplyToUser(
    ChatCompletionMessageToolCall call,
    Map<String, dynamic> args,
    ConversationManager manager,
  ) async {
    final message = _trimmed(args['message']);
    if (message.isEmpty) {
      await _reject(
        call: call,
        manager: manager,
        error: 'Error: reply_to_user needs a non-empty message.',
      );
      return;
    }
    if (_replyToUser != null) {
      await _reject(
        call: call,
        manager: manager,
        error: 'Error: reply_to_user may be called at most once per wake.',
      );
      return;
    }
    _replyToUser = message;
    await _accept(call, manager, 'Reply delivered.');
  }

  Future<void> _handleCreateAd(
    ChatCompletionMessageToolCall call,
    Map<String, dynamic> args,
    ConversationManager manager,
  ) async {
    final headline = _trimmed(args['headline']);
    final tone = GoalNudgeTone.values
        .where((t) => t.name == args['tone'])
        .firstOrNull;
    final animation = GoalBannerAnimation.values
        .where((a) => a.name == args['animation'])
        .firstOrNull;
    if (headline.isEmpty || tone == null || animation == null) {
      await _reject(
        call: call,
        manager: manager,
        error:
            'Error: create_goal_ad needs a non-empty headline, tone (one '
            'of ${goalNudgeToneNames.join('|')}) and animation (one of '
            '${goalBannerAnimationNames.join('|')}).',
      );
      return;
    }
    final accent =
        GoalBannerAccent.values
            .where((a) => a.name == args['accent'])
            .firstOrNull ??
        GoalBannerAccent.calm;
    final tagline = _trimmed(args['tagline']);
    final cta = _trimmed(args['cta']);
    _createdAds.add((
      brief: GoalNudgeBrief(
        headline: headline,
        tone: tone,
        animation: animation,
        accent: accent,
        tagline: tagline.isEmpty ? null : tagline,
        cta: cta.isEmpty ? null : cta,
      ),
      reasonSummary: null,
    ));
    await _accept(call, manager, 'Banner ad queued for rendering.');
  }

  Future<void> _handleAdAction(
    ChatCompletionMessageToolCall call,
    Map<String, dynamic> args,
    ConversationManager manager,
    List<GoalAdAction> sink,
    String verb,
  ) async {
    final adId = _trimmed(args['adId']);
    final reason = _trimmed(args['reason']);
    if (adId.isEmpty || reason.isEmpty) {
      await _reject(
        call: call,
        manager: manager,
        error: 'Error: $verb needs both adId and reason.',
      );
      return;
    }
    if (!_knownAdIds.contains(adId)) {
      await _reject(
        call: call,
        manager: manager,
        error:
            'Error: unknown adId "$adId" — use an adId from the FACTS '
            'block exactly as given.',
      );
      return;
    }
    sink.add((adId: adId, reason: reason));
    await _accept(call, manager, 'Ad $verb recorded.');
  }

  Future<void> _handleProposeRevision(
    ChatCompletionMessageToolCall call,
    Map<String, dynamic> args,
    ConversationManager manager,
  ) async {
    final changes = args['changes'];
    final rationale = _trimmed(args['rationale']);
    if (changes is! Map<String, dynamic> ||
        changes.isEmpty ||
        rationale.isEmpty) {
      await _reject(
        call: call,
        manager: manager,
        error:
            'Error: propose_goal_revision needs a non-empty changes '
            'object and a rationale.',
      );
      return;
    }
    if (_revisionProposals.isNotEmpty) {
      await _reject(
        call: call,
        manager: manager,
        error:
            'Error: only one revision proposal per wake — the first one '
            'is already queued for user approval.',
      );
      return;
    }
    _revisionProposals.add((changes: changes, rationale: rationale));
    await _accept(call, manager, 'Revision proposal queued for user approval.');
  }

  Future<void> _handleObservation(
    ChatCompletionMessageToolCall call,
    Map<String, dynamic> args,
    ConversationManager manager,
  ) async {
    final note = _trimmed(args['note']);
    if (note.isEmpty) {
      await _reject(
        call: call,
        manager: manager,
        error: 'Error: "note" must be a non-empty string.',
      );
      return;
    }
    _observations.add(ObservationRecord(text: note));
    await _accept(call, manager, 'Observation recorded.');
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

  Future<void> _reject({
    required ChatCompletionMessageToolCall call,
    required ConversationManager manager,
    required String error,
  }) async {
    manager.addToolResponse(toolCallId: call.id, response: error);
    await recordToolResultMessage(
      toolName: call.function.name,
      errorMessage: error,
    );
  }
}
