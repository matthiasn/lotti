import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/state/task_agent_model_providers.dart';
import 'package:lotti/features/agents/state/template_query_providers.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/daily_os_next/agents/state/day_agent_providers.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_preferences_controller.dart';
import 'package:lotti/features/daily_os_next/ui/pages/daily_os_settings_page.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../../agents/test_utils.dart';

final _provider = AiConfigInferenceProvider(
  id: 'provider-remote',
  baseUrl: 'https://inference.example.com/v1',
  apiKey: 'secret',
  name: 'Private Cloud',
  createdAt: DateTime(2024, 3, 15),
  inferenceProviderType: InferenceProviderType.genericOpenAi,
);

AiConfigModel _model(String id, String name) => AiConfigModel(
  id: id,
  name: name,
  providerModelId: 'wire/$id',
  inferenceProviderId: _provider.id,
  createdAt: DateTime(2024, 3, 15),
  inputModalities: const [Modality.text],
  outputModalities: const [Modality.text],
  isReasoningModel: true,
  supportsFunctionCalling: true,
);

AiConfigInferenceProfile _profile(String id, String name, String modelId) =>
    AiConfigInferenceProfile(
      id: id,
      name: name,
      createdAt: DateTime(2024, 3, 15),
      thinkingModelId: modelId,
    );

class _PreferencesController extends DailyOsPreferencesController {
  _PreferencesController(this.initial);

  final DailyOsPreferences initial;

  @override
  DailyOsPreferences build() => initial;
}

void main() {
  final modelA = _model('model-a', 'Reasoner A');
  final modelB = _model('model-b', 'Reasoner B');
  final profileA = _profile('profile-a', 'Work profile', modelA.id);
  final profileB = _profile('profile-b', 'Local profile', modelB.id);
  final template = makeTestTemplate(
    id: dayAgentTemplateId,
    agentId: dayAgentTemplateId,
    kind: AgentTemplateKind.dayAgent,
    profileId: profileA.id,
  );

  late MockDayAgentService service;

  setUp(() {
    service = MockDayAgentService();
    when(
      () => service.updateDefaultInferenceProfile(any()),
    ).thenAnswer((_) async {});
  });

  Future<void> pumpSettings(WidgetTester tester) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const DailyOsSettingsBody(),
        overrides: [
          dayAgentServiceProvider.overrideWithValue(service),
          agentTemplateProvider.overrideWith((ref, id) async => template),
          taskAgentSetupOptionsProvider.overrideWith(
            (ref) async => TaskAgentSetupOptions(
              profiles: [profileA, profileB],
              models: [modelA, modelB],
              providers: [_provider],
            ),
          ),
          dailyOsPreferencesControllerProvider.overrideWith(
            () => _PreferencesController(
              DailyOsPreferences(userName: 'Alex'),
            ),
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('shows the chosen route and definitive remote disclosure', (
    tester,
  ) async {
    await pumpSettings(tester);

    final messages = tester.element(find.byType(DailyOsSettingsBody)).messages;
    expect(find.text('Work profile'), findsOneWidget);
    expect(find.textContaining('Reasoner A'), findsOneWidget);
    expect(
      find.textContaining(
        messages.dailyOsSettingsRemoteDisclosure(
          'Private Cloud',
          'inference.example.com',
        ),
      ),
      findsOneWidget,
    );
    final field = find.descendant(
      of: find.byKey(const Key('daily_os_user_name_field')),
      matching: find.byType(TextField),
    );
    expect(tester.widget<TextField>(field).controller?.text, 'Alex');
  });

  testWidgets('persists a profile selected through the shared picker', (
    tester,
  ) async {
    await pumpSettings(tester);

    await tester.tap(find.byKey(const Key('daily_os_default_profile')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Local profile'));
    await tester.pump();

    verify(
      () => service.updateDefaultInferenceProfile(profileB.id),
    ).called(1);
  });
}
