import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/classified_feedback.dart';

// ── Generators for Glados round-trip ─────────────────────────────────────────

extension _AnyClassifiedFeedback on glados.Any {
  glados.Generator<FeedbackSentiment> get feedbackSentiment =>
      glados.AnyUtils(this).choose(FeedbackSentiment.values);

  glados.Generator<FeedbackCategory> get feedbackCategory =>
      glados.AnyUtils(this).choose(FeedbackCategory.values);

  glados.Generator<ObservationPriority?> get optionalObservationPriority =>
      glados.AnyUtils(this).choose(<ObservationPriority?>[
        null,
        ...ObservationPriority.values,
      ]);

  glados.Generator<ClassifiedFeedbackItem> get classifiedFeedbackItem =>
      glados.CombinableAny(this).combine4(
        feedbackSentiment,
        feedbackCategory,
        glados.any.letterOrDigits,
        optionalObservationPriority,
        (
          FeedbackSentiment sentiment,
          FeedbackCategory category,
          String source,
          ObservationPriority? priority,
        ) => ClassifiedFeedbackItem(
          sentiment: sentiment,
          category: category,
          source: source.isEmpty ? 'src' : source,
          detail: 'detail',
          agentId: 'agent-1',
          observationPriority: priority,
        ),
      );
}

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

  group('ClassifiedFeedback computed properties', () {
    test('totalCount equals items.length for non-empty list', () {
      final feedback = ClassifiedFeedback(
        items: [
          makeItem(sentiment: FeedbackSentiment.positive),
          makeItem(sentiment: FeedbackSentiment.negative),
          makeItem(),
        ],
        windowStart: DateTime(2024, 3, 10),
        windowEnd: DateTime(2024, 3, 20),
        totalObservationsScanned: 10,
        totalDecisionsScanned: 5,
      );
      expect(feedback.items.length, equals(3));
    });

    test('items is empty when constructed with empty list', () {
      final feedback = ClassifiedFeedback(
        items: const [],
        windowStart: DateTime(2024, 3, 10),
        windowEnd: DateTime(2024, 3, 20),
        totalObservationsScanned: 0,
        totalDecisionsScanned: 0,
      );
      expect(feedback.items, isEmpty);
    });

    test('critical extension returns only critical-priority items', () {
      final feedback = ClassifiedFeedback(
        items: [
          const ClassifiedFeedbackItem(
            sentiment: FeedbackSentiment.positive,
            category: FeedbackCategory.accuracy,
            source: 'obs',
            detail: 'great',
            agentId: 'agent-1',
            observationPriority: ObservationPriority.critical,
          ),
          makeItem(),
        ],
        windowStart: DateTime(2024, 3, 10),
        windowEnd: DateTime(2024, 3, 20),
        totalObservationsScanned: 2,
        totalDecisionsScanned: 0,
      );
      expect(feedback.critical, hasLength(1));
      expect(
        feedback.critical.first.observationPriority,
        equals(ObservationPriority.critical),
      );
    });
  });

  group('ClassifiedFeedbackItem JSON with optional fields', () {
    test('fromJson tolerates missing sourceEntityId (null)', () {
      final json = <String, dynamic>{
        'sentiment': 'positive',
        'category': 'accuracy',
        'source': 'decision',
        'detail': 'confirmed proposal',
        'agentId': 'agent-1',
      };
      final item = ClassifiedFeedbackItem.fromJson(json);
      expect(item.sourceEntityId, isNull);
      expect(item.confidence, isNull);
      expect(item.observationPriority, isNull);
    });

    test('fromJson parses observationPriority correctly', () {
      final json = <String, dynamic>{
        'sentiment': 'negative',
        'category': 'general',
        'source': 'observation',
        'detail': 'something went wrong',
        'agentId': 'agent-2',
        'observationPriority': 'critical',
      };
      final item = ClassifiedFeedbackItem.fromJson(json);
      expect(item.observationPriority, equals(ObservationPriority.critical));
    });

    test('fromJson with unknown observationPriority value returns null', () {
      final json = <String, dynamic>{
        'sentiment': 'neutral',
        'category': 'general',
        'source': 'obs',
        'detail': 'detail',
        'agentId': 'agent-1',
        'observationPriority': 'unknownValue',
      };
      final item = ClassifiedFeedbackItem.fromJson(json);
      expect(item.observationPriority, isNull);
    });
  });

  group('Glados JSON round-trips', () {
    glados.Glados(
      glados.any.classifiedFeedbackItem,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'ClassifiedFeedbackItem toJson → fromJson round-trip preserves equality',
      (item) {
        final json = jsonDecode(jsonEncode(item.toJson()));
        final restored =
            ClassifiedFeedbackItem.fromJson(json as Map<String, dynamic>);
        expect(restored, equals(item), reason: 'item=$item');
      },
      tags: 'glados',
    );
  });

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
