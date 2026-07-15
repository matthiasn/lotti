import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_runtime_settings.dart';

void main() {
  group('AiRuntimeSettings', () {
    test('defaults agent wake concurrency to three when storage is absent', () {
      expect(
        AiRuntimeSettings.fromStoredAgentWakeConcurrency(null),
        const AiRuntimeSettings(),
      );
      expect(
        const AiRuntimeSettings().agentWakeConcurrency,
        defaultAgentWakeConcurrency,
      );
    });

    test('loads valid stored concurrency values', () {
      expect(
        AiRuntimeSettings.fromStoredAgentWakeConcurrency('4'),
        const AiRuntimeSettings(agentWakeConcurrency: 4),
      );
    });

    test('falls back to the default for malformed stored values', () {
      for (final raw in ['', 'not-a-number']) {
        expect(
          AiRuntimeSettings.fromStoredAgentWakeConcurrency(raw),
          const AiRuntimeSettings(),
          reason: 'raw=$raw',
        );
      }
    });

    test('clamps stored concurrency to the supported safe range', () {
      expect(
        AiRuntimeSettings.fromStoredAgentWakeConcurrency('0'),
        const AiRuntimeSettings(
          agentWakeConcurrency: minAgentWakeConcurrency,
        ),
      );
      expect(
        AiRuntimeSettings.fromStoredAgentWakeConcurrency('99'),
        const AiRuntimeSettings(
          agentWakeConcurrency: maxAgentWakeConcurrency,
        ),
      );
    });

    test('copyWith normalizes requested concurrency', () {
      expect(
        const AiRuntimeSettings().copyWith(agentWakeConcurrency: 4),
        const AiRuntimeSettings(agentWakeConcurrency: 4),
      );
      expect(
        const AiRuntimeSettings().copyWith(agentWakeConcurrency: -1),
        const AiRuntimeSettings(
          agentWakeConcurrency: minAgentWakeConcurrency,
        ),
      );
    });

    test('copyWith preserves values and equality includes hashCode', () {
      const settings = AiRuntimeSettings(agentWakeConcurrency: 4);
      final copy = settings.copyWith();

      expect(copy, settings);
      expect(copy.hashCode, settings.hashCode);
    });
  });
}
