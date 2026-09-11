import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/inference.dart';

void main() {
  group('LottiInferenceRequest', () {
    test('copyWith replaces only the named fields', () {
      final request = LottiInferenceRequest(
        messages: [LottiMessage.userText('hi')],
        model: 'gpt-4o',
        temperature: 0.3,
        maxCompletionTokens: 128,
        reasoningEffort: LottiReasoningEffort.low,
      );

      final updated = request.copyWith(
        model: 'gpt-5',
        reasoningEffort: LottiReasoningEffort.high,
      );

      expect(updated.model, 'gpt-5');
      expect(updated.reasoningEffort, LottiReasoningEffort.high);
      expect(updated.temperature, 0.3);
      expect(updated.maxCompletionTokens, 128);
      expect(updated.messages, request.messages);
    });
  });

  group('LottiReasoningEffort', () {
    test('is ordered from cheapest to most thorough', () {
      // Melious clamps `high` down to `medium` for its quirked models by
      // comparing levels, so the declaration order is load-bearing.
      expect(LottiReasoningEffort.values, [
        LottiReasoningEffort.minimal,
        LottiReasoningEffort.low,
        LottiReasoningEffort.medium,
        LottiReasoningEffort.high,
      ]);
    });
  });
}
