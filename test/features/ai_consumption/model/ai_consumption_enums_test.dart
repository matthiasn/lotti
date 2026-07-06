import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_enums.dart';

void main() {
  group('AiConsumptionResponseType', () {
    test('persisted names are stable across releases', () {
      // The enum name is written into the serialized JSON blob and the
      // projected `response_type` column. Renaming a value strands already
      // synced rows, so this test pins every persisted name — deliberately
      // without pinning order, which the enum's contract allows to change.
      expect(
        AiConsumptionResponseType.values.map((v) => v.name),
        unorderedEquals([
          'agentTurn',
          'textGeneration',
          'audioTranscription',
          'imageAnalysis',
          'imageGeneration',
          'promptGeneration',
        ]),
      );
    });
  });
}
