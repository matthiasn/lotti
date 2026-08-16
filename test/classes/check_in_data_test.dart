import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';

void main() {
  group('CheckInData', () {
    test('round-trip JSON serialization preserves all fields', () {
      const data = CheckInData(
        relationshipId: 'rel-001',
        interactionType: CheckInInteractionType.call,
        sentiment: CheckInSentiment.good,
        topics: ['job search', 'vacation plans'],
        payAttentionTo: 'Ask about the interview result',
        avoid: 'The inheritance discussion',
      );

      final json = jsonDecode(jsonEncode(data)) as Map<String, dynamic>;
      final restored = CheckInData.fromJson(json);

      expect(restored, data);
      expect(restored.relationshipId, 'rel-001');
      expect(restored.interactionType, CheckInInteractionType.call);
      expect(restored.sentiment, CheckInSentiment.good);
      expect(restored.topics, ['job search', 'vacation plans']);
      expect(restored.payAttentionTo, 'Ask about the interview result');
      expect(restored.avoid, 'The inheritance discussion');
    });

    test('defaults are applied correctly', () {
      const data = CheckInData(
        relationshipId: 'rel-001',
        interactionType: CheckInInteractionType.inPerson,
      );

      expect(data.sentiment, isNull);
      expect(data.topics, isEmpty);
      expect(data.payAttentionTo, isNull);
      expect(data.avoid, isNull);
    });

    test('all interaction types round-trip through JSON', () {
      for (final type in CheckInInteractionType.values) {
        final data = CheckInData(
          relationshipId: 'rel-001',
          interactionType: type,
        );
        final json = jsonDecode(jsonEncode(data)) as Map<String, dynamic>;
        expect(
          CheckInData.fromJson(json).interactionType,
          type,
          reason: type.name,
        );
      }
    });

    test('all sentiments round-trip through JSON', () {
      for (final sentiment in CheckInSentiment.values) {
        final data = CheckInData(
          relationshipId: 'rel-001',
          interactionType: CheckInInteractionType.other,
          sentiment: sentiment,
        );
        final json = jsonDecode(jsonEncode(data)) as Map<String, dynamic>;
        expect(
          CheckInData.fromJson(json).sentiment,
          sentiment,
          reason: sentiment.name,
        );
      }
    });

    test('missing sentiment stays null (explicit user judgment only)', () {
      final json = <String, dynamic>{
        'relationshipId': 'rel-001',
        'interactionType': 'message',
      };
      final restored = CheckInData.fromJson(json);
      expect(restored.sentiment, isNull);
      expect(restored.interactionType, CheckInInteractionType.message);
    });
  });
}
