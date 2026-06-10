import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_slots.dart';
import 'package:lotti/features/daily_os_next/agents/prompt/day_agent_prompt_sections.dart';

/// Pure renderer for the planner's week context: the `<recent_days>` and
/// `<week_ahead>` prompt sections (planned-vs-recorded day paragraphs plus
/// upcoming plans and claim deadlines).
///
/// Everything here is deterministic template rendering — the exact wording of
/// every line lives in THIS file and nowhere else. Facts come exclusively from
/// entities (plans, recorded spans, claims); the agent's own day summary is
/// rendered verbatim (sanitized) as testimony adjacent to the facts, never as
/// a fact source. Day classification is anchored to the wall clock (`now`),
/// not the wake's workspace day: a drafting-tomorrow wake must see tomorrow as
/// "(upcoming)" — never "Missed:" or fake rest-day lines for days that have
/// not happened.

/// Days of history rendered before the plan date (the plan date itself is
/// also rendered, so the lookback spans 8 day paragraphs).
const weekContextLookbackDays = 7;

/// Days of lookahead after the plan date for `<week_ahead>`.
const weekContextLookaheadDays = 5;

/// Hard cap on a day summary's length (enforced at the write path; re-applied
/// defensively when rendering).
const daySummaryMaxChars = 500;

/// Caps keeping the section inside a weak model's token budget; each truncation
/// renders a deterministic overflow marker instead of dropping silently.
const _maxCategoriesPerDay = 6;
const _maxNamedMisses = 5;
const _maxDeadlineLines = 10;

/// A lightweight recorded-time span, derived from `ResolvedTimeEntry` pairs by
/// the service layer. The entire [duration] buckets to `localDay(start)` —
/// a documented divergence from the per-day timeline lane, whose wide
/// containment window includes midnight-spanning entries that no single-day
/// window contains.
class RecordedSpan {
  /// Creates a span.
  const RecordedSpan({
    required this.categoryId,
    required this.start,
    required this.duration,
    this.taskId,
  });

  /// The category the time belongs to (null renders as "Uncategorized").
  final String? categoryId;

  /// When the recorded time started — the day it buckets to.
  final DateTime start;

  /// Recorded duration.
  final Duration duration;

  /// The backing task, when the time was recorded against one.
  final String? taskId;
}

/// The rendered week-context section bodies (no surrounding tags).
class WeekContext {
  /// Creates the rendered pair.
  const WeekContext({required this.recentDays, required this.weekAhead});

  /// Body of `<recent_days>`, or null when every lookback day is
  /// information-free (cold start renders nothing instead of eight
  /// "Nothing recorded." lines).
  final String? recentDays;

  /// Body of `<week_ahead>`, or null when there are no future plans and no
  /// deadlines in the window.
  final String? weekAhead;

  /// Whether both sections are absent.
  bool get isEmpty => recentDays == null && weekAhead == null;
}

/// Builds the week context. Pure: depends only on its arguments.
///
/// [now] is the wall clock that classifies each day as past / today /
/// upcoming. [planDate] anchors the windows: lookback days are
/// `[planDate − 7 .. planDate]`, week-ahead days `[planDate + 1 .. planDate
/// + 5]`. Deadline lines use `[localDay(now) .. localDay(now) + 5)` (claims
/// are selected by visibility — a claim whose deadline is ahead but whose
/// `latestEnd` elapsed may be invisible; documented, accepted).
///
/// [categoryName] resolves a category id to a display name; null means
/// unknown (the raw id is used as fallback). Null-category recorded time
/// renders as an "Uncategorized" bucket and never suppresses a real
/// category's miss.
WeekContext buildWeekContext({
  required DateTime planDate,
  required DateTime now,
  required List<AttentionRequestEntity> claims,
  required List<DayPlanEntity> dayPlans,
  required List<DaySummaryEntity> daySummaries,
  required List<RecordedSpan> recordedSpans,
  required String? Function(String categoryId) categoryName,
}) {
  // `localDay` converts to local time and returns a LOCAL midnight, so every
  // base used in the `DateTime(y, m, d ± n)` window arithmetic below is
  // local by construction (never UTC) — wall-clock day semantics are the
  // contract here (ADR 0028), and component arithmetic on these bases stays
  // at local midnight across DST transitions.
  final anchor = localDay(planDate);
  final today = localDay(now);

  final plansByDayId = <String, DayPlanEntity>{
    for (final plan in dayPlans) plan.dayId: plan,
  };
  final summariesByDayId = <String, DaySummaryEntity>{
    for (final summary in daySummaries) summary.dayId: summary,
  };
  final spansByDay = <String, List<RecordedSpan>>{};
  for (final span in recordedSpans) {
    spansByDay.putIfAbsent(dayPlanId(localDay(span.start)), () => []).add(span);
  }

  String resolveCategory(String? categoryId) {
    if (categoryId == null || categoryId.isEmpty) return 'Uncategorized';
    final resolved = categoryName(categoryId);
    return collapseToSingleLine(
      resolved == null || resolved.trim().isEmpty ? categoryId : resolved,
    );
  }

  // ── recent_days ──────────────────────────────────────────────────────────
  final paragraphs = <String>[];
  var hasAnyInformation = false;
  for (var offset = -weekContextLookbackDays; offset <= 0; offset++) {
    final day = DateTime(anchor.year, anchor.month, anchor.day + offset);
    final dayId = dayPlanId(day);
    final plan = plansByDayId[dayId];
    final summary = summariesByDayId[dayId];
    final spans = spansByDay[dayId] ?? const [];
    if (plan != null || summary != null || spans.isNotEmpty) {
      hasAnyInformation = true;
    }
    paragraphs.add(
      _renderDayParagraph(
        day: day,
        today: today,
        plan: plan,
        summary: summary,
        spans: spans,
        resolveCategory: resolveCategory,
      ),
    );
  }
  final recentDays = hasAnyInformation ? paragraphs.join('\n\n') : null;

  // ── week_ahead ───────────────────────────────────────────────────────────
  final aheadLines = <String>[];
  for (var offset = 1; offset <= weekContextLookaheadDays; offset++) {
    final day = DateTime(anchor.year, anchor.month, anchor.day + offset);
    final plan = plansByDayId[dayPlanId(day)];
    if (plan == null) continue;
    aheadLines.add(
      _renderWeekAheadPlanLine(
        day: day,
        plan: plan,
        resolveCategory: resolveCategory,
      ),
    );
  }
  aheadLines.addAll(
    _renderDeadlineLines(
      claims: claims,
      today: today,
      resolveCategory: resolveCategory,
    ),
  );
  final weekAhead = aheadLines.isEmpty ? null : aheadLines.join('\n');

  return WeekContext(recentDays: recentDays, weekAhead: weekAhead);
}

enum _DayKind { past, today, upcoming }

String _renderDayParagraph({
  required DateTime day,
  required DateTime today,
  required DayPlanEntity? plan,
  required DaySummaryEntity? summary,
  required List<RecordedSpan> spans,
  required String Function(String?) resolveCategory,
}) {
  final kind = day.isBefore(today)
      ? _DayKind.past
      : (day.isAfter(today) ? _DayKind.upcoming : _DayKind.today);

  final blocks = [
    for (final block in plan?.data.plannedBlocks ?? const <PlannedBlock>[])
      if (block.state != PlannedBlockState.dropped) block,
  ];

  // Aggregate planned/recorded minutes per category key (null = uncategorized;
  // a null-category bucket can never suppress a real category's miss because
  // the keys differ).
  final plannedByCategory = <String?, int>{};
  for (final block in blocks) {
    plannedByCategory.update(
      block.categoryId,
      (v) => v + _blockMinutes(block),
      ifAbsent: () => _blockMinutes(block),
    );
  }
  final recordedByCategory = <String?, int>{};
  var totalRecordedMinutes = 0;
  for (final span in spans) {
    final minutes = span.duration.inMinutes;
    totalRecordedMinutes += minutes;
    recordedByCategory.update(
      span.categoryId,
      (v) => v + minutes,
      ifAbsent: () => minutes,
    );
  }

  final header = StringBuffer(_dayLabel(day))
    ..write(switch (kind) {
      _DayKind.past => '',
      _DayKind.today => ' (today so far)',
      _DayKind.upcoming => ' (upcoming)',
    })
    ..write(' — ')
    ..write(plan == null ? 'no plan' : _planStatusLabel(plan.data.status))
    ..write('.');

  final clauses = <String>[
    // A past rest day is signal; a day that has not happened must never
    // render a fake rest-day line.
    if (kind == _DayKind.past && totalRecordedMinutes == 0) 'Nothing recorded.',
    ..._categoryClauses(
      plannedByCategory: plannedByCategory,
      recordedByCategory: recordedByCategory,
      kind: kind,
      resolveCategory: resolveCategory,
    ),
  ];

  final unmatched = _unmatchedBlocks(
    blocks: blocks,
    spans: spans,
    recordedByCategory: recordedByCategory,
  );
  if (unmatched.isNotEmpty) {
    clauses.add(
      _blockListClause(
        label: kind == _DayKind.past ? 'Missed' : 'Still planned',
        overflowSuffix: kind == _DayKind.past ? 'more missed' : 'more planned',
        blocks: unmatched,
        resolveCategory: resolveCategory,
      ),
    );
  }

  if (kind == _DayKind.past && totalRecordedMinutes > 0) {
    clauses.add(
      'Total recorded: ${formatAggregateMinutes(totalRecordedMinutes)}.',
    );
  }
  if (clauses.isEmpty && kind == _DayKind.today) {
    clauses.add('Nothing recorded yet.');
  }

  final factsLine = clauses.isEmpty
      ? header.toString()
      : '$header ${clauses.join(' ')}';

  if (summary == null) return factsLine;
  var note = collapseToSingleLine(summary.text);
  if (note.length > daySummaryMaxChars) {
    // Defensive render-side cap (the write path enforces the budget, but
    // foreign/legacy data may exceed it). Never split a surrogate pair at the
    // cut — a lone surrogate becomes U+FFFD on the wire.
    var cut = daySummaryMaxChars;
    final last = note.codeUnitAt(cut - 1);
    if (last >= 0xD800 && last <= 0xDBFF) cut--;
    note = '${note.substring(0, cut)}…';
  }
  return '$factsLine\nAgent note: $note';
}

/// Per-category clauses for categories with recorded time (planned-only
/// categories surface via "Missed:"/"Still planned:" block lists instead),
/// capped at [_maxCategoriesPerDay] selected by `max(planned, recorded)`
/// descending (name ascending on ties), rendered sorted by display name, with
/// a deterministic overflow marker.
List<String> _categoryClauses({
  required Map<String?, int> plannedByCategory,
  required Map<String?, int> recordedByCategory,
  required _DayKind kind,
  required String Function(String?) resolveCategory,
}) {
  final entries =
      [
        for (final entry in recordedByCategory.entries)
          if (entry.value > 0)
            (
              name: resolveCategory(entry.key),
              planned: plannedByCategory[entry.key] ?? 0,
              recorded: entry.value,
            ),
      ]..sort((a, b) {
        final byWeight = _weight(b).compareTo(_weight(a));
        if (byWeight != 0) return byWeight;
        return a.name.compareTo(b.name);
      });

  final kept = entries.take(_maxCategoriesPerDay).toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  final overflow = entries.skip(_maxCategoriesPerDay).toList();

  final clauses = <String>[
    for (final entry in kept) _categoryClause(entry: entry, kind: kind),
  ];
  if (overflow.isNotEmpty) {
    final overflowMinutes = overflow.fold<int>(0, (sum, e) => sum + _weight(e));
    clauses.add(
      '+${overflow.length} more '
      '(${formatAggregateMinutes(overflowMinutes)}).',
    );
  }
  return clauses;
}

int _weight(({String name, int planned, int recorded}) entry) =>
    entry.planned > entry.recorded ? entry.planned : entry.recorded;

String _categoryClause({
  required ({String name, int planned, int recorded}) entry,
  required _DayKind kind,
}) {
  final name = entry.name;
  final planned = entry.planned;
  final recorded = entry.recorded;
  final recordedText = formatAggregateMinutes(recorded);
  final plannedText = formatAggregateMinutes(planned);
  switch (kind) {
    case _DayKind.past:
      if (planned <= 0) return '$name: $recordedText recorded.';
      if (recorded == planned) {
        return '$name: $recordedText recorded vs $plannedText planned.';
      }
      final over = recorded > planned;
      final delta = formatAggregateMinutes((recorded - planned).abs());
      return '$name: $recordedText recorded vs $plannedText planned '
          '($delta ${over ? 'over' : 'under'}).';
    case _DayKind.today:
    case _DayKind.upcoming:
      if (planned <= 0) return '$name: $recordedText recorded.';
      return '$name: $recordedText recorded of $plannedText planned.';
  }
}

/// Blocks not matched by recorded time (the "Missed:" / "Still planned:" set):
/// a block with a taskId is unmatched when no span that day carries the same
/// taskId; a taskId-less block is unmatched only when its exact category
/// recorded zero that day.
List<PlannedBlock> _unmatchedBlocks({
  required List<PlannedBlock> blocks,
  required List<RecordedSpan> spans,
  required Map<String?, int> recordedByCategory,
}) {
  final recordedTaskIds = <String>{
    for (final span in spans)
      if (span.taskId != null) span.taskId!,
  };
  return [
    for (final block in blocks)
      if (block.taskId != null
          ? !recordedTaskIds.contains(block.taskId)
          : (recordedByCategory[block.categoryId] ?? 0) == 0)
        block,
  ];
}

String _blockListClause({
  required String label,
  required String overflowSuffix,
  required List<PlannedBlock> blocks,
  required String Function(String?) resolveCategory,
}) {
  final kept = blocks.take(_maxNamedMisses);
  final overflowCount = blocks.length - _maxNamedMisses;
  String item(PlannedBlock block) {
    final title = _blockTitle(block, resolveCategory);
    final minutes = formatBlockMinutes(_blockMinutes(block));
    final category = resolveCategory(block.categoryId);
    return "'$title' ($minutes, $category)";
  }

  final items = [for (final block in kept) item(block)];
  final overflow = overflowCount > 0 ? ' +$overflowCount $overflowSuffix.' : '';
  return '$label: ${items.join(', ')}.$overflow';
}

String _blockTitle(
  PlannedBlock block,
  String Function(String?) resolveCategory,
) {
  final title = block.title?.trim();
  if (title != null && title.isNotEmpty) return collapseToSingleLine(title);
  return resolveCategory(block.categoryId);
}

int _blockMinutes(PlannedBlock block) =>
    block.endTime.difference(block.startTime).inMinutes;

String _renderWeekAheadPlanLine({
  required DateTime day,
  required DayPlanEntity plan,
  required String Function(String?) resolveCategory,
}) {
  final plannedByCategory = <String?, int>{};
  for (final block in plan.data.plannedBlocks) {
    if (block.state == PlannedBlockState.dropped) continue;
    plannedByCategory.update(
      block.categoryId,
      (v) => v + _blockMinutes(block),
      ifAbsent: () => _blockMinutes(block),
    );
  }
  final header = '${_dayLabel(day)} — ${_planStatusLabel(plan.data.status)}';
  if (plannedByCategory.isEmpty) return '$header.';

  final entries =
      [
        for (final entry in plannedByCategory.entries)
          (name: resolveCategory(entry.key), planned: entry.value, recorded: 0),
      ]..sort((a, b) {
        final byPlanned = b.planned.compareTo(a.planned);
        if (byPlanned != 0) return byPlanned;
        return a.name.compareTo(b.name);
      });
  final kept = entries.take(_maxCategoriesPerDay).toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  final overflow = entries.skip(_maxCategoriesPerDay).toList();
  final overflowTotal = overflow.fold<int>(0, (sum, e) => sum + e.planned);
  final overflowPart =
      '+${overflow.length} more (${formatAggregateMinutes(overflowTotal)})';
  final parts = [
    for (final entry in kept)
      '${entry.name} ${formatAggregateMinutes(entry.planned)}',
    if (overflow.isNotEmpty) overflowPart,
  ];
  return '$header: ${parts.join(', ')}.';
}

List<String> _renderDeadlineLines({
  required List<AttentionRequestEntity> claims,
  required DateTime today,
  required String Function(String?) resolveCategory,
}) {
  // One bracket convention everywhere: [today .. today + lookahead).
  final windowEnd = DateTime(
    today.year,
    today.month,
    today.day + weekContextLookaheadDays,
  );
  final dated =
      [
        for (final claim in claims)
          if (claim.deadline != null)
            if (!localDay(claim.deadline!).isBefore(today) &&
                localDay(claim.deadline!).isBefore(windowEnd))
              claim,
      ]..sort((a, b) {
        final byDeadline = a.deadline!.compareTo(b.deadline!);
        if (byDeadline != 0) return byDeadline;
        final byTitle = a.title.compareTo(b.title);
        if (byTitle != 0) return byTitle;
        return a.id.compareTo(b.id);
      });

  String line(AttentionRequestEntity claim) {
    final title = collapseToSingleLine(claim.title);
    final due =
        '${_dayLabel(localDay(claim.deadline!))} '
        '${_timeLabel(claim.deadline!)}';
    final requested = formatBlockMinutes(claim.requestedMinutes);
    final category = resolveCategory(claim.categoryId);
    return "Deadline: '$title' due $due ($requested requested, $category).";
  }

  final lines = <String>[
    for (final claim in dated.take(_maxDeadlineLines)) line(claim),
  ];
  if (dated.length > _maxDeadlineLines) {
    lines.add('+${dated.length - _maxDeadlineLines} more.');
  }
  return lines;
}

String _planStatusLabel(DayPlanStatus status) => switch (status) {
  DayPlanStatusCommitted() => 'committed plan',
  // Legacy agreed/needsReview statuses render as drafts.
  DayPlanStatusDraft() ||
  DayPlanStatusAgreed() ||
  DayPlanStatusNeedsReview() => 'draft plan',
};

const _weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _monthLabels = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _dayLabel(DateTime day) =>
    '${_weekdayLabels[day.weekday - 1]} ${_monthLabels[day.month - 1]} '
    '${day.day}';

String _timeLabel(DateTime at) {
  final local = at.toLocal();
  final h = local.hour.toString().padLeft(2, '0');
  final m = local.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

/// Aggregate (category/day total) duration: minutes under an hour render as
/// `45m`; otherwise integer-tenths hours (`10.2h`, whole hours as `9h`).
/// Integer math only — formatting doubles would round-trip
/// nondeterministically.
String formatAggregateMinutes(int minutes) {
  if (minutes < 60) return '${minutes}m';
  final tenths = (minutes * 10 + 30) ~/ 60;
  if (tenths % 10 == 0) return '${tenths ~/ 10}h';
  return '${tenths ~/ 10}.${tenths % 10}h';
}

/// Block-level (single block / requested) duration: whole hours render as
/// `2h`, anything else as raw minutes (`90m`, `45m`).
String formatBlockMinutes(int minutes) {
  if (minutes >= 60 && minutes % 60 == 0) return '${minutes ~/ 60}h';
  return '${minutes}m';
}
