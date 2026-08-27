// Turns a goal check-in compaction judging packet (written by
// test/features/agents/eval/goal/compaction/goal_compaction_eval_live_test.dart)
// plus an optional scores file (written by the judge, in the schema described
// in docs/evaluations/goal_agent_models/compaction.md) into one markdown
// report.
//
// The deterministic metrics — status accuracy, tool-set agreement with the
// full-context arm, provider-reported tokens, the growth curve, digest cost —
// come from the packet alone. The judged metrics — fact recall by age,
// hallucination, recommendation agreement — appear when a scores file is
// given, and the pass bar is evaluated only then.
//
// Usage:
//   fvm dart run tool/goal_compaction_eval_report.dart packet.json [scores.json]
//
// Pure Dart on purpose: runnable without a Flutter context, testable from
// test/tool/goal_compaction_eval_report_test.dart.

import 'dart:convert';
import 'dart:io';

const goalCompactionPacketKind = 'lotti.goalCompactionEvalPacket';
const goalCompactionScoresKind = 'lotti.goalCompactionEvalScores';

void main(List<String> args) {
  final flags = args.where((arg) => arg.startsWith('--')).toList();
  if (flags.isNotEmpty) {
    stderr.writeln(
      'Unknown flag(s): ${flags.join(' ')}. This tool takes only file paths.',
    );
    exitCode = 2;
    return;
  }
  final paths = args.toList();
  if (paths.isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/goal_compaction_eval_report.dart '
      '<packet.json> [scores.json]',
    );
    exitCode = 2;
    return;
  }
  Map<String, dynamic>? packet;
  Map<String, dynamic>? scores;
  for (final path in paths) {
    final file = File(path);
    if (!file.existsSync()) {
      stderr.writeln('No such file: $path');
      exitCode = 2;
      return;
    }
    final decoded = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    switch (decoded['kind']) {
      case goalCompactionPacketKind:
        packet = decoded;
      case goalCompactionScoresKind:
        scores = decoded;
      default:
        stderr.writeln('Unknown artifact kind in $path: ${decoded['kind']}');
        exitCode = 2;
        return;
    }
  }
  if (packet == null) {
    stderr.writeln('No packet given.');
    exitCode = 2;
    return;
  }
  stdout.write(buildGoalCompactionEvalReport(packet: packet, scores: scores));
}

/// The pass bar, evaluated against the full-context arm.
///
/// Numbers, not adjectives: a candidate arm passes when its old-fact recall
/// is at least [minRecallRatioVsFull] of the full arm's, it hallucinates no
/// more than the full arm (plus [hallucinationSlack]), its recommendations
/// agree with the full arm at least [minRecommendationAgreement] of the
/// time, it never contradicts the full arm more than
/// [maxContradictionRate], it restates the status as accurately, and its
/// context stays under [maxUserVoiceTokens] at the full horizon.
class GoalCompactionPassBar {
  const GoalCompactionPassBar({
    this.minRecallRatioVsFull = 0.9,
    this.hallucinationSlack = 0.05,
    this.minRecommendationAgreement = 0.9,
    this.maxContradictionRate = 0.1,
    this.maxUserVoiceTokens = 2500,
  });

  final double minRecallRatioVsFull;
  final double hallucinationSlack;
  final double minRecommendationAgreement;
  final double maxContradictionRate;
  final int maxUserVoiceTokens;
}

String buildGoalCompactionEvalReport({
  required Map<String, dynamic> packet,
  Map<String, dynamic>? scores,
  GoalCompactionPassBar passBar = const GoalCompactionPassBar(),
}) {
  final strategyIds = (packet['strategyIds'] as List).cast<String>();
  final cases = (packet['cases'] as List).cast<Map<String, dynamic>>();
  final fixtures = (packet['fixtures'] as List).cast<Map<String, dynamic>>();
  final growth = ((packet['growthCurve'] as List?) ?? const [])
      .cast<Map<String, dynamic>>();
  final samples = cases.isEmpty
      ? 0
      : cases.map((c) => c['sample'] as int).reduce((a, b) => a > b ? a : b);

  final buffer = StringBuffer()
    ..writeln('# Goal check-in compaction eval')
    ..writeln()
    ..writeln(
      'Agent model `${packet['modelId']}` on '
      '`${(packet['provider'] as Map)['baseUrl']}`, temperature '
      '${packet['temperature']}, reference ${packet['reference']}. '
      '${fixtures.length} fixture(s) × ${strategyIds.length} arm(s) × '
      '$samples sample(s) = ${cases.length} case(s).',
    )
    ..writeln()
    // ── Deterministic ───────────────────────────────────────────────────
    ..writeln('## Deterministic metrics')
    ..writeln()
    ..writeln(
      '| Arm | Cases | Errors | Status correct | Report | Reply | '
      'Tool set = full | Wake input tokens | userVoice tokens | '
      'Verbatim | Digests |',
    )
    ..writeln(
      '| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |',
    );
  final fullByKey = <String, Map<String, dynamic>>{
    for (final c in cases)
      if (c['strategyId'] == 'full') _caseKey(c): c,
  };
  final deterministic = <String, _ArmStats>{};
  for (final strategyId in strategyIds) {
    final arm = cases.where((c) => c['strategyId'] == strategyId).toList();
    final stats = _ArmStats();
    for (final c in arm) {
      final wake = c['wake'] as Map<String, dynamic>;
      stats.cases++;
      if (c['errorMessage'] != null) stats.errors++;
      if (wake['statusCorrect'] == true) stats.statusCorrect++;
      if (wake['reportedStatus'] != null) stats.reports++;
      if (wake['reply'] != null) stats.replies++;
      final full = fullByKey[_caseKey(c)];
      if (full != null) {
        stats.comparable++;
        final mine = (wake['toolNames'] as List).join(',');
        final theirs =
            ((full['wake'] as Map<String, dynamic>)['toolNames'] as List).join(
              ',',
            );
        if (mine == theirs) stats.toolSetAgree++;
      }
      stats.wakeInput.add(wake['inputTokens'] as int?);
      final voice = c['userVoice'] as Map<String, dynamic>;
      stats.voiceTokens.add(voice['estimatedTokens'] as int?);
      stats.verbatim.add(voice['verbatimCount'] as int?);
      stats.digests.add(voice['digestCount'] as int?);
    }
    deterministic[strategyId] = stats;
    buffer.writeln(
      '| `$strategyId` | ${stats.cases} | ${stats.errors} | '
      '${_ratio(stats.statusCorrect, stats.cases)} | '
      '${_ratio(stats.reports, stats.cases)} | '
      '${_ratio(stats.replies, stats.cases)} | '
      '${strategyId == 'full' ? '—' : _ratio(stats.toolSetAgree, stats.comparable)} | '
      '${_mean(stats.wakeInput)} | ${_mean(stats.voiceTokens)} | '
      '${_mean(stats.verbatim)} | ${_mean(stats.digests)} |',
    );
  }

  // ── Growth curve ──────────────────────────────────────────────────────
  if (growth.isNotEmpty) {
    final months = growth.map((g) => g['months'] as int).toSet().toList()
      ..sort();
    buffer
      ..writeln()
      ..writeln(
        '## Token growth curve (userVoice, estimated, mean over fixtures)',
      )
      ..writeln()
      ..writeln(
        '| Months | Check-ins | ${strategyIds.map((s) => '`$s`').join(' | ')} |',
      )
      ..writeln('| ---: | ---: |${' ---: |' * strategyIds.length}');
    for (final m in months) {
      final at = growth.where((g) => g['months'] == m).toList();
      final checkIns = _mean([for (final g in at) g['checkIns'] as int?]);
      final cells = strategyIds.map((s) {
        final points = at.where((g) => g['strategyId'] == s);
        return _mean([for (final g in points) g['estimatedTokens'] as int?]);
      });
      buffer.writeln('| $m | $checkIns | ${cells.join(' | ')} |');
    }
  }

  // ── Digest cost ───────────────────────────────────────────────────────
  final digestUsage = packet['digestUsage'] as Map<String, dynamic>?;
  if (digestUsage != null && digestUsage.isNotEmpty) {
    final totalCheckIns = fixtures.fold<int>(
      0,
      (sum, f) => sum + (f['checkInCount'] as int),
    );
    final inputTokens = digestUsage['inputTokens'] as int?;
    final outputTokens = digestUsage['outputTokens'] as int?;
    buffer
      ..writeln()
      ..writeln('## Digest cost (hierarchical arm, amortised)')
      ..writeln()
      ..writeln(
        '${digestUsage['calls']} digest call(s), ${digestUsage['cacheHits']} '
        'cache hit(s); ${inputTokens ?? '?'} input + ${outputTokens ?? '?'} '
        'output tokens over $totalCheckIns check-ins'
        '${inputTokens != null && outputTokens != null && totalCheckIns > 0 ? ' ≈ ${((inputTokens + outputTokens) / totalCheckIns).toStringAsFixed(0)} tokens per check-in, once' : ''}.',
      );
  }

  // ── Judged ────────────────────────────────────────────────────────────
  final judged = <String, _JudgedStats>{};
  if (scores != null) {
    final scoreCases = (scores['cases'] as List).cast<Map<String, dynamic>>();
    final probesByCase = <String, Map<String, dynamic>>{
      for (final c in cases) _caseKey(c, withStrategy: true): c,
    };
    _requireCompleteScores(cases, scoreCases);
    buffer
      ..writeln()
      ..writeln('## Judged metrics (judge: ${scores['judge']})')
      ..writeln();
    for (final strategyId in strategyIds) {
      final stats = _JudgedStats();
      for (final s in scoreCases.where((s) => s['strategyId'] == strategyId)) {
        final packetCase = probesByCase[_caseKey(s, withStrategy: true)];
        if (packetCase == null) {
          // A scores file from another run would silently distort every
          // rate; refuse rather than fold unknown probes into the totals.
          throw StateError(
            'scores case ${_caseKey(s, withStrategy: true)} has no packet case',
          );
        }
        final packetProbes = (packetCase['probes'] as List)
            .cast<Map<String, dynamic>>();
        final ageById = <String, String>{
          for (final p in packetProbes) p['id'] as String: p['age'] as String,
        };
        final basisById = <String, String?>{
          for (final p in packetProbes)
            p['id'] as String: p['basis'] as String?,
        };
        for (final p in (s['probes'] as List).cast<Map<String, dynamic>>()) {
          final age = ageById[p['id']] ?? 'unknown';
          final grade = p['grade'] as String;
          final bucket = stats.byAge.putIfAbsent(age, _AgeStats.new);
          bucket.total++;
          stats.all.total++;
          switch (grade) {
            case 'correct':
              bucket.score += 1;
              stats.all.score += 1;
            case 'partial':
              bucket.score += 0.5;
              stats.all.score += 0.5;
            case 'honestUnknown':
              bucket.honestUnknown++;
              stats.all.honestUnknown++;
            case 'wrong':
              // A wrong answer the agent presented AS history is a
              // hallucination. Flagged notInHistory, or unparseable (null
              // basis), it is merely a miss.
              if (basisById[p['id']] == 'history') {
                bucket.hallucinated++;
                stats.all.hallucinated++;
              }
          }
        }
        final rec = s['recommendation'] as Map<String, dynamic>?;
        if (rec != null) {
          stats.recommendations++;
          switch (rec['agreement']) {
            case 'same':
              stats.same++;
            case 'compatible':
              stats.compatible++;
            case 'contradictory':
              stats.contradictory++;
          }
          if (rec['forbiddenHit'] == true) stats.forbidden++;
        }
      }
      judged[strategyId] = stats;
    }

    final ages = ['recent', 'mid', 'old'];
    buffer
      ..writeln('### Fact recall (correct = 1, partial = ½) by fact age')
      ..writeln()
      ..writeln(
        '| Arm | ${ages.join(' | ')} | All | Hallucination | Honest unknown |',
      )
      ..writeln('| --- |${' ---: |' * (ages.length + 3)}');
    for (final strategyId in strategyIds) {
      final stats = judged[strategyId]!;
      final cells = ages.map((age) {
        final bucket = stats.byAge[age];
        return bucket == null ? '—' : _score(bucket.score, bucket.total);
      });
      buffer.writeln(
        '| `$strategyId` | ${cells.join(' | ')} | '
        '${_score(stats.all.score, stats.all.total)} | '
        '${_ratio(stats.all.hallucinated, stats.all.total)} | '
        '${_ratio(stats.all.honestUnknown, stats.all.total)} |',
      );
    }

    buffer
      ..writeln()
      ..writeln('### Recommendation consistency with the full-context arm')
      ..writeln()
      ..writeln(
        '| Arm | Same | Compatible | Contradictory | Forbidden direction |',
      )
      ..writeln('| --- | ---: | ---: | ---: | ---: |');
    for (final strategyId in strategyIds) {
      final stats = judged[strategyId]!;
      if (stats.recommendations == 0) {
        buffer.writeln('| `$strategyId` | — | — | — | — |');
        continue;
      }
      buffer.writeln(
        '| `$strategyId` | ${_ratio(stats.same, stats.recommendations)} | '
        '${_ratio(stats.compatible, stats.recommendations)} | '
        '${_ratio(stats.contradictory, stats.recommendations)} | '
        '${_ratio(stats.forbidden, stats.recommendations)} |',
      );
    }

    // ── Pass bar ────────────────────────────────────────────────────────
    final full = judged['full'];
    final fullDet = deterministic['full'];
    if (full != null && fullDet != null) {
      buffer
        ..writeln()
        ..writeln('## Pass bar')
        ..writeln()
        ..writeln(
          'Old-fact recall ≥ ${(passBar.minRecallRatioVsFull * 100).round()}% '
          'of full; hallucination ≤ full + ${(passBar.hallucinationSlack * 100).round()} pp; '
          'recommendation same-or-compatible ≥ ${(passBar.minRecommendationAgreement * 100).round()}%; '
          'contradictory ≤ ${(passBar.maxContradictionRate * 100).round()}%; '
          'status accuracy ≥ full; userVoice ≤ ${passBar.maxUserVoiceTokens} tokens.',
        )
        ..writeln()
        ..writeln(
          '| Arm | Old recall | Hallucination | Agreement | Contradiction | Status | Tokens | Verdict |',
        )
        ..writeln('| --- | :-: | :-: | :-: | :-: | :-: | :-: | :-: |');
      final fullOld = full.byAge['old'];
      final fullOldRecall = fullOld == null || fullOld.total == 0
          ? 0.0
          : fullOld.score / fullOld.total;
      final fullHallucination = full.all.total == 0
          ? 0.0
          : full.all.hallucinated / full.all.total;
      final fullStatus = fullDet.cases == 0
          ? 0.0
          : fullDet.statusCorrect / fullDet.cases;
      for (final strategyId in strategyIds) {
        if (strategyId == 'full') continue;
        final stats = judged[strategyId]!;
        final det = deterministic[strategyId]!;
        final old = stats.byAge['old'];
        final oldRecall = old == null || old.total == 0
            ? 0.0
            : old.score / old.total;
        final hallucination = stats.all.total == 0
            ? 0.0
            : stats.all.hallucinated / stats.all.total;
        final agreement = stats.recommendations == 0
            ? 0.0
            : (stats.same + stats.compatible) / stats.recommendations;
        final contradiction = stats.recommendations == 0
            ? 0.0
            : stats.contradictory / stats.recommendations;
        final status = det.cases == 0 ? 0.0 : det.statusCorrect / det.cases;
        final tokens = _meanValue(det.voiceTokens);
        final checks = [
          oldRecall >= fullOldRecall * passBar.minRecallRatioVsFull,
          hallucination <= fullHallucination + passBar.hallucinationSlack,
          agreement >= passBar.minRecommendationAgreement,
          contradiction <= passBar.maxContradictionRate,
          status >= fullStatus,
          tokens != null && tokens <= passBar.maxUserVoiceTokens,
        ];
        buffer.writeln(
          '| `$strategyId` | ${checks.map(_mark).join(' | ')} | '
          '**${checks.every((c) => c) ? 'PASS' : 'FAIL'}** |',
        );
      }
    }
  } else {
    buffer
      ..writeln()
      ..writeln(
        '_No scores file given: fact recall, hallucination and recommendation '
        'consistency need the judge. See the run book for the scores schema._',
      );
  }

  // ── Appendix ──────────────────────────────────────────────────────────
  buffer
    ..writeln()
    ..writeln('## Cases')
    ..writeln();
  for (final c in cases) {
    final wake = c['wake'] as Map<String, dynamic>;
    buffer
      ..writeln(
        '### ${c['fixtureId']} × `${c['strategyId']}` × s${c['sample']}',
      )
      ..writeln()
      ..writeln(
        'Status expected `${wake['expectedStatus']}`, reported '
        '`${wake['reportedStatus'] ?? '—'}`; tools: '
        '${(wake['toolNames'] as List).isEmpty ? 'none' : (wake['toolNames'] as List).join(', ')}; '
        'wake input ${wake['inputTokens'] ?? '?'} tokens.',
      )
      ..writeln();
    if (c['errorMessage'] != null) {
      buffer
        ..writeln('Error: ${c['errorMessage']}')
        ..writeln();
    }
    if (wake['oneLiner'] != null) {
      buffer
        ..writeln('> ${wake['oneLiner']}')
        ..writeln();
    }
    if (wake['reply'] != null) {
      buffer
        ..writeln(_clip(wake['reply'] as String, 600))
        ..writeln();
    }
  }
  return buffer.toString();
}

/// A verdict over a subset would be a verdict over the judge's selection.
/// Every packet case must be scored, and every probe of every case graded,
/// before any rate is computed.
void _requireCompleteScores(
  List<Map<String, dynamic>> cases,
  List<Map<String, dynamic>> scoreCases,
) {
  final scored = <String, Map<String, dynamic>>{
    for (final s in scoreCases) _caseKey(s, withStrategy: true): s,
  };
  for (final c in cases) {
    final key = _caseKey(c, withStrategy: true);
    final s = scored[key];
    if (s == null) {
      throw StateError('packet case $key has no scores case');
    }
    final expected = {
      for (final p in (c['probes'] as List).cast<Map<String, dynamic>>())
        p['id'] as String,
    };
    final graded = {
      for (final p in (s['probes'] as List).cast<Map<String, dynamic>>())
        p['id'] as String,
    };
    final missing = expected.difference(graded);
    if (missing.isNotEmpty) {
      throw StateError(
        'scores case $key is missing probe(s): ${missing.join(', ')}',
      );
    }
    if (s['recommendation'] == null) {
      throw StateError('scores case $key has no recommendation verdict');
    }
  }
}

String _caseKey(Map<String, dynamic> c, {bool withStrategy = false}) =>
    withStrategy
    ? '${c['fixtureId']}|${c['strategyId']}|${c['sample']}'
    : '${c['fixtureId']}|${c['sample']}';

class _ArmStats {
  int cases = 0;
  int errors = 0;
  int statusCorrect = 0;
  int reports = 0;
  int replies = 0;
  int comparable = 0;
  int toolSetAgree = 0;
  final wakeInput = <int?>[];
  final voiceTokens = <int?>[];
  final verbatim = <int?>[];
  final digests = <int?>[];
}

class _AgeStats {
  int total = 0;
  double score = 0;
  int hallucinated = 0;
  int honestUnknown = 0;
}

class _JudgedStats {
  final byAge = <String, _AgeStats>{};
  final all = _AgeStats();
  int recommendations = 0;
  int same = 0;
  int compatible = 0;
  int contradictory = 0;
  int forbidden = 0;
}

String _ratio(int part, int total) =>
    total == 0 ? '—' : '$part/$total (${(100 * part / total).round()}%)';

String _score(double score, int total) =>
    total == 0 ? '—' : '${(100 * score / total).round()}%';

double? _meanValue(List<int?> values) {
  final present = values.whereType<int>().toList();
  if (present.isEmpty) return null;
  return present.reduce((a, b) => a + b) / present.length;
}

String _mean(List<int?> values) {
  final mean = _meanValue(values);
  return mean == null ? '—' : mean.round().toString();
}

String _mark(bool ok) => ok ? '✓' : '✗';

String _clip(String text, int max) {
  final flat = text.replaceAll('\n', ' ').trim();
  return flat.length <= max ? flat : '${flat.substring(0, max)}…';
}
