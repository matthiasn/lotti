import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/classified_feedback.dart';

void main() {
  ClassifiedFeedbackItem makeItem({
    FeedbackSentiment sentiment = FeedbackSentiment.neutral,
    FeedbackCategory category = FeedbackCategory.general,
    String source = 'test',
  }) {
    return ClassifiedFeedbackItem(
      sentiment: sentiment,
      category: category,
      source: source,
      detail: 'detail',
      agentId: 'agent-1',
    );
  }

  group('JSON serialization', () {
    test('ClassifiedFeedbackItem roundtrips through JSON', () {
      const item = ClassifiedFeedbackItem(
        sentiment: FeedbackSentiment.positive,
        category: FeedbackCategory.accuracy,
        source: 'decision',
        detail: 'confirmed proposal',
        agentId: 'agent-1',
        sourceEntityId: 'cd-123',
        confidence: 0.95,
      );

      final json = item.toJson();
      final restored = ClassifiedFeedbackItem.fromJson(json);

      expect(restored, item);
    });

    test('ClassifiedFeedback roundtrips through JSON', () {
      final feedback = ClassifiedFeedback(
        items: [
          makeItem(sentiment: FeedbackSentiment.positive),
        ],
        windowStart: DateTime(2024, 3, 10),
        windowEnd: DateTime(2024, 3, 20),
        totalObservationsScanned: 5,
        totalDecisionsScanned: 3,
      );

      final json = jsonDecode(jsonEncode(feedback.toJson()));
      final restored = ClassifiedFeedback.fromJson(
        json as Map<String, dynamic>,
      );

      expect(restored.items, hasLength(1));
      expect(restored.items.first.sentiment, FeedbackSentiment.positive);
      expect(restored.totalObservationsScanned, 5);
      expect(restored.totalDecisionsScanned, 3);
    });
  });
}
