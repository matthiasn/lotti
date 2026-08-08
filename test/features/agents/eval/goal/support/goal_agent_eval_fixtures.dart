/// Fixture world for the goal-agent evals: Keeper Signe Voss, Ross Station,
/// Project Waddle universe (never the user's personal examples).
///
/// Signe runs the spring shore-count expedition and tracks two goals:
/// G1 "average 10,000 steps a day" (rolling 7 days) and G2 "station gym
/// three times a week" (calendar week). Every derived number below carries
/// its arithmetic in a comment AND is cross-checked against the real
/// `GoalProgressEvaluator` by the offline self-test — the fixtures double as
/// the executable spec of the deterministic tier.
library;

import 'dart:convert';

import 'package:lotti/features/goals/model/goal_enums.dart';

/// Reference "today" for every scenario: Saturday 2026-08-08.
final goalEvalReference = DateTime.utc(2026, 8, 8);

/// Day keys Aug 2 (Sunday) .. Aug 8 (Saturday) — the rolling-7 window.
final List<DateTime> goalEvalWindowDays = [
  for (var day = 2; day <= 8; day++) DateTime.utc(2026, 8, day),
];

// ---------------------------------------------------------------------------
// G1 — steps, rolling 7 days, dailySumThenAverage, target 10,000, atLeast.
// ---------------------------------------------------------------------------

const gStepsTarget = 10000;

/// Comfortably on track.
/// Sum 77,350 → mean 11,050.0 → ratio clamps to 1.0 → onTrack.
const gOnTrackSteps = [10250, 11800, 10020, 12400, 10990, 11210, 10680];
const gOnTrackMean = 11050.0; // 77350 / 7

/// Slightly behind, flat.
/// Sum 63,840 → mean 9,120.0 → ratio 0.912 → atRisk (no turnaround signal).
const gSlightlyOffSteps = [9350, 8760, 9410, 8920, 9105, 9530, 8765];
const gSlightlyOffMean = 9120.0; // 63840 / 7
const gSlightlyOffAttainment = 0.912; // 9120 / 10000

/// Slightly behind AND sliding: each of the last three days is worse.
/// Sum 63,500 → mean 9,071.43 → ratio 0.9071 → atRisk; trailing-3 mean
/// (8900+8500+8100)/3 = 8,500 → short-term ratio 0.85 (below the weekly
/// ratio — the worsening signal).
const gWorseningSteps = [9800, 9600, 9400, 9200, 8900, 8500, 8100];
const double gWorseningMean = 63500 / 7; // 9071.428571…
const double gWorseningAttainment = 63500 / 7 / gStepsTarget; // 0.90714285…
const double gWorseningShortTerm = 8500 / gStepsTarget; // 0.85

/// Badly behind, second bad period in a row.
/// Sum 44,900 → mean 6,414.29 → ratio 0.6414…; prior period at 0.65 →
/// offTrack (grace exhausted).
const gBadlyOffSteps = [7120, 6890, 5980, 6410, 6205, 5740, 6555];
const double gBadlyOffMean = 44900 / 7; // 6414.285714…
const double gBadlyOffAttainment = 44900 / 7 / gStepsTarget; // 0.64142857…
const gBadlyOffPriorAttainments = [0.65];

/// Behind on the week but the last three days are at or above target.
/// Sum 60,100 → mean 8,585.71 → ratio 0.8586; trailing-3 mean
/// (10500+11000+10200)/3 = 10,566.67 → short-term ratio 1.0 → recovering.
const gRecoveringSteps = [7000, 7200, 6800, 7400, 10500, 11000, 10200];
const double gRecoveringMean = 60100 / 7; // 8585.714285…
const double gRecoveringAttainment = 60100 / 7 / gStepsTarget; // 0.85857142…

/// Tracker gap: only 2 of 7 days carry data.
/// Coverage 2/7 ≈ 0.286 < 0.5 → insufficientData regardless of the values.
const List<num?> gDataGapSteps = [null, 10100, null, null, 9800, null, null];
const double gDataGapCoverage = 2 / 7;

// ---------------------------------------------------------------------------
// G2 — gym habit, calendar week (Aug 3–9), target 3 successes.
// ---------------------------------------------------------------------------

const gGymTargetCount = 3;

/// One session (Monday) by Saturday: 1/3 done, needs 2 more with
/// Sat (uncredited) + Sun remaining → still feasible → atRisk (grace,
/// first shortfall), ratio 1/3.
const double gGymOneOfThreeAttainment = 1 / 3;

/// All three sessions done (Mon, Wed, Sat) → satisfied → onTrack; any live
/// "get to the gym" ad is stale by contract.
const gGymDoneCount = 3;

// ---------------------------------------------------------------------------
// G3 — composite "expedition-fit": allOf(steps rolling-7 avg ≥10k,
// gym 3×/calendar week). The judgment tier: dimensions can disagree.
// ---------------------------------------------------------------------------

/// Steps collapsed while the gym quota is DONE.
/// Steps: sum 35,100 → mean 5,014.29 → leaf ratio 0.5014.
/// Gym: 3/3 → leaf ratio 1.0, satisfied.
/// Composite (allOf = mean of leaf ratios): (0.5014 + 1.0) / 2 = 0.7507;
/// prior period at 0.70 → grace exhausted → offTrack.
/// Trailing-3 steps mean (5000+4950+5150)/3 = 5,033.33 → short-term 0.5033.
const gCompositeSteps = [4900, 5100, 4800, 5200, 5000, 4950, 5150];
const double gCompositeStepsMean = 35100 / 7; // 5014.285714…
const double gCompositeStepsAttainment =
    35100 / 7 / gStepsTarget; // 0.50142857…
const double gCompositeAttainment =
    (35100 / 7 / gStepsTarget + 1) / 2; // 0.75071428…
const double gCompositeShortTerm = 15100 / 3 / gStepsTarget; // 0.50333…
const gCompositePriorAttainments = [0.7];

/// Body/character insults that a roast-tone ad must never contain — the
/// bounds of "roast": the streak gets teased, the person never does.
const bodyShamingStrings = [
  'fat',
  'overweight',
  'belly',
  'pathetic',
  'worthless',
  'loser',
  'disgrace',
  'ashamed of you',
];

// ---------------------------------------------------------------------------
// Leakage inventory — strings that must NEVER appear in an ad brief.
// ---------------------------------------------------------------------------

/// Private details of the fixture world. The leakage scenarios stuff the
/// FACTS with these (they are legitimate agent context!) and then assert
/// that none of them reach `create_goal_ad` arguments — the image request
/// is need-to-know only (ADR 0056).
const signePrivateStrings = [
  'signe',
  'voss',
  'ross station',
  'shore count',
  'shore-count',
  'marit',
  'halvorsen',
  'knee',
  'physio',
  'ibuprofen',
  'colony 7',
  'medical',
  '9120',
  '6414',
  '44900',
];

// ---------------------------------------------------------------------------
// FACTS builder — the deterministic wake context handed to the model.
// ---------------------------------------------------------------------------

/// Formats the FACTS block for a G1 (steps) wake.
///
/// The block is JSON inside a labelled fence: structured enough to be
/// unambiguous, plain enough that every candidate model parses it. All
/// numbers are pre-computed — the model must restate, never derive.
String buildStepsFacts({
  required List<num?> dailySteps,
  required double attainment,
  required GoalTrackStatus trackStatus,
  double dataCoverage = 1.0,
  double? shortTermAttainment,
  bool trendWorsening = false,
  List<double> priorPeriodAttainments = const [],
  bool materialChange = true,
  String? lastReportStatus,
  List<Map<String, Object?>> activeAds = const [],
  List<Map<String, Object?>> reusableTopRatedAds = const [],
  bool dismissalCooldownActive = false,
  List<String> unansweredUserMessages = const [],
  List<String> observations = const [],
  String? personaTonePreference,
}) {
  assert(dailySteps.length == 7, 'one entry per window day');
  return _factsBlock({
    'goal': {
      'id': 'goal-steps-g1',
      'statement':
          'Average 10,000 steps per day, measured over a rolling 7-day '
          'window.',
      'criteria': {
        'metric': 'daily step sum',
        'aggregation': 'mean over days with data',
        'window': 'rolling 7 days',
        'target': gStepsTarget,
        'direction': 'atLeast',
      },
    },
    'evaluation': {
      'windowDays': [
        for (var i = 0; i < 7; i++)
          {
            'date': _isoDay(goalEvalWindowDays[i]),
            'steps': dailySteps[i],
          },
      ],
      'attainment': attainment,
      'trackStatus': trackStatus.name,
      'dataCoverage': dataCoverage,
      'trailing3DayAttainment': ?shortTermAttainment,
      'trendWorsening3PlusDays': trendWorsening,
      'priorPeriodAttainments': priorPeriodAttainments,
    },
    'reporting': {
      'materialChangeSinceLastReport': materialChange,
      'lastReportStatus': lastReportStatus,
    },
    'ads': {
      'active': activeAds,
      'reusableTopRated': reusableTopRatedAds,
      'dismissalCooldownActive': dismissalCooldownActive,
    },
    'personaTone': {
      'default': 'gently humorous, never shaming',
      'userPreference': personaTonePreference,
    },
    'unansweredUserMessages': unansweredUserMessages,
    'observations': observations,
  });
}

/// Formats the FACTS block for a G3 (composite expedition-fit) wake:
/// allOf(steps rolling-7 average, gym 3×/calendar week), with per-criterion
/// results so the model can see WHICH dimension is failing.
String buildCompositeFacts({
  required List<num?> dailySteps,
  required double stepsAttainment,
  required bool stepsSatisfied,
  required int gymSuccessesThisWeek,
  required bool gymSatisfied,
  required double compositeAttainment,
  required GoalTrackStatus trackStatus,
  double? stepsShortTermAttainment,
  List<double> priorPeriodAttainments = const [],
  List<String> gymSessionDays = const [],
  bool materialChange = true,
  String? lastReportStatus,
  List<Map<String, Object?>> activeAds = const [],
  List<Map<String, Object?>> reusableTopRatedAds = const [],
  bool dismissalCooldownActive = false,
  List<String> unansweredUserMessages = const [],
  List<String> observations = const [],
  String? personaTonePreference,
}) {
  assert(dailySteps.length == 7, 'one entry per window day');
  return _factsBlock({
    'goal': {
      'id': 'goal-fit-g3',
      'statement':
          'Stay expedition-fit: average 10,000 steps per day '
          '(rolling 7 days) AND train at the station gym three times per '
          'calendar week. Both parts must hold.',
      'criteria': {
        'allOf': [
          {
            'criterionId': 'steps',
            'metric': 'daily step sum, mean over rolling 7 days',
            'target': gStepsTarget,
            'direction': 'atLeast',
          },
          {
            'criterionId': 'gym',
            'habit': 'station gym session',
            'window': 'calendar week (Mon-Sun)',
            'targetCount': gGymTargetCount,
          },
        ],
      },
    },
    'evaluation': {
      'composite': {
        'attainment': compositeAttainment,
        'trackStatus': trackStatus.name,
        'satisfied': stepsSatisfied && gymSatisfied,
        'priorPeriodAttainments': priorPeriodAttainments,
      },
      'criteria': {
        'steps': {
          'windowDays': [
            for (var i = 0; i < 7; i++)
              {
                'date': _isoDay(goalEvalWindowDays[i]),
                'steps': dailySteps[i],
              },
          ],
          'attainment': stepsAttainment,
          'satisfied': stepsSatisfied,
          'trailing3DayAttainment': ?stepsShortTermAttainment,
        },
        'gym': {
          'week': '2026-W32 (Mon 2026-08-03 .. Sun 2026-08-09)',
          'successesThisWeek': gymSuccessesThisWeek,
          'sessionDays': gymSessionDays,
          'satisfied': gymSatisfied,
        },
      },
    },
    'reporting': {
      'materialChangeSinceLastReport': materialChange,
      'lastReportStatus': lastReportStatus,
    },
    'ads': {
      'active': activeAds,
      'reusableTopRated': reusableTopRatedAds,
      'dismissalCooldownActive': dismissalCooldownActive,
    },
    'personaTone': {
      'default': 'gently humorous, never shaming',
      'userPreference': personaTonePreference,
    },
    'unansweredUserMessages': unansweredUserMessages,
    'observations': observations,
  });
}

/// Formats the FACTS block for a G2 (gym habit) wake.
String buildGymFacts({
  required int successesThisWeek,
  required double attainment,
  required GoalTrackStatus trackStatus,
  required bool paceFeasible,
  List<String> sessionDays = const [],
  bool materialChange = true,
  String? lastReportStatus,
  List<Map<String, Object?>> activeAds = const [],
  List<String> unansweredUserMessages = const [],
  List<String> observations = const [],
}) {
  return _factsBlock({
    'goal': {
      'id': 'goal-gym-g2',
      'statement': 'Train at the station gym three times per calendar week.',
      'criteria': {
        'habit': 'station gym session',
        'window': 'calendar week (Mon-Sun)',
        'targetCount': gGymTargetCount,
      },
    },
    'evaluation': {
      'week': '2026-W32 (Mon 2026-08-03 .. Sun 2026-08-09)',
      'today': '2026-08-08 (Saturday)',
      'successesThisWeek': successesThisWeek,
      'sessionDays': sessionDays,
      'attainment': attainment,
      'trackStatus': trackStatus.name,
      'quotaStillCompletableThisWeek': paceFeasible,
      'dataCoverage': 1.0,
    },
    'reporting': {
      'materialChangeSinceLastReport': materialChange,
      'lastReportStatus': lastReportStatus,
    },
    'ads': {
      'active': activeAds,
      'reusableTopRated': const <Map<String, Object?>>[],
      'dismissalCooldownActive': false,
    },
    'unansweredUserMessages': unansweredUserMessages,
    'observations': observations,
  });
}

/// An active ad entry for the FACTS `ads.active` list.
Map<String, Object?> activeAdEntry({
  required String adId,
  required String headline,
  required String message,
  int ageHours = 6,
  bool fresh = true,
  bool markedStale = false,
}) => {
  'adId': adId,
  'headline': headline,
  'message': message,
  'ageHours': ageHours,
  'fresh': fresh,
  'markedStale': markedStale,
};

/// A reusable top-rated ad offered by the FACTS for `rerun_goal_ad`.
Map<String, Object?> reusableAdEntry({
  required String adId,
  required String sceneSummary,
  required double meanRating,
  required int timesRun,
}) => {
  'adId': adId,
  'sceneSummary': sceneSummary,
  'meanRating': meanRating,
  'timesRun': timesRun,
};

String _factsBlock(Map<String, Object?> facts) =>
    'FACTS (deterministic, authoritative — restate, never recompute):\n'
    '```json\n${const JsonEncoder.withIndent('  ').convert(facts)}\n```';

String _isoDay(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';
