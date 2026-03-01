import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/classified_feedback.dart';
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

  group('buildRitualContext', () {
    test('uses ritual system prompt instead of standard evolution prompt', () {
      final ctx = builder.buildRitualContext(
        template: makeTestTemplate(),
        currentVersion: makeTestTemplateVersion(),
        recentVersions: [makeTestTemplateVersion()],
        instanceReports: [],
        instanceObservations: [],
        pastNotes: [],
        metrics: makeTestMetrics(),
        changesSinceLastSession: 0,
        classifiedFeedback: makeFeedbackWith(),
        sessionNumber: 1,
      );

      expect(ctx.systemPrompt, contains('improver agent'));
      expect(ctx.systemPrompt, contains('one-on-one ritual'));
      expect(ctx.systemPrompt, contains('Present feedback'));
      expect(ctx.systemPrompt, contains('Ask questions'));
      // Should NOT contain the standard evolution agent prompt.
      expect(ctx.systemPrompt, isNot(contains('evolution agent')));
    });

    test('includes classified feedback summary in user message', () {
      final items = [
        makeTestClassifiedFeedbackItem(
          sentiment: FeedbackSentiment.negative,
          detail: 'Report confidence too low',
        ),
        makeTestClassifiedFeedbackItem(
          // ignore: avoid_redundant_argument_values
          sentiment: FeedbackSentiment.positive,
          detail: 'Good task analysis',
        ),
      ];

      final ctx = builder.buildRitualContext(
        template: makeTestTemplate(),
        currentVersion: makeTestTemplateVersion(),
        recentVersions: [makeTestTemplateVersion()],
        instanceReports: [],
        instanceObservations: [],
        pastNotes: [],
        metrics: makeTestMetrics(),
        changesSinceLastSession: 0,
        classifiedFeedback: makeFeedbackWith(feedbackItems: items),
        sessionNumber: 1,
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
      final items = [
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
      ];

      final ctx = builder.buildRitualContext(
        template: makeTestTemplate(),
        currentVersion: makeTestTemplateVersion(),
        recentVersions: [makeTestTemplateVersion()],
        instanceReports: [],
        instanceObservations: [],
        pastNotes: [],
        metrics: makeTestMetrics(),
        changesSinceLastSession: 0,
        classifiedFeedback: makeFeedbackWith(feedbackItems: items),
        sessionNumber: 1,
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
      final items = [
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
      ];

      final ctx = builder.buildRitualContext(
        template: makeTestTemplate(),
        currentVersion: makeTestTemplateVersion(),
        recentVersions: [makeTestTemplateVersion()],
        instanceReports: [],
        instanceObservations: [],
        pastNotes: [],
        metrics: makeTestMetrics(),
        changesSinceLastSession: 0,
        classifiedFeedback: makeFeedbackWith(feedbackItems: items),
        sessionNumber: 1,
      );

      expect(ctx.initialUserMessage, contains('Feedback by Category'));
      expect(ctx.initialUserMessage, contains('accuracy (2)'));
      expect(ctx.initialUserMessage, contains('communication (1)'));
    });

    test('includes session continuity information', () {
      final ctx = builder.buildRitualContext(
        template: makeTestTemplate(),
        currentVersion: makeTestTemplateVersion(),
        recentVersions: [makeTestTemplateVersion()],
        instanceReports: [],
        instanceObservations: [],
        pastNotes: [],
        metrics: makeTestMetrics(),
        changesSinceLastSession: 0,
        classifiedFeedback: makeFeedbackWith(),
        sessionNumber: 5,
      );

      expect(ctx.initialUserMessage, contains('Session Continuity'));
      expect(ctx.initialUserMessage, contains('ritual session #5'));
      expect(ctx.initialUserMessage, contains('Sessions completed so far: 4'));
    });

    test('builds valid context with empty feedback', () {
      final ctx = builder.buildRitualContext(
        template: makeTestTemplate(),
        currentVersion: makeTestTemplateVersion(),
        recentVersions: [makeTestTemplateVersion()],
        instanceReports: [],
        instanceObservations: [],
        pastNotes: [],
        metrics: makeTestMetrics(),
        changesSinceLastSession: 0,
        classifiedFeedback: makeFeedbackWith(),
        sessionNumber: 1,
      );

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
      final items = List.generate(
        RitualContextBuilder.maxFeedbackItems + 10,
        (i) => makeTestClassifiedFeedbackItem(
          detail: 'Feedback item $i',
          // ignore: avoid_redundant_argument_values
          sentiment: FeedbackSentiment.positive,
        ),
      );

      final ctx = builder.buildRitualContext(
        template: makeTestTemplate(),
        currentVersion: makeTestTemplateVersion(),
        recentVersions: [makeTestTemplateVersion()],
        instanceReports: [],
        instanceObservations: [],
        pastNotes: [],
        metrics: makeTestMetrics(),
        changesSinceLastSession: 0,
        classifiedFeedback: makeFeedbackWith(feedbackItems: items),
        sessionNumber: 1,
      );

      // The summary should show the capped count.
      expect(
        ctx.initialUserMessage,
        contains('(${RitualContextBuilder.maxFeedbackItems} items)'),
      );
    });

    test('preserves standard evolution user message content', () {
      final ctx = builder.buildRitualContext(
        template: makeTestTemplate(displayName: 'My Agent'),
        currentVersion: makeTestTemplateVersion(
          directives: 'Be helpful',
          version: 3,
        ),
        recentVersions: [makeTestTemplateVersion()],
        instanceReports: [],
        instanceObservations: [],
        pastNotes: [],
        metrics: makeTestMetrics(),
        changesSinceLastSession: 5,
        classifiedFeedback: makeFeedbackWith(),
        sessionNumber: 1,
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
      final items = [
        makeTestClassifiedFeedbackItem(
          // ignore: avoid_redundant_argument_values
          sentiment: FeedbackSentiment.positive,
          detail: 'item',
        ),
      ];

      final ctx = builder.buildRitualContext(
        template: makeTestTemplate(),
        currentVersion: makeTestTemplateVersion(),
        recentVersions: [makeTestTemplateVersion()],
        instanceReports: [],
        instanceObservations: [],
        pastNotes: [],
        metrics: makeTestMetrics(),
        changesSinceLastSession: 0,
        classifiedFeedback: makeFeedbackWith(feedbackItems: items),
        sessionNumber: 1,
      );

      expect(ctx.initialUserMessage, contains('2024-03-01'));
      expect(ctx.initialUserMessage, contains('2024-03-15'));
    });
  });
}
