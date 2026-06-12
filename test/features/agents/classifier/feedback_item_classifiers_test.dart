import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/classifier/feedback_item_classifiers.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/classified_feedback.dart';

import '../test_data/entity_factories.dart';
import '../test_data/evolution_factories.dart';
import '../test_data/wake_factories.dart';

void main() {
  group('classifyReport', () {
    test('returns null when the report has no confidence', () {
      expect(classifyReport(makeTestReport()), isNull);
    });

    test('maps confidence thresholds to sentiment', () {
      for (final (confidence, sentiment) in [
        (0.8, FeedbackSentiment.positive),
        (0.5, FeedbackSentiment.neutral),
        (0.2, FeedbackSentiment.negative),
      ]) {
        final item = classifyReport(makeTestReport(confidence: confidence))!;
        expect(item.sentiment, sentiment, reason: 'confidence=$confidence');
        expect(item.category, FeedbackCategory.accuracy);
        expect(item.source, FeedbackSources.metric);
        expect(item.sourceEntityId, 'report-001');
        expect(item.confidence, confidence);
      }
    });
  });

  group('classifyWakeRunRating', () {
    test('returns null when the run is unrated', () {
      expect(classifyWakeRunRating(makeTestWakeRun()), isNull);
    });

    test('maps the rating to sentiment via the shared thresholds', () {
      for (final (rating, sentiment) in [
        (5.0, FeedbackSentiment.positive),
        (3.0, FeedbackSentiment.neutral),
        (1.0, FeedbackSentiment.negative),
      ]) {
        final item = classifyWakeRunRating(makeTestWakeRun(userRating: rating));
        expect(item?.sentiment, sentiment, reason: 'rating=$rating');
        expect(item?.source, FeedbackSources.rating);
        expect(item?.detail, contains(rating.toStringAsFixed(1)));
      }
    });
  });

  group('classifyEvolutionSession', () {
    test('classifies an abandoned session as negative', () {
      final item = classifyEvolutionSession(
        makeTestEvolutionSession(status: EvolutionSessionStatus.abandoned),
        'template-target',
      );

      expect(item.sentiment, FeedbackSentiment.negative);
      expect(item.source, FeedbackSources.evolutionSession);
      expect(item.detail, contains('abandoned'));
      expect(item.detail, contains('template-target'));
    });

    test('classifies a completed rated session by its rating', () {
      final item = classifyEvolutionSession(
        makeTestEvolutionSession(
          status: EvolutionSessionStatus.completed,
          userRating: 4.5,
        ),
        'template-target',
      );

      expect(item.sentiment, FeedbackSentiment.positive);
      expect(item.detail, contains('completed with rating 4.5'));
    });

    test('falls back to neutral for active or unrated sessions', () {
      final item = classifyEvolutionSession(
        makeTestEvolutionSession(),
        'template-target',
      );

      expect(item.sentiment, FeedbackSentiment.neutral);
      expect(item.detail, contains('active'));
    });
  });

  group('sentimentFromRating', () {
    test('maps thresholds inclusively at 4.0 and 2.0', () {
      expect(sentimentFromRating(4), FeedbackSentiment.positive);
      expect(sentimentFromRating(3.9), FeedbackSentiment.neutral);
      expect(sentimentFromRating(2.1), FeedbackSentiment.neutral);
      expect(sentimentFromRating(2), FeedbackSentiment.negative);
    });
  });

  group('observationDetailText', () {
    test('falls back when payload is missing or has no usable text', () {
      expect(observationDetailText(null), 'Observation recorded');
      expect(
        observationDetailText(makeTestMessagePayload(content: const {})),
        'Observation recorded',
      );
      expect(
        observationDetailText(
          makeTestMessagePayload(content: const {'text': '   '}),
        ),
        'Observation recorded',
      );
    });

    test('returns the text, truncated to 200 characters', () {
      expect(
        observationDetailText(
          makeTestMessagePayload(content: const {'text': 'short note'}),
        ),
        'short note',
      );
      final long = 'x' * 500;
      final detail = observationDetailText(
        makeTestMessagePayload(content: {'text': long}),
      );
      expect(detail.length, lessThanOrEqualTo(201));
      expect(detail, startsWith('xxx'));
    });
  });
}
