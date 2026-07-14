import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/agents/state/task_agent_model_providers.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_service.dart';
import 'package:lotti/features/daily_os_next/agents/state/day_agent_providers.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/daily_os_inference_setup_sheet.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../../agents/test_utils.dart';

void main() {
  final provider = AiConfigInferenceProvider(
    id: 'provider',
    baseUrl: 'https://provider.example.com',
    apiKey: 'key',
    name: 'Provider',
    createdAt: DateTime(2024, 3, 15),
    inferenceProviderType: InferenceProviderType.genericOpenAi,
  );
  final model = AiConfigModel(
    id: 'model',
    name: 'Direct model',
    providerModelId: 'wire/model',
    inferenceProviderId: provider.id,
    createdAt: DateTime(2024, 3, 15),
    inputModalities: const [Modality.text],
    outputModalities: const [Modality.text],
    isReasoningModel: true,
    supportsFunctionCalling: true,
  );
  final profile = AiConfigInferenceProfile(
    id: 'profile',
    name: 'Default profile',
    createdAt: DateTime(2024, 3, 15),
    thinkingModelId: model.id,
  );
  final instanceProfile = AiConfigInferenceProfile(
    id: 'profile-instance',
    name: 'Instance profile',
    createdAt: DateTime(2024, 3, 15),
    thinkingModelId: model.id,
  );
  final identity = makeTestIdentity(
    id: dailyOsPlannerAgentId,
    agentId: dailyOsPlannerAgentId,
    kind: AgentKinds.dayAgent,
    config: AgentConfig(
      profileId: profile.id,
      inferenceSetup: AgentInferenceSetup(
        mode: AgentInferenceSetupMode.configured,
        origin: AgentInferenceSetupOrigin.user,
        baseProfileId: profile.id,
        thinkingModelOverrideId: model.id,
      ),
    ),
  );

  Future<void> pumpSheet(
    WidgetTester tester, {
    required MockDayAgentService service,
    required AgentIdentityEntity planner,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () => DailyOsInferenceSetupSheet.show(context),
            child: const Text('Open'),
          ),
        ),
        overrides: [
          dayAgentServiceProvider.overrideWithValue(service),
          agentIdentityProvider.overrideWith((ref, id) async => planner),
          taskAgentSetupOptionsProvider.overrideWith(
            (ref) async => TaskAgentSetupOptions(
              profiles: [profile, instanceProfile],
              models: [model],
              providers: [provider],
            ),
          ),
        ],
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the active override and restores the Daily OS default', (
    tester,
  ) async {
    final service = MockDayAgentService();
    final update = Completer<void>();
    when(
      service.resetPlannerInferenceToDefault,
    ).thenAnswer((_) => update.future);

    await pumpSheet(tester, service: service, planner: identity);
    expect(find.text('Direct model'), findsOneWidget);
    expect(find.text('Use Daily OS default'), findsOneWidget);
    expect(find.text('Default profile'), findsOneWidget);

    await tester.tap(find.text('Use Daily OS default'));
    await tester.pump();

    verify(service.resetPlannerInferenceToDefault).called(1);
    expect(
      find.byKey(const Key('daily_os_inference_reset_progress')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('daily_os_inference_model_progress')),
      findsNothing,
    );
    update.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('chooses a persistent profile override for the planner', (
    tester,
  ) async {
    final service = MockDayAgentService();
    final update = Completer<void>();
    when(
      () => service.updatePlannerProfileOverride(instanceProfile.id),
    ).thenAnswer((_) => update.future);
    final inheritedPlanner = identity.copyWith(
      config: AgentConfig(
        profileId: profile.id,
        inferenceSetup: AgentInferenceSetup(
          mode: AgentInferenceSetupMode.configured,
          origin: AgentInferenceSetupOrigin.templateSnapshot,
          baseProfileId: profile.id,
          originEntityId: dayAgentTemplateId,
        ),
      ),
    );

    await pumpSheet(tester, service: service, planner: inheritedPlanner);
    await tester.tap(find.text('Choose Daily OS profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Instance profile'));
    await tester.pump();

    verify(
      () => service.updatePlannerProfileOverride(instanceProfile.id),
    ).called(1);
    expect(
      find.byKey(const Key('daily_os_inference_profile_progress')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('daily_os_inference_model_progress')),
      findsNothing,
    );
    update.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('shows model progress on the model action only', (tester) async {
    final service = MockDayAgentService();
    final update = Completer<void>();
    when(
      () => service.updatePlannerThinkingModelOverride(model.id),
    ).thenAnswer((_) => update.future);

    await pumpSheet(tester, service: service, planner: identity);
    await tester.tap(find.text('Direct model').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Direct model').last);
    await tester.pump();

    verify(
      () => service.updatePlannerThinkingModelOverride(model.id),
    ).called(1);
    expect(
      find.byKey(const Key('daily_os_inference_model_progress')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('daily_os_inference_profile_progress')),
      findsNothing,
    );
    update.complete();
    await tester.pumpAndSettle();
  });
}
