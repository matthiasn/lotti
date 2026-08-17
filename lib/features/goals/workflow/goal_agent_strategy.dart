import 'dart:convert';
import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/nudge_models.dart';
import 'package:lotti/features/agents/model/observation_record.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/workflow/agent_message_recording.dart';
import 'package:lotti/features/agents/workflow/agent_tool_arg_parsing.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/goals/workflow/goal_agent_contract.dart';
import 'package:openai_dart/openai_dart.dart';

/// A banner brief accumulated from one `create_goal_ad` call.
typedef GoalAdRequest = ({NudgeBrief brief, String? reasonSummary});

/// A retire/rerun request accumulated during the conversation.
typedef GoalAdAction = ({String adId, String reason});

/// A request to hide one active banner until an exact future instant.
typedef GoalAdSnooze = ({
  String adId,
  DateTime until,
  int returnUtcOffsetMinutes,
  String reason,
});

/// A revision proposal accumulated from `propose_goal_revision_v2`.
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
    required Set<String> knownAdIds,
    Set<String>? activeAdIds,
    this._allowedCurrentActionCriterionIds = const {},
    this.expectedStatus,
    this.expectedRollingAggregates = const [],
  }) : _knownAdIds = knownAdIds,
       _activeAdIds = activeAdIds ?? knownAdIds;

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

  /// Ad ids that are currently rendered. Snoozing is only meaningful for
  /// this subset; reusable or retired library entries remain valid rerun
  /// targets but cannot be hidden from a surface where they are not shown.
  final Set<String> _activeAdIds;

  /// Criterion ids deterministic FACTS explicitly mark actionable at the
  /// evaluation reference. Explicit structured current-action items with any
  /// other id are dropped before the report becomes user-visible.
  final Set<String> _allowedCurrentActionCriterionIds;

  /// The deterministic track status of this wake's FACTS. The contract
  /// declares it authoritative, so a report claiming any other status is
  /// rejected in-conversation instead of publishing a contradiction.
  final GoalTrackStatus? expectedStatus;

  /// Deterministic aggregate values, pre-rounded exactly as FACTS render them,
  /// that the report's rolling standing must quote. Empty disables the check.
  final List<String> expectedRollingAggregates;

  GoalTrackStatus? _reportStatus;
  String? _reportOneLiner;
  String? _reportTldr;
  String? _reportContent;
  Map<String, Object?>? _reportSections;
  String? _finalResponse;
  String? _replyToUser;
  var _bannerRequested = false;
  final _createdAds = <GoalAdRequest>[];
  final _rerunRequests = <GoalAdAction>[];
  final _retireRequests = <GoalAdAction>[];
  final _snoozeRequests = <GoalAdSnooze>[];
  final _revisionProposals = <GoalRevisionProposal>[];
  final _observations = <ObservationRecord>[];

  GoalTrackStatus? get reportStatus => _reportStatus;
  String? get reportOneLiner => _reportOneLiner;
  String? get reportTldr => _reportTldr;
  String? get reportContent => _reportContent;

  /// The report's sections as data, for the card to render under localized
  /// headings. Null for a free-form report, which has none.
  Map<String, Object?>? get reportSections => _reportSections;
  String? get finalResponse => _finalResponse;
  String? get replyToUser => _replyToUser;

  /// Whether the reply declared that the pending message asked for a banner.
  ///
  /// The language-independent half of P5. The runtime's regex detector reads
  /// English only, and the typed `create_goal_ad` call cannot carry the intent
  /// on a wake whose tools were withheld, so the model states it as data and
  /// the deterministic tier decides what to do with it.
  bool get bannerRequested => _bannerRequested;
  bool get hasReport => _reportStatus != null;
  List<GoalAdRequest> get createdAds => List.unmodifiable(_createdAds);
  List<GoalAdAction> get rerunRequests => List.unmodifiable(_rerunRequests);
  List<GoalAdAction> get retireRequests => List.unmodifiable(_retireRequests);
  List<GoalAdSnooze> get snoozeRequests => List.unmodifiable(_snoozeRequests);
  List<GoalRevisionProposal> get revisionProposals =>
      List.unmodifiable(_revisionProposals);
  List<ObservationRecord> get observations => List.unmodifiable(_observations);

  /// Called by the workflow after the loop with the last assistant text.
  void recordFinalResponse(String? content) {
    if (content != null && content.isNotEmpty) _finalResponse = content;
  }

  /// Drops a reply the deterministic workflow proved stale so a pinned
  /// corrective reply can replace it within the same wake.
  void discardVisibleReply() {
    _replyToUser = null;
    _finalResponse = null;
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
        case GoalAgentToolNames.snoozeGoalAd:
          await _handleSnoozeAd(call, args, manager);
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
    final content = _trimmed(args['content']);
    final hasStructuredReport = args.containsKey('report');
    final structured = GoalStructuredReport.tryParse(args['report']);
    final tldr = hasStructuredReport
        ? structured?.tldr ?? ''
        : _trimmed(args['tldr']);
    if (status == null || oneLiner.isEmpty || tldr.isEmpty) {
      await _reject(
        call: call,
        manager: manager,
        error: hasStructuredReport
            ? 'Error: update_goal_report needs status (one of '
                  '${goalTrackStatusNames.join('|')}), a non-empty oneLiner '
                  'and a complete structured report.'
            : 'Error: update_goal_report needs status (one of '
                  '${goalTrackStatusNames.join('|')}), a non-empty oneLiner '
                  'and a non-empty tldr.',
      );
      return;
    }
    // The prompt tells the model that status names are field values, never
    // prose. That instruction is the only thing standing between a weaker
    // model and "the overall status is insufficientData" reaching the user, so
    // it is enforced here too: reject and let the model retry in the user's
    // own language. Deliberately not sanitized away — deleting the token would
    // leave a sentence with a hole in it, and mapping it to English words
    // would put English into ten other catalogs.
    final tokenInProse = _statusTokenIn([
      oneLiner,
      tldr,
      if (structured != null) ...[
        structured.currentPeriod,
        structured.rollingWindow,
        structured.latestChange,
        structured.coverage,
        for (final item in structured.now) item.action,
        ...structured.later,
      ],
      content,
    ]);
    if (tokenInProse != null) {
      await _reject(
        call: call,
        manager: manager,
        error:
            'Error: "$tokenInProse" is a status field value, not prose. '
            "Rewrite the visible text in the user's language and call "
            'update_goal_report again.',
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
    // The rolling standing slot exists to state the deterministic aggregate.
    // Models substitute the LATEST reading for it — reporting a 7-day mean
    // weight of 94 kg when FACTS say 95 — or recompute a spurious precision
    // ("127.85" where FACTS carry 127). Both put a wrong number in front of
    // the user, and every evaluated model does it, so it is enforced here
    // rather than asked for in prose. Same authority as trackStatus above.
    if (structured != null && expectedRollingAggregates.isNotEmpty) {
      final missing = expectedRollingAggregates
          .where((value) => !_quotesNumber(structured.rollingWindow, value))
          .toList();
      if (missing.isNotEmpty) {
        await _reject(
          call: call,
          manager: manager,
          error:
              'Error: the rolling standing must quote the FACTS aggregates '
              'verbatim — ${missing.join(', ')} '
              '${missing.length == 1 ? 'is' : 'are'} missing. Use the '
              'aggregate, never the latest reading, and never recompute it.',
        );
        return;
      }
    }
    _reportStatus = status;
    _reportOneLiner = oneLiner;
    _reportTldr = tldr;
    // A structured report supplies both tiers: `tldr` is the collapsed view
    // above, and the composed sections are the body behind "Show more". Any
    // free-form `content` alongside it is ignored, so it cannot reintroduce
    // an action the deterministic current-action filter removed.
    //
    // Composing the sections into `tldr` instead — which is what this did —
    // left `content` null, and the card's expandable test (`content != tldr`)
    // then found nothing to expand. The whole report rendered collapsed, as
    // one unbroken wall of text with no affordance to shorten it.
    _reportContent = hasStructuredReport
        ? structured?.visibleSummary(
            allowedCurrentActionCriterionIds: _allowedCurrentActionCriterionIds,
          )
        : (content.isEmpty ? null : content);
    // Persisted beside the composed markdown, not instead of it: the flat
    // text stays the fallback for any surface that has only `content`, and
    // for reports written before sections existed.
    _reportSections = structured?.toProvenance(
      allowedCurrentActionCriterionIds: _allowedCurrentActionCriterionIds,
    );
    await _accept(call, manager, 'Goal report updated.');
  }

  /// Whether [text] quotes [value] as a COMPLETE number.
  ///
  /// Substring matching passed the exact fabrication this check exists to
  /// catch: "127.85" contains "127", so a recomputed precision the FACTS
  /// never carried scored as a faithful quote. Digits and decimal points on
  /// either side disqualify a match, so 127 matches "127 mmHg" and "127," but
  /// not "127.85" or "1127".
  ///
  /// Known limit: this proves the aggregate APPEARS, not that it is bound to
  /// the right series. A slot naming 95 as the target while stating 94 as the
  /// average still passes. Closing that needs the aggregates carried as typed
  /// per-series fields rather than recovered from prose.
  static bool _quotesNumber(String text, String value) => RegExp(
    r'(?<![\d.])' + RegExp.escape(value) + r'(?![\d.])',
  ).hasMatch(text);

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
    _bannerRequested = args['userAskedForBanner'] == true;
    await _accept(call, manager, 'Reply delivered.');
  }

  Future<void> _handleCreateAd(
    ChatCompletionMessageToolCall call,
    Map<String, dynamic> args,
    ConversationManager manager,
  ) async {
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
            'Error: create_goal_ad needs a non-empty headline, tone (one '
            'of ${goalNudgeToneNames.join('|')}) and animation (one of '
            '${goalBannerAnimationNames.join('|')}).',
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
      'Ad snoozed until ${until.toIso8601String()}.',
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
            'Error: propose_goal_revision_v2 needs a non-empty changes '
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

  /// The first status token found standing as a word in any visible string.
  ///
  /// Word-bounded so a legitimate sentence cannot trip it: the tokens are
  /// camelCase identifiers (`insufficientData`, `offTrack`) that no language
  /// writes by accident.
  String? _statusTokenIn(List<String> texts) {
    for (final text in texts) {
      if (text.isEmpty) continue;
      for (final token in goalTrackStatusNames) {
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
