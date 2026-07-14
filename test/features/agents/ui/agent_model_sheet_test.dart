import 'dart:async';

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
import 'package:lotti/features/design_system/components/checkboxes/design_system_checkbox.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../../categories/test_utils.dart';
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
  late GlobalKey<ScaffoldMessengerState> taskMessengerKey;

  setUp(() {
    service = MockTaskAgentService();
    journalDb = MockJournalDb();
    taskMessengerKey = GlobalKey<ScaffoldMessengerState>();
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

  List<Override> overrides({
    bool automaticUpdates = true,
    AgentConfig? config,
    ResolvedAgentSetup? resolvedSetup,
    TaskAgentSetupOptions? setupOptions,
  }) {
    final identity = makeTestIdentity().copyWith(
      config:
          config ??
          AgentConfig(
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
      taskAgentResolvedSetupProvider.overrideWith(
        (ref, id) async => resolvedSetup ?? resolved,
      ),
      taskAgentSetupOptionsProvider.overrideWith(
        (ref) async => setupOptions ?? options,
      ),
      taskAgentServiceProvider.overrideWithValue(service),
      journalDbProvider.overrideWithValue(journalDb),
    ];
  }

  Future<void> openSheet(
    WidgetTester tester, {
    bool automaticUpdates = true,
    AgentConfig? config,
    ResolvedAgentSetup? resolvedSetup,
    TaskAgentSetupOptions? setupOptions,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        ScaffoldMessenger(
          key: taskMessengerKey,
          child: Scaffold(
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
        ),
        overrides: overrides(
          automaticUpdates: automaticUpdates,
          config: config,
          resolvedSetup: resolvedSetup,
          setupOptions: setupOptions,
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> openProfilePage(WidgetTester tester) async {
    await tester.ensureVisible(
      find.byKey(const ValueKey('agent-choose-profile')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('agent-choose-profile')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
  }

  Future<void> openModelPage(WidgetTester tester) async {
    await tester.ensureVisible(
      find.byKey(const ValueKey('agent-choose-model')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('agent-choose-model')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
  }

  Future<void> revealDisableConfirmation(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('agent-disable')));
    await tester.pump();
    await tester.ensureVisible(find.text('Turn off'));
    await tester.pump();
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
        findsOneWidget,
      );
      expect(find.text('Saved profile · Profile default'), findsOneWidget);
      expect(find.text('You chose this for this agent'), findsOneWidget);
      expect(find.text('Saved profile'), findsOneWidget);
      expect(find.text('Choose a thinking model'), findsOneWidget);
      expect(find.text('No AI setup'), findsOneWidget);
      expect(find.byType(Divider), findsNothing);
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

      await openProfilePage(tester);
      expect(find.text('Copy category default'), findsOneWidget);
      expect(
        find.text(
          'Copies the category’s current setup. Later category changes won’t '
          'affect this agent.',
        ),
        findsOneWidget,
      );
      expect(
        find.byType(DesignSystemSelectionRow),
        findsNWidgets(2),
      );
    },
  );

  testWidgets(
    'automation checkbox persists off',
    (
      tester,
    ) async {
      await openSheet(tester);

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

  testWidgets(
    'profile choice waits for persistence, closes, and toasts in task scope',
    (tester) async {
      final saveCompleter = Completer<void>();
      when(
        () => service.updateAgentProfile(
          agentId: any(named: 'agentId'),
          profileId: any(named: 'profileId'),
        ),
      ).thenAnswer((_) => saveCompleter.future);
      await openSheet(tester);

      await openProfilePage(tester);
      await tester.tap(
        find.byKey(const ValueKey('agent-profile-profile-1')),
      );
      await tester.pump();

      expect(find.text('Choose an inference profile'), findsOneWidget);
      expect(find.byType(DesignSystemToast), findsNothing);

      saveCompleter.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      verify(
        () => service.updateAgentProfile(
          agentId: 'agent-1',
          profileId: 'profile-1',
        ),
      ).called(1);
      expect(find.text('Agent setup'), findsNothing);
      expect(
        find.text(
          'Using Saved profile for every future agent update until you change it.',
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(taskMessengerKey),
          matching: find.byType(DesignSystemToast),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('model choice persists and closes the outer setup modal', (
    tester,
  ) async {
    await openSheet(tester);

    await openModelPage(tester);
    expect(find.text('Qwen 3.5 Plus'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('agent-model-model-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    verify(
      () => service.updateAgentThinkingModelOverride(
        agentId: 'agent-1',
        modelConfigId: 'model-1',
      ),
    ).called(1);
    expect(find.text('Agent setup'), findsNothing);
    expect(
      find.textContaining('Using Qwen 3.5 Plus'),
      findsOneWidget,
    );
  });

  testWidgets('multiple providers drill down and back within the same modal', (
    tester,
  ) async {
    final secondProvider = AiConfigInferenceProvider(
      id: 'provider-2',
      baseUrl: 'http://localhost:11434',
      apiKey: '',
      name: 'Local Ollama',
      createdAt: DateTime(2024),
      inferenceProviderType: InferenceProviderType.ollama,
    );
    final secondModel = AiConfigModel(
      id: 'model-2',
      name: 'Llama Local',
      providerModelId: 'llama:latest',
      inferenceProviderId: secondProvider.id,
      createdAt: DateTime(2024),
      inputModalities: const [Modality.text],
      outputModalities: const [Modality.text],
      isReasoningModel: false,
    );
    await openSheet(
      tester,
      config: AgentConfig(
        automaticUpdatesEnabled: true,
        inferenceSetup: AgentInferenceSetup(
          mode: AgentInferenceSetupMode.configured,
          origin: AgentInferenceSetupOrigin.user,
          baseProfileId: profile.id,
          thinkingModelOverrideId: secondModel.id,
        ),
      ),
      setupOptions: TaskAgentSetupOptions(
        profiles: [profile],
        models: [model, secondModel],
        providers: [provider, secondProvider],
      ),
    );

    await openModelPage(tester);
    expect(
      find.byKey(const ValueKey('agent-provider-provider-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('agent-provider-provider-2')),
      findsOneWidget,
    );
    expect(find.byType(Divider), findsNothing);

    final modelBackButton = tester
        .widgetList<IconButton>(find.byType(IconButton))
        .where((button) => button.tooltip == 'Back')
        .last;
    modelBackButton.onPressed!();
    await tester.pumpAndSettle();
    expect(find.text('Agent setup'), findsOneWidget);

    await openModelPage(tester);
    await tester.tap(
      find.byKey(const ValueKey('agent-provider-provider-2')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Llama Local'), findsOneWidget);
    final selectedRow = tester.widget<DesignSystemSelectionRow>(
      find.byKey(const ValueKey('agent-model-model-2')),
    );
    expect(selectedRow.selected, isTrue);
    expect(selectedRow.selectedLabel, 'Selected');

    final selectedModelBackButton = tester
        .widgetList<IconButton>(find.byType(IconButton))
        .where((button) => button.tooltip == 'Back')
        .last;
    selectedModelBackButton.onPressed!();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('agent-provider-provider-2')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('agent-provider-provider-2')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('agent-model-model-2')));
    await tester.pump(const Duration(milliseconds: 500));

    verify(
      () => service.updateAgentThinkingModelOverride(
        agentId: 'agent-1',
        modelConfigId: 'model-2',
      ),
    ).called(1);
    expect(find.text('Agent setup'), findsNothing);
  });

  testWidgets('No AI setup requires confirmation and persists disabled mode', (
    tester,
  ) async {
    await openSheet(tester);

    await revealDisableConfirmation(tester);
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
    final saveCompleter = Completer<void>();
    when(
      () => service.updateAgentInferenceSetup(
        agentId: any(named: 'agentId'),
        setup: any(named: 'setup'),
      ),
    ).thenAnswer((_) => saveCompleter.future);
    final task = makeTestTask(id: 'task-1').copyWith(
      meta: makeTestTask(id: 'task-1').meta.copyWith(categoryId: 'category-1'),
    );
    when(
      () => journalDb.journalEntityById('task-1'),
    ).thenAnswer((_) async => task);
    when(
      () => journalDb.getCategoryById('category-1'),
    ).thenAnswer(
      (_) async => CategoryTestUtils.createTestCategory(id: 'category-1'),
    );
    await openSheet(tester);

    await openProfilePage(tester);
    await tester.tap(find.text('Copy category default'));
    await tester.pump();

    expect(find.text('Choose an inference profile'), findsOneWidget);

    saveCompleter.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

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
    expect(find.text('Agent setup'), findsNothing);
  });

  testWidgets('category default copies its profile and model snapshot', (
    tester,
  ) async {
    final task = makeTestTask(id: 'task-1').copyWith(
      meta: makeTestTask(id: 'task-1').meta.copyWith(categoryId: 'category-1'),
    );
    when(
      () => journalDb.journalEntityById('task-1'),
    ).thenAnswer((_) async => task);
    when(() => journalDb.getCategoryById('category-1')).thenAnswer(
      (_) async => CategoryTestUtils.createTestCategory(
        id: 'category-1',
        defaultProfileId: profile.id,
      ),
    );
    await openSheet(tester);

    await openProfilePage(tester);
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
    expect(setup.mode, AgentInferenceSetupMode.configured);
    expect(setup.baseProfileId, profile.id);
    expect(find.textContaining('Using Saved profile'), findsWidgets);
  });

  testWidgets('origin labels cover disabled, category, template, and legacy', (
    tester,
  ) async {
    final cases = <(ResolvedAgentSetup, String)>[
      (
        const ResolvedAgentSetup(status: AgentSetupResolutionStatus.disabled),
        'Disabled',
      ),
      (
        ResolvedAgentSetup(
          status: AgentSetupResolutionStatus.resolved,
          profile: resolved.profile,
          setupOrigin: AgentInferenceSetupOrigin.categorySnapshot,
        ),
        'Copied from the category default when this agent was created',
      ),
      (
        ResolvedAgentSetup(
          status: AgentSetupResolutionStatus.resolved,
          profile: resolved.profile,
          setupOrigin: AgentInferenceSetupOrigin.templateSnapshot,
        ),
        'Copied from the template',
      ),
      (
        ResolvedAgentSetup(
          status: AgentSetupResolutionStatus.resolved,
          profile: resolved.profile,
          setupOrigin: AgentInferenceSetupOrigin.unknown,
        ),
        'Legacy setup',
      ),
    ];

    for (final (setup, expected) in cases) {
      await openSheet(tester, resolvedSetup: setup);
      expect(find.text(expected), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('broken profile routes and empty model state remain explicit', (
    tester,
  ) async {
    await openSheet(
      tester,
      setupOptions: TaskAgentSetupOptions(
        profiles: [profile],
        models: const [],
        providers: [provider],
      ),
    );
    expect(
      find.text('No compatible thinking models available'),
      findsOneWidget,
    );
    await openProfilePage(tester);
    expect(find.text('Selected AI setup is unavailable'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    await openSheet(
      tester,
      setupOptions: TaskAgentSetupOptions(
        profiles: [profile],
        models: [model],
        providers: const [],
      ),
    );
    await openProfilePage(tester);
    expect(find.text('Selected AI setup is unavailable'), findsOneWidget);
    await tester.tap(find.byTooltip('Back').last);
    await tester.pumpAndSettle();
    await openModelPage(tester);
    expect(
      find.byKey(const ValueKey('agent-model-model-1')),
      findsOneWidget,
    );
  });

  testWidgets('failed save shows an error and restores interaction', (
    tester,
  ) async {
    when(
      () => service.updateAgentProfile(
        agentId: any(named: 'agentId'),
        profileId: any(named: 'profileId'),
      ),
    ).thenThrow(StateError('save failed'));
    await openSheet(tester);

    await openProfilePage(tester);
    await tester.tap(
      find.byKey(const ValueKey('agent-profile-profile-1')),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Error'), findsWidgets);
    expect(
      tester
          .widgetList<AbsorbPointer>(find.byType(AbsorbPointer))
          .any((widget) => !widget.absorbing),
      isTrue,
    );
  });

  testWidgets('cancel keeps AI setup and direct override can be cleared', (
    tester,
  ) async {
    await openSheet(
      tester,
      config: AgentConfig(
        automaticUpdatesEnabled: true,
        inferenceSetup: AgentInferenceSetup(
          mode: AgentInferenceSetupMode.configured,
          origin: AgentInferenceSetupOrigin.user,
          baseProfileId: profile.id,
          thinkingModelOverrideId: model.id,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('agent-clear-override')));
    await tester.pump();
    verify(
      () => service.updateAgentThinkingModelOverride(
        agentId: 'agent-1',
        modelConfigId: null,
      ),
    ).called(1);

    await revealDisableConfirmation(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    verifyNever(
      () => service.updateAgentInferenceSetup(
        agentId: any(named: 'agentId'),
        setup: any(named: 'setup'),
      ),
    );
  });

  testWidgets('disabled setup blocks automation and explains remediation', (
    tester,
  ) async {
    await openSheet(
      tester,
      config: const AgentConfig(
        automaticUpdatesEnabled: false,
        inferenceSetup: AgentInferenceSetup(
          mode: AgentInferenceSetupMode.disabled,
          origin: AgentInferenceSetupOrigin.user,
        ),
      ),
      resolvedSetup: const ResolvedAgentSetup(
        status: AgentSetupResolutionStatus.disabled,
      ),
      setupOptions: const TaskAgentSetupOptions(
        profiles: [],
        models: [],
        providers: [],
      ),
    );

    expect(find.text('No AI setup'), findsNWidgets(2));
    expect(
      find.text('Choose an AI setup before turning on automatic updates.'),
      findsOneWidget,
    );
    final checkbox = tester.widget<DesignSystemCheckbox>(
      find.byKey(const Key('taskAgentAutomaticUpdatesCheckbox')),
    );
    expect(checkbox.onChanged, isNull);

    await openProfilePage(tester);
    expect(find.text('No profiles available on this device'), findsOneWidget);
  });
}
