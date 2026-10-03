import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agent_wake_cadence.dart';
import 'package:lotti/features/ai/model/ai_runtime_settings.dart';

void main() {
  group('AiRuntimeSettings', () {
    test('defaults agent wake concurrency to three when storage is absent', () {
      expect(AiRuntimeSettings.fromStored(), const AiRuntimeSettings());
      expect(
        const AiRuntimeSettings().agentWakeConcurrency,
        defaultAgentWakeConcurrency,
      );
    });

    test('loads valid stored concurrency values', () {
      expect(
        AiRuntimeSettings.fromStored(agentWakeConcurrency: '4'),
        const AiRuntimeSettings(agentWakeConcurrency: 4),
      );
    });

    test('falls back to the default for malformed stored values', () {
      for (final raw in ['', 'not-a-number']) {
        expect(
          AiRuntimeSettings.fromStored(agentWakeConcurrency: raw),
          const AiRuntimeSettings(),
          reason: 'raw=$raw',
        );
      }
    });

    test('clamps stored concurrency to the supported safe range', () {
      expect(
        AiRuntimeSettings.fromStored(agentWakeConcurrency: '0'),
        const AiRuntimeSettings(
          agentWakeConcurrency: minAgentWakeConcurrency,
        ),
      );
      expect(
        AiRuntimeSettings.fromStored(agentWakeConcurrency: '99'),
        const AiRuntimeSettings(
          agentWakeConcurrency: maxAgentWakeConcurrency,
        ),
      );
    });

    test('defaults the wake cadence to hourly, and loads a stored one', () {
      expect(
        const AiRuntimeSettings().defaultWakeCadence,
        AgentWakeCadence.hourly,
      );
      expect(
        AiRuntimeSettings.fromStored(defaultWakeCadence: 'live'),
        const AiRuntimeSettings(defaultWakeCadence: AgentWakeCadence.live),
      );
    });

    test('an unknown stored cadence falls back to the default', () {
      expect(
        AiRuntimeSettings.fromStored(defaultWakeCadence: 'everyFortnight'),
        const AiRuntimeSettings(),
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

    test('copyWith replaces the cadence and leaves concurrency alone', () {
      expect(
        const AiRuntimeSettings(
          agentWakeConcurrency: 4,
        ).copyWith(defaultWakeCadence: AgentWakeCadence.recordingsOnly),
        const AiRuntimeSettings(
          agentWakeConcurrency: 4,
          defaultWakeCadence: AgentWakeCadence.recordingsOnly,
        ),
      );
    });

    test('copyWith preserves values and equality includes hashCode', () {
      const settings = AiRuntimeSettings(
        agentWakeConcurrency: 4,
        defaultWakeCadence: AgentWakeCadence.live,
      );
      final copy = settings.copyWith();

      expect(copy, settings);
      expect(copy.hashCode, settings.hashCode);
      expect(
        settings,
        isNot(settings.copyWith(defaultWakeCadence: AgentWakeCadence.hourly)),
      );
    });
  });
}
