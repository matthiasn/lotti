import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_nudge_models.dart';
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
      expect(
        strategy.reportTldr,
        'Blood pressure logging is complete today at 125/84.\n\n'
        'Rolling averages remain above target at 127/89.\n\n'
        'Blood pressure improved from 129/94 to 125/84.\n\n'
        'Two readings make the series sparse.\n\n'
        'Keep taking the medication tomorrow.',
      );
      expect(strategy.reportContent, isNull);
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

      expect(gated.reportTldr, contains('Log weight today.'));
      expect(gated.reportTldr, isNot(contains('Take medication today.')));
    },
  );

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
    expect(ad.brief.tone, GoalNudgeTone.nudge);
    expect(ad.brief.animation, GoalBannerAnimation.typewriter);
    expect(ad.brief.accent, GoalBannerAccent.calm);
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
      expect(rejection(), contains('ISO 8601'));
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
    expect(rejection(), contains('ISO 8601'));
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
    expect(rejection(), contains('is not active'));
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
