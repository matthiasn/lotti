import 'dart:convert';
import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:lotti/classes/nudge_models.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/workflow/agent_message_recording.dart';
import 'package:lotti/features/agents/workflow/agent_tool_arg_parsing.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/relationships/model/relationship_health_metrics.dart';
import 'package:lotti/features/relationships/workflow/relationship_agent_contract.dart';
import 'package:openai_dart/openai_dart.dart';

/// A banner brief accumulated from one `create_relationship_ad` call.
typedef RelationshipAdRequest = ({NudgeBrief brief, String? reasonSummary});

/// A request to hide one active banner until an exact future instant.
typedef RelationshipAdSnooze = ({
  String adId,
  DateTime until,
  int returnUtcOffsetMinutes,
  String reason,
});

/// The accumulated briefing of one `update_relationship_report` call.
typedef RelationshipBriefing = ({
  RelationshipHealthBand band,
  String rationale,
  double? confidence,
  String oneLiner,
  String tldr,
  String content,
});

/// [ConversationStrategy] for the relationship agent's Phase B wake (the
/// goal-strategy shape): every tool call is validated and ACCUMULATED;
/// nothing is persisted mid-conversation. The workflow reads the
/// accumulators after the loop and writes all outputs in one transaction,
/// so a wake that dies halfway leaves no half-applied state behind.
///
/// A wake with zero tool calls is a legal outcome: the continuation prompt
/// never nags for output.
class RelationshipAgentStrategy extends ConversationStrategy
    with AgentMessageRecording {
  RelationshipAgentStrategy({
    required this.syncService,
    required this.agentId,
    required this.threadId,
    required this.runKey,
    required this._activeAdIds,
  });

  @override
  final AgentSyncService syncService;
  @override
  final String agentId;
  @override
  final String threadId;
  @override
  final String runKey;

  /// Ad ids currently rendered — the only ids snooze may reference, so a
  /// hallucinated id fails in-conversation instead of corrupting state.
  final Set<String> _activeAdIds;

  RelationshipBriefing? _briefing;
  String? _finalResponse;
  String? _replyToUser;
  final _createdAds = <RelationshipAdRequest>[];
  final _snoozeRequests = <RelationshipAdSnooze>[];

  RelationshipBriefing? get briefing => _briefing;
  bool get hasBriefing => _briefing != null;
  String? get finalResponse => _finalResponse;
  String? get replyToUser => _replyToUser;
  List<RelationshipAdRequest> get createdAds => List.unmodifiable(_createdAds);
  List<RelationshipAdSnooze> get snoozeRequests =>
      List.unmodifiable(_snoozeRequests);

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
          name: 'RelationshipAgentStrategy',
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
        case RelationshipAgentToolNames.replyToUser:
          await _handleReplyToUser(call, args, manager);
        case RelationshipAgentToolNames.updateRelationshipReport:
          await _handleUpdateReport(call, args, manager);
        case RelationshipAgentToolNames.createRelationshipAd:
          await _handleCreateAd(call, args, manager);
        case RelationshipAgentToolNames.snoozeRelationshipAd:
          await _handleSnoozeAd(call, args, manager);
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
  /// cheapest behaviour, and a continuation prompt demanding output would
  /// train churn back in (the goal-strategy lesson).
  @override
  String? getContinuationPrompt(ConversationManager manager) => null;

  Future<void> _handleUpdateReport(
    ChatCompletionMessageToolCall call,
    Map<String, dynamic> args,
    ConversationManager manager,
  ) async {
    final band = RelationshipHealthBand.values
        .where((b) => b.name == args['healthBand'])
        .firstOrNull;
    final rationale = _trimmed(args['healthRationale']);
    final oneLiner = _trimmed(args['oneLiner']);
    final tldr = _trimmed(args['tldr']);
    final content = _trimmed(args['content']);
    if (band == null ||
        rationale.isEmpty ||
        oneLiner.isEmpty ||
        tldr.isEmpty ||
        content.isEmpty) {
      await _reject(
        call: call,
        manager: manager,
        error:
            'Error: update_relationship_report needs healthBand (one of '
            '${relationshipHealthBandNames.join('|')}), a non-empty '
            'healthRationale, oneLiner, tldr and content.',
      );
      return;
    }
    // Band names are field values, never prose (the goal-strategy rule):
    // "the relationship is needsAttention" must not reach the user.
    final tokenInProse = _bandTokenIn([oneLiner, tldr, content, rationale]);
    if (tokenInProse != null) {
      await _reject(
        call: call,
        manager: manager,
        error:
            'Error: "$tokenInProse" is a health-band field value, not '
            "prose. Rewrite the visible text in the user's language and "
            'call update_relationship_report again.',
      );
      return;
    }
    final rawConfidence = args['healthConfidence'];
    final confidence =
        rawConfidence is num &&
            rawConfidence.isFinite &&
            rawConfidence >= 0 &&
            rawConfidence <= 1
        ? rawConfidence.toDouble()
        : null;
    _briefing = (
      band: band,
      rationale: rationale,
      confidence: confidence,
      oneLiner: oneLiner,
      tldr: tldr,
      content: content,
    );
    await _accept(call, manager, 'Briefing updated.');
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
    // One banner per wake (the run-scoped deterministic id can persist only
    // one row) — reject the repeat IN-CONVERSATION rather than confirming
    // output that the transaction would silently discard (the
    // `reply_to_user` at-most-once pattern).
    if (_createdAds.isNotEmpty) {
      await _reject(
        call: call,
        manager: manager,
        error:
            'Error: create_relationship_ad may be called at most once per '
            'wake; the first banner is already queued.',
      );
      return;
    }
    final headline = _trimmed(args['headline']);
    final tone = NudgeTone.values
        .where((t) => t.name == args['tone'])
        .firstOrNull;
    final animation = NudgeBannerAnimation.values
        .where((a) => a.name == args['animation'])
        .firstOrNull;
    if (headline.isEmpty || tone == null || animation == null) {
      await _reject(
        call: call,
        manager: manager,
        error:
            'Error: create_relationship_ad needs a non-empty headline, '
            'tone (one of ${relationshipNudgeToneNames.join('|')}) and '
            'animation (one of '
            '${relationshipBannerAnimationNames.join('|')}).',
      );
      return;
    }
    final accent =
        NudgeBannerAccent.values
            .where((a) => a.name == args['accent'])
            .firstOrNull ??
        NudgeBannerAccent.calm;
    final tagline = _trimmed(args['tagline']);
    final cta = _trimmed(args['cta']);
    _createdAds.add((
      brief: NudgeBrief(
        headline: headline,
        tone: tone,
        animation: animation,
        accent: accent,
        tagline: tagline.isEmpty ? null : tagline,
        cta: cta.isEmpty ? null : cta,
      ),
      reasonSummary: null,
    ));
    await _accept(call, manager, 'Banner nudge queued for rendering.');
  }

  Future<void> _handleSnoozeAd(
    ChatCompletionMessageToolCall call,
    Map<String, dynamic> args,
    ConversationManager manager,
  ) async {
    final adId = _trimmed(args['adId']);
    final reason = _trimmed(args['reason']);
    final untilText = _trimmed(args['until']);
    final hasExplicitOffset = RegExp(
      r'(?:[zZ]|[+-]\d{2}:?\d{2})$',
    ).hasMatch(untilText);
    final until = hasExplicitOffset
        ? DateTime.tryParse(untilText)?.toUtc()
        : null;
    final returnUtcOffsetMinutes = hasExplicitOffset
        ? _iso8601UtcOffsetMinutes(untilText)
        : null;
    if (adId.isEmpty ||
        reason.isEmpty ||
        until == null ||
        returnUtcOffsetMinutes == null ||
        !until.isAfter(clock.now().toUtc())) {
      await _reject(
        call: call,
        manager: manager,
        error:
            'Error: snooze needs a known active adId, a future ISO 8601 '
            'until instant, and a reason.',
      );
      return;
    }
    if (!_activeAdIds.contains(adId)) {
      await _reject(
        call: call,
        manager: manager,
        error:
            'Error: adId "$adId" is not active — snooze an active adId '
            'from the FACTS block exactly as given.',
      );
      return;
    }
    final request = (
      adId: adId,
      until: until,
      returnUtcOffsetMinutes: returnUtcOffsetMinutes,
      reason: reason,
    );
    final alreadyRequested = _snoozeRequests.any(
      (existing) =>
          existing.adId == request.adId &&
          existing.until == request.until &&
          existing.returnUtcOffsetMinutes == request.returnUtcOffsetMinutes,
    );
    if (!alreadyRequested) _snoozeRequests.add(request);
    await _accept(
      call,
      manager,
      'Banner snoozed until ${until.toIso8601String()}.',
    );
  }

  int? _iso8601UtcOffsetMinutes(String value) {
    if (value.endsWith('Z') || value.endsWith('z')) return 0;
    final match = RegExp(r'([+-])(\d{2}):?(\d{2})$').firstMatch(value);
    if (match == null) return null;
    final hours = int.parse(match.group(2)!);
    final minutes = int.parse(match.group(3)!);
    if (hours > 14 || minutes > 59 || (hours == 14 && minutes != 0)) {
      return null;
    }
    final absolute = hours * 60 + minutes;
    return match.group(1) == '-' ? -absolute : absolute;
  }

  /// The first UNMISTAKABLE band token found standing as a word in any
  /// visible string. Unlike the goal statuses, most relationship bands are
  /// ordinary English words (`steady`, `thriving`, `strained`) that a
  /// legitimate briefing may well contain — only the camelCase identifiers
  /// (`needsAttention`) that no language writes by accident are banned
  /// from prose.
  String? _bandTokenIn(List<String> texts) {
    final unmistakable = relationshipHealthBandNames.where(
      (token) => token != token.toLowerCase(),
    );
    for (final text in texts) {
      if (text.isEmpty) continue;
      for (final token in unmistakable) {
        if (RegExp('\\b$token\\b').hasMatch(text)) return token;
      }
    }
    return null;
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
