/// Tagged-plaintext payload envelope for the Daily OS day-agent prompt.
///
/// The wake payload is a set of `<snake_case_tag>` sections rather than a
/// single `jsonEncode`d document: tags keep what JSON gave us — named
/// sections and boundary integrity — while letting prose sections carry real
/// newlines, which weak local models read far better than newline-escaped
/// run-on strings. Data-shaped, tool-facing sections (attention claims with
/// ids, the capture corpus, the drafting/refine baseline, observations and
/// trigger tokens) stay JSON *inside* their tags so the model can copy ids
/// verbatim into tool calls; prose sections (the rendered day log, durable
/// knowledge, the week-context paragraphs) are plain text.
///
/// This module is the single owner of the tag vocabulary, the shared
/// sanitizers, and the section builder so every producer — the user-message
/// builder, the week-context renderer, and the v2 prompt-record reconstructor —
/// neutralizes forged boundaries the exact same way.
library;

import 'dart:convert';

/// Section tag names for the day-agent prompt payload.
///
/// Listed in stable→volatile order, the same order [DayAgentPromptSections]
/// callers emit so a changing trailing section never evicts a stable prefix
/// from the provider's KV cache.
abstract final class DayAgentPromptTags {
  /// The wake's day workspace (e.g. `dayplan-2026-06-10`).
  static const dayId = 'day_id';

  /// The plan date as an ISO-8601 instant.
  static const planDate = 'plan_date';

  /// The always-on compact hook index of durable knowledge (ADR 0022).
  static const knowledgeIndex = 'knowledge_index';

  /// The compacted day log (ADR 0017) — the derivable section the v2 prompt
  /// record splices around.
  static const dayLog = 'day_log';

  /// Day-scoped attention claims and standing agreements (JSON).
  static const attentionPlanning = 'attention_planning';

  /// Scope-filtered durable-knowledge statements for this wake.
  static const knowledgeStatements = 'knowledge_statements';

  /// Rolling lookback paragraphs: planned-vs-recorded facts + agent testimony.
  static const recentDays = 'recent_days';

  /// Upcoming planned days and claim deadlines within the lookahead window.
  static const weekAhead = 'week_ahead';

  /// Capture transcript + task corpus for a capture-submitted wake (JSON).
  static const capture = 'capture';

  /// Drafting baseline plan, decided tasks, decided capture items (JSON).
  static const drafting = 'drafting';

  /// Refine baseline plan (JSON).
  static const refine = 'refine';

  /// Pre-compaction fallback listing of recent observations (JSON).
  static const recentObservations = 'recent_observations';

  /// The wake's trigger tokens (JSON).
  static const triggerTokens = 'trigger_tokens';

  /// The volatile wall-clock, kept last.
  static const currentLocalTime = 'current_local_time';

  /// Every tag, used by [neutralizePromptTags] to strip forged boundaries.
  static const all = <String>[
    dayId,
    planDate,
    knowledgeIndex,
    dayLog,
    attentionPlanning,
    knowledgeStatements,
    recentDays,
    weekAhead,
    capture,
    drafting,
    refine,
    recentObservations,
    triggerTokens,
    currentLocalTime,
  ];
}

/// Opens the derivable day-log section in the rendered payload. The ADR 0020
/// v2 prompt record splices the persisted prompt around this marker so the
/// (growing) log is stored once in the event log, not in every wake record.
///
/// Kept as a literal — not interpolated from [DayAgentPromptTags.dayLog] — so
/// it is unconditionally a compile-time constant usable in the persistence and
/// reconstruction splices.
const dayLogSectionOpenMarker = '<day_log>\n';

/// Closes the derivable day-log section (see [dayLogSectionOpenMarker]).
const dayLogSectionCloseMarker = '\n</day_log>';

final _whitespaceRun = RegExp(r'\s+');

/// Neutralizes any literal opening/closing section tag from the full
/// vocabulary so interpolated content (task titles, capture transcripts,
/// durable-knowledge statements) cannot forge a section boundary.
///
/// `jsonEncode` does not escape `<`/`>`, so even the JSON-kept sections must
/// run through this — a task title `</attention_planning><recent_days>` would
/// otherwise inject structure the model trusts. Only the exact tag literals
/// are rewritten (to their HTML-entity form), so ordinary prose containing
/// `<` or `>` is left legible.
String neutralizePromptTags(String input) {
  var out = input;
  for (final tag in DayAgentPromptTags.all) {
    out = out
        .replaceAll('<$tag>', '&lt;$tag&gt;')
        .replaceAll('</$tag>', '&lt;/$tag&gt;');
  }
  return out;
}

/// Collapses all whitespace runs (including newlines) to single spaces, trims,
/// then neutralizes tags. For single-line interpolations — agent-note text,
/// block titles, category names — that must never fabricate a day paragraph: a
/// note containing `\n\n` or a fact-line-shaped first line would otherwise
/// split into multiple lines inside `<recent_days>`.
String collapseToSingleLine(String input) =>
    neutralizePromptTags(input.replaceAll(_whitespaceRun, ' ').trim());

/// Accumulates ordered tagged plaintext sections, omitting information-free
/// ones, and renders them blank-line separated. Stable→volatile ordering is
/// the caller's responsibility (it adds sections in order).
class DayAgentPromptSections {
  final List<String> _sections = <String>[];

  /// Adds a prose section whose [body] is tag-neutralized. No-op when [body]
  /// is null or empty.
  void addText(String tag, String? body) {
    if (body == null || body.isEmpty) return;
    _sections.add('<$tag>\n${neutralizePromptTags(body)}\n</$tag>');
  }

  /// Adds a JSON section: [value] is pretty-printed then tag-neutralized so
  /// the model can copy ids verbatim while forged boundaries are still
  /// stripped. No-op when [value] is null.
  void addJson(String tag, Object? value) {
    if (value == null) return;
    final encoded = const JsonEncoder.withIndent('  ').convert(value);
    _sections.add('<$tag>\n${neutralizePromptTags(encoded)}\n</$tag>');
  }

  /// Adds a section whose [body] the caller has already fully rendered and
  /// sanitized (the week-context renderer sanitizes every interpolation
  /// itself). No-op when [body] is null or empty.
  void addPreRendered(String tag, String? body) {
    if (body == null || body.isEmpty) return;
    _sections.add('<$tag>\n$body\n</$tag>');
  }

  /// The assembled payload.
  String build() => _sections.join('\n\n');
}
