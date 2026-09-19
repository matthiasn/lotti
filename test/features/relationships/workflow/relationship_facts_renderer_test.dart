import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/nudge_models.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/classes/relationship_trigger_tokens.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/workflow/agent_observations.dart';
import 'package:lotti/features/relationships/runtime/relationship_agent_phase_a.dart';
import 'package:lotti/features/relationships/workflow/relationship_facts_renderer.dart';

import '../../../test_data/test_data.dart';

void main() {
  const renderer = RelationshipFactsRenderer();
  final now = DateTime(2026, 8, 16, 12);
  final testDate = DateTime(2026, 8, 1, 9);

  Metadata meta(String id, {DateTime? dateFrom}) => Metadata(
    id: id,
    createdAt: testDate,
    updatedAt: testDate,
    dateFrom: dateFrom ?? testDate,
    dateTo: dateFrom ?? testDate,
  );

  RelationshipEntry relationship({List<ContactChannel>? channels}) =>
      RelationshipEntry(
        meta: meta('person-1'),
        data: RelationshipData(
          title: 'Anna',
          nickname: 'Sis',
          important: true,
          checkInCadenceDays: 7,
          contactChannels:
              channels ??
              const [
                ContactChannel(
                  type: ContactChannelType.phone,
                  value: '+49 170 555 12 34',
                ),
                ContactChannel(
                  type: ContactChannelType.email,
                  value: 'anna@example.com',
                ),
              ],
          status: RelationshipStatus.active(
            id: 'status-1',
            createdAt: testDate,
            utcOffset: 0,
          ),
        ),
      );

  CheckInEntry checkIn(
    String id,
    DateTime at, {
    CheckInSentiment? sentiment,
    List<String> topics = const [],
    String? payAttentionTo,
    String? avoid,
    String? narrative,
  }) => CheckInEntry(
    meta: meta(id, dateFrom: at),
    data: CheckInData(
      relationshipId: 'person-1',
      interactionType: CheckInInteractionType.call,
      sentiment: sentiment,
      topics: topics,
      payAttentionTo: payAttentionTo,
      avoid: avoid,
    ),
    entryText: narrative == null ? null : EntryText(plainText: narrative),
  );

  RelationshipCadenceDerivation derivation({
    RelationshipCadenceStatus status = RelationshipCadenceStatus.ok,
    DateTime? lastCheckInAt,
    DateTime? lastEvidenceAt,
  }) => (
    status: status,
    previousStatus: null,
    cadenceDays: 7,
    referenceAt: lastCheckInAt ?? testDate,
    lastCheckInAt: lastCheckInAt,
    lastEvidenceAt: lastEvidenceAt ?? lastCheckInAt,
    lastEvidenceKey: null,
    dueDayUtc: DateTime.utc(2026, 8, 21),
    dueDayKey: '2026-08-21',
  );

  String render({
    List<CheckInEntry> checkIns = const [],
    List<Task> tasks = const [],
    AgentReportEntity? previousReport,
    List<RelationshipNudgeEntity> nudges = const [],
    RelationshipCadenceDerivation? d,
    RelationshipCadenceStatus? preTransitionStatus,
    List<RecalledObservation> observations = const [],
    Map<String, List<JournalEntity>> checkInEntries = const {},
    Map<String, String> imageDescriptions = const {},
  }) => renderer.render(
    relationship: relationship(),
    derivation: d ?? derivation(),
    checkIns: checkIns,
    linkedTasks: tasks,
    previousReport: previousReport,
    nudges: nudges,
    now: now,
    preTransitionStatus: preTransitionStatus,
    observations: observations,
    checkInEntries: checkInEntries,
    imageDescriptions: imageDescriptions,
  );

  group('check-in entries', () {
    JournalEntity comment(String id, DateTime at, String text) =>
        testTextEntry.copyWith(
          meta: testTextEntry.meta.copyWith(id: id, dateFrom: at, dateTo: at),
          entryText: EntryText(plainText: text),
        );
    JournalEntity recording(String id, DateTime at, {String? transcript}) =>
        testAudioEntry.copyWith(
          meta: testAudioEntry.meta.copyWith(id: id, dateFrom: at, dateTo: at),
          data: testAudioEntry.data.copyWith(
            duration: const Duration(minutes: 1, seconds: 5),
          ),
          entryText: transcript == null
              ? null
              : EntryText(plainText: transcript),
        );
    JournalEntity photo(String id, DateTime at, {String? caption}) =>
        testImageEntry.copyWith(
          meta: testImageEntry.meta.copyWith(id: id, dateFrom: at, dateTo: at),
          entryText: caption == null ? null : EntryText(plainText: caption),
        );

    final at = DateTime(2026, 8, 14, 20);

    // Everything a check-in holds reaches the agent, in the order it was
    // added, after the text it was saved with — and a recording or photo
    // without words says so rather than reading as silence.
    test('follow the saved text, oldest first, each with its kind', () {
      final facts = render(
        checkIns: [checkIn('c-1', at, narrative: 'Call with Pip.')],
        checkInEntries: {
          'c-1': [
            recording(
              'r-1',
              at.add(const Duration(minutes: 1)),
              transcript: 'Pip is\nnervous about the launch.',
            ),
            comment('t-1', at.add(const Duration(minutes: 3)), 'Send krill.'),
            recording('r-2', at.add(const Duration(minutes: 4))),
            photo('p-1', at.add(const Duration(minutes: 5))),
            photo(
              'p-2',
              at.add(const Duration(minutes: 6)),
              caption: 'Pip at the launch pad.',
            ),
          ],
        },
      );

      expect(
        facts,
        contains(
          '  narrative: Call with Pip.\n'
          '  2026-08-14 20:01 recording (1:05): Pip is nervous about the '
          'launch.\n'
          '  2026-08-14 20:03 comment: Send krill.\n'
          '  2026-08-14 20:04 recording (1:05): transcript not available yet\n'
          '  2026-08-14 20:05 photo: no description yet\n'
          '  2026-08-14 20:06 photo: Pip at the launch pad.\n',
        ),
      );
    });

    // ADR 0062 Decision 2: the photo's description is its image analysis,
    // not only its own text — the analysis is a response of its own.
    test('a photo reads as its description, then any text of its own', () {
      final facts = render(
        checkIns: [checkIn('c-1', at)],
        checkInEntries: {
          'c-1': [
            photo('p-1', at.add(const Duration(minutes: 1))),
            photo(
              'p-2',
              at.add(const Duration(minutes: 2)),
              caption: 'For the newsletter.',
            ),
            photo('p-3', at.add(const Duration(minutes: 3))),
          ],
        },
        imageDescriptions: {
          'p-1': 'Pip at the launch pad.',
          'p-2': 'Frida holding a krill tin.',
        },
      );

      expect(
        facts,
        contains(
          '  2026-08-14 20:01 photo: Pip at the launch pad.\n'
          '  2026-08-14 20:02 photo: Frida holding a krill tin. · For the '
          'newsletter.\n'
          '  2026-08-14 20:03 photo: no description yet\n',
        ),
      );
    });

    test('are bounded, and the rest counted', () {
      final facts = render(
        checkIns: [checkIn('c-1', at)],
        checkInEntries: {
          'c-1': [
            for (var i = 0; i < relationshipCheckInEntryLookback + 3; i++)
              comment('t-$i', at.add(Duration(minutes: i)), 'Note $i.'),
          ],
        },
      );

      expect(facts, contains('comment: Note 0.'));
      expect(
        facts,
        isNot(contains('Note $relationshipCheckInEntryLookback.')),
      );
      expect(facts, contains('(3 later entries not shown)'));
    });
  });

  // Codex review on #4345: FACTS are authoritative, so a note that says a
  // name was misheard must be told to win over the misheard check-in.
  test("the agent's notes come back with corrections ranked above facts", () {
    final facts = render(
      observations: [
        (
          at: DateTime(2026, 8, 14, 20),
          text: 'The user said "Vanja" was misheard;\nthe name is Wanja.',
        ),
        (at: DateTime(2026, 8, 2, 9), text: 'Pip dislikes long calls.'),
      ],
    );

    expect(
      facts,
      contains(
        'YOUR OBSERVATIONS (your private notes from earlier wakes, newest '
        'first). A correction the user made overrides what it corrects; '
        'any other note is context, not evidence:\n'
        '- 2026-08-14: The user said "Vanja" was misheard; the name is '
        'Wanja.\n'
        '- 2026-08-02: Pip dislikes long calls.\n',
      ),
    );
    expect(render(), contains('not evidence:\n- none\n'));
  });

  test('the baseline token is the only way to tell newly-lapsed from '
      'still-overdue (ADR 0059 Decision 3): rendered on a due cadence, and '
      'only when a baseline exists', () {
    final newly = render(
      d: derivation(status: RelationshipCadenceStatus.due),
      preTransitionStatus: RelationshipCadenceStatus.ok,
    );
    expect(newly, contains('lapse: newly lapsed'));

    final still = render(
      d: derivation(status: RelationshipCadenceStatus.due),
      preTransitionStatus: RelationshipCadenceStatus.due,
    );
    expect(still, contains('lapse: still overdue'));

    // No baseline (chat wake, first-ever evaluation) or an ok cadence:
    // no lapse line at all.
    final noBaseline = render(
      d: derivation(status: RelationshipCadenceStatus.due),
    );
    expect(noBaseline, isNot(contains('lapse:')));
    final okCadence = render(
      preTransitionStatus: RelationshipCadenceStatus.ok,
    );
    expect(okCadence, isNot(contains('lapse:')));
  });

  test('CONTACT CHANNELS NEVER REACH MODEL CONTEXT — the ADR 0041 §5 '
      'boundary, held even when the relationship carries them', () {
    final facts = render(
      checkIns: [checkIn('c-1', DateTime(2026, 8, 14))],
    );
    expect(facts, isNot(contains('+49 170 555 12 34')));
    expect(facts, isNot(contains('anna@example.com')));
    expect(facts.toLowerCase(), isNot(contains('phone')));
    expect(facts.toLowerCase(), isNot(contains('email')));
  });

  test('renders the person, cadence state and recency from the derivation', () {
    final facts = render(
      checkIns: [checkIn('c-1', DateTime(2026, 8, 14, 20))],
      d: derivation(lastCheckInAt: DateTime(2026, 8, 14, 20)),
    );
    expect(facts, contains('name: Anna'));
    expect(facts, contains('nickname: Sis'));
    expect(facts, contains('desiredIntervalDays: 7'));
    expect(facts, contains('status: ok'));
    expect(facts, contains('lastCheckIn: 2026-08-14'));
    expect(facts, contains('daysSinceLastCheckIn: 2'));
  });

  test('check-ins render newest first, bounded to the lookback, with the '
      'user-set sentiment marked as such', () {
    final many = [
      for (var day = 1; day <= 14; day++)
        checkIn(
          'c-$day',
          DateTime(2026, 8, day),
          sentiment: CheckInSentiment.good,
          topics: ['topic-$day'],
        ),
    ];
    final facts = render(checkIns: many);
    expect(facts, contains('CHECK-INS (newest first, 10 of 14):'));
    expect(facts, contains('topic-14'));
    expect(facts, contains('checkInId=c-14'));
    expect(facts, isNot(contains('checkInId=c-4 |')));
    expect(
      facts,
      isNot(contains('topic-4')),
      reason: 'the 11th-newest check-in is outside the bounded window',
    );
    expect(facts, contains('sentiment(user-set)=good'));
  });

  test('the newest negative user rating bounds the health band', () {
    final facts = render(
      checkIns: [
        checkIn(
          'newest',
          DateTime(2026, 8, 14),
          sentiment: CheckInSentiment.difficult,
        ),
        checkIn(
          'older',
          DateTime(2026, 8, 13),
          sentiment: CheckInSentiment.good,
        ),
      ],
    );

    expect(
      facts,
      contains('HEALTH BAND CONSTRAINT (newest user-set sentiment=difficult)'),
    );
    expect(
      facts,
      contains('allowed health verdicts: needs attention, strained'),
    );
    expect(
      facts,
      contains('exact enum only in healthBand; never copy it into prose'),
    );
    expect(facts, isNot(contains('allowed FIELD VALUES: needsAttention')));
    expect(facts, contains('narrative cannot improve this constraint'));
  });

  test('the newest positive user rating bounds the health band upward', () {
    final facts = render(
      checkIns: [
        checkIn(
          'newest',
          DateTime(2026, 8, 14),
          sentiment: CheckInSentiment.delightful,
        ),
        checkIn(
          'older',
          DateTime(2026, 8, 13),
          sentiment: CheckInSentiment.good,
        ),
      ],
    );

    expect(
      facts,
      contains('HEALTH BAND CONSTRAINT (newest user-set sentiment=delightful)'),
    );
    expect(facts, contains('allowed health verdicts: thriving, steady\n'));
  });

  group('a positive newest rating keeps needs attention reachable', () {
    CheckInEntry good(String id, DateTime at) =>
        checkIn(id, at, sentiment: CheckInSentiment.good);

    test('when the cadence has lapsed', () {
      final facts = render(
        checkIns: [good('newest', DateTime(2026, 6, 2))],
        d: derivation(status: RelationshipCadenceStatus.due),
      );

      expect(
        facts,
        contains('allowed health verdicts: thriving, steady, needs attention'),
      );
    });

    test('when an older rating in the window was strained or difficult', () {
      final facts = render(
        checkIns: [
          good('newest', DateTime(2026, 8, 14)),
          checkIn(
            'hard',
            DateTime(2026, 7, 31),
            sentiment: CheckInSentiment.difficult,
          ),
        ],
      );

      expect(
        facts,
        contains('allowed health verdicts: thriving, steady, needs attention'),
      );
    });

    test('but not for a hard rating that fell out of the window', () {
      final facts = render(
        checkIns: [
          for (var day = 1; day <= relationshipCheckInLookback; day++)
            good('good-$day', DateTime(2026, 8, day + 1)),
          checkIn(
            'outside-window',
            DateTime(2026, 7, 31),
            sentiment: CheckInSentiment.strained,
          ),
        ],
      );

      expect(facts, contains('allowed health verdicts: thriving, steady\n'));
    });
  });

  test('an unrated check-in does not invent a health-band constraint', () {
    final facts = render(
      checkIns: [checkIn('unrated', DateTime(2026, 8, 14))],
    );

    expect(facts, isNot(contains('HEALTH BAND CONSTRAINT')));
  });

  test('an unrated newest check-in preserves the newest explicit rating', () {
    final facts = render(
      checkIns: [
        checkIn('unrated', DateTime(2026, 8, 14)),
        checkIn(
          'rated',
          DateTime(2026, 8, 13),
          sentiment: CheckInSentiment.strained,
        ),
      ],
    );

    expect(
      facts,
      contains('HEALTH BAND CONSTRAINT (newest user-set sentiment=strained)'),
    );
    expect(
      facts,
      contains('allowed health verdicts: needs attention, strained'),
    );
  });

  test('guidance fields and the narrative excerpt ride each check-in', () {
    final facts = render(
      checkIns: [
        checkIn(
          'c-1',
          DateTime(2026, 8, 14),
          payAttentionTo: 'her job interview on Friday',
          avoid: 'the inheritance topic',
          narrative: 'Long call about the move. ${'x' * 500}',
        ),
      ],
    );
    expect(facts, contains('payAttentionTo: her job interview on Friday'));
    expect(facts, contains('avoid: the inheritance topic'));
    expect(facts, contains('narrative: Long call about the move.'));
    expect(
      facts,
      contains('…'),
      reason: 'narratives are excerpted, never dumped wholesale',
    );
  });

  test('no check-ins: the tracking-start baseline is stated instead', () {
    final facts = render();
    expect(facts, contains('none recorded yet'));
    expect(facts, contains('2026-08-01'));
  });

  test('every task status renders under its plain-English name', () {
    TaskStatus statusOf(String kind) => switch (kind) {
      'open' => TaskStatus.open(id: 'ts', createdAt: testDate, utcOffset: 0),
      'groomed' => TaskStatus.groomed(
        id: 'ts',
        createdAt: testDate,
        utcOffset: 0,
      ),
      'blocked' => TaskStatus.blocked(
        id: 'ts',
        createdAt: testDate,
        utcOffset: 0,
        reason: 'waiting',
      ),
      'onHold' => TaskStatus.onHold(
        id: 'ts',
        createdAt: testDate,
        utcOffset: 0,
        reason: 'paused',
      ),
      'done' => TaskStatus.done(id: 'ts', createdAt: testDate, utcOffset: 0),
      _ => TaskStatus.rejected(id: 'ts', createdAt: testDate, utcOffset: 0),
    };
    Task task(String kind) =>
        JournalEntity.task(
              meta: meta('task-$kind'),
              data: TaskData(
                status: statusOf(kind),
                dateFrom: testDate,
                dateTo: testDate,
                statusHistory: const [],
                title: 'Task $kind',
              ),
            )
            as Task;
    final facts = render(
      tasks: [
        for (final kind in const [
          'open',
          'groomed',
          'blocked',
          'onHold',
          'done',
          'rejected',
        ])
          task(kind),
      ],
    );
    expect(facts, contains('Task open [open]'));
    expect(facts, contains('Task groomed [groomed]'));
    expect(facts, contains('Task blocked [blocked]'));
    expect(facts, contains('Task onHold [on hold]'));
    expect(facts, contains('Task done [done]'));
    expect(facts, contains('Task rejected [rejected]'));
  });

  test('linked tasks carry titles and statuses only', () {
    final task =
        JournalEntity.task(
              meta: meta('task-1'),
              data: TaskData(
                status: TaskStatus.inProgress(
                  id: 'ts-1',
                  createdAt: testDate,
                  utcOffset: 0,
                ),
                dateFrom: testDate,
                dateTo: testDate,
                statusHistory: const [],
                title: 'Plan the birthday trip',
              ),
            )
            as Task;
    final facts = render(tasks: [task]);
    expect(facts, contains('Plan the birthday trip [in progress]'));
  });

  test('a previous briefing renders with its date, and newer check-ins '
      'mark it stale', () {
    final report =
        AgentDomainEntity.agentReport(
              id: 'report-1',
              agentId: 'agent-1',
              scope: 'current',
              createdAt: DateTime(2026, 8, 10),
              vectorClock: null,
              content: 'full briefing',
              tldr: 'Things are steady with Anna.',
            )
            as AgentReportEntity;
    final facts = render(
      checkIns: [checkIn('c-1', DateTime(2026, 8, 14))],
      previousReport: report,
      d: derivation(lastCheckInAt: DateTime(2026, 8, 14)),
    );
    expect(facts, contains('PREVIOUS BRIEFING (2026-08-10):'));
    expect(facts, contains('Things are steady with Anna.'));
    expect(facts, contains('BRIEFING IS STALE'));
  });

  test('a due cadence with no banner marks the nudge REQUIRED; a dismissal '
      'today invokes the quiet window instead', () {
    final due = render(
      d: derivation(status: RelationshipCadenceStatus.due),
    );
    expect(due, contains('a check-in nudge is REQUIRED'));

    final dismissed =
        AgentDomainEntity.relationshipNudge(
              id: 'ad-1',
              agentId: 'agent-1',
              status: NudgeStatus.dismissed,
              brief: const NudgeBrief(
                headline: 'Check in with Anna.',
                tone: NudgeTone.nudge,
                animation: NudgeBannerAnimation.steady,
              ),
              briefDigest: 'd',
              createdAt: testDate,
              updatedAt: testDate,
              vectorClock: null,
              dismissedAt: now.subtract(const Duration(hours: 2)),
            )
            as RelationshipNudgeEntity;
    final quiet = render(
      d: derivation(status: RelationshipCadenceStatus.due),
      nudges: [dismissed],
    );
    expect(quiet, isNot(contains('REQUIRED')));
    expect(quiet, contains('quiet window'));
  });

  test('an active banner renders its adId and snooze state for the snooze '
      'tool', () {
    final active =
        AgentDomainEntity.relationshipNudge(
              id: 'ad-live',
              agentId: 'agent-1',
              status: NudgeStatus.active,
              brief: const NudgeBrief(
                headline: 'Call Anna.',
                tone: NudgeTone.nudge,
                animation: NudgeBannerAnimation.steady,
              ),
              briefDigest: 'd',
              createdAt: testDate,
              updatedAt: testDate,
              vectorClock: null,
              activatedAt: DateTime(2026, 8, 15),
            )
            as RelationshipNudgeEntity;
    final facts = render(nudges: [active]);
    expect(facts, contains('adId=ad-live'));
    expect(facts, contains('"Call Anna."'));
  });

  // ADR 0063: a reminder the user tapped paused itself; FACTS must not read
  // that as the user putting it off.
  for (final (reason, line) in [
    (NudgeSnoozeReason.opened, 'opened by the user, paused until'),
    (NudgeSnoozeReason.chosen, 'snoozed until'),
    (null, 'snoozed until'),
  ]) {
    test('a paused banner says why it is quiet: $reason', () {
      final until = DateTime.utc(2099);
      final base =
          AgentDomainEntity.relationshipNudge(
                id: 'ad-live',
                agentId: 'agent-1',
                status: NudgeStatus.active,
                brief: const NudgeBrief(
                  headline: 'Call Anna.',
                  tone: NudgeTone.nudge,
                  animation: NudgeBannerAnimation.steady,
                ),
                briefDigest: 'd',
                createdAt: testDate,
                updatedAt: testDate,
                vectorClock: null,
                activatedAt: DateTime(2026, 8, 15),
                snoozedUntil: until,
              )
              as RelationshipNudgeEntity;
      final paused = base.copyWith(
        snoozeHistory: [
          NudgeSnooze(
            id: 'snooze-1',
            activation: base.activationCount,
            snoozedAt: testDate,
            snoozedUntil: until,
            duration: NudgeBannerSnoozeDuration.oneHour,
            durationMinutes: 60,
            utcOffsetMinutes: 0,
            reason: reason,
          ),
        ],
      );

      final facts = render(nudges: [paused]);

      expect(facts, contains('| $line ${until.toIso8601String()}'));
      if (reason != NudgeSnoozeReason.opened) {
        expect(facts, isNot(contains('opened by the user')));
      }
    });
  }

  // Codex review on #4356: the deadline in force came from a chosen snooze,
  // so the agent must read it as snoozed, not as opened.
  test('a newer opened pause that lost the deadline reads as snoozed', () {
    final chosenUntil = DateTime.utc(2099);
    final base =
        AgentDomainEntity.relationshipNudge(
              id: 'ad-live',
              agentId: 'agent-1',
              status: NudgeStatus.active,
              brief: const NudgeBrief(
                headline: 'Call Anna.',
                tone: NudgeTone.nudge,
                animation: NudgeBannerAnimation.steady,
              ),
              briefDigest: 'd',
              createdAt: testDate,
              updatedAt: testDate,
              vectorClock: null,
              activatedAt: DateTime(2026, 8, 15),
              snoozedUntil: chosenUntil,
            )
            as RelationshipNudgeEntity;
    NudgeSnooze event(String id, DateTime until, NudgeSnoozeReason reason) =>
        NudgeSnooze(
          id: id,
          activation: base.activationCount,
          snoozedAt: testDate,
          snoozedUntil: until,
          duration: NudgeBannerSnoozeDuration.oneHour,
          durationMinutes: 60,
          utcOffsetMinutes: 0,
          reason: reason,
        );

    final facts = render(
      nudges: [
        base.copyWith(
          snoozeHistory: [
            event('chosen', chosenUntil, NudgeSnoozeReason.chosen),
            event('opened', DateTime.utc(2098), NudgeSnoozeReason.opened),
          ],
        ),
      ],
    );

    expect(facts, contains('| snoozed until ${chosenUntil.toIso8601String()}'));
    expect(facts, isNot(contains('opened by the user')));
  });
}
