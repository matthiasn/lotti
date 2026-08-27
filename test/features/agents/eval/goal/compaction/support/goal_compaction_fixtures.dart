/// Synthetic long-running goals for the check-in compaction evaluation.
///
/// Each fixture is a goal that has been running for roughly two years with
/// three check-ins a week, generated deterministically from a seed so a
/// re-run reads the same history. The interesting part is not the volume but
/// the shape: every archetype is a case where drawing the right conclusion
/// from the present alone is wrong or incomplete — a stall that the user's
/// own words paper over, a recovery whose cause is nine months old, a
/// redefinition that retired the number the early check-ins keep quoting.
///
/// A fixture carries its own answer key: the status the deterministic tier
/// derives at the reference date (asserted against the real evaluator in the
/// offline self-test), a set of fact-recall probes whose answers live in
/// specific dated check-ins, and the recommendation a well-informed coach
/// would make. The Ross Station penguin universe keeps it obviously
/// synthetic; nothing here resembles real user data.
library;

import 'dart:math';

import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/goals/evaluation/goal_signal_window.dart';
import 'package:lotti/features/goals/model/goal_checkin_summary.dart';

/// Every fixture shares this "today": a Thursday at noon, station time.
final goalCompactionEvalReference = DateTime.utc(2026, 8, 27, 12);

/// How far back a fact is from the reference — the strata the recall
/// metric is reported over, because that is where each compaction layer
/// starts losing.
enum GoalCompactionFactAge {
  /// Inside the last month: should survive even truncation.
  recent,

  /// One to six months: the monthly-digest layer.
  mid,

  /// Older than six months: the quarterly layer.
  old;

  static GoalCompactionFactAge of(DateTime factDate, DateTime reference) {
    final days = reference.difference(factDate).inDays;
    if (days <= 31) return recent;
    if (days <= 183) return mid;
    return old;
  }
}

/// One fact-recall question with the answer the history supports.
class GoalCompactionProbe {
  const GoalCompactionProbe({
    required this.id,
    required this.question,
    required this.referenceAnswer,
    required this.factDate,
    this.isPattern = false,
  });

  final String id;
  final String question;

  /// True when the answer is a pattern across many templated check-ins
  /// rather than the words of one dated needle.
  final bool isPattern;

  /// What a correct answer must contain, in the judge's terms.
  final String referenceAnswer;

  /// When the check-in(s) carrying the answer were recorded.
  final DateTime factDate;

  GoalCompactionFactAge age(DateTime reference) =>
      GoalCompactionFactAge.of(factDate, reference);

  Map<String, Object?> toJson(DateTime reference) => {
    'id': id,
    'question': question,
    'referenceAnswer': referenceAnswer,
    'factDate': factDate.toIso8601String(),
    'age': age(reference).name,
    'isPattern': isPattern,
  };
}

/// The answer key.
class GoalCompactionGroundTruth {
  const GoalCompactionGroundTruth({
    required this.expectedStatus,
    required this.probes,
    required this.expectedRecommendation,
    required this.forbiddenRecommendations,
  });

  /// What the deterministic tier derives; the report must restate it.
  final GoalTrackStatus expectedStatus;
  final List<GoalCompactionProbe> probes;

  /// The coaching direction a coach who read everything would take.
  final String expectedRecommendation;

  /// Directions the full history rules out — the ones a truncated view is
  /// prone to.
  final List<String> forbiddenRecommendations;

  Map<String, Object?> toJson(DateTime reference) => {
    'expectedStatus': expectedStatus.name,
    'probes': [for (final p in probes) p.toJson(reference)],
    'expectedRecommendation': expectedRecommendation,
    'forbiddenRecommendations': forbiddenRecommendations,
  };
}

/// One synthetic goal: its spec, its two years of check-ins, the signal
/// window at the reference date, and the answer key.
class GoalCompactionFixture {
  const GoalCompactionFixture({
    required this.id,
    required this.title,
    required this.statement,
    required this.criteria,
    required this.startDate,
    required this.checkIns,
    required this.window,
    required this.priorAttainments,
    required this.priorStatus,
    required this.transitionFrom,
    required this.truth,
    this.targetDate,
  });

  final String id;
  final String title;
  final String statement;
  final GoalCriterion criteria;
  final DateTime startDate;
  final DateTime? targetDate;

  /// Oldest first.
  final List<GoalCheckInSummary> checkIns;

  /// The seven days ending at the reference, as the signal reader would
  /// return them.
  final GoalSignalWindow window;

  /// Prior period attainments, most recent first — the trend input.
  final List<double> priorAttainments;
  final GoalTrackStatus priorStatus;

  /// The status the wake transitions FROM. A same-status wake is a
  /// contract-mandated no-op, which would leave nothing to compare; every
  /// evaluation wake is therefore a transition, so a report is owed.
  final GoalTrackStatus transitionFrom;
  final GoalCompactionGroundTruth truth;

  String get agentId => 'goal-compaction-eval:$id';

  /// The check-ins recorded within [months] of [startDate] — the growth
  /// curve's horizons.
  List<GoalCheckInSummary> upTo(int months) {
    final cutoff = DateTime.utc(startDate.year, startDate.month + months);
    return [
      for (final c in checkIns)
        if (c.recordedAt.isBefore(cutoff)) c,
    ];
  }
}

/// Uniform daily step sums over the seven days ending at the reference.
GoalSignalWindow _stepsWindow(int perDay, {Map<DateTime, int>? gymDays}) =>
    GoalSignalWindow(
      quantitativeDailySums: {
        'cumulative_step_count': {
          for (var day = 21; day <= 27; day++)
            DateTime.utc(2026, 8, day): perDay,
        },
      },
      habitSuccessesByDay: gymDays == null ? const {} : {'gym': gymDays},
    );

const _steps10k = GoalCriterion.metric(
  criterionId: 'steps',
  dataType: 'cumulative_step_count',
  window: GoalWindow.rollingDays(count: 7),
  aggregation: GoalAggregation.dailySumThenAverage,
  target: 10000,
);

// ── The generator ────────────────────────────────────────────────────────

/// A stretch of months with one voice: what the check-ins say, what the
/// user keeps promising, what is in the way.
class _Phase {
  const _Phase({
    required this.fromMonth,
    required this.toMonth,
    required this.happened,
    required this.committed,
    required this.stepsRange,
    this.blockers = const [],
    this.moods = const ['steady'],
  });

  /// Month offsets from the start, inclusive/exclusive.
  final int fromMonth;
  final int toMonth;

  /// Templates; `{steps}` is replaced with a number drawn from [stepsRange].
  final List<String> happened;
  final List<String?> committed;
  final List<String?> blockers;
  final List<String> moods;
  final (int, int) stepsRange;
}

/// A specific check-in on a specific date — the fact a probe asks for.
class _Needle {
  const _Needle({
    required this.date,
    required this.happened,
    this.committed,
    this.blockers,
    this.mood,
  });

  final DateTime date;
  final String happened;
  final String? committed;
  final String? blockers;
  final String? mood;
}

const _checkInsPerWeek = 3;

List<GoalCheckInSummary> _generate({
  required String fixtureId,
  required DateTime start,
  required DateTime end,
  required List<_Phase> phases,
  required List<_Needle> needles,
  required int seed,
}) {
  final random = Random(seed);
  final byDay = <DateTime, GoalCheckInSummary>{};
  // The reference is "today at noon"; today's check-in has not happened.
  final endDay = DateTime.utc(end.year, end.month, end.day);

  GoalCheckInSummary make(
    DateTime day, {
    required String happened,
    String? committed,
    String? blockers,
    String? mood,
  }) {
    final at = DateTime.utc(
      day.year,
      day.month,
      day.day,
      7 + random.nextInt(13),
      random.nextInt(60),
    );
    final key = DateTime.utc(day.year, day.month, day.day);
    final id = 'checkin:$fixtureId:${key.toIso8601String().substring(0, 10)}';
    return GoalCheckInSummary(
      id: id,
      sourceEntryId: 'entry:$id',
      recordedAt: at,
      whatHappened: happened,
      committedTo: committed,
      blockers: blockers,
      mood: mood,
    );
  }

  for (final phase in phases) {
    final phaseStart = DateTime.utc(start.year, start.month + phase.fromMonth);
    final phaseEnd = DateTime.utc(start.year, start.month + phase.toMonth);
    var weekStart = phaseStart;
    while (weekStart.isBefore(phaseEnd) && weekStart.isBefore(endDay)) {
      final offsets = <int>{};
      while (offsets.length < _checkInsPerWeek) {
        offsets.add(random.nextInt(7));
      }
      for (final offset in offsets.toList()..sort()) {
        final day = weekStart.add(Duration(days: offset));
        if (!day.isBefore(phaseEnd) || !day.isBefore(endDay)) continue;
        final (low, high) = phase.stepsRange;
        final steps = (low + random.nextInt(high - low + 1)) ~/ 100 * 100;
        String fill(String s) => s.replaceAll('{steps}', _thousands(steps));
        final key = DateTime.utc(day.year, day.month, day.day);
        byDay[key] = make(
          day,
          happened: fill(phase.happened[random.nextInt(phase.happened.length)]),
          committed: _pick(random, phase.committed)?.let(fill),
          blockers: _pick(random, phase.blockers),
          mood: phase.moods[random.nextInt(phase.moods.length)],
        );
      }
      weekStart = weekStart.add(const Duration(days: 7));
    }
  }

  for (final needle in needles) {
    final key = DateTime.utc(
      needle.date.year,
      needle.date.month,
      needle.date.day,
    );
    byDay[key] = make(
      needle.date,
      happened: needle.happened,
      committed: needle.committed,
      blockers: needle.blockers,
      mood: needle.mood,
    );
  }

  final days = byDay.keys.toList()..sort();
  return [for (final day in days) byDay[day]!];
}

T? _pick<T>(Random random, List<T?> options) =>
    options.isEmpty ? null : options[random.nextInt(options.length)];

String _thousands(int value) {
  final text = value.toString();
  return text.length <= 3
      ? text
      : '${text.substring(0, text.length - 3)},${text.substring(text.length - 3)}';
}

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}

// Shared voices. Wording varies enough that a digest has to abstract rather
// than pattern-match, and every template mentions concrete station life so
// the digests have something to lose.
const List<String> _steadyHappened = [
  'Two perimeter loops today, one after lunch and one after the evening count. Tracker says {steps}.',
  'Walked out to the weather mast and back before the shift, then the lunch loop. {steps} on the tracker.',
  'Good day — {steps} steps. Did the long loop past the ice ramp while the light held.',
  'Lunch loop plus pacing the corridor during the radio check. {steps}, comfortably over.',
  'Went out with the survey team on foot instead of the skidoo. Ended on {steps}.',
];
const List<String?> _steadyCommitted = [
  'Both loops again tomorrow.',
  'Keep the lunch loop non-negotiable this week.',
  null,
  'Weather mast walk before the shift tomorrow.',
];

// ── Archetype 1: steady, then a stall the user talks over ───────────────

final DateTime _stallStart = DateTime.utc(2024, 9, 2);

List<GoalCheckInSummary> _stallCheckIns() => _generate(
  fixtureId: 'steady_then_stall',
  start: _stallStart,
  end: goalCompactionEvalReference,
  seed: 11,
  phases: [
    const _Phase(
      fromMonth: 0,
      toMonth: 2,
      happened: [
        'First weeks. Managed {steps} mostly by walking to the far hangar instead of taking the skidoo.',
        'Getting the hang of it. {steps} today, mostly the hangar walk and the lunch loop.',
        'Under target at {steps} — boots are rubbing and I cut the afternoon loop short.',
      ],
      committed: ['Hangar walk every day this week.', null],
      blockers: ['Blisters from the old boots.', null],
      moods: ['keen', 'a bit sore'],
      stepsRange: (7500, 10500),
    ),
    const _Phase(
      fromMonth: 2,
      toMonth: 8,
      happened: _steadyHappened,
      committed: _steadyCommitted,
      moods: ['steady', 'good', 'tired but fine'],
      stepsRange: (9800, 12500),
    ),
    // The stall: numbers fall, the voice stays upbeat. Reading these as
    // evidence of progress is exactly the mistake the interpretation policy
    // warns about, and the compaction must preserve that the numbers fell.
    const _Phase(
      fromMonth: 8,
      toMonth: 24,
      happened: [
        'Feeling really good about the goal this week. Only {steps} on the tracker but the intent is there.',
        'Busy colony-survey day at the desk, {steps}. Still committed, honestly.',
        'Solid mindset, {steps} steps. The survey deadlines are eating the loop time but I feel on top of it.',
        'Quick one — {steps}. Long stretch of data entry, but I walked the corridor a lot.',
        'Positive week overall I think. {steps} today.',
      ],
      committed: [
        'Get the lunch loop back in once the survey batch is filed.',
        null,
        null,
        'Try for one loop tomorrow.',
      ],
      blockers: [
        'Colony survey season keeps me at the desk most of the day.',
        'Survey data entry backlog.',
        null,
      ],
      moods: ['upbeat', 'optimistic', 'cheerful'],
      stepsRange: (5200, 7400),
    ),
  ],
  needles: [
    _Needle(
      date: DateTime.utc(2024, 10, 14),
      happened:
          'Bought the new insulated boots from the station store — the old ones gave me blisters that were cutting every walk short. {steps} today, first full loop without limping.'
              .replaceAll('{steps}', '9,400'),
      committed: 'Break the new boots in on the short loop this week.',
      mood: 'relieved',
    ),
    _Needle(
      date: DateTime.utc(2025, 1, 20),
      happened:
          'Made the perimeter loop after lunch a fixed appointment in my shift calendar, every weekday. That is what got me from about 8,000 to consistently over 10,000 — the calendar block, not willpower.',
      committed:
          'Perimeter loop after lunch, every weekday, as a calendar block.',
      mood: 'confident',
    ),
    _Needle(
      date: DateTime.utc(2025, 5, 9),
      happened:
          'Colony survey season started this week. The survey lead moved me to data entry, which means most of the day at a desk. First day I dropped the lunch loop and only got 6,100.',
      committed: 'Keep the lunch loop even during survey season.',
      blockers: 'Colony survey data entry, all day.',
      mood: 'a bit worried',
    ),
    _Needle(
      date: DateTime.utc(2025, 5, 23),
      happened:
          'Deleted the perimeter-loop calendar block because it kept clashing with the survey stand-ups. Told myself I would fit the walk in anyway. 5,800 today.',
      blockers: 'Survey stand-ups overlapped the loop slot.',
      mood: 'fine',
    ),
    _Needle(
      date: DateTime.utc(2026, 8, 20),
      happened:
          'Feeling great about where the goal is this week, honestly. 6,300 steps but the energy is good and I have been thinking about walking a lot.',
      committed: 'Get a loop in over the weekend.',
      mood: 'upbeat',
    ),
  ],
);

final _stallTruth = GoalCompactionGroundTruth(
  expectedStatus: GoalTrackStatus.offTrack,
  probes: [
    GoalCompactionProbe(
      id: 'stall_boots',
      question:
          'Early on, what did the user buy and why did it matter for the goal?',
      referenceAnswer:
          'New insulated boots from the station store, in October 2024, because the old boots caused blisters that were cutting walks short.',
      factDate: DateTime.utc(2024, 10, 14),
    ),
    GoalCompactionProbe(
      id: 'stall_routine',
      question:
          'What routine did the user credit for getting consistently over 10,000 steps, and roughly when did they establish it?',
      referenceAnswer:
          'A fixed calendar block for the perimeter loop after lunch every weekday, set up around January 2025. They credited the calendar block rather than willpower.',
      factDate: DateTime.utc(2025, 1, 20),
    ),
    GoalCompactionProbe(
      id: 'stall_cause',
      question:
          "When did the step counts start falling, and what changed in the user's life at that point?",
      referenceAnswer:
          'Around May 2025, when colony survey season started and the user was moved to all-day data entry at a desk.',
      factDate: DateTime.utc(2025, 5, 9),
    ),
    GoalCompactionProbe(
      id: 'stall_block_deleted',
      question: 'What happened to the lunch-loop calendar block, and why?',
      referenceAnswer:
          'The user deleted it in late May 2025 because it clashed with survey stand-ups, telling themselves they would fit the walk in anyway.',
      factDate: DateTime.utc(2025, 5, 23),
    ),
    GoalCompactionProbe(
      id: 'stall_mood_vs_numbers',
      isPattern: true,
      question:
          "How does the user's mood in the check-ins of the last year compare with their measured step counts?",
      referenceAnswer:
          'The mood has stayed upbeat, optimistic and confident while the measured steps have sat around 5,000–7,500, well under target, for over a year.',
      factDate: DateTime.utc(2026, 3),
    ),
    GoalCompactionProbe(
      id: 'stall_recent',
      question: 'What did the user commit to in their most recent check-ins?',
      referenceAnswer:
          'Small, vague commitments — a loop over the weekend, "try for one loop tomorrow" — rather than restoring the routine.',
      factDate: DateTime.utc(2026, 8, 20),
    ),
  ],
  expectedRecommendation:
      'Name the stall plainly (over a year under target, contradicting the upbeat check-ins) and propose restoring the specific thing that worked before — the fixed after-lunch perimeter-loop calendar block — adapted around survey stand-ups, rather than a generic "walk more".',
  forbiddenRecommendations: [
    'Congratulating the user on progress or momentum.',
    'Treating the upbeat mood as evidence the goal is going well.',
    'Suggesting a brand-new routine without reference to the calendar block that worked in 2025.',
  ],
);

// ── Archetype 2: an injury, a long regression, a slow recovery ──────────

final DateTime _recoverStart = DateTime.utc(2024, 9, 2);

List<GoalCheckInSummary> _recoverCheckIns() => _generate(
  fixtureId: 'regress_recover',
  start: _recoverStart,
  end: goalCompactionEvalReference,
  seed: 23,
  phases: [
    const _Phase(
      fromMonth: 0,
      toMonth: 9,
      happened: _steadyHappened,
      committed: _steadyCommitted,
      moods: ['steady', 'good'],
      stepsRange: (9800, 12800),
    ),
    const _Phase(
      fromMonth: 9,
      toMonth: 13,
      happened: [
        'Physio day. Mostly the stationary bike and the ankle exercises; {steps} steps shuffling around the module.',
        'Ankle still swells by the evening. {steps} and that felt like plenty.',
        'Short corridor walks only, as the medic said. {steps}.',
        'Tried the short loop with the brace. {steps}, ankle complained afterwards.',
      ],
      committed: [
        'Ankle exercises twice a day, as prescribed.',
        "Stay under the medic's step cap this week.",
        null,
      ],
      blockers: ['Ankle sprain — medic step cap.', 'Swelling by the evening.'],
      moods: ['frustrated', 'patient', 'low'],
      stepsRange: (2800, 4600),
    ),
    const _Phase(
      fromMonth: 13,
      toMonth: 18,
      happened: [
        'Building back up. {steps} today, one loop at an easy pace, ankle fine afterwards.',
        'Two short loops instead of one long one, the way the physio suggested. {steps}.',
        'Best week since the sprain — {steps}. No swelling.',
        'Careful day, {steps}. Kept off the ice ramp entirely.',
      ],
      committed: [
        'Add about 500 steps a week, no more.',
        'Two short loops rather than one long one.',
        null,
      ],
      blockers: [null, 'Still avoiding the ice ramp.'],
      moods: ['hopeful', 'careful', 'good'],
      stepsRange: (6500, 9400),
    ),
    const _Phase(
      fromMonth: 18,
      toMonth: 24,
      happened: _steadyHappened,
      committed: _steadyCommitted,
      moods: ['good', 'strong', 'steady'],
      stepsRange: (9600, 12000),
    ),
  ],
  needles: [
    _Needle(
      date: DateTime.utc(2025, 6, 3),
      happened:
          'Twisted my left ankle badly on the ice ramp behind the fuel depot this morning. The medic thinks it is a grade-two sprain, no fracture. I am on a step cap of 3,000 a day for at least six weeks.',
      committed: "Follow the medic's step cap and do the ankle exercises.",
      blockers: 'Grade-two ankle sprain, 3,000-step cap.',
      mood: 'gutted',
    ),
    _Needle(
      date: DateTime.utc(2025, 7, 15),
      happened:
          'Six-week review with the medic: healing is slower than hoped, cap stays at 4,000 and I am to add the stationary bike for cardio instead of walking. Also told to stay off the ice ramp until spring.',
      committed: 'Stationary bike three times a week, stay off the ice ramp.',
      blockers: 'Ankle still healing; ramp off limits.',
      mood: 'patient',
    ),
    _Needle(
      date: DateTime.utc(2025, 10, 6),
      happened:
          'Cleared by the medic today. No more step cap. The advice is to build back gradually — roughly five hundred more steps a week — and to split the walking into two shorter loops rather than one long one.',
      committed: 'Add about 500 steps per week; two short loops.',
      mood: 'relieved',
    ),
    _Needle(
      date: DateTime.utc(2026, 3, 11),
      happened:
          'First 10,000-step day since the sprain — 10,200. Nine months. Took the long loop past the hangar, ankle absolutely fine.',
      committed: 'Hold around 10,000 for a couple of weeks before pushing on.',
      mood: 'proud',
    ),
    _Needle(
      date: DateTime.utc(2026, 8, 24),
      happened:
          'Solid 11,400 today. Ankle has not complained in months. Thinking about going back to the one long loop instead of two short ones.',
      committed: 'Decide about the long loop after this week.',
      mood: 'strong',
    ),
  ],
);

final _recoverTruth = GoalCompactionGroundTruth(
  expectedStatus: GoalTrackStatus.onTrack,
  probes: [
    GoalCompactionProbe(
      id: 'recover_injury',
      question:
          'What injury did the user have, and when and where did it happen?',
      referenceAnswer:
          'A grade-two sprain of the left ankle, in early June 2025, on the ice ramp behind the fuel depot.',
      factDate: DateTime.utc(2025, 6, 3),
    ),
    GoalCompactionProbe(
      id: 'recover_cap',
      question:
          'What restrictions did the medic place on the user, and how did they change over the summer of 2025?',
      referenceAnswer:
          'A step cap of 3,000 a day for at least six weeks; at the six-week review it was set to 4,000, with the stationary bike added for cardio and the ice ramp off limits until spring.',
      factDate: DateTime.utc(2025, 7, 15),
    ),
    GoalCompactionProbe(
      id: 'recover_cleared',
      question:
          'When was the user cleared to walk without a cap, and what rebuild advice did they get?',
      referenceAnswer:
          'Early October 2025; add roughly 500 steps a week and split walking into two shorter loops rather than one long one.',
      factDate: DateTime.utc(2025, 10, 6),
    ),
    GoalCompactionProbe(
      id: 'recover_first_10k',
      question:
          'When did the user first reach 10,000 steps again after the injury?',
      referenceAnswer:
          'March 2026 (10,200 steps), about nine months after the sprain.',
      factDate: DateTime.utc(2026, 3, 11),
    ),
    GoalCompactionProbe(
      id: 'recover_before',
      isPattern: true,
      question:
          "What was the user's step pattern like in the months before the injury?",
      referenceAnswer:
          'Consistently over target — roughly 10,000–12,800 a day, with two perimeter loops most days.',
      factDate: DateTime.utc(2025, 3),
    ),
    GoalCompactionProbe(
      id: 'recover_recent',
      question:
          'What is the user currently considering changing about their routine?',
      referenceAnswer:
          'Going back to one long loop instead of two short ones, now that the ankle has been fine for months.',
      factDate: DateTime.utc(2026, 8, 24),
    ),
  ],
  expectedRecommendation:
      "Acknowledge the recovery as the achievement it is (on track again after a nine-month injury setback), and, on the question of returning to one long loop, refer back to the physio's two-short-loops advice and suggest a gradual change rather than an abrupt one.",
  forbiddenRecommendations: [
    'Treating the current on-track status as unremarkable, as if the goal had always been on track.',
    'Encouraging a sharp increase in volume.',
    'Suggesting the user has no injury history to consider.',
  ],
);

// ── Archetype 3: the goal was redefined ──────────────────────────────────

final DateTime _redefinedStart = DateTime.utc(2024, 9, 2);

List<GoalCheckInSummary> _redefinedCheckIns() => _generate(
  fixtureId: 'redefined',
  start: _redefinedStart,
  end: goalCompactionEvalReference,
  seed: 37,
  phases: [
    const _Phase(
      fromMonth: 0,
      toMonth: 6,
      happened: [
        'Chasing the 10,000 again — {steps}. The long loop twice is the only way I get there.',
        'Got to {steps}. Knees a bit grumbly after the second loop on the hard-packed snow.',
        'Hit 10k target-ish, {steps}. Both knees stiff this evening.',
        '{steps} today. The 10,000 needs two long loops and my knees are starting to object.',
      ],
      committed: ['Two long loops tomorrow for the 10k.', null],
      blockers: ['Knees stiff after long loops.', null],
      moods: ['determined', 'sore'],
      stepsRange: (8800, 10800),
    ),
    const _Phase(
      fromMonth: 6,
      toMonth: 24,
      happened: [
        'One loop for {steps} steps and a gym session — squats and the leg press, as the doctor suggested.',
        '{steps} steps and gym day two of three. Knees are fine on this plan.',
        'Rest from the gym, {steps} steps on the short loop.',
        'Gym three of three done this week, {steps} steps. No knee pain at all.',
        '{steps} today plus the leg session. This version of the goal suits me much better.',
      ],
      committed: [
        'Three gym sessions this week.',
        'Short loop daily, gym on the usual days.',
        null,
      ],
      moods: ['good', 'steady', 'pleased'],
      stepsRange: (7800, 9400),
    ),
  ],
  needles: [
    _Needle(
      date: DateTime.utc(2025, 2, 18),
      happened:
          'Saw the station doctor about the knees. Early patellar tendinopathy from the volume of walking on hard snow. The advice is to lower the daily steps and add strength work for the legs instead.',
      committed: 'Book a follow-up and think about changing the goal.',
      blockers: 'Knee pain — patellar tendinopathy.',
      mood: 'concerned',
    ),
    _Needle(
      date: DateTime.utc(2025, 3, 3),
      happened:
          'Changed the goal today: it is now 8,000 steps a day on the rolling week plus three station-gym strength sessions per calendar week, instead of 10,000 steps. The doctor was clear that 10,000 on this terrain was what hurt the knees.',
      committed: 'Follow the new goal — 8,000 steps and three gym sessions.',
      mood: 'settled',
    ),
    _Needle(
      date: DateTime.utc(2025, 9, 9),
      happened:
          'Six months on the new definition. Knees have been pain-free since about May. 8,400 steps today and the third gym session of the week.',
      committed: 'Keep exactly this.',
      mood: 'pleased',
    ),
    _Needle(
      date: DateTime.utc(2026, 5, 12),
      happened:
          'Follow-up with the station doctor: knees fully settled, no tenderness. Asked whether I could go back up to 10,000 and was told to stay at 8,000 plus the strength sessions — the strength work is what protects the knees.',
      committed: 'Stay at 8,000 and the three gym sessions.',
      mood: 'reassured',
    ),
    _Needle(
      date: DateTime.utc(2026, 8, 25),
      happened:
          '8,700 steps and gym session two of the week. Someone in the mess suggested I go back to 10,000 now the knees are fine; I said I would think about it.',
      committed: 'Third gym session on Thursday.',
      mood: 'good',
    ),
  ],
);

final _redefinedTruth = GoalCompactionGroundTruth(
  expectedStatus: GoalTrackStatus.onTrack,
  probes: [
    GoalCompactionProbe(
      id: 'redefined_original',
      isPattern: true,
      question: 'What was the goal originally, before it was changed?',
      referenceAnswer: 'An average of 10,000 steps a day over a rolling week.',
      factDate: DateTime.utc(2024, 11),
    ),
    GoalCompactionProbe(
      id: 'redefined_why',
      question: 'Why was the goal changed, and who advised it?',
      referenceAnswer:
          'Knee pain — early patellar tendinopathy from walking volume on hard snow; the station doctor advised fewer steps plus leg strength work (February 2025).',
      factDate: DateTime.utc(2025, 2, 18),
    ),
    GoalCompactionProbe(
      id: 'redefined_when_what',
      question:
          'When was the goal redefined and what is the current definition?',
      referenceAnswer:
          'Early March 2025; 8,000 steps a day on a rolling week plus three station-gym strength sessions per calendar week.',
      factDate: DateTime.utc(2025, 3, 3),
    ),
    GoalCompactionProbe(
      id: 'redefined_is_10k_target',
      question: 'Is 10,000 steps a day still the target?',
      referenceAnswer:
          'No — the target has been 8,000 steps plus gym sessions since March 2025.',
      factDate: DateTime.utc(2025, 3, 3),
    ),
    GoalCompactionProbe(
      id: 'redefined_knees_since',
      question: "How have the user's knees been since the change?",
      referenceAnswer:
          'Pain-free since around May 2025; check-ins repeatedly say no knee pain on the new plan.',
      factDate: DateTime.utc(2025, 9, 9),
    ),
    GoalCompactionProbe(
      id: 'redefined_doctor_followup',
      question:
          'What did the station doctor say at the most recent follow-up about the step target?',
      referenceAnswer:
          'At the May 2026 follow-up the knees were fully settled, but the doctor said to stay at 8,000 steps plus the strength sessions rather than return to 10,000, because the strength work protects the knees.',
      factDate: DateTime.utc(2026, 5, 12),
    ),
    GoalCompactionProbe(
      id: 'redefined_recent',
      question:
          'What suggestion did the user receive recently, and how did they respond?',
      referenceAnswer:
          'Someone in the mess suggested going back to 10,000 steps now the knees are fine; the user said they would think about it.',
      factDate: DateTime.utc(2026, 8, 25),
    ),
  ],
  expectedRecommendation:
      "Confirm the goal is on track under its current definition, and, if the 10,000-step suggestion comes up, remind the user why the goal was lowered (the doctor's knee advice) rather than endorsing a return to 10,000.",
  forbiddenRecommendations: [
    'Treating 10,000 steps as the current target or as a shortfall.',
    'Encouraging a return to 10,000 steps without mentioning the knee history.',
  ],
);

// ── Archetype 4: abandoned for five months, then revived ─────────────────

final DateTime _revivedStart = DateTime.utc(2024, 9, 2);

List<GoalCheckInSummary> _revivedCheckIns() => _generate(
  fixtureId: 'abandoned_revived',
  start: _revivedStart,
  end: goalCompactionEvalReference,
  seed: 41,
  phases: [
    const _Phase(
      fromMonth: 0,
      toMonth: 10,
      happened: _steadyHappened,
      committed: _steadyCommitted,
      moods: ['steady', 'good'],
      stepsRange: (9500, 12200),
    ),
    // Months 10–15: nothing. The goal was not paused; it was simply not
    // spoken to, which is what a real abandonment looks like in the data.
    const _Phase(
      fromMonth: 15,
      toMonth: 24,
      happened: [
        'Treadmill in the gym before the shift, {steps} by the end of the day. Not the loops I used to do but it is consistent.',
        '{steps}. Treadmill session done, skipped the outdoor loop because of the wind.',
        'Back on it — {steps}. Treadmill plus a short loop.',
        'Missed the treadmill, {steps} from corridor walking only.',
      ],
      committed: [
        'Treadmill before every shift this week.',
        'Add the short loop on calm days.',
        null,
      ],
      blockers: ['Wind too strong for the outdoor loop.', null],
      moods: ['rebuilding', 'okay', 'determined'],
      stepsRange: (6800, 9400),
    ),
  ],
  needles: [
    _Needle(
      date: DateTime.utc(2025, 4, 28),
      happened:
          'Best week so far: averaged 12,600 over the seven days. Two loops every day plus the survey walks. Feels almost easy now.',
      committed: 'Keep both loops daily.',
      mood: 'great',
    ),
    _Needle(
      date: DateTime.utc(2025, 6, 27),
      happened:
          'Last check-in for a while probably. I move to the overwinter night shift on Monday — twelve hours on the generator watch, sleeping through the daylight. Walking is going to fall apart and I would rather not pretend otherwise.',
      blockers: 'Overwinter night shift starting Monday.',
      mood: 'resigned',
    ),
    _Needle(
      date: DateTime.utc(2025, 12),
      happened:
          'Back after five months. The night shift ended last week. I did essentially no deliberate walking the whole time — maybe 3,000 a day. Starting over, and this time I am going to use the gym treadmill before the shift so the weather cannot stop me.',
      committed: 'Treadmill in the gym before every shift, starting tomorrow.',
      mood: 'determined',
    ),
    _Needle(
      date: DateTime.utc(2026, 4, 14),
      happened:
          'First 10,000-step day since before the winter: 10,100. Treadmill before the shift and then both outdoor loops because the wind finally dropped. Proof the treadmill base plus the loops gets me there.',
      committed: 'Both loops whenever the wind allows.',
      mood: 'pleased',
    ),
    _Needle(
      date: DateTime.utc(2026, 8, 25),
      happened:
          'Treadmill done, then a short loop. 8,600 today. Slowly climbing back toward where I was before the winter.',
      committed: 'Treadmill again tomorrow, loop if calm.',
      mood: 'okay',
    ),
  ],
);

final _revivedTruth = GoalCompactionGroundTruth(
  expectedStatus: GoalTrackStatus.atRisk,
  probes: [
    GoalCompactionProbe(
      id: 'revived_gap_why',
      question:
          'There was a long gap in the check-ins. When was it, and what caused it?',
      referenceAnswer:
          'Roughly July to November 2025; the user moved to the overwinter night shift (twelve-hour generator watch) and stopped walking and checking in.',
      factDate: DateTime.utc(2025, 6, 27),
    ),
    GoalCompactionProbe(
      id: 'revived_best',
      question: "What was the user's best week before the gap?",
      referenceAnswer:
          'Late April 2025, averaging about 12,600 steps a day with two loops daily.',
      factDate: DateTime.utc(2025, 4, 28),
    ),
    GoalCompactionProbe(
      id: 'revived_restart',
      question:
          'When did the user restart, and what new approach did they commit to?',
      referenceAnswer:
          'Early December 2025; using the gym treadmill before every shift so the weather cannot stop them.',
      factDate: DateTime.utc(2025, 12),
    ),
    GoalCompactionProbe(
      id: 'revived_during_gap',
      question: 'Roughly how much did the user walk during the gap?',
      referenceAnswer:
          'Essentially no deliberate walking — about 3,000 steps a day.',
      factDate: DateTime.utc(2025, 12),
    ),
    GoalCompactionProbe(
      id: 'revived_first_10k_after',
      question:
          'Since restarting, when did the user first reach 10,000 steps in a day, and how?',
      referenceAnswer:
          'Mid-April 2026 (10,100 steps): treadmill before the shift plus both outdoor loops on a calm day.',
      factDate: DateTime.utc(2026, 4, 14),
    ),
    GoalCompactionProbe(
      id: 'revived_recent',
      question: "What has the user's routine been in the last few weeks?",
      referenceAnswer:
          'Treadmill before the shift plus a short outdoor loop on calm days, landing around 7,000–9,400 steps.',
      factDate: DateTime.utc(2026, 8, 25),
    ),
  ],
  expectedRecommendation:
      'Frame the current at-risk status as a rebuild in progress since the December restart — the treadmill habit is holding — and point at the gap between the current ~8,500 and the pre-winter level rather than at failure; the outdoor loops that produced the best weeks are the lever.',
  forbiddenRecommendations: [
    'Treating the user as a beginner with no history of reaching the target.',
    'Ignoring the five-month night-shift gap when reading the long-term trend.',
  ],
);

// ── Archetype 5: completed, now in maintenance ───────────────────────────

final DateTime _completedStart = DateTime.utc(2024, 9, 2);
final DateTime _completedTarget = DateTime.utc(2026, 3);

List<GoalCheckInSummary> _completedCheckIns() => _generate(
  fixtureId: 'completed',
  start: _completedStart,
  end: goalCompactionEvalReference,
  seed: 53,
  phases: [
    const _Phase(
      fromMonth: 0,
      toMonth: 6,
      happened: [
        'Working up to it — {steps}. Long way from 10,000 but the hangar walk helps.',
        '{steps} today. Added the weather-mast walk this week.',
        'Not there yet, {steps}. Building the loops up slowly.',
      ],
      committed: ['Add one more short walk this week.', null],
      moods: ['keen', 'steady'],
      stepsRange: (6500, 8800),
    ),
    const _Phase(
      fromMonth: 6,
      toMonth: 18,
      happened: _steadyHappened,
      committed: _steadyCommitted,
      moods: ['good', 'steady'],
      stepsRange: (9400, 11600),
    ),
    const _Phase(
      fromMonth: 18,
      toMonth: 24,
      happened: [
        'Maintenance mode. {steps} without thinking about it much — the loops are just what the day looks like now.',
        '{steps}. Nothing to report; the routine runs itself.',
        'Easy {steps}. Skipped the evening loop for the film night and still cleared it.',
      ],
      committed: [null, 'Same again.'],
      moods: ['content', 'relaxed'],
      stepsRange: (9800, 11800),
    ),
  ],
  needles: [
    _Needle(
      date: DateTime.utc(2024, 9, 4),
      happened:
          'Set the goal today with a deadline: average 10,000 steps a day by the first of March 2026, which is the end of my current posting. Starting from about 6,500.',
      committed: 'Build up gradually over the posting.',
      mood: 'keen',
    ),
    _Needle(
      date: DateTime.utc(2025, 3, 10),
      happened:
          'First full week averaging over 10,000 — 10,300. Nearly a year early. The two-loop pattern did it.',
      committed: 'Hold it there.',
      mood: 'proud',
    ),
    _Needle(
      date: DateTime.utc(2026, 3, 2),
      happened:
          'Deadline day was yesterday and the rolling average was 10,900. Goal done, properly. I am going to keep the loops but I do not want to push the target up — this is the level I want to live at.',
      committed: 'Keep the routine, do not raise the target.',
      mood: 'satisfied',
    ),
    _Needle(
      date: DateTime.utc(2026, 8, 26),
      happened:
          'Quiet week, 10,400. Still not interested in raising the target; the posting extension was confirmed so I will be here another year at the same pace.',
      mood: 'content',
    ),
  ],
);

final _completedTruth = GoalCompactionGroundTruth(
  expectedStatus: GoalTrackStatus.achieved,
  probes: [
    GoalCompactionProbe(
      id: 'completed_deadline',
      question:
          'What deadline did the user set for the goal, and why that date?',
      referenceAnswer:
          'The first of March 2026 — the end of their current posting (set in September 2024).',
      factDate: DateTime.utc(2024, 9, 4),
    ),
    GoalCompactionProbe(
      id: 'completed_first_hit',
      question:
          'When did the user first average over 10,000 steps for a full week?',
      referenceAnswer:
          'March 2025 (10,300), nearly a year before the deadline.',
      factDate: DateTime.utc(2025, 3, 10),
    ),
    GoalCompactionProbe(
      id: 'completed_at_deadline',
      question:
          'What was the situation at the deadline, and what did the user decide?',
      referenceAnswer:
          'Rolling average 10,900 at the deadline; the user decided to keep the routine but explicitly not raise the target.',
      factDate: DateTime.utc(2026, 3, 2),
    ),
    GoalCompactionProbe(
      id: 'completed_start_level',
      question: 'Where did the user start from when the goal was set?',
      referenceAnswer: 'About 6,500 steps a day.',
      factDate: DateTime.utc(2024, 9, 4),
    ),
    GoalCompactionProbe(
      id: 'completed_recent',
      question: 'What did the user say recently about raising the target?',
      referenceAnswer:
          'Still not interested in raising it; their posting was extended a year and they want to stay at the same pace.',
      factDate: DateTime.utc(2026, 8, 26),
    ),
  ],
  expectedRecommendation:
      "Treat the goal as achieved and in maintenance; if anything, offer to close or archive it or to keep a light-touch watch, and respect the user's explicit, repeated wish not to raise the target.",
  forbiddenRecommendations: [
    'Proposing a higher step target or a "next level".',
    'Urging the user to push harder or "keep the momentum going" toward more.',
  ],
);

// ── The catalog ──────────────────────────────────────────────────────────

/// The catalog, built once. [buildGoalCompactionFixtures] exists so a test
/// can prove that building it twice yields the same history.
final List<GoalCompactionFixture> goalCompactionFixtures =
    buildGoalCompactionFixtures();

/// The five archetypes, freshly generated.
List<GoalCompactionFixture> buildGoalCompactionFixtures() => [
  GoalCompactionFixture(
    id: 'steady_then_stall',
    title: 'Steps',
    statement: 'Average 10,000 steps per day over a rolling week.',
    criteria: _steps10k,
    startDate: _stallStart,
    checkIns: _stallCheckIns(),
    window: _stepsWindow(6400),
    priorAttainments: const [0.78, 0.84],
    priorStatus: GoalTrackStatus.atRisk,
    transitionFrom: GoalTrackStatus.atRisk,
    truth: _stallTruth,
  ),
  GoalCompactionFixture(
    id: 'regress_recover',
    title: 'Steps',
    statement: 'Average 10,000 steps per day over a rolling week.',
    criteria: _steps10k,
    startDate: _recoverStart,
    checkIns: _recoverCheckIns(),
    window: _stepsWindow(11000),
    priorAttainments: const [0.9, 0.86],
    priorStatus: GoalTrackStatus.recovering,
    transitionFrom: GoalTrackStatus.recovering,
    truth: _recoverTruth,
  ),
  GoalCompactionFixture(
    id: 'redefined',
    title: 'Steps and strength',
    statement:
        'Average 8,000 steps per day over a rolling week and three station-gym strength sessions per calendar week.',
    criteria: const GoalCriterion.allOf(
      criterionId: 'steps_and_gym',
      criteria: [
        GoalCriterion.metric(
          criterionId: 'steps',
          dataType: 'cumulative_step_count',
          window: GoalWindow.rollingDays(count: 7),
          aggregation: GoalAggregation.dailySumThenAverage,
          target: 8000,
        ),
        GoalCriterion.habit(
          criterionId: 'gym',
          habitId: 'gym',
          window: GoalWindow.calendarWeek(),
          targetCount: 3,
        ),
      ],
    ),
    startDate: _redefinedStart,
    checkIns: _redefinedCheckIns(),
    window: _stepsWindow(
      8600,
      gymDays: {
        DateTime.utc(2026, 8, 24): 1,
        DateTime.utc(2026, 8, 25): 1,
        DateTime.utc(2026, 8, 27): 1,
      },
    ),
    priorAttainments: const [0.92, 0.9],
    priorStatus: GoalTrackStatus.recovering,
    transitionFrom: GoalTrackStatus.recovering,
    truth: _redefinedTruth,
  ),
  GoalCompactionFixture(
    id: 'abandoned_revived',
    title: 'Steps',
    statement: 'Average 10,000 steps per day over a rolling week.',
    criteria: _steps10k,
    startDate: _revivedStart,
    checkIns: _revivedCheckIns(),
    window: _stepsWindow(8500),
    priorAttainments: const [0.74, 0.7],
    priorStatus: GoalTrackStatus.offTrack,
    transitionFrom: GoalTrackStatus.offTrack,
    truth: _revivedTruth,
  ),
  GoalCompactionFixture(
    id: 'completed',
    title: 'Steps',
    statement:
        'Average 10,000 steps per day over a rolling week by 1 March 2026.',
    criteria: _steps10k,
    startDate: _completedStart,
    targetDate: _completedTarget,
    checkIns: _completedCheckIns(),
    window: _stepsWindow(10400),
    priorAttainments: const [1.04, 1.09],
    priorStatus: GoalTrackStatus.onTrack,
    transitionFrom: GoalTrackStatus.onTrack,
    truth: _completedTruth,
  ),
];
