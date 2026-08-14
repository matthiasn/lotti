import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_automation_policy.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';

enum _GeneratedSetupShape { legacy, configured, disabled }

class _GeneratedAutomationScenario {
  const _GeneratedAutomationScenario({
    required this.setupShape,
    required this.lifecycle,
    required this.preference,
    required this.initiator,
  });

  final _GeneratedSetupShape setupShape;
  final AgentLifecycle lifecycle;
  final bool? preference;
  final WakeInitiator initiator;

  AgentConfig get config => AgentConfig(
    automaticUpdatesEnabled: preference,
    inferenceSetup: switch (setupShape) {
      _GeneratedSetupShape.legacy => null,
      _GeneratedSetupShape.configured => const AgentInferenceSetup(
        mode: AgentInferenceSetupMode.configured,
        origin: AgentInferenceSetupOrigin.user,
        thinkingModelOverrideId: 'model-id',
      ),
      _GeneratedSetupShape.disabled => const AgentInferenceSetup(
        mode: AgentInferenceSetupMode.disabled,
        origin: AgentInferenceSetupOrigin.user,
      ),
    },
  );

  bool get expected {
    if (lifecycle == AgentLifecycle.created ||
        lifecycle == AgentLifecycle.destroyed ||
        setupShape == _GeneratedSetupShape.disabled) {
      return false;
    }
    if (initiator == WakeInitiator.user) return true;
    return (preference ?? false) && lifecycle == AgentLifecycle.active;
  }

  @override
  String toString() =>
      '_GeneratedAutomationScenario('
      'setupShape: $setupShape, lifecycle: $lifecycle, '
      'preference: $preference, initiator: $initiator)';
}

extension _AnyAutomationScenario on glados.Any {
  glados.Generator<_GeneratedAutomationScenario> get automationScenario =>
      glados.CombinableAny(this).combine4(
        glados.AnyUtils(this).choose(_GeneratedSetupShape.values),
        glados.AnyUtils(this).choose(AgentLifecycle.values),
        glados.AnyUtils(this).choose(const <bool?>[null, true, false]),
        glados.AnyUtils(this).choose(WakeInitiator.values),
        (
          _GeneratedSetupShape setupShape,
          AgentLifecycle lifecycle,
          bool? preference,
          WakeInitiator initiator,
        ) => _GeneratedAutomationScenario(
          setupShape: setupShape,
          lifecycle: lifecycle,
          preference: preference,
          initiator: initiator,
        ),
      );
}

void main() {
  glados.Glados(
    glados.any.automationScenario,
    glados.ExploreConfig(numRuns: 180),
  ).test(
    'wake permission follows setup, lifecycle, preference, and initiator',
    (scenario) {
      expect(
        taskAgentWakeAllowed(
          config: scenario.config,
          lifecycle: scenario.lifecycle,
          initiator: scenario.initiator,
        ),
        scenario.expected,
        reason: '$scenario',
      );
    },
    tags: 'glados',
  );

  group('projectAgentAutomaticWakesAllowed', () {
    test('keeps the legacy null preference enabled for active agents', () {
      expect(
        projectAgentAutomaticWakesAllowed(
          config: const AgentConfig(),
          lifecycle: AgentLifecycle.active,
        ),
        isTrue,
      );
    });

    test(
      'rejects explicit opt-out, inactive lifecycle, and disabled setup',
      () {
        expect(
          projectAgentAutomaticWakesAllowed(
            config: const AgentConfig(automaticUpdatesEnabled: false),
            lifecycle: AgentLifecycle.active,
          ),
          isFalse,
        );
        expect(
          projectAgentAutomaticWakesAllowed(
            config: const AgentConfig(automaticUpdatesEnabled: true),
            lifecycle: AgentLifecycle.dormant,
          ),
          isFalse,
        );
        expect(
          projectAgentAutomaticWakesAllowed(
            config: const AgentConfig(
              automaticUpdatesEnabled: true,
              inferenceSetup: AgentInferenceSetup(
                mode: AgentInferenceSetupMode.disabled,
                origin: AgentInferenceSetupOrigin.user,
              ),
            ),
            lifecycle: AgentLifecycle.active,
          ),
          isFalse,
        );
      },
    );
  });

  group('projectAgentWakeAllowed', () {
    test('automatic opt-out still permits an explicit user wake', () {
      const config = AgentConfig(automaticUpdatesEnabled: false);

      expect(
        projectAgentWakeAllowed(
          config: config,
          lifecycle: AgentLifecycle.active,
          initiator: WakeInitiator.automation,
        ),
        isFalse,
      );
      expect(
        projectAgentWakeAllowed(
          config: config,
          lifecycle: AgentLifecycle.active,
          initiator: WakeInitiator.user,
        ),
        isTrue,
      );
    });

    test('disabled setup blocks user and automatic wakes', () {
      const config = AgentConfig(
        inferenceSetup: AgentInferenceSetup(
          mode: AgentInferenceSetupMode.disabled,
          origin: AgentInferenceSetupOrigin.user,
        ),
      );

      for (final initiator in WakeInitiator.values) {
        expect(
          projectAgentWakeAllowed(
            config: config,
            lifecycle: AgentLifecycle.active,
            initiator: initiator,
          ),
          isFalse,
        );
      }
    });
  });
}
