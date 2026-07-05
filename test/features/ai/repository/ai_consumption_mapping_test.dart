// ignore_for_file: deprecated_member_use_from_same_package

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/repository/ai_consumption_mapping.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_enums.dart';

void main() {
  // Exhaustive expectation table: every AiResponseType must have an entry.
  // Adding a new AiResponseType without deciding its consumption mapping
  // fails this test (and the switch in the extension stops compiling).
  const expected = <AiResponseType, AiConsumptionResponseType>{
    AiResponseType.imageAnalysis: AiConsumptionResponseType.imageAnalysis,
    AiResponseType.audioTranscription:
        AiConsumptionResponseType.audioTranscription,
    AiResponseType.promptGeneration: AiConsumptionResponseType.promptGeneration,
    AiResponseType.imagePromptGeneration:
        AiConsumptionResponseType.promptGeneration,
    AiResponseType.imageGeneration: AiConsumptionResponseType.imageGeneration,
    // Legacy pre-agent types map onto plain text generation.
    AiResponseType.taskSummary: AiConsumptionResponseType.textGeneration,
    AiResponseType.checklistUpdates: AiConsumptionResponseType.textGeneration,
  };

  test('expectation table covers every AiResponseType value', () {
    expect(expected.keys.toSet(), AiResponseType.values.toSet());
  });

  for (final type in AiResponseType.values) {
    test('$type maps to ${expected[type]}', () {
      expect(type.consumptionResponseType, expected[type]);
    });
  }
}
