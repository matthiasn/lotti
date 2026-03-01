import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/classified_feedback.dart';
import 'package:lotti/features/agents/workflow/evolution_context_builder.dart';
import 'package:lotti/features/agents/workflow/ritual_context_builder.dart';

import '../test_utils.dart';

void main() {
  late RitualContextBuilder builder;

  setUp(() {
    builder = RitualContextBuilder();
  });

  ClassifiedFeedback makeFeedbackWith({
    List<ClassifiedFeedbackItem>? feedbackItems,
  }) {
    return makeTestClassifiedFeedback(
      items: feedbackItems,
      windowStart: DateTime(2024, 3),
      windowEnd: DateTime(2024, 3, 15),
    );
  }

  /// Helper to reduce boilerplate — only pass the params that differ.
  EvolutionContext buildCtx({
    AgentTemplateEntity? template,
    AgentTemplateVersionEntity? currentVersion,
    List<ClassifiedFeedbackItem>? feedbackItems,
    int sessionNumber = 1,
    int changesSinceLastSession = 0,
  }) {
    return builder.buildRitualContext(
      template: template ?? makeTestTemplate(),
      currentVersion: currentVersion ?? makeTestTemplateVersion(),
      recentVersions: [makeTestTemplateVersion()],
      instanceReports: [],
      instanceObservations: [],
      pastNotes: [],
      metrics: makeTestMetrics(),
      changesSinceLastSession: changesSinceLastSession,
      classifiedFeedback: makeFeedbackWith(feedbackItems: feedbackItems),
      sessionNumber: sessionNumber,
    );
  }

  group('buildRitualContext', () {
    test('uses ritual system prompt instead of standard evolution prompt', () {
      final ctx = buildCtx();

      expect(ctx.systemPrompt, contains('improver agent'));
      expect(ctx.systemPrompt, contains('one-on-one ritual'));
      expect(ctx.systemPrompt, contains('Present feedback'));
      expect(ctx.systemPrompt, contains('Ask questions'));
      // Should NOT contain the standard evolution agent prompt.
      expect(ctx.systemPrompt, isNot(contains('evolution agent')));
    });

    test('includes classified feedback summary in user message', () {
      final ctx = buildCtx(
        feedbackItems: [
          makeTestClassifiedFeedbackItem(
            sentiment: FeedbackSentiment.negative,
            detail: 'Report confidence too low',
          ),
          makeTestClassifiedFeedbackItem(
            // ignore: avoid_redundant_argument_values
            sentiment: FeedbackSentiment.positive,
            detail: 'Good task analysis',
          ),
        ],
      );

      expect(ctx.initialUserMessage, contains('Classified Feedback Summary'));
      expect(ctx.initialUserMessage, contains('Negative Signals (1)'));
      expect(ctx.initialUserMessage, contains('Positive Signals (1)'));
      expect(
        ctx.initialUserMessage,
        contains('Report confidence too low'),
      );
      expect(ctx.initialUserMessage, contains('Good task analysis'));
    });

    test('groups feedback by sentiment with negative first', () {
      final ctx = buildCtx(
        feedbackItems: [
          makeTestClassifiedFeedbackItem(
            // ignore: avoid_redundant_argument_values
            sentiment: FeedbackSentiment.positive,
            detail: 'positive item',
          ),
          makeTestClassifiedFeedbackItem(
            sentiment: FeedbackSentiment.negative,
            detail: 'negative item',
          ),
          makeTestClassifiedFeedbackItem(
            sentiment: FeedbackSentiment.neutral,
            detail: 'neutral item',
          ),
        ],
      );

      final msg = ctx.initialUserMessage;
      final negativeIndex = msg.indexOf('Negative Signals');
      final positiveIndex = msg.indexOf('Positive Signals');
      final neutralIndex = msg.indexOf('Neutral Signals');

      // Negative should appear before positive, which appears before neutral.
      expect(negativeIndex, lessThan(positiveIndex));
      expect(positiveIndex, lessThan(neutralIndex));
    });

    test('includes feedback by category section', () {
      final ctx = buildCtx(
        feedbackItems: [
          makeTestClassifiedFeedbackItem(
            // ignore: avoid_redundant_argument_values
            category: FeedbackCategory.accuracy,
            detail: 'accuracy feedback',
          ),
          makeTestClassifiedFeedbackItem(
            category: FeedbackCategory.communication,
            detail: 'communication feedback',
          ),
          makeTestClassifiedFeedbackItem(
            // ignore: avoid_redundant_argument_values
            category: FeedbackCategory.accuracy,
            detail: 'another accuracy feedback',
          ),
        ],
      );

      expect(ctx.initialUserMessage, contains('Feedback by Category'));
      expect(ctx.initialUserMessage, contains('accuracy (2)'));
      expect(ctx.initialUserMessage, contains('communication (1)'));
    });

    test('includes session continuity information', () {
      final ctx = buildCtx(sessionNumber: 5);

      expect(ctx.initialUserMessage, contains('Session Continuity'));
      expect(ctx.initialUserMessage, contains('ritual session #5'));
      expect(ctx.initialUserMessage, contains('Sessions completed so far: 4'));
    });

    test('builds valid context with empty feedback', () {
      final ctx = buildCtx();

      expect(ctx.systemPrompt, isNotEmpty);
      expect(ctx.initialUserMessage, isNotEmpty);
      expect(ctx.initialUserMessage, contains('Classified Feedback Summary'));
      expect(
        ctx.initialUserMessage,
        contains('No classified feedback items'),
      );
      // Should not have category section when empty.
      expect(
        ctx.initialUserMessage,
        isNot(contains('Feedback by Category')),
      );
    });

    test('respects maxFeedbackItems cap', () {
      // Create more items than the cap.
      final ctx = buildCtx(
        feedbackItems: List.generate(
          RitualContextBuilder.maxFeedbackItems + 10,
          (i) => makeTestClassifiedFeedbackItem(
            detail: 'Feedback item $i',
            // ignore: avoid_redundant_argument_values
            sentiment: FeedbackSentiment.positive,
          ),
        ),
      );

      // The summary should show the capped count.
      expect(
        ctx.initialUserMessage,
        contains('(${RitualContextBuilder.maxFeedbackItems} items)'),
      );
    });

    test('preserves standard evolution user message content', () {
      final ctx = buildCtx(
        template: makeTestTemplate(displayName: 'My Agent'),
        currentVersion: makeTestTemplateVersion(
          directives: 'Be helpful',
          version: 3,
        ),
        changesSinceLastSession: 5,
      );

      // Should include standard sections from the base builder.
      expect(ctx.initialUserMessage, contains('Evolution Session: My Agent'));
      expect(ctx.initialUserMessage, contains('Current Directives (v3)'));
      expect(ctx.initialUserMessage, contains('Be helpful'));
      expect(ctx.initialUserMessage, contains('Performance Metrics'));
      expect(
        ctx.initialUserMessage,
        contains('Changes Since Last Session'),
      );
    });

    test('includes feedback window dates in summary', () {
      final ctx = buildCtx(
        feedbackItems: [
          makeTestClassifiedFeedbackItem(
            // ignore: avoid_redundant_argument_values
            sentiment: FeedbackSentiment.positive,
            detail: 'item',
          ),
        ],
      );

      expect(ctx.initialUserMessage, contains('2024-03-01'));
      expect(ctx.initialUserMessage, contains('2024-03-15'));
    });
  });
}
