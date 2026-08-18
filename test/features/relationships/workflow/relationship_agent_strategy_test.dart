import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/nudge_models.dart';
import 'package:lotti/features/relationships/model/relationship_health_metrics.dart';
import 'package:lotti/features/relationships/workflow/relationship_agent_contract.dart';
import 'package:lotti/features/relationships/workflow/relationship_agent_strategy.dart';
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

Map<String, dynamic> _reportArgs({
  String band = 'steady',
  String rationale = 'Recent calls felt warm, per your sentiments.',
  String oneLiner = 'Things are in a good rhythm with Anna.',
  String tldr = 'You spoke four days ago; the tone has been warm.',
  String content = 'Full briefing: last call covered her job search…',
  Object? confidence,
}) => {
  'healthBand': band,
  'healthRationale': rationale,
  'oneLiner': oneLiner,
  'tldr': tldr,
  'content': content,
  'healthConfidence': ?confidence,
};

void main() {
  late MockAgentSyncService syncService;
  late MockConversationManager manager;
  late RelationshipAgentStrategy strategy;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    syncService = MockAgentSyncService();
    manager = MockConversationManager();
    when(() => syncService.upsertEntity(any())).thenAnswer((_) async {});
    strategy = RelationshipAgentStrategy(
      syncService: syncService,
      agentId: 'relationship_agent:person-1',
      threadId: 'thread-1',
      runKey: 'run-1',
      activeAdIds: {'ad-live'},
    );
  });

  String lastResponse() =>
      (verify(
            () => manager.addToolResponse(
              toolCallId: any(named: 'toolCallId'),
              response: captureAny(named: 'response'),
            ),
          ).captured.last)
          as String;

  group('update_relationship_report', () {
    test('accumulates the full briefing with band and confidence', () async {
      await strategy.processToolCalls(
        toolCalls: [
          _call(
            name: RelationshipAgentToolNames.updateRelationshipReport,
            args: _reportArgs(confidence: 0.9),
          ),
        ],
        manager: manager,
      );
      final briefing = strategy.briefing!;
      expect(briefing.band, RelationshipHealthBand.steady);
      expect(briefing.confidence, 0.9);
      expect(briefing.tldr, contains('four days ago'));
      expect(strategy.hasBriefing, isTrue);
    });

    test('rejects an unknown band or missing slots', () async {
      await strategy.processToolCalls(
        toolCalls: [
          _call(
            name: RelationshipAgentToolNames.updateRelationshipReport,
            args: _reportArgs(band: 'flourishing'),
          ),
        ],
        manager: manager,
      );
      expect(strategy.hasBriefing, isFalse);
      expect(lastResponse(), contains('healthBand'));
    });

    test('the camelCase band token is banned from prose, while ordinary '
        'English band words stay legal', () async {
      await strategy.processToolCalls(
        toolCalls: [
          _call(
            name: RelationshipAgentToolNames.updateRelationshipReport,
            args: _reportArgs(
              tldr: 'This relationship is needsAttention right now.',
            ),
          ),
        ],
        manager: manager,
      );
      expect(strategy.hasBriefing, isFalse);
      expect(lastResponse(), contains('needsAttention'));

      // "steady" is an ordinary word a legitimate briefing may contain.
      await strategy.processToolCalls(
        toolCalls: [
          _call(
            name: RelationshipAgentToolNames.updateRelationshipReport,
            args: _reportArgs(
              tldr: 'A steady rhythm of calls has held all month.',
            ),
          ),
        ],
        manager: manager,
      );
      expect(strategy.hasBriefing, isTrue);
    });

    test('an out-of-range confidence is dropped, not clamped', () async {
      await strategy.processToolCalls(
        toolCalls: [
          _call(
            name: RelationshipAgentToolNames.updateRelationshipReport,
            args: _reportArgs(confidence: 3),
          ),
        ],
        manager: manager,
      );
      expect(strategy.briefing!.confidence, isNull);
    });
  });

  group('reply_to_user', () {
    test('captures exactly one visible answer', () async {
      await strategy.processToolCalls(
        toolCalls: [
          _call(
            name: RelationshipAgentToolNames.replyToUser,
            args: {'message': 'You last spoke five weeks ago.'},
          ),
          _call(
            name: RelationshipAgentToolNames.replyToUser,
            args: {'message': 'Second answer.'},
            id: 'call-2',
          ),
        ],
        manager: manager,
      );
      expect(strategy.replyToUser, 'You last spoke five weeks ago.');
      expect(lastResponse(), contains('at most once'));
    });
  });

  group('create_relationship_ad', () {
    test('accumulates the brief with the calm default accent', () async {
      await strategy.processToolCalls(
        toolCalls: [
          _call(
            name: RelationshipAgentToolNames.createRelationshipAd,
            args: {
              'headline': "Check in with Anna — it's been 5 weeks.",
              'tagline': 'Last time: her job search.',
              'tone': 'nudge',
              'animation': 'steady',
            },
          ),
        ],
        manager: manager,
      );
      final ad = strategy.createdAds.single;
      expect(ad.brief.headline, contains('5 weeks'));
      expect(ad.brief.accent, NudgeBannerAccent.calm);
      expect(ad.brief.tagline, 'Last time: her job search.');
    });

    test(
      'rejects a second create in-conversation — only one banner can '
      'persist per wake, so a repeat must not be confirmed as queued',
      () async {
        await strategy.processToolCalls(
          toolCalls: [
            _call(
              name: RelationshipAgentToolNames.createRelationshipAd,
              args: {
                'headline': 'Call Anna.',
                'tone': 'nudge',
                'animation': 'steady',
              },
            ),
            _call(
              name: RelationshipAgentToolNames.createRelationshipAd,
              args: {
                'headline': 'A second, silently-dropped banner.',
                'tone': 'nudge',
                'animation': 'steady',
              },
              id: 'call-2',
            ),
          ],
          manager: manager,
        );
        expect(strategy.createdAds, hasLength(1));
        expect(strategy.createdAds.single.brief.headline, 'Call Anna.');
        expect(lastResponse(), contains('at most once'));
      },
    );

    test('rejects a missing headline or foreign preset', () async {
      await strategy.processToolCalls(
        toolCalls: [
          _call(
            name: RelationshipAgentToolNames.createRelationshipAd,
            args: {'headline': '', 'tone': 'nudge', 'animation': 'steady'},
          ),
          _call(
            name: RelationshipAgentToolNames.createRelationshipAd,
            args: {
              'headline': 'Call Anna.',
              'tone': 'sarcastic',
              'animation': 'steady',
            },
            id: 'call-2',
          ),
        ],
        manager: manager,
      );
      expect(strategy.createdAds, isEmpty);
    });
  });

  group('snooze_relationship_ad', () {
    test('accumulates a valid snooze of an active banner', () async {
      await withClock(Clock.fixed(DateTime.utc(2026, 8, 16, 12)), () async {
        await strategy.processToolCalls(
          toolCalls: [
            _call(
              name: RelationshipAgentToolNames.snoozeRelationshipAd,
              args: {
                'adId': 'ad-live',
                'until': '2026-08-16T18:00:00+02:00',
                'reason': 'meeting all afternoon',
              },
            ),
          ],
          manager: manager,
        );
        final snooze = strategy.snoozeRequests.single;
        expect(snooze.adId, 'ad-live');
        expect(snooze.until, DateTime.utc(2026, 8, 16, 16));
        expect(snooze.returnUtcOffsetMinutes, 120);
      });
    });

    test(
      'rejects a past instant, a missing offset, and a non-active id',
      () async {
        await withClock(Clock.fixed(DateTime.utc(2026, 8, 16, 12)), () async {
          await strategy.processToolCalls(
            toolCalls: [
              _call(
                name: RelationshipAgentToolNames.snoozeRelationshipAd,
                args: {
                  'adId': 'ad-live',
                  'until': '2026-08-16T10:00:00Z',
                  'reason': 'past',
                },
              ),
              _call(
                name: RelationshipAgentToolNames.snoozeRelationshipAd,
                args: {
                  'adId': 'ad-live',
                  'until': '2026-08-16T18:00:00',
                  'reason': 'zone-free',
                },
                id: 'call-2',
              ),
              _call(
                name: RelationshipAgentToolNames.snoozeRelationshipAd,
                args: {
                  'adId': 'ad-unknown',
                  'until': '2026-08-16T18:00:00Z',
                  'reason': 'foreign id',
                },
                id: 'call-3',
              ),
            ],
            manager: manager,
          );
          expect(strategy.snoozeRequests, isEmpty);
        });
      },
    );

    test(
      'an identical repeated snooze is deduplicated, not queued twice',
      () async {
        await withClock(Clock.fixed(DateTime.utc(2026, 8, 16, 12)), () async {
          final call = _call(
            name: RelationshipAgentToolNames.snoozeRelationshipAd,
            args: {
              'adId': 'ad-live',
              'until': '2026-08-16T18:00:00+02:00',
              'reason': 'meeting all afternoon',
            },
          );
          await strategy.processToolCalls(
            toolCalls: [call, call],
            manager: manager,
          );
          expect(strategy.snoozeRequests, hasLength(1));
        });
      },
    );
  });

  test('the conversation contract: continue while the manager can, and '
      'never nag for output via a continuation prompt', () {
    when(manager.canContinue).thenReturn(true);
    expect(strategy.shouldContinue(manager), isTrue);
    when(manager.canContinue).thenReturn(false);
    expect(strategy.shouldContinue(manager), isFalse);
    expect(strategy.getContinuationPrompt(manager), isNull);
  });

  test('an empty reply_to_user is rejected — a blank visible turn is '
      'worse than none', () async {
    await strategy.processToolCalls(
      toolCalls: [
        _call(
          name: RelationshipAgentToolNames.replyToUser,
          args: {'message': '   '},
        ),
      ],
      manager: manager,
    );
    expect(strategy.replyToUser, isNull);
    expect(lastResponse(), contains('non-empty message'));
  });

  test('an unknown tool and malformed arguments are rejected without '
      'derailing the wake', () async {
    await strategy.processToolCalls(
      toolCalls: [
        _call(name: 'delete_relationship', args: {'id': 'person-1'}),
        const ChatCompletionMessageToolCall(
          id: 'call-2',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: RelationshipAgentToolNames.replyToUser,
            arguments: 'not json',
          ),
        ),
      ],
      manager: manager,
    );
    expect(strategy.replyToUser, isNull);
    expect(strategy.createdAds, isEmpty);
  });

  test('recordFinalResponse keeps the last assistant text as the fallback '
      'reply carrier', () {
    strategy
      ..recordFinalResponse('')
      ..recordFinalResponse('Visible fallback.');
    expect(strategy.finalResponse, 'Visible fallback.');
  });
}
