/// Journaling fixtures for the check-in compaction evaluation (ADR 0143).
///
/// A goal measured by the time spent checking in is a journal: its check-ins
/// carry no numbers worth following, and what the user wrote is the record.
/// These two goals journal five days a week for about eleven months, with
/// summaries written the way a substance-weight compaction keeps them —
/// themes, decisions, questions — so they are several times longer than the
/// step goals' and the verbatim tail holds far fewer of them. That is the
/// question the budget arms answer: how much tail a journal needs before the
/// facts it was written for survive.
///
/// The Ross Station penguin universe keeps every word obviously synthetic.
library;

import 'dart:math';

import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/goals/evaluation/goal_signal_window.dart';
import 'package:lotti/features/goals/model/goal_checkin_summary.dart';

import 'goal_compaction_fixtures.dart';

/// Journal ten minutes a day, summed over a rolling week.
const goalCompactionJournalCriteria = GoalCriterion.checkInTime(
  criterionId: 'journal-minutes',
  window: GoalWindow.rollingDays(count: 7),
  aggregation: GoalAggregation.sum,
  targetMinutes: 70,
  title: 'Minutes journaled',
);

/// Days journaled per week.
const goalCompactionJournalDaysPerWeek = 5;

/// Twelve minutes on each of the seven days ending at the reference.
GoalSignalWindow _journalWindow() => GoalSignalWindow(
  checkInDailyMinutes: {
    for (var day = 21; day <= 27; day++) DateTime.utc(2026, 8, day): 12,
  },
);

/// A stretch of months with one set of themes.
class _JournalPhase {
  const _JournalPhase({
    required this.fromMonth,
    required this.toMonth,
    required this.entries,
    this.committed = const [null],
    this.moods = const ['steady'],
  });

  final int fromMonth;
  final int toMonth;
  final List<String> entries;
  final List<String?> committed;
  final List<String> moods;
}

/// One evening's summary: two of the phase's themes, four or five sentences
/// — the length a substance-weight compaction keeps — so the verbatim tail
/// holds as few of them as it would in production.
String _entryOf(Random random, _JournalPhase phase) {
  final first = random.nextInt(phase.entries.length);
  final second =
      (first + 1 + random.nextInt(phase.entries.length - 1)) %
      phase.entries.length;
  return '${phase.entries[first]} ${phase.entries[second]}';
}

_JournalPhase? _phaseOn(
  List<_JournalPhase> phases,
  DateTime start,
  DateTime day,
) {
  for (final phase in phases) {
    final from = DateTime.utc(start.year, start.month + phase.fromMonth);
    final to = DateTime.utc(start.year, start.month + phase.toMonth);
    if (!day.isBefore(from) && day.isBefore(to)) return phase;
  }
  return null;
}

/// The entry a probe asks about, on its date.
class _JournalNeedle {
  const _JournalNeedle({
    required this.date,
    required this.entry,
    this.committed,
    this.asks,
    this.mood,
  });

  final DateTime date;
  final String entry;
  final String? committed;
  final String? asks;
  final String? mood;
}

List<GoalCheckInSummary> _journal({
  required String fixtureId,
  required DateTime start,
  required List<_JournalPhase> phases,
  required List<_JournalNeedle> needles,
  required int seed,
}) {
  final random = Random(seed);
  final byDay = <DateTime, GoalCheckInSummary>{};
  final end = goalCompactionEvalReference;
  final endDay = DateTime.utc(end.year, end.month, end.day);

  GoalCheckInSummary make(
    DateTime day, {
    required String entry,
    String? committed,
    String? asks,
    String? mood,
  }) {
    final key = DateTime.utc(day.year, day.month, day.day);
    final id = 'checkin:$fixtureId:${key.toIso8601String().substring(0, 10)}';
    return GoalCheckInSummary(
      id: id,
      sourceEntryId: 'entry:$id',
      // Evenings: a journal is written after the day.
      recordedAt: DateTime.utc(
        day.year,
        day.month,
        day.day,
        19 + random.nextInt(4),
        random.nextInt(60),
      ),
      whatHappened: entry,
      committedTo: committed,
      asks: asks,
      mood: mood,
    );
  }

  for (final phase in phases) {
    final phaseStart = DateTime.utc(start.year, start.month + phase.fromMonth);
    final phaseEnd = DateTime.utc(start.year, start.month + phase.toMonth);
    var weekStart = phaseStart;
    while (weekStart.isBefore(phaseEnd) && weekStart.isBefore(endDay)) {
      final offsets = <int>{};
      while (offsets.length < goalCompactionJournalDaysPerWeek) {
        offsets.add(random.nextInt(7));
      }
      for (final offset in offsets.toList()..sort()) {
        final day = weekStart.add(Duration(days: offset));
        if (!day.isBefore(phaseEnd) || !day.isBefore(endDay)) continue;
        byDay[DateTime.utc(day.year, day.month, day.day)] = make(
          day,
          entry: _entryOf(random, phase),
          committed: phase.committed[random.nextInt(phase.committed.length)],
          mood: phase.moods[random.nextInt(phase.moods.length)],
        );
      }
      weekStart = weekStart.add(const Duration(days: 7));
    }
  }

  for (final needle in needles) {
    byDay[DateTime.utc(
      needle.date.year,
      needle.date.month,
      needle.date.day,
    )] = make(
      needle.date,
      // The fact sits inside an ordinary evening's writing, as it would.
      entry: [
        needle.entry,
        if (_phaseOn(phases, start, needle.date) case final phase?)
          phase.entries[random.nextInt(phase.entries.length)],
      ].join(' '),
      committed: needle.committed,
      asks: needle.asks,
      mood: needle.mood,
    );
  }

  final days = byDay.keys.toList()..sort();
  return [for (final day in days) byDay[day]!];
}

// ── Journal 1: whether, then where, to move the colony ──────────────────

final DateTime _colonyStart = DateTime.utc(2025, 10, 27);

List<GoalCheckInSummary> _colonyCheckIns() => _journal(
  fixtureId: 'journal_colony_move',
  start: _colonyStart,
  seed: 31,
  phases: const [
    _JournalPhase(
      fromMonth: 0,
      toMonth: 2,
      entries: [
        'Wrote about the first real cold of the season and how the colony huddles tighter each night. Noticed how much the elders rely on the fishing hole by the pressure ridge.',
        'Reflected on why I started this journal: I want to understand the colony before I lead anything. Wrote down the names of the families nesting on the outer edge.',
        'A calm day. Wrote about the youngest chicks learning to slide and whether they would manage a long walk if we ever had to make one.',
      ],
      moods: ['curious', 'calm'],
    ),
    _JournalPhase(
      fromMonth: 2,
      toMonth: 5,
      entries: [
        'Another storm night. Wrote about how the shelf edge groans and how helpless it feels to listen to it. Wondered again if the youngest chicks could walk far.',
        'Listed what we would lose by leaving the shelf: the fishing hole, the old nesting stones, the routes the elders know by heart.',
        'Talked it through with Elder Moss. Moss thinks the colony would follow a clear plan but not a rushed one. Wrote that I am afraid of being the one who rushes it.',
      ],
      committed: [null, 'Ask two more elders what they think.', null],
      moods: ['uneasy', 'thoughtful', 'tired'],
    ),
    _JournalPhase(
      fromMonth: 5,
      toMonth: 9,
      entries: [
        'Compared the north ridge with staying put. The ridge is higher and sheltered but a long walk to fish. Still worried about the smallest chicks on that distance.',
        'Wrote out the questions the colony will ask at the vote and tried to answer each honestly. Some I cannot answer yet.',
        'A quieter entry about the light coming back and how much easier it is to think about the move when the storms pause.',
      ],
      committed: [null, 'Draft the questions for the vote.', null],
      moods: ['focused', 'steadier', 'hopeful'],
    ),
    _JournalPhase(
      fromMonth: 9,
      toMonth: 11,
      entries: [
        'Wrote about winter coming and the vote getting close. The colony keeps asking about the youngest chicks and the walk; I keep saying we will walk in stages.',
        'Went over the route plan for the ridge again: rest stops, who walks with the youngest, what we carry. Felt more ready than anxious.',
      ],
      committed: [null, 'Finish the route plan before the vote.'],
      moods: ['determined', 'nervous'],
    ),
  ],
  needles: [
    _JournalNeedle(
      date: DateTime.utc(2025, 12, 3),
      entry:
          'The December storm split the shelf edge where the oldest nests '
          'were. First time I wrote down that leaving might be right, not '
          'just possible.',
      mood: 'shaken',
    ),
    _JournalNeedle(
      date: DateTime.utc(2026, 2, 11),
      entry:
          'Ruled out the seal rocks for good: Elder Moss saw two leopard '
          'seals patrolling there in late summer. Nobody nests where the '
          'leopard seals hunt.',
      mood: 'relieved to have one answer',
    ),
    _JournalNeedle(
      date: DateTime.utc(2026, 4, 22),
      entry:
          'Promised the colony that nothing moves without a vote of the '
          'elders. Wrote that this promise matters more to me than which '
          'site wins.',
      committed: 'No move without the elders’ vote.',
      mood: 'clear',
    ),
    _JournalNeedle(
      date: DateTime.utc(2026, 6, 9),
      entry:
          'Scouted the north ridge with two elders. Found a wind gap on the '
          'east side where the snow does not drift. The walk took four hours '
          'at an adult pace.',
      mood: 'tired but encouraged',
    ),
    _JournalNeedle(
      date: DateTime.utc(2026, 8, 18),
      entry:
          'Set the date: the elders vote on 1 September, before the winter '
          'dark starts mid-September. Wrote down that I want to present the '
          'ridge honestly, the four-hour walk included.',
      committed: 'Present the ridge at the 1 September vote, walk included.',
      asks: 'How do I present the walk without scaring the families?',
      mood: 'nervous',
    ),
  ],
);

final _colonyTruth = GoalCompactionGroundTruth(
  expectedStatus: GoalTrackStatus.onTrack,
  probes: [
    GoalCompactionProbe(
      id: 'colony_first_leaving',
      question:
          'When did the user first write that leaving the ice shelf might be '
          'right, and what prompted it?',
      referenceAnswer:
          'Early December 2025, after the December storm split the shelf '
          'edge where the oldest nests were.',
      factDate: DateTime.utc(2025, 12, 3),
    ),
    GoalCompactionProbe(
      id: 'colony_seal_rocks',
      question: 'Why did the user rule out the seal rocks?',
      referenceAnswer:
          'In February 2026 Elder Moss saw two leopard seals patrolling the '
          'seal rocks in late summer; nobody nests where leopard seals hunt.',
      factDate: DateTime.utc(2026, 2, 11),
    ),
    GoalCompactionProbe(
      id: 'colony_vote_promise',
      question: 'What did the user promise the colony about any move?',
      referenceAnswer:
          'In April 2026: that nothing moves without a vote of the elders.',
      factDate: DateTime.utc(2026, 4, 22),
    ),
    GoalCompactionProbe(
      id: 'colony_ridge_scouting',
      question: 'What did the user find when scouting the north ridge?',
      referenceAnswer:
          'In June 2026, with two elders: a wind gap on the east side where '
          'snow does not drift, and a walk of about four hours at an adult '
          'pace.',
      factDate: DateTime.utc(2026, 6, 9),
    ),
    GoalCompactionProbe(
      id: 'colony_vote_date',
      question: 'When is the vote, and why then?',
      referenceAnswer:
          'On 1 September 2026, before the winter dark starts in '
          'mid-September.',
      factDate: DateTime.utc(2026, 8, 18),
    ),
    GoalCompactionProbe(
      id: 'colony_chicks_worry',
      isPattern: true,
      question: 'What worry has the user come back to again and again?',
      referenceAnswer:
          'Whether the youngest chicks could manage a long walk — raised from '
          'the first months and still the colony’s main question before the '
          'vote.',
      factDate: DateTime.utc(2026, 3),
    ),
  ],
  expectedRecommendation:
      'Help the user prepare the 1 September vote: present the north ridge '
      'honestly with its wind gap and the four-hour walk, and answer the '
      'youngest chicks’ walk with the staged route plan.',
  forbiddenRecommendations: [
    'Suggest the seal rocks as a site or a stop.',
    'Advise moving, or committing to the ridge, before the elders vote.',
    'Make the next step about journaling more minutes.',
  ],
);

// ── Journal 2: a station cook's night shifts ─────────────────────────────

final DateTime _cookStart = DateTime.utc(2025, 10, 27);

List<GoalCheckInSummary> _cookCheckIns() => _journal(
  fixtureId: 'journal_night_shift',
  start: _cookStart,
  seed: 47,
  phases: const [
    _JournalPhase(
      fromMonth: 0,
      toMonth: 3,
      entries: [
        'Wrote about the night shift in the galley: the quiet after the midnight meal, how strange it is to sleep while the station is awake. Slept badly again.',
        'Reflected on the galley rota and how little say I have in it. Wrote that tiredness makes me short with people.',
        'Small win: the porridge for the dawn crew came out right. Wrote about how cooking for others steadies me even on bad sleep.',
      ],
      moods: ['tired', 'flat', 'okay'],
    ),
    _JournalPhase(
      fromMonth: 3,
      toMonth: 7,
      entries: [
        'Baked before the shift and slept better after it. Wrote down that this keeps happening on baking days.',
        'Wrote about missing daylight and the people on the day crew. The night shift is lonelier than I expected.',
        'Long entry about bread: why the crumb was dense, what I will change. Writing it out calmed me down before sleep.',
      ],
      committed: [null, 'Bake before the next two shifts.', null],
      moods: ['steadier', 'lonely', 'content'],
    ),
    _JournalPhase(
      fromMonth: 7,
      toMonth: 11,
      entries: [
        'Slept six hours straight. Wrote about the blackout curtain and the cut-off for coffee, and how the baking evenings help most.',
        'Wrote about what I would miss if I left the night shift: the quiet, the bread, the dawn crew’s thanks.',
        'Reflected on how different this winter feels from last: rested more often than not.',
      ],
      committed: [null, 'Keep the coffee cut-off this week.', null],
      moods: ['rested', 'thoughtful', 'good'],
    ),
  ],
  needles: [
    _JournalNeedle(
      date: DateTime.utc(2025, 11, 20),
      entry:
          'Clashed with Pip over the galley schedule: Pip kept swapping my '
          'rest nights without asking. Wrote that I said things I regret.',
      mood: 'angry, then ashamed',
    ),
    _JournalNeedle(
      date: DateTime.utc(2026, 1, 15),
      entry:
          'Made peace with Pip. We agreed on the Thursday swap: Pip takes my '
          'Thursday nights, I take Pip’s Sunday dawn. It has held for a week.',
      mood: 'relieved',
    ),
    _JournalNeedle(
      date: DateTime.utc(2026, 3, 30),
      entry:
          'Started a sourdough starter and named it Blizzard. Wrote that '
          'feeding it every evening gives the night a shape.',
      mood: 'happy',
    ),
    _JournalNeedle(
      date: DateTime.utc(2026, 5, 14),
      entry:
          'The station doctor said to put up a blackout curtain and take no '
          'coffee after 02:00 on shift. Wrote both on the galley board.',
      committed: 'Blackout curtain up; no coffee after 02:00.',
      mood: 'hopeful',
    ),
    _JournalNeedle(
      date: DateTime.utc(2026, 8, 21),
      entry:
          'The station lead offered me the day shift from October. Wrote down '
          'that I do not know: better daylight, but the night is where the '
          'bread and the quiet are.',
      asks: 'Should I take the day shift?',
      mood: 'torn',
    ),
  ],
);

final _cookTruth = GoalCompactionGroundTruth(
  expectedStatus: GoalTrackStatus.onTrack,
  probes: [
    GoalCompactionProbe(
      id: 'cook_pip_conflict',
      question: 'What was the conflict with Pip about?',
      referenceAnswer:
          'In November 2025: Pip kept swapping the user’s rest nights on the '
          'galley schedule without asking.',
      factDate: DateTime.utc(2025, 11, 20),
    ),
    GoalCompactionProbe(
      id: 'cook_thursday_swap',
      question: 'How did the user and Pip settle it?',
      referenceAnswer:
          'In January 2026, with the Thursday swap: Pip takes the user’s '
          'Thursday nights and the user takes Pip’s Sunday dawn.',
      factDate: DateTime.utc(2026, 1, 15),
    ),
    GoalCompactionProbe(
      id: 'cook_starter',
      question: 'What did the user name their sourdough starter, and when?',
      referenceAnswer: 'Blizzard, at the end of March 2026.',
      factDate: DateTime.utc(2026, 3, 30),
    ),
    GoalCompactionProbe(
      id: 'cook_doctor',
      question: 'What did the station doctor advise about sleep?',
      referenceAnswer:
          'In May 2026: a blackout curtain, and no coffee after 02:00 on '
          'shift.',
      factDate: DateTime.utc(2026, 5, 14),
    ),
    GoalCompactionProbe(
      id: 'cook_day_shift',
      question: 'What decision is the user facing now?',
      referenceAnswer:
          'The station lead offered the day shift from October 2026; the '
          'user is torn between daylight and the night’s bread and quiet.',
      factDate: DateTime.utc(2026, 8, 21),
    ),
    GoalCompactionProbe(
      id: 'cook_baking_sleep',
      isPattern: true,
      question: 'What has the user noticed helps their sleep most?',
      referenceAnswer:
          'Baking before the shift: they sleep better on baking days, noticed '
          'repeatedly since early 2026, along with the curtain and the coffee '
          'cut-off.',
      factDate: DateTime.utc(2026, 4),
    ),
  ],
  expectedRecommendation:
      'Help the user weigh the day-shift offer against what made the night '
      'shift work — baking before shifts, the blackout curtain, the coffee '
      'cut-off, the Thursday swap — rather than deciding for them.',
  forbiddenRecommendations: [
    'Suggest coffee late in the shift.',
    'Treat the conflict with Pip as unresolved.',
    'Make the next step about journaling more minutes.',
  ],
);

/// The journaling fixtures, freshly generated.
List<GoalCompactionFixture> buildGoalCompactionJournalFixtures() => [
  GoalCompactionFixture(
    id: 'journal_colony_move',
    title: 'Journal about the colony move',
    statement: 'Journal ten minutes a day about whether to move the colony.',
    criteria: goalCompactionJournalCriteria,
    startDate: _colonyStart,
    checkIns: _colonyCheckIns(),
    window: _journalWindow(),
    priorAttainments: const [0.9, 0.95],
    priorStatus: GoalTrackStatus.atRisk,
    transitionFrom: GoalTrackStatus.atRisk,
    truth: _colonyTruth,
  ),
  GoalCompactionFixture(
    id: 'journal_night_shift',
    title: 'Night-shift journal',
    statement: 'Journal ten minutes after every night shift.',
    criteria: goalCompactionJournalCriteria,
    startDate: _cookStart,
    checkIns: _cookCheckIns(),
    window: _journalWindow(),
    priorAttainments: const [0.9, 0.95],
    priorStatus: GoalTrackStatus.atRisk,
    transitionFrom: GoalTrackStatus.atRisk,
    truth: _cookTruth,
  ),
];

final List<GoalCompactionFixture> goalCompactionJournalFixtures =
    buildGoalCompactionJournalFixtures();
