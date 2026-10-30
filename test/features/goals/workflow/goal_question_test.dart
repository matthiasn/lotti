import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/classes/nudge_models.dart';
import 'package:lotti/features/goals/workflow/goal_question.dart';
import 'package:lotti/features/nudges/logic/nudge_private_copy.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  group('parseGoalQuestion', () {
    test('takes one short question, with or without a banner', () {
      final plain = parseGoalQuestion({'question': '  How did it go?  '});
      expect(plain.request?.question, 'How did it go?');
      expect(plain.request?.banner, isNull);

      final withBanner = parseGoalQuestion({
        'question': 'Did you get to scout the ridge?',
        'banner': {
          'headline': '  Did the physio clear the ridge walk?  ',
          'tone': 'encourage',
          'animation': 'steady',
        },
      });
      expect(withBanner.request?.banner, (
        headline: 'Did the physio clear the ridge walk?',
        tagline: null,
        tone: NudgeTone.encourage,
        animation: NudgeBannerAnimation.steady,
        accent: NudgeBannerAccent.calm,
      ));
    });

    test('refuses an empty or long question, a malformed banner, and a '
        'roasting one', () {
      expect(parseGoalQuestion({'question': ' '}).error, contains('non-empty'));
      expect(
        parseGoalQuestion({
          'question': 'x' * (goalQuestionMaxLength + 1),
        }).error,
        contains('at most $goalQuestionMaxLength'),
      );
      expect(
        parseGoalQuestion({'question': 'Hi?', 'banner': 'yes'}).error,
        contains('must be an object'),
      );
      expect(
        parseGoalQuestion({
          'question': 'Hi?',
          'banner': {'headline': ' ', 'tone': 'nudge', 'animation': 'steady'},
        }).error,
        contains('non-empty headline'),
      );
      expect(
        parseGoalQuestion({
          'question': 'Hi?',
          'banner': {'headline': 'Hey', 'tone': 'roast', 'animation': 'steady'},
        }).error,
        contains('never roasts'),
      );
    });
  });

  group('goalQuestionAllowed', () {
    final now = DateTime(2026, 8, 13, 20);

    bool allowed({
      bool interactive = false,
      int newCheckIns = 1,
      GoalOpenQuestion? latest,
    }) => goalQuestionAllowed(
      interactive: interactive,
      newCheckIns: newCheckIns,
      latest: latest,
      now: now,
    );

    test('asks only after something new was said, on an automatic wake', () {
      expect(allowed(), isTrue);
      expect(allowed(newCheckIns: 0), isFalse);
      expect(allowed(interactive: true), isFalse);
    });

    test('never while the last question waits, nor twice in a day', () {
      expect(
        allowed(latest: (askedAt: DateTime(2026, 8, 12, 9), answered: false)),
        isFalse,
      );
      expect(
        allowed(latest: (askedAt: DateTime(2026, 8, 13, 8), answered: true)),
        isFalse,
      );
      expect(
        allowed(latest: (askedAt: DateTime(2026, 8, 12, 21), answered: true)),
        isTrue,
      );
    });
  });

  test('the marker is a question id, never a user turn id', () {
    expect(isGoalQuestionOperationId(goalQuestionOperationId('run-1')), isTrue);
    expect(isGoalQuestionOperationId('chat-message-1'), isFalse);
    expect(isGoalQuestionOperationId(null), isFalse);
  });

  group('persistGoalQuestion', () {
    late MockAgentSyncService sync;
    late List<AgentDomainEntity> written;

    setUp(() {
      sync = MockAgentSyncService();
      written = [];
      when(() => sync.upsertEntity(any())).thenAnswer((invocation) async {
        written.add(invocation.positionalArguments.first as AgentDomainEntity);
      });
    });

    Future<void> persist({
      GoalQuestionBanner? banner,
      bool raiseBanner = true,
      Set<String> existing = const {},
    }) => persistGoalQuestion(
      sync,
      request: GoalQuestionRequest(
        question: 'Did you get to scout the ridge?',
        banner: banner,
      ),
      agentId: 'goal-1',
      runKey: 'run-1',
      threadId: 'thread-1',
      periodKey: '2026-08-13',
      specVersionId: 'goal-1:spec-v1',
      now: DateTime.utc(2026, 8, 13, 20),
      bannerLifetime: const Duration(hours: 72),
      raiseBanner: raiseBanner,
      existingNudgeIds: existing,
      briefDigest: (brief) => 'digest-${brief.headline}',
      bannerCopy: () =>
          (headline: 'Your agent has a question', cta: 'Answer in chat'),
    );

    const GoalQuestionBanner banner = (
      headline: 'Did the physio clear the ridge walk?',
      tagline: 'You wanted to know before Saturday.',
      tone: NudgeTone.encourage,
      animation: NudgeBannerAnimation.steady,
      accent: NudgeBannerAccent.aurora,
    );

    test('writes the question as an agent chat message marked as a question, '
        'and its banner pointing back at it', () async {
      await persist(banner: banner);

      final message = written.whereType<AgentMessageEntity>().single;
      expect(message.id, goalQuestionMessageId('goal-1', 'run-1'));
      expect(message.kind, AgentMessageKind.action);
      expect(
        message.metadata.toolName,
        AgentConversationToolNames.replyToUser,
      );
      expect(message.metadata.operationId, goalQuestionOperationId('run-1'));
      final payload = written.whereType<AgentMessagePayloadEntity>().single;
      expect(payload.content['text'], 'Did you get to scout the ridge?');

      final nudge = written.whereType<GoalNudgeEntity>().single;
      expect(nudge.status, NudgeStatus.active);
      // The brief holds words safe anywhere; the model's ride beside it,
      // shown only while private entries are.
      expect(nudge.brief.headline, 'Your agent has a question');
      expect(nudge.brief.cta, 'Answer in chat');
      expect(nudge.brief.tagline, isNull);
      expect(
        nudge.provenance[nudgePrivateHeadlineKey],
        'Did the physio clear the ridge walk?',
      );
      expect(
        nudge.provenance[nudgePrivateTaglineKey],
        'You wanted to know before Saturday.',
      );
      expect(nudge.brief.tone, NudgeTone.encourage);
      expect(nudge.brief.accent, NudgeBannerAccent.aurora);
      expect(isGoalQuestionNudge(nudge), isTrue);
      expect(nudge.provenance[goalNudgeQuestionMessageKey], message.id);
      // About words, not numbers: no digest for evidence to expire it by.
      expect(nudge.provenance.containsKey('factsDigest'), isFalse);
      expect(nudge.staleAt, DateTime.utc(2026, 8, 16, 20));
    });

    test('raises no banner when told not to, when none was asked for, or when '
        "the day's question banner exists", () async {
      await persist(banner: banner, raiseBanner: false);
      await persist();
      await persist(
        banner: banner,
        existing: {
          goalQuestionNudgeId(
            agentId: 'goal-1',
            periodKey: '2026-08-13',
            specVersionId: 'goal-1:spec-v1',
          ),
        },
      );

      expect(written.whereType<GoalNudgeEntity>(), isEmpty);
      expect(written.whereType<AgentMessageEntity>(), hasLength(3));
    });
  });
}
