import 'dart:async';

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
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
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
  late MockDayAgentService service;

  setUp(() {
    service = MockDayAgentService();
    when(
      () => service.updateDefaultInferenceProfile(any()),
    ).thenAnswer((_) async {});
  });

  Future<void> pumpSettings(
    WidgetTester tester, {
    Widget child = const DailyOsSettingsBody(),
    AiConfigInferenceProvider? provider,
    String? templateProfileId,
    List<AiConfigInferenceProfile>? profiles,
    List<AiConfigModel>? models,
  }) async {
    final configuredProvider = provider ?? _provider;
    final configuredProfiles = profiles ?? [profileA, profileB];
    final configuredModels = models ?? [modelA, modelB];
    final configuredTemplate = makeTestTemplate(
      id: dayAgentTemplateId,
      agentId: dayAgentTemplateId,
      kind: AgentTemplateKind.dayAgent,
      profileId: templateProfileId ?? profileA.id,
    );
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        child,
        overrides: [
          dayAgentServiceProvider.overrideWithValue(service),
          agentTemplateProvider.overrideWith(
            (ref, id) async => configuredTemplate,
          ),
          taskAgentSetupOptionsProvider.overrideWith(
            (ref) async => TaskAgentSetupOptions(
              profiles: configuredProfiles,
              models: configuredModels,
              providers: [configuredProvider],
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

  Future<void> chooseProfileB(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('daily_os_default_profile')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Local profile'));
    await tester.pump();
  }

  testWidgets('mobile page wraps the shared settings body with its title', (
    tester,
  ) async {
    await pumpSettings(tester, child: const DailyOsSettingsPage());

    final messages = tester.element(find.byType(DailyOsSettingsBody)).messages;
    expect(find.byType(DailyOsSettingsBody), findsOneWidget);
    expect(find.text(messages.dailyOsSettingsTitle), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

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

  testWidgets('normalizes a scheme-less host in the remote disclosure', (
    tester,
  ) async {
    await pumpSettings(
      tester,
      provider: _provider.copyWith(baseUrl: 'inference.example.com:11434/v1'),
    );

    final messages = tester.element(find.byType(DailyOsSettingsBody)).messages;
    expect(
      find.textContaining(
        messages.dailyOsSettingsRemoteDisclosure(
          'Private Cloud',
          'inference.example.com',
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('falls back to provider model ids when resolving the route', (
    tester,
  ) async {
    final wireProfile = profileA.copyWith(
      thinkingModelId: modelA.providerModelId,
    );
    await pumpSettings(
      tester,
      templateProfileId: wireProfile.id,
      profiles: [wireProfile, profileB],
    );

    expect(
      find.descendant(
        of: find.byKey(const Key('daily_os_default_profile')),
        matching: find.textContaining('Reasoner A'),
      ),
      findsOneWidget,
    );
  });

  for (final endpointCase in [
    (
      name: 'unparseable endpoint',
      baseUrl: 'http://[',
      disclosureEndpoint: 'http://[',
      local: false,
    ),
    (
      name: 'empty endpoint',
      baseUrl: '',
      disclosureEndpoint: 'Private Cloud',
      local: false,
    ),
    (
      name: 'local endpoint',
      baseUrl: 'localhost:11434',
      disclosureEndpoint: '',
      local: true,
    ),
  ]) {
    testWidgets('discloses the ${endpointCase.name}', (tester) async {
      await pumpSettings(
        tester,
        provider: _provider.copyWith(baseUrl: endpointCase.baseUrl),
      );

      final messages = tester
          .element(find.byType(DailyOsSettingsBody))
          .messages;
      final expected = endpointCase.local
          ? messages.dailyOsSettingsLocalDisclosure
          : messages.dailyOsSettingsRemoteDisclosure(
              'Private Cloud',
              endpointCase.disclosureEndpoint,
            );
      expect(find.textContaining(expected), findsOneWidget);
    });
  }

  testWidgets('shows profile progress while the update is pending', (
    tester,
  ) async {
    final update = Completer<void>();
    when(
      () => service.updateDefaultInferenceProfile(profileB.id),
    ).thenAnswer((_) => update.future);
    await pumpSettings(tester);

    await chooseProfileB(tester);

    expect(
      find.byKey(const Key('daily_os_default_profile_progress')),
      findsOneWidget,
    );
    update.complete();
    await tester.pump();
  });

  testWidgets('shows an error toast when profile persistence fails', (
    tester,
  ) async {
    when(
      () => service.updateDefaultInferenceProfile(profileB.id),
    ).thenThrow(StateError('write failed'));
    await pumpSettings(tester);

    await chooseProfileB(tester);

    final toasts = tester.widgetList<DesignSystemToast>(
      find.byType(DesignSystemToast),
    );
    expect(toasts, isNotEmpty);
    expect(
      toasts.every((toast) => toast.tone == DesignSystemToastTone.error),
      isTrue,
    );
  });

  testWidgets('persists a profile selected through the shared picker', (
    tester,
  ) async {
    await pumpSettings(tester);

    await chooseProfileB(tester);

    verify(
      () => service.updateDefaultInferenceProfile(profileB.id),
    ).called(1);
  });
}
