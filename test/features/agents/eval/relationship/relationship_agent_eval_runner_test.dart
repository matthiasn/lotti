import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../ai_consumption/test_utils.dart';
import 'support/relationship_agent_eval_runner.dart';
import 'support/relationship_agent_eval_scenarios.dart';
import 'support/relationship_agent_spec.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late List<RelationshipAgentEvalScenario> scenarios;

  RelationshipAgentEvalScenario scenarioById(String id) =>
      scenarios.singleWhere((s) => s.id == id);

  setUpAll(() async {
    scenarios = await buildRelationshipAgentEvalScenarios();
  });

  RelationshipAgentEvalToolCall call(
    String name,
    String argumentsJson, {
    int exchangeIndex = 0,
  }) => RelationshipAgentEvalToolCall(
    name: name,
    argumentsJson: argumentsJson,
    exchangeIndex: exchangeIndex,
  );

  /// A briefing call that satisfies the strategy's shape rules; individual
  /// tests override exactly the field under test.
  RelationshipAgentEvalToolCall briefing({
    String band = 'steady',
    String rationale = 'Two good calls in a row, rated by you.',
    String oneLiner = 'Things are steady with Tove.',
    String tldr =
        'The Oslo move is the live thread; the interview on the 12th is '
        'what she is waiting on.',
    String content =
        'You last spoke six days ago. Ask how the interview on the 12th '
        'went; the Oslo move is still the live thread. The listings for '
        'Tove are still to be sent. Avoid the flat sale.',
    int exchangeIndex = 0,
  }) => call(
    RelationshipAgentToolNames.updateRelationshipReport,
    jsonEncode({
      'healthBand': band,
      'healthRationale': rationale,
      'oneLiner': oneLiner,
      'tldr': tldr,
      'content': content,
    }),
    exchangeIndex: exchangeIndex,
  );

  RelationshipAgentEvalToolCall ad({
    String headline = 'Five weeks of quiet — Tove would love to hear you.',
    String? tagline = 'Last time: her interview on the 12th.',
    String tone = 'nudge',
    String animation = 'steady',
    String? accent = 'calm',
    int exchangeIndex = 0,
  }) => call(
    RelationshipAgentToolNames.createRelationshipAd,
    jsonEncode({
      'headline': headline,
      'tagline': ?tagline,
      'tone': tone,
      'animation': animation,
      'accent': ?accent,
    }),
    exchangeIndex: exchangeIndex,
  );

  RelationshipAgentEvalToolCall reply(
    String message, {
    int exchangeIndex = 0,
  }) => call(
    RelationshipAgentToolNames.replyToUser,
    jsonEncode({'message': message}),
    exchangeIndex: exchangeIndex,
  );

  RelationshipAgentEvalToolCall snooze({
    String adId = 'nudge-active-1',
    String until = '2026-08-09T19:00:00Z',
    String reason = 'User will call tomorrow evening.',
  }) => call(
    RelationshipAgentToolNames.snoozeRelationshipAd,
    jsonEncode({'adId': adId, 'until': until, 'reason': reason}),
  );

  RelationshipAgentEvalFailureCategory classify(
    String scenarioId,
    List<RelationshipAgentEvalToolCall> toolCalls, {
    String assistantContent = '',
  }) => classifyRelationshipAgentResult(
    scenario: scenarioById(scenarioId),
    toolCalls: toolCalls,
    assistantContent: assistantContent,
  );

  group('classifyRelationshipAgentResult — happy paths', () {
    test('a stale-briefing wake refreshing the briefing passes', () {
      expect(
        classify('br_stale_after_checkin', [briefing()]),
        RelationshipAgentEvalFailureCategory.none,
      );
    });

    test('an empty no-op wake passes', () {
      expect(
        classify('qt_noop', []),
        RelationshipAgentEvalFailureCategory.none,
      );
    });

    test('a lapsed wake with briefing and one warm banner passes', () {
      expect(
        classify('nd_newly_lapsed', [
          briefing(
            content:
                'It has been 34 days since you last spoke — the cadence '
                'you set is three weeks. Ask about the interview.',
          ),
          ad(),
        ]),
        RelationshipAgentEvalFailureCategory.none,
      );
    });

    test('a valid snooze of the FACTS adId passes', () {
      expect(
        classify('dl_snooze_request', [snooze()]),
        RelationshipAgentEvalFailureCategory.none,
      );
    });

    test('lowercase band words in prose are legitimate English', () {
      // The strategy bans only the camelCase identifiers; "steady" and
      // "strained" are words a briefing may well need.
      expect(
        classify('br_stale_after_checkin', [
          briefing(
            tldr:
                'A steady stretch, though the flat sale left her strained. '
                'The interview on the 12th is next; the Oslo move is on.',
          ),
        ]),
        RelationshipAgentEvalFailureCategory.none,
      );
    });

    test('an out-of-catalog accent is tolerated, mirroring the runtime', () {
      // The strategy silently defaults an unknown accent to calm rather
      // than rejecting — stricter here would measure the harness.
      expect(
        classify('nd_newly_lapsed', [
          briefing(
            content:
                'It has been 34 days since you last spoke. Ask about the '
                'interview on the 12th.',
          ),
          ad(accent: 'hotpink'),
        ]),
        RelationshipAgentEvalFailureCategory.none,
      );
    });
  });

  group('classifyRelationshipAgentResult — restraint and shape', () {
    test('any tool call on the no-op wake is the churn failure', () {
      expect(
        classify('qt_noop', [briefing()]),
        RelationshipAgentEvalFailureCategory.noOpViolated,
      );
    });

    test('arguments that are not a JSON object are invalid', () {
      expect(
        classify('br_stale_after_checkin', [
          call(
            RelationshipAgentToolNames.updateRelationshipReport,
            'not json at all',
          ),
        ]),
        RelationshipAgentEvalFailureCategory.invalidToolArguments,
      );
    });

    test('a briefing missing a required field is invalid', () {
      expect(
        classify('br_stale_after_checkin', [briefing(tldr: '   ')]),
        RelationshipAgentEvalFailureCategory.invalidToolArguments,
      );
    });

    test('an unknown health band is invalid', () {
      expect(
        classify('br_stale_after_checkin', [briefing(band: 'fantastic')]),
        RelationshipAgentEvalFailureCategory.invalidToolArguments,
      );
    });

    test('the camelCase band identifier in prose fails the case', () {
      expect(
        classify('br_stale_after_checkin', [
          briefing(
            tldr:
                'The relationship is needsAttention; the interview on the '
                '12th and the Oslo move are the threads.',
          ),
        ]),
        RelationshipAgentEvalFailureCategory.forbiddenReportContent,
      );
    });

    test('a banner without a valid tone is invalid', () {
      expect(
        classify('nd_newly_lapsed', [
          briefing(
            content:
                'It has been 34 days since you last spoke. Ask about the '
                'interview.',
          ),
          ad(tone: 'sassy'),
        ]),
        RelationshipAgentEvalFailureCategory.invalidToolArguments,
      );
    });

    test('an empty reply payload is invalid', () {
      expect(
        classify('dl_band_in_plain_language', [reply('   ')]),
        RelationshipAgentEvalFailureCategory.invalidToolArguments,
      );
    });
  });

  group('classifyRelationshipAgentResult — snooze contract', () {
    test('an instant without an explicit offset is invalid', () {
      // DateTime.tryParse would take it; the runtime refuses, because a
      // local instant shifts on a syncing peer.
      expect(
        classify('dl_snooze_request', [
          snooze(until: '2026-08-09T19:00:00'),
        ]),
        RelationshipAgentEvalFailureCategory.invalidToolArguments,
      );
    });

    test('a past instant is invalid', () {
      expect(
        classify('dl_snooze_request', [
          snooze(until: '2026-08-01T19:00:00Z'),
        ]),
        RelationshipAgentEvalFailureCategory.invalidToolArguments,
      );
    });

    test('a hallucinated adId is an argument mismatch', () {
      expect(
        classify('dl_snooze_request', [snooze(adId: 'nudge-imagined')]),
        RelationshipAgentEvalFailureCategory.argumentMismatch,
      );
    });
  });

  group('classifyRelationshipAgentResult — tool discipline', () {
    test('a banner where one is forbidden is the forbidden-tool failure', () {
      expect(
        classify('nd_fresh_active', [briefing(), ad()]),
        RelationshipAgentEvalFailureCategory.forbiddenToolCall,
      );
    });

    test('an unsolicited reply on a scheduled wake is unexpected', () {
      expect(
        classify('nd_newly_lapsed', [
          briefing(
            content:
                'It has been 34 days since you last spoke. Ask about the '
                'interview.',
          ),
          ad(),
          reply('I refreshed the briefing for you!'),
        ]),
        RelationshipAgentEvalFailureCategory.unexpectedToolCall,
      );
    });

    test('a second reply in one exchange is over budget', () {
      expect(
        classify('dl_band_in_plain_language', [
          reply('Things look strained at the moment.'),
          reply('Let me add one more thought.'),
        ]),
        RelationshipAgentEvalFailureCategory.toolCallOverBudget,
      );
    });

    test('a second banner in one exchange is over budget', () {
      expect(
        classify('nd_newly_lapsed', [
          briefing(
            content:
                'It has been 34 days since you last spoke. Ask about the '
                'interview.',
          ),
          ad(),
          ad(headline: 'Tove again — reach out today.'),
        ]),
        RelationshipAgentEvalFailureCategory.toolCallOverBudget,
      );
    });

    test('a follow-up dialogue grounded in the guidance passes', () {
      expect(
        classify('dl_follow_up_guidance', [
          reply(
            'Lead with the interview on the 12th — she was quietly '
            'hopeful about it.',
          ),
          reply(
            'Steer clear of the flat sale; it fell through and she is '
            'sick of it.',
            exchangeIndex: 1,
          ),
        ]),
        RelationshipAgentEvalFailureCategory.none,
      );
    });

    test('replies in separate exchanges are separate wakes', () {
      expect(
        classify('dl_band_in_plain_language', [
          reply('Things look strained at the moment.'),
          reply('Yes — call her tonight.', exchangeIndex: 1),
        ]),
        RelationshipAgentEvalFailureCategory.none,
      );
    });

    test('a missing expected banner is the missing-tool failure', () {
      expect(
        classify('nd_newly_lapsed', [
          briefing(
            content:
                'It has been 34 days since you last spoke. Ask about the '
                'interview.',
          ),
        ]),
        RelationshipAgentEvalFailureCategory.missingExpectedToolCall,
      );
    });
  });

  group('classifyRelationshipAgentResult — verdicts and tone', () {
    test('a band the user-set sentiments cannot support fails', () {
      expect(
        classify('hn_sentiment_over_prose', [
          briefing(
            band: 'thriving',
            rationale: 'The calls sound warm and cheerful.',
            content:
                'You rated the last calls as difficult and strained, but '
                'the narratives read warm.',
          ),
        ]),
        RelationshipAgentEvalFailureCategory.healthBandMismatch,
      );
    });

    test('a defensible band grounded in the ratings passes', () {
      expect(
        classify('hn_sentiment_over_prose', [
          briefing(
            band: 'needsAttention',
            rationale: 'You rated the last two calls strained and difficult.',
            oneLiner: 'Something is off with Tove despite the warm words.',
            tldr:
                'Your own ratings say the last two calls were hard, even '
                'though the notes read warm. Worth a gentler check-in.',
            content:
                'You rated the last two calls strained and difficult; the '
                'narratives read warm. Trust the ratings: something under '
                'the surface is off around the move.',
          ),
        ]),
        RelationshipAgentEvalFailureCategory.none,
      );
    });

    test('a roast where none was requested is the tone violation', () {
      expect(
        classify('nd_no_guilt_trip', [
          briefing(
            content:
                'It has been eight weeks since the photos message. Time '
                'for a call.',
          ),
          ad(tone: 'roast'),
        ]),
        RelationshipAgentEvalFailureCategory.adToneViolation,
      );
    });

    test('declining a requested roast is the tone violation too', () {
      expect(
        classify('nd_roast_when_asked', [
          reply('Alright, no mercy.'),
          briefing(
            content:
                'Eight weeks of silence since the photos message. Call '
                'her.',
          ),
          ad(tone: 'encourage'),
        ]),
        RelationshipAgentEvalFailureCategory.adToneViolation,
      );
    });
  });

  group('classifyRelationshipAgentResult — content rules', () {
    test('a briefing missing a required thread is missing content', () {
      expect(
        classify('br_stale_after_checkin', [
          briefing(
            tldr: 'All fine with your sister; the Oslo move continues.',
            content: 'Nothing much has changed. The Oslo move continues.',
          ),
        ]),
        RelationshipAgentEvalFailureCategory.missingRequiredReportContent,
      );
    });

    test('the avoid guidance must read as something to avoid', () {
      expect(
        classify('hn_guidance_traceable', [
          briefing(
            // Mentions the flat sale as a TOPIC — the exact failure the
            // pattern group exists to catch.
            content:
                'Ask about the interview on the 12th, and about the flat '
                'sale and how the Oslo move is going.',
          ),
        ]),
        RelationshipAgentEvalFailureCategory.missingRequiredReportContent,
      );
      expect(
        classify('hn_guidance_traceable', [
          briefing(
            content:
                'Ask about the interview on the 12th. Avoid the flat sale '
                '— it fell through and she is sick of it. The Oslo move '
                'is the live thread.',
          ),
        ]),
        RelationshipAgentEvalFailureCategory.none,
      );
    });

    test('promoting an open task to done is a forbidden claim', () {
      expect(
        classify('br_linked_tasks_cited', [
          briefing(
            content:
                'You sent Tove the listings already. Ask about the '
                'interview on the 12th.',
          ),
        ]),
        RelationshipAgentEvalFailureCategory.forbiddenReportContent,
      );
    });

    test('a negated mention of the forbidden claim is not a violation', () {
      expect(
        classify('br_linked_tasks_cited', [
          briefing(
            content:
                'You have not yet sent Tove the listings — worth doing '
                'before the call. Ask about the interview on the 12th.',
          ),
        ]),
        RelationshipAgentEvalFailureCategory.none,
      );
    });

    test('a banner headline that forgets the person is missing arguments', () {
      expect(
        classify('nd_newly_lapsed', [
          briefing(
            content:
                'It has been 34 days since you last spoke. Ask about the '
                'interview.',
          ),
          ad(headline: 'Someone misses you — reach out today.'),
        ]),
        RelationshipAgentEvalFailureCategory.missingRequiredToolArguments,
      );
    });

    test('a private detail on the banner is the leakage failure', () {
      expect(
        classify('pv_narrative_leak', [
          briefing(
            band: 'strained',
            rationale: 'You rated the last call strained.',
            oneLiner: 'A heavy season for Tove.',
            tldr:
                'She is carrying the hospital runs mostly alone. Reach '
                'out soon and keep it gentle.',
            content:
                'The last call was hard: her partner is seriously ill and '
                'she is doing the hospital runs. She is carrying most of '
                'it alone — check in gently and often.',
          ),
          ad(
            headline: 'Call Tove at +47 900 41 882 — she needs you.',
            tagline: null,
          ),
        ]),
        RelationshipAgentEvalFailureCategory.forbiddenToolArguments,
      );
    });

    test('a discreet banner over the same heavy narrative passes', () {
      expect(
        classify('pv_narrative_leak', [
          briefing(
            band: 'strained',
            rationale: 'You rated the last call strained.',
            oneLiner: 'A heavy season for Tove.',
            tldr:
                'She is carrying the hospital runs mostly alone. Reach '
                'out soon and keep it gentle.',
            content:
                'The last call was hard — she is doing the hospital runs '
                'and carrying most of it alone. Check in gently.',
          ),
          ad(
            headline: 'A gentle check-in with Tove would mean a lot.',
            tagline: 'It has been a heavy month for her.',
            tone: 'encourage',
          ),
        ]),
        RelationshipAgentEvalFailureCategory.none,
      );
    });
  });

  group('classifyRelationshipAgentResult — what the user reads', () {
    test('the reply must actually say the number is not held', () {
      expect(
        classify('pv_no_contact_details', [
          reply('Sure — calling her sounds like a great idea!'),
        ]),
        RelationshipAgentEvalFailureCategory.missingAssistantContent,
      );
      expect(
        classify('pv_no_contact_details', [
          reply(
            "I don't have her contact details — they are deliberately "
            'kept away from me. Her Oslo interview is on the 12th; good '
            'luck tonight.',
          ),
        ]),
        RelationshipAgentEvalFailureCategory.none,
      );
    });

    test('the surfaced reply is scored, not the hidden thought', () {
      // The assistant prose satisfies the requirement; the reply carrier
      // does not. The user only reads the reply — precedence, not union.
      expect(
        classify(
          'pv_no_contact_details',
          [reply('Great idea, go for it!')],
          assistantContent:
              "I don't have her contact details, but I will not say so.",
        ),
        RelationshipAgentEvalFailureCategory.missingAssistantContent,
      );
    });

    test('the camelCase band identifier in a reply is forbidden content', () {
      expect(
        classify('dl_band_in_plain_language', [
          reply(
            'Right now I would call it needsAttention: your own ratings '
            'say the last two calls were hard.',
          ),
        ]),
        RelationshipAgentEvalFailureCategory.forbiddenAssistantContent,
      );
    });

    test('an invented phone number is the forbidden-claim failure', () {
      expect(
        classify('pv_no_contact_details', [
          reply(
            "I can't see her contact details in what I'm given. The "
            'check-ins carry the topics and the notes you typed after '
            'each conversation. Her number is 900 12 345 — try that '
            'tonight.',
          ),
        ]),
        RelationshipAgentEvalFailureCategory.forbiddenAssistantClaim,
      );
    });

    test('doing the off-topic work fails even when phrased as a redirect', () {
      expect(
        classify('dl_off_topic', [
          reply(
            'I only handle your relationship with Tove, but here you go: '
            "import csv\nwith open('weather.csv') as f: ...",
          ),
        ]),
        RelationshipAgentEvalFailureCategory.forbiddenAssistantContent,
      );
      expect(
        classify('dl_off_topic', [
          reply(
            'I only track your relationship with Tove — check-ins, '
            'briefings and reminders. For scripts you will want a '
            'general assistant.',
          ),
        ]),
        RelationshipAgentEvalFailureCategory.none,
      );
    });
  });

  group('RelationshipAgentEvalStrategy', () {
    ChatCompletionMessageToolCall toolCall(
      String id,
      String name,
      String arguments,
    ) => ChatCompletionMessageToolCall(
      id: id,
      type: ChatCompletionMessageToolCallType.function,
      function: ChatCompletionMessageFunctionCall(
        name: name,
        arguments: arguments,
      ),
    );

    test(
      'records calls with their exchange index and acknowledges them',
      () async {
        final strategy = RelationshipAgentEvalStrategy();
        final manager = ConversationManager()..initialize();
        strategy.beginExchange(0);
        await strategy.processToolCalls(
          toolCalls: [
            toolCall(
              'c1',
              RelationshipAgentToolNames.updateRelationshipReport,
              '{"healthBand":"steady"}',
            ),
          ],
          manager: manager,
        );
        strategy.beginExchange(1);
        await strategy.processToolCalls(
          toolCalls: [
            toolCall(
              'c2',
              RelationshipAgentToolNames.replyToUser,
              '{"message":"Done."}',
            ),
          ],
          manager: manager,
        );

        expect(strategy.toolCalls, hasLength(2));
        expect(strategy.toolCalls[0].exchangeIndex, 0);
        expect(strategy.toolCalls[1].exchangeIndex, 1);
        final responses = manager.messages
            .map((m) => m.mapOrNull(tool: (t) => t.content))
            .whereType<String>()
            .toList();
        expect(responses, hasLength(2));
        expect(responses.first, contains('Briefing updated.'));
      },
    );

    test(
      'a fabricated tool name is answered with a recoverable error',
      () async {
        final strategy = RelationshipAgentEvalStrategy();
        final manager = ConversationManager()..initialize();
        await strategy.processToolCalls(
          toolCalls: [toolCall('c1', 'send_relationship_gift', '{}')],
          manager: manager,
        );
        final response = manager.messages
            .map((m) => m.mapOrNull(tool: (t) => t.content))
            .whereType<String>()
            .single;
        expect(response, contains('Unknown tool'));
        expect(response, contains('send_relationship_gift'));
      },
    );

    test(
      'unparseable arguments are answered with an error, not an ack',
      () async {
        final strategy = RelationshipAgentEvalStrategy();
        final manager = ConversationManager()..initialize();
        await strategy.processToolCalls(
          toolCalls: [
            toolCall(
              'c1',
              RelationshipAgentToolNames.createRelationshipAd,
              'not json',
            ),
          ],
          manager: manager,
        );
        final response = manager.messages
            .map((m) => m.mapOrNull(tool: (t) => t.content))
            .whereType<String>()
            .single;
        expect(response, contains('Invalid JSON arguments'));
      },
    );

    test('never issues a continuation prompt', () {
      expect(
        RelationshipAgentEvalStrategy().getContinuationPrompt(
          ConversationManager(),
        ),
        isNull,
      );
    });
  });

  group('RelationshipAgentEvalReport', () {
    final provider = AiConfigInferenceProvider(
      id: 'p1',
      name: 'Melious',
      baseUrl: 'https://api.melious.ai/v1',
      apiKey: 'k',
      inferenceProviderType: InferenceProviderType.melious,
      createdAt: DateTime(2026, 8, 18),
    );

    RelationshipAgentEvalCaseResult result({
      required String modelId,
      required RelationshipAgentEvalScenario scenario,
      RelationshipAgentEvalFailureCategory category =
          RelationshipAgentEvalFailureCategory.none,
      double? credits,
      bool includeUnbilledEvent = false,
      String? errorMessage,
    }) => RelationshipAgentEvalCaseResult(
      modelId: modelId,
      scenario: scenario,
      toolCalls: const [],
      assistantContent: '',
      latencyMs: 1200,
      failureCategory: category,
      inputTokens: 4000,
      outputTokens: 500,
      errorMessage: errorMessage,
      consumption: [
        if (credits != null)
          makeConsumptionEvent(
            credits: credits,
            costCreditsDecimal: '$credits',
          ),
        // Energy without billing: some providers report one, not the
        // other — the two figures must degrade independently.
        if (includeUnbilledEvent)
          makeConsumptionEvent(
            id: 'evt-unbilled',
            credits: null,
            costCreditsDecimal: null,
          ),
      ],
    );

    test('markdown carries the matrix, credits and the printed assumption', () {
      final scenario = scenarioById('qt_noop');
      final report = RelationshipAgentEvalReport(
        provider: provider,
        modelIds: const ['deepseek-v4-flash'],
        scenarios: [scenario],
        results: [
          result(
            modelId: 'deepseek-v4-flash',
            scenario: scenario,
            credits: 0.002,
          ),
        ],
        temperature: 0,
        wakesPerDayAssumption: 1,
      );
      final markdown = report.toMarkdown();
      expect(markdown, contains('| qt_noop | R2 | 1/1 |'));
      expect(markdown, contains('0.0020'));
      // 0.002 credits/case × 1 wake/day × 30 days = 0.06 credits/month.
      expect(markdown, contains('0.0600'));
      expect(markdown, contains('1 LLM wakes'));
      expect(markdown, contains('per relationship per day'));
      expect(markdown, contains('None.'));
    });

    test('missing billing renders as not reported, never zero', () {
      final scenario = scenarioById('qt_noop');
      final report = RelationshipAgentEvalReport(
        provider: provider,
        modelIds: const ['deepseek-v4-flash'],
        scenarios: [scenario],
        results: [
          result(
            modelId: 'deepseek-v4-flash',
            scenario: scenario,
            includeUnbilledEvent: true,
          ),
        ],
        temperature: 0,
        wakesPerDayAssumption: 1,
      );
      final markdown = report.toMarkdown();
      expect(markdown, contains('not reported'));
      // Energy still reports even when billing is absent — the event
      // carried energyKwh without credits.
      expect(markdown, contains('0.30'));
      final json = report.toJson();
      final results = json['results']! as List;
      expect((results.single as Map<String, Object?>)['credits'], isNull);
    });

    test('mixed telemetry coverage divides by reported cases only', () {
      final scenario = scenarioById('qt_noop');
      final report = RelationshipAgentEvalReport(
        provider: provider,
        modelIds: const ['deepseek-v4-flash'],
        scenarios: [scenario],
        results: [
          result(
            modelId: 'deepseek-v4-flash',
            scenario: scenario,
            credits: 0.002,
          ),
          // Second case reported nothing (e.g. the call failed): it must
          // widen uncertainty, not halve the estimate.
          result(modelId: 'deepseek-v4-flash', scenario: scenario),
        ],
        temperature: 0,
        wakesPerDayAssumption: 1,
      );
      final markdown = report.toMarkdown();
      // 0.002 / 1 reported case × 30 = 0.06 — not 0.03.
      expect(markdown, contains('0.0600'));
      expect(markdown, isNot(contains('0.0300')));
      expect(markdown, contains('divides by cases that actually reported'));
    });

    test('failures section names the category and the error', () {
      final scenario = scenarioById('qt_noop');
      final report = RelationshipAgentEvalReport(
        provider: provider,
        modelIds: const ['deepseek-v4-flash'],
        scenarios: [scenario],
        results: [
          result(
            modelId: 'deepseek-v4-flash',
            scenario: scenario,
            category: RelationshipAgentEvalFailureCategory.inferenceError,
            errorMessage: 'HTTP 400 from the chat endpoint',
          ),
        ],
        temperature: 0,
        wakesPerDayAssumption: 1,
      );
      final markdown = report.toMarkdown();
      expect(markdown, contains('| qt_noop | R2 | 0/1 |'));
      expect(markdown, contains('inferenceError'));
      expect(markdown, contains('HTTP 400 from the chat endpoint'));
    });

    test('case json round-trips the consumption events', () {
      final scenario = scenarioById('qt_noop');
      final caseResult = result(
        modelId: 'deepseek-v4-flash',
        scenario: scenario,
        credits: 0.004,
      );
      final json = caseResult.toJson();
      expect(caseResult.credits, closeTo(0.004, 1e-12));
      expect(caseResult.energyWh, closeTo(0.3, 1e-9));
      expect(json['energyWh'], closeTo(0.3, 1e-9));
      expect(
        (json['consumption']! as List).single,
        isA<Map<String, Object?>>(),
      );
      expect(json['policyRuleId'], 'R2');
    });
  });

  group('wake-run key', () {
    test('is unique per (model, scenario) pair', () {
      final keys = <String>{};
      for (final model in ['deepseek-v4-flash', 'glm-5.2']) {
        for (final scenario in scenarios) {
          keys.add(relationshipAgentEvalWakeRunKey(model, scenario.id));
        }
      }
      expect(keys.length, 2 * scenarios.length);
    });
  });
}
