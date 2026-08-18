import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/nudge_models.dart';
import 'package:lotti/features/goals/workflow/goal_agent_contract.dart';
import 'package:lotti/features/goals/workflow/goal_agent_strategy.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

ChatCompletionMessageToolCall _call({
  required String name,
  required Map<String, dynamic> args,
  String id = 'call-1',
}) => ChatCompletionMessageToolCall(
  id: id,
  type: ChatCompletionMessageToolCallType.function,
  function: ChatCompletionMessageFunctionCall(
    name: name,
    arguments: jsonEncode(args),
  ),
);

void main() {
  late MockAgentSyncService syncService;
  late MockConversationManager manager;
  late GoalAgentStrategy strategy;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    syncService = MockAgentSyncService();
    manager = MockConversationManager();
    when(() => syncService.upsertEntity(any())).thenAnswer((_) async {});
    strategy = GoalAgentStrategy(
      syncService: syncService,
      agentId: 'goal-1',
      threadId: 'thread-1',
      runKey: 'run-1',
      knownAdIds: {'ad-known'},
    );
  });

  String rejection() =>
      (verify(
            () => manager.addToolResponse(
              toolCallId: any(named: 'toolCallId'),
              response: captureAny(named: 'response'),
            ),
          ).captured.last)
          as String;

  test('reply_to_user captures exactly one visible answer', () async {
    await strategy.processToolCalls(
      toolCalls: [
        _call(
          name: GoalAgentToolNames.replyToUser,
          args: {'message': 'You are one gym visit from being back on pace.'},
        ),
      ],
      manager: manager,
    );
    expect(
      strategy.replyToUser,
      'You are one gym visit from being back on pace.',
    );

    await strategy.processToolCalls(
      toolCalls: [
        _call(
          id: 'call-2',
          name: GoalAgentToolNames.replyToUser,
          args: {'message': 'A second answer.'},
        ),
      ],
      manager: manager,
    );
    expect(strategy.replyToUser, isNot('A second answer.'));
    expect(rejection(), contains('at most once'));
  });

  test(
    'reply_to_user rejects blank copy instead of creating an empty bubble',
    () async {
      await strategy.processToolCalls(
        toolCalls: [
          _call(
            name: GoalAgentToolNames.replyToUser,
            args: {'message': '   '},
          ),
        ],
        manager: manager,
      );

      expect(strategy.replyToUser, isNull);
      expect(rejection(), contains('non-empty message'));
    },
  );

  test('update_goal_report accumulates the validated report', () async {
    await strategy.processToolCalls(
      toolCalls: [
        _call(
          name: GoalAgentToolNames.updateGoalReport,
          args: {
            'status': 'offTrack',
            'oneLiner': 'Averaging 6.4k of 10k steps.',
            'tldr': 'The rolling week slid under target.',
          },
        ),
      ],
      manager: manager,
    );
    expect(strategy.hasReport, isTrue);
    expect(strategy.reportStatus, GoalTrackStatus.offTrack);
    expect(strategy.reportOneLiner, 'Averaging 6.4k of 10k steps.');
    expect(strategy.reportContent, isNull);
  });

  test(
    'structured report sections become the persisted visible summary',
    () async {
      await strategy.processToolCalls(
        toolCalls: [
          _call(
            name: GoalAgentToolNames.updateGoalReport,
            args: {
              'status': 'insufficientData',
              'oneLiner': 'Today is handled; the rolling window still lags.',
              'report': {
                'tldr': 'Where the goal stands right now.',
                'currentPeriod':
                    'Blood pressure logging is complete today at 125/84.',
                'rollingWindow':
                    'Rolling averages remain above target at 127/89.',
                'latestChange':
                    'Blood pressure improved from 129/94 to 125/84.',
                'coverage': 'Two readings make the series sparse.',
                'nextActions': {
                  'now': <Object>[],
                  'later': ['Keep taking the medication tomorrow.'],
                },
              },
              'content': 'Take medication today.',
            },
          ),
        ],
        manager: manager,
      );

      expect(strategy.hasReport, isTrue);
      // The two tiers are distinct, which is the whole point: the card shows
      // the TLDR collapsed and opens the composed body behind "Show more".
      // Composing the sections into the TLDR left the content null, and the
      // card's `content != tldr` test then found nothing to expand — the
      // report rendered as one unbroken wall with no way to shorten it.
      expect(strategy.reportTldr, 'Where the goal stands right now.');
      expect(
        strategy.reportContent,
        'Blood pressure logging is complete today at 125/84.\n\n'
        'Rolling averages remain above target at 127/89.\n\n'
        'Blood pressure improved from 129/94 to 125/84.\n\n'
        'Two readings make the series sparse.\n\n'
        'Keep taking the medication tomorrow.',
      );
      // The free-form `content` argument is still ignored alongside a
      // structured report, so it cannot reintroduce a filtered action.
      expect(strategy.reportContent, isNot(contains('Take medication today.')));
    },
  );

  test(
    'only deterministically allowed current actions become visible',
    () async {
      final gated = GoalAgentStrategy(
        syncService: syncService,
        agentId: 'goal-1',
        threadId: 'thread-1',
        runKey: 'run-1',
        knownAdIds: const {},
        allowedCurrentActionCriterionIds: const {'health-weight'},
      );
      await gated.processToolCalls(
        toolCalls: [
          _call(
            name: GoalAgentToolNames.updateGoalReport,
            args: {
              'status': 'insufficientData',
              'oneLiner': 'One measurement remains.',
              'report': {
                'tldr': 'Where the goal stands right now.',
                'currentPeriod': 'Weight is not measured today.',
                'rollingWindow': 'The rolling weight average is above target.',
                'latestChange': '',
                'coverage': 'Today is missing from the series.',
                'nextActions': {
                  'now': [
                    {
                      'criterionId': 'health-weight',
                      'action': 'Log weight today.',
                    },
                    {
                      'criterionId': 'habit-bp-meds',
                      'action': 'Take medication today.',
                    },
                  ],
                  'later': <Object>[],
                },
              },
            },
          ),
        ],
        manager: manager,
      );

      expect(gated.reportContent, contains('Log weight today.'));
      expect(gated.reportContent, isNot(contains('Take medication today.')));
    },
  );

  test('a status token in visible prose is rejected, not published', () async {
    await strategy.processToolCalls(
      toolCalls: [
        _call(
          name: GoalAgentToolNames.updateGoalReport,
          args: {
            'status': 'insufficientData',
            'oneLiner': 'Not enough readings yet.',
            'report': {
              'tldr': 'The overall status is insufficientData right now.',
              'currentPeriod': 'Nothing logged today.',
              'rollingWindow': 'The rolling window is thin.',
              'latestChange': '',
              'coverage': 'Two of seven days carry data.',
              'nextActions': {'now': <Object>[], 'later': <Object>[]},
            },
          },
        ),
      ],
      manager: manager,
    );

    // The prompt says status names are field values, never prose. That
    // instruction was the only thing standing between a weaker model and
    // "the overall status is insufficientData" reaching the user.
    expect(strategy.hasReport, isFalse);
    final error = rejection();
    expect(error, contains('insufficientData'));
    expect(error, contains('not prose'));
  });

  test('a status name is still required in the status FIELD', () async {
    await strategy.processToolCalls(
      toolCalls: [
        _call(
          name: GoalAgentToolNames.updateGoalReport,
          args: {
            'status': 'insufficientData',
            'oneLiner': 'Not enough readings yet.',
            'report': {
              'tldr': 'Two days of data so far.',
              'currentPeriod': 'Nothing logged today.',
              'rollingWindow': 'The rolling window is thin.',
              'latestChange': '',
              'coverage': 'Two of seven days carry data.',
              'nextActions': {'now': <Object>[], 'later': <Object>[]},
            },
          },
        ),
      ],
      manager: manager,
    );

    // The guard must read prose only — rejecting the field itself would make
    // the tool impossible to call.
    expect(strategy.hasReport, isTrue);
    expect(strategy.reportStatus, GoalTrackStatus.insufficientData);
  });

  test('structured report rejects empty current or rolling standing', () async {
    for (final emptyKey in ['currentPeriod', 'rollingWindow']) {
      await strategy.processToolCalls(
        toolCalls: [
          _call(
            name: GoalAgentToolNames.updateGoalReport,
            args: {
              'status': 'offTrack',
              'oneLiner': 'Behind.',
              'report': {
                'tldr': 'Where the goal stands right now.',
                'currentPeriod': emptyKey == 'currentPeriod'
                    ? ''
                    : 'Nothing completed.',
                'rollingWindow': emptyKey == 'rollingWindow'
                    ? ''
                    : 'The rolling window is behind.',
                'latestChange': '',
                'coverage': '',
                'nextActions': {
                  'now': <Object>[],
                  'later': ['Keep going.'],
                },
              },
            },
          ),
        ],
        manager: manager,
      );

      expect(strategy.hasReport, isFalse, reason: emptyKey);
      expect(rejection(), contains('structured report'));
    }
  });

  test(
    'structured report rejects malformed next actions without a fallback',
    () async {
      await strategy.processToolCalls(
        toolCalls: [
          _call(
            name: GoalAgentToolNames.updateGoalReport,
            args: {
              'status': 'offTrack',
              'oneLiner': 'Behind.',
              'report': {
                'tldr': 'Where the goal stands right now.',
                'currentPeriod': 'Nothing completed.',
                'rollingWindow': 'The rolling window is behind.',
                'latestChange': '',
                'coverage': '',
                'nextActions': 'Walk tomorrow',
              },
            },
          ),
        ],
        manager: manager,
      );

      expect(strategy.hasReport, isFalse);
      expect(rejection(), contains('structured report'));
    },
  );

  test('a report status contradicting the deterministic FACTS is '
      'rejected — the computed status is authoritative', () async {
    final gated = GoalAgentStrategy(
      syncService: syncService,
      agentId: 'goal-1',
      threadId: 'thread-1',
      runKey: 'run-1',
      knownAdIds: const {},
      expectedStatus: GoalTrackStatus.offTrack,
    );
    await gated.processToolCalls(
      toolCalls: [
        _call(
          name: GoalAgentToolNames.updateGoalReport,
          args: {'status': 'onTrack', 'oneLiner': 'All good!', 'tldr': 'x'},
        ),
      ],
      manager: manager,
    );
    expect(gated.hasReport, isFalse);
    expect(rejection(), contains('"offTrack"'));

    await gated.processToolCalls(
      toolCalls: [
        _call(
          name: GoalAgentToolNames.updateGoalReport,
          args: {'status': 'offTrack', 'oneLiner': 'Behind.', 'tldr': 'x'},
        ),
      ],
      manager: manager,
    );
    expect(gated.reportStatus, GoalTrackStatus.offTrack);
  });

  test('a report breaking several rules is told about all of them', () async {
    // Sequential rejection cost one round trip per rule: the model fixed
    // what it was told and tripped the next rule on the way out. A wake gets
    // exactly ONE forced report retry, so two rules reported one at a time
    // ended the wake with no standing report at all — which the outcome eval
    // caught happening on 8 of one model's 9 failures.
    final gated = GoalAgentStrategy(
      syncService: syncService,
      agentId: 'goal-1',
      threadId: 'thread-1',
      runKey: 'run-1',
      knownAdIds: const {},
      expectedStatus: GoalTrackStatus.offTrack,
      expectedRollingAggregates: const ['6000'],
    );
    await gated.processToolCalls(
      toolCalls: [
        _call(
          name: GoalAgentToolNames.updateGoalReport,
          args: {
            // Three rules at once: a status contradicting FACTS, a status
            // token used as prose, and a rolling standing that never quotes
            // the deterministic aggregate.
            'status': 'atRisk',
            'oneLiner': 'The goal is atRisk this week.',
            'report': {
              'tldr': 'Slightly behind.',
              'currentPeriod': 'Around 6.4k yesterday.',
              'rollingWindow': 'Averaging about 6.5k steps a day.',
              'latestChange': 'Down from last week.',
              'coverage': '7 days.',
              'nextActions': {'now': <Object?>[], 'later': <Object?>[]},
            },
          },
        ),
      ],
      manager: manager,
    );

    expect(gated.hasReport, isFalse);
    final refusal = rejection();
    expect(refusal, contains('broke 3 rules'));
    expect(refusal, contains('fix all of them in one call'));
    // Each rule named, so one retry can satisfy every one of them.
    expect(refusal, contains('is a status field value, not prose'));
    expect(refusal, contains('the FACTS trackStatus is "offTrack"'));
    expect(refusal, contains('6000 is missing'));
    // Numbered, because an unstructured concatenation of three sentences is
    // what the model has to act on.
    expect(refusal, contains('1)'));
    expect(refusal, contains('3)'));

    // And the corrected report — every rule honoured at once — lands.
    await gated.processToolCalls(
      toolCalls: [
        _call(
          name: GoalAgentToolNames.updateGoalReport,
          args: {
            'status': 'offTrack',
            'oneLiner': 'Well under the daily target.',
            'report': {
              'tldr': 'Behind on steps.',
              'currentPeriod': 'Around 6.4k yesterday.',
              'rollingWindow': 'Averaging 6000 steps a day against 10000.',
              'latestChange': 'Down from last week.',
              'coverage': '7 days.',
              'nextActions': {'now': <Object?>[], 'later': <Object?>[]},
            },
          },
        ),
      ],
      manager: manager,
    );
    expect(gated.reportStatus, GoalTrackStatus.offTrack);
  });

  test(
    'a report the parser refused is still checked against the rules',
    () async {
      // `latestChange` is simply absent — a slot a model with nothing to report
      // omits, and one `tryParse` requires to be PRESENT even when empty. The
      // parse therefore fails, and every field it would have exposed used to
      // become unreadable: the status-token scan lost the structured slots and
      // the aggregate rule stopped applying altogether. The model was told only
      // that its report was incomplete, fixed the shape, and met those rules for
      // the first time on the one forced retry a wake gets — the sequential
      // rejection batching exists to prevent, reached through the parse path.
      final gated = GoalAgentStrategy(
        syncService: syncService,
        agentId: 'goal-1',
        threadId: 'thread-1',
        runKey: 'run-1',
        knownAdIds: const {},
        expectedStatus: GoalTrackStatus.offTrack,
        expectedRollingAggregates: const ['6000'],
      );
      await gated.processToolCalls(
        toolCalls: [
          _call(
            name: GoalAgentToolNames.updateGoalReport,
            args: {
              // Status agrees with FACTS and `oneLiner` is clean, so the two
              // violations below can only be found inside the structured slots
              // the failed parse used to hide.
              'status': 'offTrack',
              'oneLiner': 'Well under the daily target.',
              'report': {
                'tldr': 'Behind on steps.',
                'currentPeriod': 'The current period reads offTrack.',
                'rollingWindow': 'Averaging about 6.5k steps a day.',
                'coverage': '7 days.',
                'nextActions': {'now': <Object?>[], 'later': <Object?>[]},
              },
            },
          ),
        ],
        manager: manager,
      );

      expect(gated.hasReport, isFalse);
      final refusal = rejection();
      expect(refusal, contains('broke 3 rules'));
      expect(refusal, contains('a complete structured report'));
      // Both of these were unreachable while the parse failure hid the slots.
      expect(
        refusal,
        contains('"offTrack" is a status field value, not prose'),
      );
      expect(refusal, contains('6000 is missing'));

      // One retry, every rule honoured, and the report lands.
      await gated.processToolCalls(
        toolCalls: [
          _call(
            name: GoalAgentToolNames.updateGoalReport,
            args: {
              'status': 'offTrack',
              'oneLiner': 'Well under the daily target.',
              'report': {
                'tldr': 'Behind on steps.',
                'currentPeriod': 'Around 6.4k yesterday.',
                'rollingWindow': 'Averaging 6000 steps a day against 10000.',
                'latestChange': 'Down from last week.',
                'coverage': '7 days.',
                'nextActions': {'now': <Object?>[], 'later': <Object?>[]},
              },
            },
          ),
        ],
        manager: manager,
      );
      expect(gated.reportStatus, GoalTrackStatus.offTrack);
    },
  );

  test('an absent rolling standing is reported once, not twice', () async {
    // The lenient view reads a missing slot as empty, and an empty standing
    // trivially fails "quote 6000". Reporting that alongside "incomplete"
    // would tell the model twice that a section it never wrote is wrong.
    final gated = GoalAgentStrategy(
      syncService: syncService,
      agentId: 'goal-1',
      threadId: 'thread-1',
      runKey: 'run-1',
      knownAdIds: const {},
      expectedStatus: GoalTrackStatus.offTrack,
      expectedRollingAggregates: const ['6000'],
    );
    await gated.processToolCalls(
      toolCalls: [
        _call(
          name: GoalAgentToolNames.updateGoalReport,
          args: {
            'status': 'offTrack',
            'oneLiner': 'Well under the daily target.',
            'report': {
              'tldr': 'Behind on steps.',
              'currentPeriod': 'Around 6.4k yesterday.',
              'latestChange': 'Down from last week.',
              'coverage': '7 days.',
              'nextActions': {'now': <Object?>[], 'later': <Object?>[]},
            },
          },
        ),
      ],
      manager: manager,
    );

    expect(gated.hasReport, isFalse);
    final refusal = rejection();
    expect(refusal, contains('a complete structured report'));
    expect(refusal, isNot(contains('6000 is missing')));
    // A single problem keeps the plain wording — no "broke N rules" envelope.
    expect(refusal, isNot(contains('broke')));
  });

  test('a single broken rule reads exactly as it always did', () async {
    // The envelope is for the multiple case only: one problem must not gain
    // a "broke 1 rules" preamble.
    final gated = GoalAgentStrategy(
      syncService: syncService,
      agentId: 'goal-1',
      threadId: 'thread-1',
      runKey: 'run-1',
      knownAdIds: const {},
      expectedStatus: GoalTrackStatus.offTrack,
    );
    await gated.processToolCalls(
      toolCalls: [
        _call(
          name: GoalAgentToolNames.updateGoalReport,
          args: {
            'status': 'atRisk',
            'oneLiner': 'Slightly behind.',
            'tldr': 'A little under target.',
          },
        ),
      ],
      manager: manager,
    );
    expect(
      rejection(),
      'Error: the FACTS trackStatus is "offTrack" and it is authoritative '
      '— use it verbatim.',
    );
  });

  test('a missing status does not also report a status mismatch', () async {
    // "needs status" and "the status is wrong" are the same defect stated
    // twice; reporting both would make the model hunt for a second problem
    // that does not exist.
    final gated = GoalAgentStrategy(
      syncService: syncService,
      agentId: 'goal-1',
      threadId: 'thread-1',
      runKey: 'run-1',
      knownAdIds: const {},
      expectedStatus: GoalTrackStatus.offTrack,
    );
    await gated.processToolCalls(
      toolCalls: [
        _call(
          name: GoalAgentToolNames.updateGoalReport,
          args: {'oneLiner': 'Behind.', 'tldr': 'Behind on steps.'},
        ),
      ],
      manager: manager,
    );
    final refusal = rejection();
    expect(refusal, contains('needs status'));
    expect(refusal, isNot(contains('broke')));
    expect(refusal, isNot(contains('authoritative')));
  });

  test('a rolling standing quoting the latest reading instead of the '
      'aggregate is rejected', () async {
    // Every evaluated model substitutes the latest weigh-in for the 7-day
    // mean on the multi-series health goal — 94 kg where FACTS say 95 — which
    // publishes a wrong number, not a wording variant. Same authority as the
    // track status: the deterministic aggregate wins.
    Map<String, Object?> report(String rollingWindow) => {
      'status': 'offTrack',
      'oneLiner': 'Behind.',
      'report': {
        'tldr': 'Behind on weight.',
        'currentPeriod': 'Latest weigh-in 94 kg.',
        'rollingWindow': rollingWindow,
        'latestChange': '95 to 94 kg.',
        'coverage': '3 weigh-ins.',
        'nextActions': {'now': <Object?>[], 'later': <Object?>[]},
      },
    };
    final gated = GoalAgentStrategy(
      syncService: syncService,
      agentId: 'goal-1',
      threadId: 'thread-1',
      runKey: 'run-1',
      knownAdIds: const {},
      expectedRollingAggregates: const ['95'],
    );
    await gated.processToolCalls(
      toolCalls: [
        _call(
          name: GoalAgentToolNames.updateGoalReport,
          args: report('Weight averages 94 kg against a 88 kg target.'),
        ),
      ],
      manager: manager,
    );
    expect(gated.hasReport, isFalse);
    final refusal = rejection();
    expect(refusal, contains('95'));
    expect(refusal, contains('never the latest reading'));

    await gated.processToolCalls(
      toolCalls: [
        _call(
          name: GoalAgentToolNames.updateGoalReport,
          args: report('Weight averages 95 kg against a 88 kg target.'),
        ),
      ],
      manager: manager,
    );
    expect(gated.reportStatus, GoalTrackStatus.offTrack);
  });

  test(
    'a recomputed precision does not count as quoting the aggregate',
    () async {
      // The motivating fabrication: FACTS carry 127, the model wrote "127.85".
      // Substring matching accepted it, so the check passed exactly the output
      // it exists to reject.
      Future<GoalAgentStrategy> attempt(String rollingWindow) async {
        final gated = GoalAgentStrategy(
          syncService: syncService,
          agentId: 'goal-1',
          threadId: 'thread-1',
          runKey: 'run-1',
          knownAdIds: const {},
          expectedRollingAggregates: const ['127'],
        );
        await gated.processToolCalls(
          toolCalls: [
            _call(
              name: GoalAgentToolNames.updateGoalReport,
              args: {
                'status': 'offTrack',
                'oneLiner': 'Behind.',
                'report': {
                  'tldr': 'Behind on blood pressure.',
                  'currentPeriod': 'Latest systolic 125.',
                  'rollingWindow': rollingWindow,
                  'latestChange': '129 to 125.',
                  'coverage': '2 readings.',
                  'nextActions': {'now': <Object?>[], 'later': <Object?>[]},
                },
              },
            ),
          ],
          manager: manager,
        );
        return gated;
      }

      expect(
        (await attempt('Systolic averages 127.85 mmHg.')).hasReport,
        isFalse,
      );
      expect(
        (await attempt('Systolic averages 1127 mmHg.')).hasReport,
        isFalse,
      );
      // The genuine quote is accepted, punctuation and units included.
      expect((await attempt('Systolic averages 127 mmHg.')).hasReport, isTrue);
      expect(
        (await attempt('Systolic sits at 127, above target.')).hasReport,
        isTrue,
      );
    },
  );

  test('a reader-formatted aggregate still counts as quoting it', () async {
    // FACTS carry a bare Dart number; a report writes the number the way a
    // reader expects to see it. Digit-exact matching rejected EVERY
    // four-digit aggregate from every evaluated model — "8,600" against
    // 8600 — while passing every three-digit one, so the health goals
    // passed and the step goals lost their reports entirely.
    Future<bool> accepts(String rollingWindow, String aggregate) async {
      final gated = GoalAgentStrategy(
        syncService: syncService,
        agentId: 'goal-1',
        threadId: 'thread-1',
        runKey: 'run-1',
        knownAdIds: const {},
        expectedRollingAggregates: [aggregate],
      );
      await gated.processToolCalls(
        toolCalls: [
          _call(
            name: GoalAgentToolNames.updateGoalReport,
            args: {
              'status': 'offTrack',
              'oneLiner': 'Behind.',
              'report': {
                'tldr': 'Behind on steps.',
                'currentPeriod': 'Yesterday was light.',
                'rollingWindow': rollingWindow,
                'latestChange': 'Down on the week.',
                'coverage': '7 days.',
                'nextActions': {'now': <Object?>[], 'later': <Object?>[]},
              },
            },
          ),
        ],
        manager: manager,
      );
      return gated.hasReport;
    }

    // What the models actually write, captured from live runs.
    for (final written in [
      'Rolling 7-day average is 8,600 steps against a 10,000 target.',
      'Rolling 7-day mean is ~8,600 steps (attainment 0.86).',
      // Locales that group with a period or a space.
      'Der 7-Tage-Schnitt liegt bei 8.600 Schritten.',
      'La moyenne sur 7 jours est de 8 600 pas.',
      // The number ending the sentence: the trailing period is punctuation,
      // not a decimal point, and rejecting it was a plain bug.
      'The rolling seven-day average is 8600.',
    ]) {
      expect(
        await accepts(written, '8600'),
        isTrue,
        reason: 'must accept: $written',
      );
    }

    // And the fabrications this check exists for are still refused — the
    // normalization must not buy acceptance with accuracy.
    for (final fabricated in [
      // A recomputed precision FACTS never carried.
      'Rolling average 8600.42 steps.',
      // A different number that merely contains the digits.
      'Rolling average 18600 steps.',
      // Grouped, but a different value.
      'Rolling 7-day average is 8,700 steps.',
    ]) {
      expect(
        await accepts(fabricated, '8600'),
        isFalse,
        reason: 'must refuse: $fabricated',
      );
    }
  });

  test('normalizing separators never destroys a raw match', () async {
    // "weight 95 100" reads as two numbers; collapsing the space would hide
    // the 95. The raw text is tried first for exactly this reason.
    final gated = GoalAgentStrategy(
      syncService: syncService,
      agentId: 'goal-1',
      threadId: 'thread-1',
      runKey: 'run-1',
      knownAdIds: const {},
      expectedRollingAggregates: const ['95'],
    );
    await gated.processToolCalls(
      toolCalls: [
        _call(
          name: GoalAgentToolNames.updateGoalReport,
          args: {
            'status': 'offTrack',
            'oneLiner': 'Behind.',
            'report': {
              'tldr': 'Behind on weight.',
              'currentPeriod': 'Weighed in today.',
              'rollingWindow': 'Rolling weight 95 100 g above target.',
              'latestChange': 'Down 1 kg.',
              'coverage': '3 weigh-ins.',
              'nextActions': {'now': <Object?>[], 'later': <Object?>[]},
            },
          },
        ),
      ],
      manager: manager,
    );
    expect(gated.hasReport, isTrue);
  });

  test('the reply carries a banner request in any language', () async {
    // The regex detector reads English only, and a wake whose ad tools were
    // withheld cannot carry the intent through a typed create_goal_ad call.
    // Without this the German request below would silently get no banner.
    await strategy.processToolCalls(
      toolCalls: [
        _call(
          name: GoalAgentToolNames.replyToUser,
          args: {
            'message': 'Alles klar — ein neues Banner kommt.',
            'userAskedForBanner': true,
          },
        ),
      ],
      manager: manager,
    );
    expect(strategy.bannerRequested, isTrue);
    expect(strategy.replyToUser, 'Alles klar — ein neues Banner kommt.');
  });

  test('an ordinary reply declares no banner request', () async {
    // Absent and false must both mean "not asked": the flag may only ever
    // widen what the deterministic tier permits, never by omission.
    await strategy.processToolCalls(
      toolCalls: [
        _call(
          name: GoalAgentToolNames.replyToUser,
          args: {'message': 'Du liegst diese Woche knapp darunter.'},
        ),
      ],
      manager: manager,
    );
    expect(strategy.bannerRequested, isFalse);

    final explicitFalse = GoalAgentStrategy(
      syncService: syncService,
      agentId: 'goal-1',
      threadId: 'thread-1',
      runKey: 'run-1',
      knownAdIds: const {},
    );
    await explicitFalse.processToolCalls(
      toolCalls: [
        _call(
          name: GoalAgentToolNames.replyToUser,
          args: {'message': 'Noch nicht.', 'userAskedForBanner': false},
        ),
      ],
      manager: manager,
    );
    expect(explicitFalse.bannerRequested, isFalse);
  });

  test('a report with no aggregates to quote is left alone', () async {
    // An empty window has no mean, and an insufficientData report names the
    // gap. Demanding a number there would force the model to invent one.
    final ungated = GoalAgentStrategy(
      syncService: syncService,
      agentId: 'goal-1',
      threadId: 'thread-1',
      runKey: 'run-1',
      knownAdIds: const {},
    );
    await ungated.processToolCalls(
      toolCalls: [
        _call(
          name: GoalAgentToolNames.updateGoalReport,
          args: {
            'status': 'insufficientData',
            'oneLiner': 'No readings yet.',
            'report': {
              'tldr': 'No readings yet.',
              'currentPeriod': 'Nothing logged.',
              'rollingWindow': 'The window holds no observations.',
              'latestChange': '',
              'coverage': 'No coverage.',
              'nextActions': {'now': <Object?>[], 'later': <Object?>[]},
            },
          },
        ),
      ],
      manager: manager,
    );
    expect(ungated.reportStatus, GoalTrackStatus.insufficientData);
  });

  test('a status outside the enum is rejected in-conversation, so the '
      'report stays unset for the forced retry', () async {
    await strategy.processToolCalls(
      toolCalls: [
        _call(
          name: GoalAgentToolNames.updateGoalReport,
          args: {'status': 'doomed', 'oneLiner': 'x', 'tldr': 'y'},
        ),
      ],
      manager: manager,
    );
    expect(strategy.hasReport, isFalse);
    expect(rejection(), contains('update_goal_report needs status'));
  });

  test('create_goal_ad builds a typed brief with preset fallbacks', () async {
    await strategy.processToolCalls(
      toolCalls: [
        _call(
          name: GoalAgentToolNames.createGoalAd,
          args: {
            'headline': 'Your shoes filed a missing person report.',
            'tagline': 'Six days. Zero gym.',
            'cta': 'Lace up now',
            'tone': 'nudge',
            'animation': 'typewriter',
            // No accent: the calm default must apply.
          },
        ),
      ],
      manager: manager,
    );
    final ad = strategy.createdAds.single;
    expect(ad.brief.headline, 'Your shoes filed a missing person report.');
    expect(ad.brief.tone, NudgeTone.nudge);
    expect(ad.brief.animation, NudgeBannerAnimation.typewriter);
    expect(ad.brief.accent, NudgeBannerAccent.calm);
    expect(ad.brief.cta, 'Lace up now');
  });

  test('an invented animation preset is rejected — the catalog is '
      'code-owned', () async {
    await strategy.processToolCalls(
      toolCalls: [
        _call(
          name: GoalAgentToolNames.createGoalAd,
          args: {'headline': 'x', 'tone': 'nudge', 'animation': 'explode'},
        ),
      ],
      manager: manager,
    );
    expect(strategy.createdAds, isEmpty);
    expect(rejection(), contains('animation'));
  });

  test('retire/rerun accept only adIds offered in FACTS', () async {
    await strategy.processToolCalls(
      toolCalls: [
        _call(
          id: 'call-a',
          name: GoalAgentToolNames.retireGoalAd,
          args: {'adId': 'ad-known', 'reason': 'back on pace'},
        ),
        _call(
          id: 'call-b',
          name: GoalAgentToolNames.rerunGoalAd,
          args: {'adId': 'ad-hallucinated', 'reason': 'it was great'},
        ),
      ],
      manager: manager,
    );
    expect(strategy.retireRequests.single.adId, 'ad-known');
    expect(strategy.rerunRequests, isEmpty);
    expect(rejection(), contains('unknown adId'));
  });

  test('rerun rejects an active ad instead of acknowledging a no-op', () async {
    await strategy.processToolCalls(
      toolCalls: [
        _call(
          id: 'retire-active',
          name: GoalAgentToolNames.retireGoalAd,
          args: {'adId': 'ad-known', 'reason': 'replace it'},
        ),
        _call(
          id: 'rerun-active',
          name: GoalAgentToolNames.rerunGoalAd,
          args: {'adId': 'ad-known', 'reason': 'run it again'},
        ),
      ],
      manager: manager,
    );

    expect(strategy.retireRequests, hasLength(1));
    expect(strategy.rerunRequests, isEmpty);
    expect(rejection(), contains('already active'));
    expect(
      strategy.unresolvedRejectedTools,
      contains(GoalAgentToolNames.rerunGoalAd),
    );
  });

  test(
    'an accepted ad mutation does not erase a different rejection',
    () async {
      await withClock(
        Clock.fixed(DateTime.utc(2026, 8, 11, 12)),
        () => strategy.processToolCalls(
          toolCalls: [
            _call(
              id: 'bad-snooze',
              name: GoalAgentToolNames.snoozeGoalAd,
              args: {
                'adId': 'ad-known',
                'until': '2026-08-11T10:00:00Z',
                'reason': 'too late',
              },
            ),
            _call(
              id: 'valid-create',
              name: GoalAgentToolNames.createGoalAd,
              args: {
                'headline': 'Try again today.',
                'tone': 'nudge',
                'animation': 'steady',
              },
            ),
          ],
          manager: manager,
        ),
      );

      expect(strategy.createdAds, hasLength(1));
      expect(
        strategy.unresolvedRejectedTools,
        contains(GoalAgentToolNames.snoozeGoalAd),
      );
    },
  );

  test('snooze accepts any requested future instant for a known ad', () async {
    final now = DateTime.utc(2026, 8, 11, 12);
    await withClock(
      Clock.fixed(now),
      () => strategy.processToolCalls(
        toolCalls: [
          _call(
            name: GoalAgentToolNames.snoozeGoalAd,
            args: {
              'adId': 'ad-known',
              'until': '2026-08-12T08:30:00+02:00',
              'reason': 'user asked for tomorrow morning',
            },
          ),
        ],
        manager: manager,
      ),
    );

    final request = strategy.snoozeRequests.single;
    expect(request.adId, 'ad-known');
    expect(request.until, DateTime.utc(2026, 8, 12, 6, 30));
    expect(request.returnUtcOffsetMinutes, 120);
    expect(request.reason, 'user asked for tomorrow morning');
  });

  test('identical snooze requests are accumulated only once', () async {
    final now = DateTime.utc(2026, 8, 11, 12);
    await withClock(
      Clock.fixed(now),
      () => strategy.processToolCalls(
        toolCalls: [
          _call(
            name: GoalAgentToolNames.snoozeGoalAd,
            args: {
              'adId': 'ad-known',
              'until': '2026-08-12T08:30:00+02:00',
              'reason': 'first request',
            },
          ),
          _call(
            name: GoalAgentToolNames.snoozeGoalAd,
            args: {
              'adId': 'ad-known',
              'until': '2026-08-12T08:30:00+02:00',
              'reason': 'repeated request',
            },
          ),
        ],
        manager: manager,
      ),
    );

    expect(strategy.snoozeRequests, hasLength(1));
    expect(strategy.snoozeRequests.single.reason, 'first request');
  });

  test(
    'snooze rejects offsets outside the DateTime timezone contract',
    () async {
      await withClock(
        Clock.fixed(DateTime.utc(2026, 8, 11, 12)),
        () => strategy.processToolCalls(
          toolCalls: [
            _call(
              name: GoalAgentToolNames.snoozeGoalAd,
              args: {
                'adId': 'ad-known',
                'until': '2026-08-12T08:30:00+14:30',
                'reason': 'invalid offset',
              },
            ),
          ],
          manager: manager,
        ),
      );

      expect(strategy.snoozeRequests, isEmpty);
      expect(rejection(), contains('explicit UTC offset'));
    },
  );

  test('snooze rejects future timestamps without an explicit offset', () async {
    await withClock(
      Clock.fixed(DateTime.utc(2026, 8, 11, 12)),
      () => strategy.processToolCalls(
        toolCalls: [
          _call(
            name: GoalAgentToolNames.snoozeGoalAd,
            args: {
              'adId': 'ad-known',
              'until': '2026-08-12T08:30:00',
              'reason': 'ambiguous local time',
            },
          ),
        ],
        manager: manager,
      ),
    );

    expect(strategy.snoozeRequests, isEmpty);
    expect(rejection(), contains('explicit UTC offset'));
  });

  test('snooze rejects past deadlines and unknown ads', () async {
    await withClock(
      Clock.fixed(DateTime.utc(2026, 8, 11, 12)),
      () => strategy.processToolCalls(
        toolCalls: [
          _call(
            id: 'past',
            name: GoalAgentToolNames.snoozeGoalAd,
            args: {
              'adId': 'ad-known',
              'until': '2026-08-11T11:59:00Z',
              'reason': 'past',
            },
          ),
          _call(
            id: 'unknown',
            name: GoalAgentToolNames.snoozeGoalAd,
            args: {
              'adId': 'invented',
              'until': '2026-08-11T13:00:00Z',
              'reason': 'later',
            },
          ),
        ],
        manager: manager,
      ),
    );

    expect(strategy.snoozeRequests, isEmpty);
    expect(rejection(), contains('unknown adId'));
  });

  test('snooze rejects a known reusable ad that is not active', () async {
    final activeOnly = GoalAgentStrategy(
      syncService: syncService,
      agentId: 'goal-1',
      threadId: 'thread-1',
      runKey: 'run-1',
      knownAdIds: const {'ad-active', 'ad-reusable'},
      activeAdIds: const {'ad-active'},
    );

    await withClock(
      Clock.fixed(DateTime.utc(2026, 8, 11, 12)),
      () => activeOnly.processToolCalls(
        toolCalls: [
          _call(
            name: GoalAgentToolNames.snoozeGoalAd,
            args: {
              'adId': 'ad-reusable',
              'until': '2026-08-11T13:00:00Z',
              'reason': 'hide it',
            },
          ),
        ],
        manager: manager,
      ),
    );

    expect(activeOnly.snoozeRequests, isEmpty);
    expect(rejection(), contains('is not active'));
  });

  test('only ONE revision proposal per wake is accepted', () async {
    for (final (id, target) in [('call-a', 12000), ('call-b', 8000)]) {
      await strategy.processToolCalls(
        toolCalls: [
          _call(
            id: id,
            name: GoalAgentToolNames.proposeGoalRevision,
            args: {
              'changes': {'targetValue': target},
              'rationale': 'user asked',
            },
          ),
        ],
        manager: manager,
      );
    }
    expect(strategy.revisionProposals, hasLength(1));
    expect(strategy.revisionProposals.single.changes['targetValue'], 12000);
    expect(rejection(), contains('only one revision proposal'));
  });

  test('observations and unknown tools', () async {
    await strategy.processToolCalls(
      toolCalls: [
        _call(
          id: 'call-a',
          name: GoalAgentToolNames.recordGoalObservation,
          args: {'note': 'User prefers roast-tone ads.'},
        ),
        _call(id: 'call-b', name: 'made_up_tool', args: {}),
      ],
      manager: manager,
    );
    expect(strategy.observations.single.text, 'User prefers roast-tone ads.');
    expect(rejection(), contains('unknown tool'));
  });

  test('the continuation prompt never nags — a no-op wake stays legal '
      '(policy row P2)', () {
    expect(strategy.getContinuationPrompt(manager), isNull);
  });

  test(
    'unparseable tool arguments are reported back, not crashed on',
    () async {
      await strategy.processToolCalls(
        toolCalls: [
          const ChatCompletionMessageToolCall(
            id: 'call-raw',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: GoalAgentToolNames.updateGoalReport,
              arguments: '{not json',
            ),
          ),
        ],
        manager: manager,
      );
      expect(strategy.hasReport, isFalse);
      expect(rejection(), contains('invalid arguments format'));
    },
  );

  test('ad actions need both adId and reason; a changes payload must be an '
      'object', () async {
    await strategy.processToolCalls(
      toolCalls: [
        _call(
          id: 'c1',
          name: GoalAgentToolNames.retireGoalAd,
          args: {'adId': 'ad-known', 'reason': '  '},
        ),
        _call(
          id: 'c2',
          name: GoalAgentToolNames.proposeGoalRevision,
          args: {'changes': 'make it easier', 'rationale': 'r'},
        ),
        _call(
          id: 'c3',
          name: GoalAgentToolNames.recordGoalObservation,
          args: {'note': '   '},
        ),
      ],
      manager: manager,
    );
    expect(strategy.retireRequests, isEmpty);
    expect(strategy.revisionProposals, isEmpty);
    expect(strategy.observations, isEmpty);
  });

  test('shouldContinue delegates to the manager and the final response '
      'keeps only non-empty text', () {
    when(manager.canContinue).thenReturn(true);
    expect(strategy.shouldContinue(manager), isTrue);
    strategy
      ..recordFinalResponse('')
      ..recordFinalResponse(null);
    expect(strategy.finalResponse, isNull);
    strategy.recordFinalResponse('Answered the user.');
    expect(strategy.finalResponse, 'Answered the user.');
  });
}
