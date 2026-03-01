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

  ClassifiedFeedback makeFeedback(List<ClassifiedFeedbackItem> items) {
    return ClassifiedFeedback(
      items: items,
      windowStart: DateTime(2024),
      windowEnd: DateTime(2024, 1, 31),
      totalObservationsScanned: 0,
      totalDecisionsScanned: 0,
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
      final restored =
          ClassifiedFeedback.fromJson(json as Map<String, dynamic>);

      expect(restored.items, hasLength(1));
      expect(restored.items.first.sentiment, FeedbackSentiment.positive);
      expect(restored.totalObservationsScanned, 5);
      expect(restored.totalDecisionsScanned, 3);
    });
  });

  group('ClassifiedFeedbackX', () {
    test('positive returns only positive-sentiment items', () {
      final feedback = makeFeedback([
        makeItem(sentiment: FeedbackSentiment.positive),
        makeItem(sentiment: FeedbackSentiment.negative),
        makeItem(),
        makeItem(sentiment: FeedbackSentiment.positive),
      ]);

      expect(feedback.positive, hasLength(2));
      expect(
        feedback.positive.every(
          (i) => i.sentiment == FeedbackSentiment.positive,
        ),
        isTrue,
      );
    });

    test('negative returns only negative-sentiment items', () {
      final feedback = makeFeedback([
        makeItem(sentiment: FeedbackSentiment.positive),
        makeItem(sentiment: FeedbackSentiment.negative),
        makeItem(),
      ]);

      expect(feedback.negative, hasLength(1));
      expect(feedback.negative.first.sentiment, FeedbackSentiment.negative);
    });

    test('byCategory groups items by their category', () {
      final feedback = makeFeedback([
        makeItem(category: FeedbackCategory.accuracy),
        makeItem(),
        makeItem(category: FeedbackCategory.accuracy),
      ]);

      final grouped = feedback.byCategory;

      expect(grouped, hasLength(2));
      expect(grouped[FeedbackCategory.accuracy], hasLength(2));
      expect(grouped[FeedbackCategory.general], hasLength(1));
    });

    test('positive and negative return empty lists when no matches', () {
      final feedback = makeFeedback([
        makeItem(),
      ]);

      expect(feedback.positive, isEmpty);
      expect(feedback.negative, isEmpty);
    });

    test('byCategory returns empty map for empty items', () {
      final feedback = makeFeedback([]);

      expect(feedback.byCategory, isEmpty);
    });
  });
}
