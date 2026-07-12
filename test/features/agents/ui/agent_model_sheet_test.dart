import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/agents/state/task_agent_model_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_model_sheet.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../../projects/test_utils.dart';
import '../test_data/entity_factories.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  final provider = AiConfigInferenceProvider(
    id: 'provider-1',
    baseUrl: 'https://example.invalid',
    apiKey: 'test-key',
    name: 'Melious.ai',
    createdAt: DateTime(2024),
    inferenceProviderType: InferenceProviderType.melious,
  );
  final model = AiConfigModel(
    id: 'model-1',
    name: 'Qwen 3.5 Plus',
    providerModelId: 'qwen3.5-plus',
    inferenceProviderId: provider.id,
    createdAt: DateTime(2024),
    inputModalities: const [Modality.text],
    outputModalities: const [Modality.text],
    isReasoningModel: true,
    publisher: 'Alibaba',
    supportsFunctionCalling: true,
  );
  final profile = AiConfigInferenceProfile(
    id: 'profile-1',
    name: 'Saved profile',
    createdAt: DateTime(2024),
    thinkingModelId: model.id,
  );
  final resolved = ResolvedAgentSetup(
    status: AgentSetupResolutionStatus.resolved,
    profile: ResolvedProfile(
      thinkingModelId: model.providerModelId,
      thinkingProvider: provider,
      thinkingModel: model,
    ),
    source: AgentSetupResolutionSource.baseProfile,
    setupOrigin: AgentInferenceSetupOrigin.user,
  );
  final options = TaskAgentSetupOptions(
    profiles: [profile],
    models: [model],
    providers: [provider],
  );

  late MockTaskAgentService service;
  late MockJournalDb journalDb;

  setUp(() {
    service = MockTaskAgentService();
    journalDb = MockJournalDb();
    when(
      () => service.updateAutomaticUpdates(
        agentId: any(named: 'agentId'),
        enabled: any(named: 'enabled'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => service.updateAgentProfile(
        agentId: any(named: 'agentId'),
        profileId: any(named: 'profileId'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => service.updateAgentThinkingModelOverride(
        agentId: any(named: 'agentId'),
        modelConfigId: any(named: 'modelConfigId'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => service.updateAgentInferenceSetup(
        agentId: any(named: 'agentId'),
        setup: any(named: 'setup'),
      ),
    ).thenAnswer((_) async {});
  });

  List<Override> overrides({bool automaticUpdates = true}) {
    final identity = makeTestIdentity().copyWith(
      config: AgentConfig(
        automaticUpdatesEnabled: automaticUpdates,
        profileId: profile.id,
        inferenceSetup: AgentInferenceSetup(
          mode: AgentInferenceSetupMode.configured,
          origin: AgentInferenceSetupOrigin.user,
          baseProfileId: profile.id,
        ),
      ),
    );
    return [
      agentIdentityProvider.overrideWith((ref, id) async => identity),
      taskAgentResolvedSetupProvider.overrideWith((ref, id) async => resolved),
      taskAgentSetupOptionsProvider.overrideWith((ref) async => options),
      taskAgentServiceProvider.overrideWithValue(service),
      journalDbProvider.overrideWithValue(journalDb),
    ];
  }

  Future<void> openSheet(
    WidgetTester tester, {
    bool automaticUpdates = true,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => AgentModelSheet.show(
                context: context,
                taskId: 'task-1',
                agentId: 'agent-1',
              ),
              child: const Text('Open'),
            ),
          ),
        ),
        overrides: overrides(automaticUpdates: automaticUpdates),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets(
    'shows current route, source, persistent actions, and automation',
    (
      tester,
    ) async {
      await openSheet(tester);

      expect(find.text('Agent setup'), findsOneWidget);
      expect(
        find.text('Qwen 3.5 Plus · Alibaba · via Melious.ai'),
        findsNWidgets(2),
      );
      expect(find.text('Saved profile · Profile default'), findsOneWidget);
      expect(find.text('You chose this for this agent'), findsOneWidget);
      expect(find.text('Copy category default'), findsOneWidget);
      expect(
        find.text(
          'Copies the category’s current setup. Later category changes won’t '
          'affect this agent.',
        ),
        findsOneWidget,
      );
      expect(find.text('Saved profile'), findsOneWidget);
      expect(find.text('Choose a thinking model'), findsOneWidget);
      expect(find.text('No AI setup'), findsOneWidget);
      expect(find.text('Automatic updates'), findsOneWidget);
      expect(
        find.text(
          'When anything related to this task changes, a two-minute countdown starts. Changes '
          'during the countdown are bundled into one update.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Changes apply to every future update until you change them.',
        ),
        findsOneWidget,
      );
      expect(
        tester
            .getSize(
              find.byKey(const Key('taskAgentAutomaticUpdatesCheckbox')),
            )
            .height,
        greaterThanOrEqualTo(kMinInteractiveDimension),
      );
    },
  );

  testWidgets(
    'automation checkbox persists off and profile/model choices save',
    (
      tester,
    ) async {
      await openSheet(tester);

      await tester.tap(find.text('Saved profile'));
      await tester.pump();
      await tester.pump();
      verify(
        () => service.updateAgentProfile(
          agentId: 'agent-1',
          profileId: 'profile-1',
        ),
      ).called(1);

      await tester.tap(find.text('Choose a thinking model'));
      await tester.pump();
      verify(
        () => service.updateAgentThinkingModelOverride(
          agentId: 'agent-1',
          modelConfigId: 'model-1',
        ),
      ).called(1);

      await tester.drag(
        find.byType(Scrollable).last,
        const Offset(0, -300),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const Key('taskAgentAutomaticUpdatesCheckbox')),
      );
      await tester.pump();
      verify(
        () =>
            service.updateAutomaticUpdates(agentId: 'agent-1', enabled: false),
      ).called(1);
    },
  );

  testWidgets('No AI setup requires confirmation and persists disabled mode', (
    tester,
  ) async {
    await openSheet(tester);

    await tester.tap(find.text('No AI setup'));
    await tester.pump();
    expect(find.text('Turn off AI setup?'), findsOneWidget);
    await tester.tap(find.text('Turn off'));
    await tester.pump();

    final setup =
        verify(
              () => service.updateAgentInferenceSetup(
                agentId: 'agent-1',
                setup: captureAny(named: 'setup'),
              ),
            ).captured.single
            as AgentInferenceSetup;
    expect(setup.mode, AgentInferenceSetupMode.disabled);
    expect(setup.origin, AgentInferenceSetupOrigin.user);
  });

  testWidgets('category without a default persists visible no-setup state', (
    tester,
  ) async {
    final task = makeTestTask(id: 'task-1').copyWith(
      meta: makeTestTask(id: 'task-1').meta.copyWith(categoryId: 'category-1'),
    );
    when(
      () => journalDb.journalEntityById('task-1'),
    ).thenAnswer((_) async => task);
    when(
      () => journalDb.getCategoryById('category-1'),
    ).thenAnswer((_) async => null);
    await openSheet(tester);

    await tester.tap(find.text('Copy category default'));
    await tester.pump();

    final setup =
        verify(
              () => service.updateAgentInferenceSetup(
                agentId: 'agent-1',
                setup: captureAny(named: 'setup'),
              ),
            ).captured.single
            as AgentInferenceSetup;
    expect(setup.mode, AgentInferenceSetupMode.disabled);
    expect(setup.origin, AgentInferenceSetupOrigin.categorySnapshot);
    expect(setup.originEntityId, 'category-1');
  });
}
