import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:lotti/features/agents/projection/compaction_plan.dart';
import 'package:lotti/features/ai/service/text_chunker.dart';
import 'package:lotti/features/goals/logic/goal_user_voice.dart';
import 'package:lotti/features/goals/model/goal_checkin_summary.dart';

/// Turns a goal's check-in history into the `userVoice` entries one wake
/// carries.
///
/// The seam the compaction evaluation measures across: every strategy reads
/// the same [GoalCheckInSummary] list and emits entries for the same FACTS
/// slot, so swapping the mechanism changes nothing else about a wake. The
/// production wake uses [TruncatingCheckInCompaction]; the other two exist so
/// the evaluation can hold the uncompacted history up as the oracle and
/// measure a hierarchical candidate against it.
abstract interface class GoalCheckInCompactionStrategy {
  /// Stable identifier, used as the arm name in evaluation reports.
  String get id;

  /// Builds the entries for [summaries] as seen from [reference].
  Future<GoalUserVoiceContext> build(
    List<GoalCheckInSummary> summaries, {
    required DateTime reference,
  });
}

/// What a strategy produced, with the counts a report needs.
@immutable
class GoalUserVoiceContext {
  const GoalUserVoiceContext({
    required this.entries,
    required this.verbatimCount,
    this.digestCount = 0,
  });

  static const empty = GoalUserVoiceContext(entries: [], verbatimCount: 0);

  /// Oldest first, exactly as rendered into FACTS.
  final List<Map<String, Object?>> entries;

  /// Check-ins carried unchanged.
  final int verbatimCount;

  /// Digest entries standing in for older check-ins.
  final int digestCount;

  /// Token estimate of the entries as they are emitted, keys included —
  /// the same estimator the wake budget uses.
  int get estimatedTokens => entries.fold(
    0,
    (sum, e) => sum + TextChunker.estimateTokens(jsonEncode(e)),
  );
}

/// Every check-in, verbatim, unbounded. The evaluation oracle; never a
/// production choice, because it grows without limit.
class FullContextCheckInCompaction implements GoalCheckInCompactionStrategy {
  const FullContextCheckInCompaction();

  @override
  String get id => 'full';

  @override
  Future<GoalUserVoiceContext> build(
    List<GoalCheckInSummary> summaries, {
    required DateTime reference,
  }) async {
    final chronological = _chronological(summaries);
    return GoalUserVoiceContext(
      entries: [for (final s in chronological) goalUserVoiceEntry(s)],
      verbatimCount: chronological.length,
    );
  }
}

/// What ships today: the most recent check-ins that fit [budget] tokens,
/// everything older dropped.
class TruncatingCheckInCompaction implements GoalCheckInCompactionStrategy {
  const TruncatingCheckInCompaction({this.budget = goalUserVoiceTokenBudget});

  final int budget;

  @override
  String get id => 'truncate';

  @override
  Future<GoalUserVoiceContext> build(
    List<GoalCheckInSummary> summaries, {
    required DateTime reference,
  }) async {
    final entries = goalUserVoiceEntries(summaries, budget: budget);
    return GoalUserVoiceContext(
      entries: entries,
      verbatimCount: entries.length,
    );
  }
}

/// The granularity a folded span is digested at.
enum GoalCheckInDigestLayer {
  month(maxWords: 120),
  quarter(maxWords: 80),
  year(maxWords: 80),

  /// Everything older than the yearly horizon, as ONE span. This is what
  /// makes the block bounded: without it a goal adds an entry per year of
  /// its life.
  earlier(maxWords: 80);

  const GoalCheckInDigestLayer({required this.maxWords});

  /// Upper bound on the digest's length. Coarser layers cover more
  /// check-ins in FEWER words: the point of ageing a span is that its token
  /// cost falls, so the total stays bounded as years accumulate.
  final int maxWords;
}

/// One folded span of history handed to a [GoalCheckInDigestWriter].
@immutable
class GoalCheckInDigestRequest {
  const GoalCheckInDigestRequest({
    required this.periodLabel,
    required this.layer,
    required this.from,
    required this.to,
    required this.checkIns,
  });

  /// Human-readable span, e.g. `2025-03`, `2024-Q4`, `2024` or
  /// `before-2023`.
  final String periodLabel;
  final GoalCheckInDigestLayer layer;
  final DateTime from;
  final DateTime to;

  /// Oldest first.
  final List<GoalCheckInSummary> checkIns;

  int get maxWords => layer.maxWords;
}

/// Writes the prose digest of one folded span.
///
/// Abstract so the strategy stays pure: production would back it with an
/// inference call and persist the result; the evaluation backs it with a
/// cached inference call; unit tests back it with a fake.
abstract interface class GoalCheckInDigestWriter {
  Future<String> write(GoalCheckInDigestRequest request);
}

/// Recent check-ins verbatim, older months digested, then quarters, then
/// years, then one "earlier" span for everything beyond the yearly horizon —
/// each coarser layer shorter than the last.
///
/// Layer boundaries are calendar-aligned so a span's digest is stable as
/// time moves on: a month that has been folded once reads the same on every
/// later wake until it ages into a quarter, which is what makes the digests
/// cacheable and persistable. The entry count is bounded by the horizons
/// alone — at most the months inside the monthly horizon, the quarters
/// inside the quarterly one, the years inside the yearly one, and one
/// earlier span — never by the goal's age.
class HierarchicalCheckInCompaction implements GoalCheckInCompactionStrategy {
  const HierarchicalCheckInCompaction({
    required this.digestWriter,
    this.verbatimBudget = goalUserVoiceTokenBudget,
    this.monthlyHorizonMonths = 6,
    this.quarterlyHorizonMonths = 18,
    this.yearlyHorizonMonths = 36,
  }) : assert(monthlyHorizonMonths > 0, 'monthlyHorizonMonths must be > 0'),
       assert(
         quarterlyHorizonMonths > monthlyHorizonMonths,
         'quarterlyHorizonMonths must exceed monthlyHorizonMonths',
       ),
       assert(
         yearlyHorizonMonths > quarterlyHorizonMonths,
         'yearlyHorizonMonths must exceed quarterlyHorizonMonths',
       );

  final GoalCheckInDigestWriter digestWriter;

  /// Token budget for the verbatim tail, sized like the production slice so
  /// the recent picture is exactly what truncation shows today.
  final int verbatimBudget;

  /// Folded months younger than this stay monthly; older ones merge into
  /// quarters.
  final int monthlyHorizonMonths;

  /// Quarters younger than this stay quarterly; older ones merge into
  /// calendar years.
  final int quarterlyHorizonMonths;

  /// Years younger than this stay yearly; everything older is one span.
  final int yearlyHorizonMonths;

  @override
  String get id => 'hierarchical';

  @override
  Future<GoalUserVoiceContext> build(
    List<GoalCheckInSummary> summaries, {
    required DateTime reference,
  }) async {
    final chronological = _chronological(summaries);
    if (chronological.isEmpty) return GoalUserVoiceContext.empty;

    final plan = planCompaction(
      tail: [
        for (final s in chronological)
          TailEntry(
            id: s.id,
            tokens: TextChunker.estimateTokens(
              jsonEncode(goalUserVoiceEntry(s)),
            ),
          ),
      ],
      budget: verbatimBudget,
    );
    final kept = plan.keepIds.toSet();
    final folded = [
      for (final s in chronological)
        if (!kept.contains(s.id)) s,
    ];
    final verbatim = [
      for (final s in chronological)
        if (kept.contains(s.id)) s,
    ];

    final requests = _spans(folded, reference);
    final digests = <Map<String, Object?>>[];
    for (final request in requests) {
      final text = await digestWriter.write(request);
      digests.add(<String, Object?>{
        'kind': 'digest',
        'layer': request.layer.name,
        'period': request.periodLabel,
        'fromLocal': request.from.toLocal().toIso8601String(),
        'toLocal': request.to.toLocal().toIso8601String(),
        'checkIns': request.checkIns.length,
        'digest': text,
      });
    }

    return GoalUserVoiceContext(
      entries: [...digests, for (final s in verbatim) goalUserVoiceEntry(s)],
      verbatimCount: verbatim.length,
      digestCount: digests.length,
    );
  }

  /// Groups [folded] (oldest first) into calendar spans: monthly inside
  /// [monthlyHorizonMonths] before [reference], quarterly inside
  /// [quarterlyHorizonMonths], yearly inside [yearlyHorizonMonths], and one
  /// span for everything earlier.
  List<GoalCheckInDigestRequest> _spans(
    List<GoalCheckInSummary> folded,
    DateTime reference,
  ) {
    if (folded.isEmpty) return const [];
    // Horizons and labels are both taken in local time: a UTC reference
    // near a month boundary would otherwise place the boundary in one zone
    // and the check-ins in another, moving a whole month between layers.
    final local = reference.toLocal();
    final monthlyHorizon = DateTime(
      local.year,
      local.month - monthlyHorizonMonths,
    );
    final quarterlyHorizon = DateTime(
      local.year,
      local.month - quarterlyHorizonMonths,
    );
    final yearlyHorizon = DateTime(
      local.year,
      local.month - yearlyHorizonMonths,
    );
    final groups =
        <String, (GoalCheckInDigestLayer, List<GoalCheckInSummary>)>{};
    for (final s in folded) {
      final at = s.recordedAt.toLocal();
      final (layer, label) = at.isBefore(yearlyHorizon)
          ? (GoalCheckInDigestLayer.earlier, 'before-${yearlyHorizon.year}')
          : at.isBefore(quarterlyHorizon)
          ? (GoalCheckInDigestLayer.year, '${at.year}')
          : at.isBefore(monthlyHorizon)
          ? (
              GoalCheckInDigestLayer.quarter,
              '${at.year}-Q${(at.month - 1) ~/ 3 + 1}',
            )
          : (
              GoalCheckInDigestLayer.month,
              '${at.year}-${at.month.toString().padLeft(2, '0')}',
            );
      groups.putIfAbsent(label, () => (layer, [])).$2.add(s);
    }
    return [
      for (final entry in groups.entries)
        GoalCheckInDigestRequest(
          periodLabel: entry.key,
          layer: entry.value.$1,
          from: entry.value.$2.first.recordedAt,
          to: entry.value.$2.last.recordedAt,
          checkIns: entry.value.$2,
        ),
    ];
  }
}

List<GoalCheckInSummary> _chronological(List<GoalCheckInSummary> summaries) =>
    [...summaries]..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
