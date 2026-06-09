// Aggregates traces + verdicts into a per-profile summary (ADR 0029).
//
// Pure (no IO) so it is unit-testable. The `run_level2.sh` reporter step loads
// traces via `TraceWriter.readTraces` and passes them here.

import 'eval_models.dart';

/// Rolled-up numbers for one model profile across all scenarios in a run.
class ProfileSummary {
  const ProfileSummary({
    required this.profileName,
    required this.traceCount,
    required this.level1PassCount,
    required this.meanTotalTokens,
    required this.judgedCount,
    required this.judgePassCount,
    required this.meanGoalAttainment,
    required this.meanQuality,
    required this.meanEfficiency,
  });

  final String profileName;
  final int traceCount;
  final int level1PassCount;
  final double meanTotalTokens;
  final int judgedCount;
  final int judgePassCount;
  final double meanGoalAttainment;
  final double meanQuality;
  final double meanEfficiency;

  double get level1PassRate =>
      traceCount == 0 ? 0 : level1PassCount / traceCount;

  double get judgePassRate =>
      judgedCount == 0 ? 0 : judgePassCount / judgedCount;
}

abstract final class EvalReporter {
  /// One [ProfileSummary] per distinct profile, sorted by profile name.
  static List<ProfileSummary> summarize(List<EvalTrace> traces) {
    final byProfile = <String, List<EvalTrace>>{};
    for (final trace in traces) {
      byProfile.putIfAbsent(trace.profile.name, () => <EvalTrace>[]).add(trace);
    }
    final summaries = <ProfileSummary>[];
    for (final entry in byProfile.entries) {
      final group = entry.value;
      final judged = group
          .where((t) => t.verdict != null)
          .toList(growable: false);
      summaries.add(
        ProfileSummary(
          profileName: entry.key,
          traceCount: group.length,
          level1PassCount: group.where((t) => t.level1Passed).length,
          meanTotalTokens: _mean(
            group.map((t) => t.output.usage.totalTokens.toDouble()),
          ),
          judgedCount: judged.length,
          judgePassCount: judged.where((t) => t.verdict!.pass).length,
          meanGoalAttainment: _mean(
            judged.map((t) => t.verdict!.goalAttainment.toDouble()),
          ),
          meanQuality: _mean(judged.map((t) => t.verdict!.quality.toDouble())),
          meanEfficiency: _mean(
            judged.map((t) => t.verdict!.efficiency.toDouble()),
          ),
        ),
      );
    }
    summaries.sort((a, b) => a.profileName.compareTo(b.profileName));
    return summaries;
  }

  /// A human-readable summary table.
  static String render(List<EvalTrace> traces) {
    final summaries = summarize(traces);
    if (summaries.isEmpty) return 'No traces to report.';
    final buffer = StringBuffer()
      ..writeln('Eval summary (${traces.length} traces)')
      ..writeln(
        'profile           L1 pass   mean tok   judged   judge pass   '
        'goal / qual / eff',
      )
      ..writeln(
        '----------------  --------  ---------  -------  ----------   '
        '-----------------',
      );
    for (final s in summaries) {
      buffer.writeln(
        '${s.profileName.padRight(16)}  '
        '${_pct(s.level1PassRate).padLeft(8)}  '
        '${s.meanTotalTokens.round().toString().padLeft(9)}  '
        '${s.judgedCount.toString().padLeft(7)}  '
        '${_pct(s.judgePassRate).padLeft(10)}   '
        '${_one(s.meanGoalAttainment)} / ${_one(s.meanQuality)} / '
        '${_one(s.meanEfficiency)}',
      );
    }
    return buffer.toString();
  }

  static double _mean(Iterable<double> values) {
    final list = values.toList(growable: false);
    if (list.isEmpty) return 0;
    return list.reduce((a, b) => a + b) / list.length;
  }

  static String _pct(double ratio) => '${(ratio * 100).round()}%';

  static String _one(double value) => value.toStringAsFixed(1);
}
