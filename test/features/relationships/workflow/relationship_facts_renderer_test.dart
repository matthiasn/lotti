import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/nudge_models.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/classes/relationship_trigger_tokens.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/relationships/runtime/relationship_agent_phase_a.dart';
import 'package:lotti/features/relationships/workflow/relationship_facts_renderer.dart';

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
  }) => (
    status: status,
    previousStatus: null,
    cadenceDays: 7,
    referenceAt: lastCheckInAt ?? testDate,
    lastCheckInAt: lastCheckInAt,
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
  }) => renderer.render(
    relationship: relationship(),
    derivation: d ?? derivation(),
    checkIns: checkIns,
    linkedTasks: tasks,
    previousReport: previousReport,
    nudges: nudges,
    now: now,
    preTransitionStatus: preTransitionStatus,
  );

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
    expect(
      facts,
      isNot(contains('topic-4')),
      reason: 'the 11th-newest check-in is outside the bounded window',
    );
    expect(facts, contains('sentiment(user-set)=good'));
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
}
