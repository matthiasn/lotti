part of 'goal_agent_workflow.dart';

/// Conservative deterministic gate for a user-initiated replacement banner.
///
/// Cooldown overrides cannot depend on the model first agreeing to call the ad
/// tool. A missing-banner report, or a short affirmation immediately following
/// the agent's banner offer, also carries replacement intent. Visibility
/// requests such as snooze or dismiss always win.
bool isExplicitGoalAdReplacementRequest(
  String? message, {
  String? previousAssistantMessage,
}) {
  if (message == null) return false;
  final normalized = message.toLowerCase().trim();
  if (_isShortGoalAdAffirmation(normalized) &&
      _offersGoalBanner(previousAssistantMessage)) {
    return true;
  }
  final mentionsAd = RegExp(r'\b(?:banner|ad|advert)\b').hasMatch(normalized);
  if (!mentionsAd) return false;
  final declinesReplacement = RegExp(
    r"\b(?:don't|dont|do not|never)\s+"
    r'(?:want|need|replace|show|give|make|create|serve)\b',
  ).hasMatch(normalized);
  if (declinesReplacement) return false;
  final isVisibilityRequest = RegExp(
    r'\b(?:snooze|hide|dismiss|remove|stop|pause)\b',
  ).hasMatch(normalized);
  if (isVisibilityRequest) return false;
  final directReplacementVerb = RegExp(
    r'\b(?:new|another|replacement|replace|create|make|give|serve)\b',
  ).hasMatch(normalized);
  final qualifiedRequest = RegExp(
    r'\b(?:show|want|need)\b.*\b(?:new|another|replacement)\b',
  ).hasMatch(normalized);
  final requestsBanner = RegExp(
    r'\b(?:want|need)\b[^.!?]{0,80}\b(?:banner|ad|advert)\b|'
    r'\bshow\s+me\b[^.!?]{0,60}\b(?:banner|ad|advert)\b',
  ).hasMatch(normalized);
  final reportsMissingBanner = RegExp(
    r'\b(?:see|have|got)\s+no\s+(?:banner|ad|advert)\b|'
    r'\b(?:banner|ad|advert)\s+(?:is\s+)?(?:missing|not\s+(?:showing|visible))\b|'
    r"\bwhere(?:'s|\s+is)\s+(?:my\s+|the\s+)?(?:banner|ad|advert)\b",
  ).hasMatch(normalized);
  return directReplacementVerb ||
      qualifiedRequest ||
      requestsBanner ||
      reportsMissingBanner;
}

/// True when a chat message asks for the STANDING REPORT itself to change —
/// shorter, restructured, sectioned, less repetitive — rather than asking a
/// question about the goal.
///
/// The report is a stored artifact: a reply alone leaves the user reading the
/// same text they complained about. Like the ad heuristic this is an English
/// fast path that forces a forgotten tool call; the language-independent
/// carrier is the model choosing `update_goal_report` itself, which the
/// system prompt asks for explicitly.
bool isExplicitGoalReportUpdateRequest(
  String? message, {
  String? previousAssistantMessage,
}) {
  if (message == null) return false;
  final normalized = message.toLowerCase().trim();
  // "Yes, please" after the agent offers to rewrite the report is the same
  // request in its most common form; the offer is the only place the subject
  // is named, exactly as the banner path treats an affirmation.
  if (_isShortGoalAdAffirmation(normalized) &&
      _offersGoalReportRewrite(previousAssistantMessage)) {
    return true;
  }
  final mentionsReport = RegExp(
    r'\b(?:report|summary|write[-\s]?up)\b',
  ).hasMatch(normalized);
  if (!mentionsReport) return false;
  // A question ABOUT the report is not a request to rewrite it. Leading
  // interrogatives only: "can/could/would you shorten it" are requests, and
  // they are deliberately not in this set.
  final asksAboutReport = RegExp(
    r'^(?:how|what|why|when|where|which|who)\b',
  ).hasMatch(normalized);
  if (asksAboutReport) return false;
  // Negation binds loosely in real messages — "don't want you to change the
  // report", "please don't make the report shorter" — so any negation ahead
  // of a change word within the same clause declines the rewrite. Forcing a
  // rewrite against an explicit refusal overwrites a report the user asked
  // to keep, which is worse than missing an implicit request.
  final declinesChange = RegExp(
    r"\b(?:don't|dont|do not|never|no\s+need\s+to|rather\s+not|"
    r'stop|leave|keep)\b[^.!?]{0,60}\b(?:change|update|rewrite|rewriting|'
    'restructure|touch|shorten|shorter|concise|condense|trim|tighten|'
    r'split|format|structure|improve|less|make|alone|as\s+is)\b',
  ).hasMatch(normalized);
  if (declinesChange) return false;
  return RegExp(
    r'\b(?:rewrite|rewrote|restructure|reorganise|reorganize|shorten|shorter|'
    'concise|condense|trim|tighten|split|bullets?|sections?|format|structure|'
    r'update|refresh|change|improve|less)\b|'
    r'\bwall\s+of\s+text\b|'
    r'\bbreak\s+(?:it|this|that|the\s+report)?\s*up\b',
  ).hasMatch(normalized);
}

/// Whether the agent's previous visible reply OFFERED to rewrite the standing
/// report, which is what makes a bare "yes" a rewrite request.
bool _offersGoalReportRewrite(String? message) {
  if (message == null) return false;
  final normalized = message.toLowerCase();
  if (!RegExp(r'\b(?:report|summary|write[-\s]?up)\b').hasMatch(normalized)) {
    return false;
  }
  return RegExp(
    r"\b(?:if\s+you(?:'d|\s+would)?\s+(?:like|want)|want\s+me\s+to|"
    r'would\s+you\s+like|shall\s+i|should\s+i|say\s+the\s+word|'
    r'i\s+can\s+(?:rewrite|restructure|shorten|split|reformat)|'
    r'let\s+me\s+(?:rewrite|restructure|shorten|split|reformat))\b',
  ).hasMatch(normalized);
}

bool _isShortGoalAdAffirmation(String message) => RegExp(
  r'^(?:yes|yep|yeah|sure|ok|okay|please|do\s+it|go\s+ahead|make\s+it\s+happen)'
  r'(?:[,.]?\s+(?:please|now))?[.!]*$',
).hasMatch(message);
bool _offersGoalBanner(String? message) {
  if (message == null) return false;
  final normalized = message.toLowerCase();
  if (!RegExp(r'\b(?:banner|ad|advert)\b').hasMatch(normalized)) return false;
  return RegExp(
    r"\b(?:if\s+you(?:'d|\s+would)?\s+(?:like|want)|want\s+me\s+to|"
    r'would\s+you\s+like|shall\s+i|should\s+i|say\s+the\s+word|'
    r'ask\s+me|tell\s+me)\b',
  ).hasMatch(normalized);
}
