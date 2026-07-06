import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_enums.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_event.dart';
import 'package:lotti/features/sync/vector_clock.dart';

import '../test_utils.dart';

void main() {
  group('AiConsumptionEvent serialization', () {
    test(
      'fully populated event round-trips losslessly through encoded JSON',
      () {
        final event = makeConsumptionEvent(
          vectorClock: const VectorClock({'host-a': 3, 'host-b': 1}),
          parentId: 'wake-run-1',
          entryId: 'entry-1',
          agentId: 'agent-1',
          wakeRunKey: 'wake-run-1',
          threadId: 'thread-1',
          turnIndex: 2,
          promptId: 'prompt-1',
          skillId: 'skill-1',
          configId: 'config-1',
          providerModelId: 'glm-5.2-cloud',
          cachedInputTokens: 200,
          thoughtsTokens: 50,
          upstreamProviderId: 'z-ai',
        );

        final decoded = AiConsumptionEvent.fromJson(
          jsonDecode(jsonEncode(event.toJson())) as Map<String, dynamic>,
        );

        expect(decoded, event);
        expect(
          decoded.vectorClock,
          const VectorClock({'host-a': 3, 'host-b': 1}),
        );
      },
    );

    test('minimal event keeps null clock and impact fields null after '
        'round-trip', () {
      final event = AiConsumptionEvent(
        id: 'evt-min',
        createdAt: DateTime(2026, 3, 15, 12),
        providerType: InferenceProviderType.gemini,
        responseType: AiConsumptionResponseType.audioTranscription,
        vectorClock: null,
      );

      final decoded = AiConsumptionEvent.fromJson(
        jsonDecode(jsonEncode(event.toJson())) as Map<String, dynamic>,
      );

      expect(decoded, event);
      expect(decoded.vectorClock, isNull);
      expect(decoded.credits, isNull);
      expect(decoded.energyKwh, isNull);
      expect(decoded.carbonGCo2, isNull);
      expect(decoded.waterLiters, isNull);
    });

    test('enums and timestamps persist as stable JSON scalars', () {
      // These string forms are the sync wire format — a change strands rows
      // already synced by older builds. Production stamps zone-naive local
      // time (`DateTime.now()` at capture), so the pinned string is
      // deliberately Z-less; this test documents the format as it is, not as
      // it arguably should be.
      final json = makeConsumptionEvent(
        createdAt: DateTime(2026, 3, 15, 12),
      ).toJson();

      expect(json['providerType'], 'melious');
      expect(json['responseType'], 'agentTurn');
      expect(json['createdAt'], '2026-03-15T12:00:00.000');
    });
  });
}
