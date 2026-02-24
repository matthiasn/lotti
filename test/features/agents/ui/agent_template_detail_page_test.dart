import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_template_detail_page.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../test_utils.dart';

final _testDate = DateTime(2024, 3, 15);

final _testProvider = AiConfig.inferenceProvider(
  id: 'prov-1',
  baseUrl: 'https://example.com',
  apiKey: 'key',
  name: 'Test Provider',
  createdAt: _testDate,
  inferenceProviderType: InferenceProviderType.gemini,
);

final _testModel = AiConfig.model(
  id: 'model-1',
  name: 'Test Model',
  providerModelId: 'models/test-model',
  inferenceProviderId: 'prov-1',
  createdAt: _testDate,
  inputModalities: [Modality.text],
  outputModalities: [Modality.text],
  isReasoningModel: true,
  supportsFunctionCalling: true,
);

/// Shared overrides for the AI config providers used by AgentModelSelector.
List<Override> _aiConfigOverrides({
  List<AiConfig> providers = const [],
  List<AiConfig> models = const [],
}) =>
    [
      aiConfigByTypeControllerProvider(
        configType: AiConfigType.inferenceProvider,
      ).overrideWithBuild(
        (ref, notifier) => Stream.value(providers),
      ),
      aiConfigByTypeControllerProvider(
        configType: AiConfigType.model,
      ).overrideWithBuild(
        (ref, notifier) => Stream.value(models),
      ),
    ];

void main() {
  late MockAgentTemplateService mockTemplateService;

  setUpAll(() {
    registerFallbackValue(AgentTemplateKind.taskAgent);
  });

  setUp(() async {
    await setUpTestGetIt();
    mockTemplateService = MockAgentTemplateService();
  });

  tearDown(tearDownTestGetIt);

  Widget buildCreateSubject({
    List<AiConfig> providers = const [],
    List<AiConfig> models = const [],
    List<Override> extraOverrides = const [],
  }) {
    return makeTestableWidgetNoScroll(
      const AgentTemplateDetailPage(),
      overrides: [
        agentTemplateServiceProvider.overrideWithValue(mockTemplateService),
        agentTemplatesProvider.overrideWith(
          (ref) async => <AgentDomainEntity>[],
        ),
        ..._aiConfigOverrides(providers: providers, models: models),
        ...extraOverrides,
      ],
    );
  }

  Widget buildEditSubject({
    required String templateId,
    AgentTemplateEntity? template,
    AgentTemplateVersionEntity? activeVersion,
    List<AgentTemplateVersionEntity> versionHistory = const [],
    List<Override> extraOverrides = const [],
  }) {
    final tpl =
        template ?? makeTestTemplate(id: templateId, agentId: templateId);
    final ver = activeVersion ?? makeTestTemplateVersion(agentId: templateId);

    return makeTestableWidgetNoScroll(
      AgentTemplateDetailPage(templateId: templateId),
      overrides: [
        agentTemplateServiceProvider.overrideWithValue(mockTemplateService),
        agentTemplateProvider.overrideWith(
          (ref, id) async => tpl,
        ),
        activeTemplateVersionProvider.overrideWith(
          (ref, id) async => ver,
        ),
        templateVersionHistoryProvider.overrideWith(
          (ref, id) async => versionHistory.isEmpty
              ? <AgentDomainEntity>[ver]
              : versionHistory.cast<AgentDomainEntity>(),
        ),
        agentTemplatesProvider.overrideWith(
          (ref) async => <AgentDomainEntity>[],
        ),
        ..._aiConfigOverrides(),
        ...extraOverrides,
      ],
    );
  }

  group('AgentTemplateDetailPage - Create mode', () {
    testWidgets('shows create title and empty form', (tester) async {
      await tester.pumpWidget(buildCreateSubject());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentTemplateDetailPage));
      expect(
        find.text(context.messages.agentTemplateCreateTitle),
        findsOneWidget,
      );

      // Name field is empty
      expect(
        find.text(context.messages.agentTemplateDisplayNameLabel),
        findsOneWidget,
      );
    });

    testWidgets('save is disabled without a model selected', (tester) async {
      await tester.pumpWidget(buildCreateSubject());
      await tester.pumpAndSettle();

      // Enter a name but no model selected
      final nameField = find.byType(TextField).first;
      await tester.enterText(nameField, 'My Template');
      await tester.pump();

      // Create button should be disabled (not tappable)
      final context = tester.element(find.byType(AgentTemplateDetailPage));
      final createButton = find.text(context.messages.createButton);
      expect(createButton, findsOneWidget);

      // The button's ancestor FilledButton should have null onPressed
      final button = tester.widget<FilledButton>(
        find.ancestor(
          of: createButton,
          matching: find.byType(FilledButton),
        ),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('save calls createTemplate and pops', (tester) async {
      when(
        () => mockTemplateService.createTemplate(
          displayName: any(named: 'displayName'),
          kind: any(named: 'kind'),
          modelId: any(named: 'modelId'),
          directives: any(named: 'directives'),
          authoredBy: any(named: 'authoredBy'),
        ),
      ).thenAnswer((_) async => makeTestTemplate());

      await tester.pumpWidget(
        buildCreateSubject(
          providers: [_testProvider],
          models: [_testModel],
        ),
      );
      await tester.pumpAndSettle();

      // Enter a name
      final nameField = find.byType(TextField).first;
      await tester.enterText(nameField, 'My Template');
      await tester.pump();

      // Select a model via the model picker
      final modelDropdowns = find.byIcon(Icons.arrow_drop_down);
      await tester.tap(modelDropdowns.at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Test Model'));
      await tester.pumpAndSettle();

      // Tap create button
      final context = tester.element(find.byType(AgentTemplateDetailPage));
      await tester.tap(find.text(context.messages.createButton));
      await tester.pumpAndSettle();

      verify(
        () => mockTemplateService.createTemplate(
          displayName: 'My Template',
          kind: AgentTemplateKind.taskAgent,
          modelId: 'models/test-model',
          directives: any(named: 'directives'),
          authoredBy: 'user',
        ),
      ).called(1);
    });
  });

  group('AgentTemplateDetailPage - Edit mode', () {
    const templateId = 'tpl-edit-001';

    testWidgets('populates form fields from template', (tester) async {
      when(() => mockTemplateService.getAgentsForTemplate(any()))
          .thenAnswer((_) async => []);

      await tester.pumpWidget(
        buildEditSubject(
          templateId: templateId,
          template: makeTestTemplate(
            id: templateId,
            agentId: templateId,
            displayName: 'Laura',
            modelId: 'models/custom-model',
          ),
          activeVersion: makeTestTemplateVersion(
            agentId: templateId,
            directives: 'Be helpful and kind.',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Name field populated
      expect(find.text('Laura'), findsOneWidget);
      // Model selector shows providerModelId as subtitle
      // (model name won't resolve without matching AI config)
      expect(find.text('models/custom-model'), findsOneWidget);
      // Directives populated
      expect(find.text('Be helpful and kind.'), findsOneWidget);
    });

    testWidgets('shows edit title and populated form fields', (tester) async {
      when(() => mockTemplateService.getAgentsForTemplate(any()))
          .thenAnswer((_) async => []);

      await tester.pumpWidget(
        buildEditSubject(templateId: templateId),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentTemplateDetailPage));
      expect(
        find.text(context.messages.agentTemplateEditTitle),
        findsOneWidget,
      );

      // Name field populated with template display name
      expect(find.text('Test Template'), findsOneWidget);
      // Directives field populated with version directives
      expect(find.text('You are a helpful agent.'), findsOneWidget);
      // Save-as-new-version button present
      expect(
        find.text(context.messages.agentTemplateSaveNewVersion),
        findsOneWidget,
      );
    });

    testWidgets('save calls createVersion', (tester) async {
      when(() => mockTemplateService.getAgentsForTemplate(any()))
          .thenAnswer((_) async => []);
      when(
        () => mockTemplateService.createVersion(
          templateId: any(named: 'templateId'),
          directives: any(named: 'directives'),
          authoredBy: any(named: 'authoredBy'),
        ),
      ).thenAnswer((_) async => makeTestTemplateVersion(version: 2));

      await tester.pumpWidget(
        buildEditSubject(templateId: templateId),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentTemplateDetailPage));
      await tester.tap(
        find.text(context.messages.agentTemplateSaveNewVersion),
      );
      await tester.pumpAndSettle();

      verify(
        () => mockTemplateService.createVersion(
          templateId: templateId,
          directives: any(named: 'directives'),
          authoredBy: 'user',
        ),
      ).called(1);
    });

    testWidgets('version history shows versions', (tester) async {
      when(() => mockTemplateService.getAgentsForTemplate(any()))
          .thenAnswer((_) async => []);

      final v1 = makeTestTemplateVersion(
        id: 'v1',
        agentId: templateId,
        status: AgentTemplateVersionStatus.archived,
      );
      final v2 = makeTestTemplateVersion(
        id: 'v2',
        agentId: templateId,
        version: 2,
      );

      await tester.pumpWidget(
        buildEditSubject(
          templateId: templateId,
          activeVersion: v2,
          versionHistory: [v2, v1],
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentTemplateDetailPage));

      // Scroll to make version history visible
      await tester.scrollUntilVisible(
        find.text(context.messages.agentTemplateVersionHistoryTitle),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Section title visible
      expect(
        find.text(context.messages.agentTemplateVersionHistoryTitle),
        findsOneWidget,
      );

      // Version labels visible
      expect(
        find.text(context.messages.agentTemplateVersionLabel(1)),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.agentTemplateVersionLabel(2)),
        findsOneWidget,
      );

      // Active/Archived badges visible
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Archived'), findsOneWidget);
    });

    testWidgets('rollback calls rollbackToVersion', (tester) async {
      when(() => mockTemplateService.getAgentsForTemplate(any()))
          .thenAnswer((_) async => []);
      when(
        () => mockTemplateService.rollbackToVersion(
          templateId: any(named: 'templateId'),
          versionId: any(named: 'versionId'),
        ),
      ).thenAnswer((_) async {});

      final v1 = makeTestTemplateVersion(
        id: 'v1',
        agentId: templateId,
        status: AgentTemplateVersionStatus.archived,
      );
      final v2 = makeTestTemplateVersion(
        id: 'v2',
        agentId: templateId,
        version: 2,
      );

      await tester.pumpWidget(
        buildEditSubject(
          templateId: templateId,
          activeVersion: v2,
          versionHistory: [v2, v1],
        ),
      );
      await tester.pumpAndSettle();

      // Scroll down to make the restore icon visible, then tap it
      await tester.scrollUntilVisible(
        find.byIcon(Icons.restore),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.restore));
      await tester.pumpAndSettle();

      // Confirm in dialog
      final context = tester.element(find.byType(AgentTemplateDetailPage));
      await tester.tap(
        find.text(context.messages.agentTemplateRollbackAction).last,
      );
      await tester.pumpAndSettle();

      verify(
        () => mockTemplateService.rollbackToVersion(
          templateId: templateId,
          versionId: 'v1',
        ),
      ).called(1);
    });

    testWidgets('delete calls deleteTemplate', (tester) async {
      when(() => mockTemplateService.getAgentsForTemplate(any()))
          .thenAnswer((_) async => []);
      when(() => mockTemplateService.deleteTemplate(any()))
          .thenAnswer((_) async {});

      await tester.pumpWidget(
        buildEditSubject(templateId: templateId),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentTemplateDetailPage));

      // Tap delete button
      await tester.tap(find.text(context.messages.deleteButton).first);
      await tester.pumpAndSettle();

      // Confirm in dialog
      await tester.tap(find.text(context.messages.deleteButton).last);
      await tester.pumpAndSettle();

      verify(
        () => mockTemplateService.deleteTemplate(templateId),
      ).called(1);
    });

    testWidgets('shows error when deleting template with instances',
        (tester) async {
      when(() => mockTemplateService.getAgentsForTemplate(any()))
          .thenAnswer((_) async => []);
      when(() => mockTemplateService.deleteTemplate(any())).thenThrow(
        const TemplateInUseException(
          templateId: 'test',
          activeCount: 1,
        ),
      );

      await tester.pumpWidget(
        buildEditSubject(templateId: templateId),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentTemplateDetailPage));

      // Tap delete button
      await tester.tap(find.text(context.messages.deleteButton).first);
      await tester.pumpAndSettle();

      // Confirm in dialog
      await tester.tap(find.text(context.messages.deleteButton).last);
      await tester.pumpAndSettle();

      expect(
        find.text(context.messages.agentTemplateDeleteHasInstances),
        findsOneWidget,
      );
    });

    testWidgets('shows loading indicator when template is loading',
        (tester) async {
      final completer = Completer<AgentDomainEntity?>();

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const AgentTemplateDetailPage(templateId: 'tpl-loading'),
          overrides: [
            agentTemplateServiceProvider.overrideWithValue(mockTemplateService),
            agentTemplateProvider.overrideWith(
              (ref, id) => completer.future,
            ),
            activeTemplateVersionProvider.overrideWith(
              (ref, id) async => null,
            ),
            templateVersionHistoryProvider.overrideWith(
              (ref, id) async => <AgentDomainEntity>[],
            ),
            agentTemplatesProvider.overrideWith(
              (ref) async => <AgentDomainEntity>[],
            ),
            ..._aiConfigOverrides(),
          ],
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('shows error state when provider errors', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const AgentTemplateDetailPage(templateId: 'tpl-error'),
          overrides: [
            agentTemplateServiceProvider.overrideWithValue(mockTemplateService),
            agentTemplateProvider.overrideWith(
              (ref, id) => throw Exception('provider failed'),
            ),
            activeTemplateVersionProvider.overrideWith(
              (ref, id) async => null,
            ),
            templateVersionHistoryProvider.overrideWith(
              (ref, id) async => <AgentDomainEntity>[],
            ),
            agentTemplatesProvider.overrideWith(
              (ref) async => <AgentDomainEntity>[],
            ),
            ..._aiConfigOverrides(),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentTemplateDetailPage));
      expect(
        find.text(context.messages.commonError),
        findsOneWidget,
      );
      // Should NOT show "not found"
      expect(
        find.text(context.messages.agentTemplateNotFound),
        findsNothing,
      );
    });

    testWidgets('shows template not found when template is null',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const AgentTemplateDetailPage(templateId: 'tpl-missing'),
          overrides: [
            agentTemplateServiceProvider.overrideWithValue(mockTemplateService),
            agentTemplateProvider.overrideWith(
              (ref, id) async => null,
            ),
            activeTemplateVersionProvider.overrideWith(
              (ref, id) async => null,
            ),
            templateVersionHistoryProvider.overrideWith(
              (ref, id) async => <AgentDomainEntity>[],
            ),
            agentTemplatesProvider.overrideWith(
              (ref) async => <AgentDomainEntity>[],
            ),
            ..._aiConfigOverrides(),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentTemplateDetailPage));
      expect(
        find.text(context.messages.agentTemplateNotFound),
        findsOneWidget,
      );
    });

    testWidgets('shows commonError snackbar when save fails', (tester) async {
      when(() => mockTemplateService.getAgentsForTemplate(any()))
          .thenAnswer((_) async => []);
      when(
        () => mockTemplateService.createVersion(
          templateId: any(named: 'templateId'),
          directives: any(named: 'directives'),
          authoredBy: any(named: 'authoredBy'),
        ),
      ).thenThrow(Exception('save failed'));

      await tester.pumpWidget(
        buildEditSubject(templateId: templateId),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentTemplateDetailPage));
      await tester.tap(
        find.text(context.messages.agentTemplateSaveNewVersion),
      );
      await tester.pumpAndSettle();

      expect(find.text(context.messages.commonError), findsOneWidget);
    });

    testWidgets('shows commonError snackbar on generic delete error',
        (tester) async {
      when(() => mockTemplateService.getAgentsForTemplate(any()))
          .thenAnswer((_) async => []);
      when(() => mockTemplateService.deleteTemplate(any()))
          .thenThrow(Exception('unexpected delete error'));

      await tester.pumpWidget(
        buildEditSubject(templateId: templateId),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentTemplateDetailPage));

      // Tap delete button
      await tester.tap(find.text(context.messages.deleteButton).first);
      await tester.pumpAndSettle();

      // Confirm in dialog
      await tester.tap(find.text(context.messages.deleteButton).last);
      await tester.pumpAndSettle();

      expect(find.text(context.messages.commonError), findsOneWidget);
    });

    testWidgets('shows commonError snackbar on rollback error', (tester) async {
      when(() => mockTemplateService.getAgentsForTemplate(any()))
          .thenAnswer((_) async => []);
      when(
        () => mockTemplateService.rollbackToVersion(
          templateId: any(named: 'templateId'),
          versionId: any(named: 'versionId'),
        ),
      ).thenThrow(Exception('rollback failed'));

      final v1 = makeTestTemplateVersion(
        id: 'v1',
        agentId: templateId,
        status: AgentTemplateVersionStatus.archived,
      );
      final v2 = makeTestTemplateVersion(
        id: 'v2',
        agentId: templateId,
        version: 2,
      );

      await tester.pumpWidget(
        buildEditSubject(
          templateId: templateId,
          activeVersion: v2,
          versionHistory: [v2, v1],
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to restore icon and tap
      await tester.scrollUntilVisible(
        find.byIcon(Icons.restore),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.restore));
      await tester.pumpAndSettle();

      // Confirm in dialog
      final context = tester.element(find.byType(AgentTemplateDetailPage));
      await tester.tap(
        find.text(context.messages.agentTemplateRollbackAction).last,
      );
      await tester.pumpAndSettle();

      expect(find.text(context.messages.commonError), findsOneWidget);
    });

    testWidgets('shows no versions text when version list is empty',
        (tester) async {
      when(() => mockTemplateService.getAgentsForTemplate(any()))
          .thenAnswer((_) async => []);

      final tpl = makeTestTemplate(id: templateId, agentId: templateId);
      final ver = makeTestTemplateVersion(agentId: templateId);

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const AgentTemplateDetailPage(templateId: templateId),
          overrides: [
            agentTemplateServiceProvider.overrideWithValue(mockTemplateService),
            agentTemplateProvider.overrideWith(
              (ref, id) async => tpl,
            ),
            activeTemplateVersionProvider.overrideWith(
              (ref, id) async => ver,
            ),
            templateVersionHistoryProvider.overrideWith(
              (ref, id) async => <AgentDomainEntity>[],
            ),
            agentTemplatesProvider.overrideWith(
              (ref) async => <AgentDomainEntity>[],
            ),
            ..._aiConfigOverrides(),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentTemplateDetailPage));

      // Scroll to version history section
      await tester.scrollUntilVisible(
        find.text(context.messages.agentTemplateVersionHistoryTitle),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(
        find.text(context.messages.agentTemplateNoVersions),
        findsOneWidget,
      );
    });

    testWidgets('shows loading indicator in version history section',
        (tester) async {
      when(() => mockTemplateService.getAgentsForTemplate(any()))
          .thenAnswer((_) async => []);

      final tpl = makeTestTemplate(id: templateId, agentId: templateId);
      final ver = makeTestTemplateVersion(agentId: templateId);
      final completer = Completer<List<AgentDomainEntity>>();

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const AgentTemplateDetailPage(templateId: templateId),
          overrides: [
            agentTemplateServiceProvider.overrideWithValue(mockTemplateService),
            agentTemplateProvider.overrideWith(
              (ref, id) async => tpl,
            ),
            activeTemplateVersionProvider.overrideWith(
              (ref, id) async => ver,
            ),
            templateVersionHistoryProvider.overrideWith(
              (ref, id) => completer.future,
            ),
            agentTemplatesProvider.overrideWith(
              (ref) async => <AgentDomainEntity>[],
            ),
            ..._aiConfigOverrides(),
          ],
        ),
      );
      // Use pump with duration instead of pumpAndSettle because the
      // Completer never completes, so animations never settle.
      await tester.pump(const Duration(seconds: 1));

      final context = tester.element(find.byType(AgentTemplateDetailPage));

      // Scroll to version history section
      await tester.scrollUntilVisible(
        find.text(context.messages.agentTemplateVersionHistoryTitle),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();

      // The version history section should show a loading indicator
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('shows error text in version history section', (tester) async {
      when(() => mockTemplateService.getAgentsForTemplate(any()))
          .thenAnswer((_) async => []);

      final tpl = makeTestTemplate(id: templateId, agentId: templateId);
      final ver = makeTestTemplateVersion(agentId: templateId);

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const AgentTemplateDetailPage(templateId: templateId),
          overrides: [
            agentTemplateServiceProvider.overrideWithValue(mockTemplateService),
            agentTemplateProvider.overrideWith(
              (ref, id) async => tpl,
            ),
            activeTemplateVersionProvider.overrideWith(
              (ref, id) async => ver,
            ),
            templateVersionHistoryProvider.overrideWith(
              (ref, id) => Future<List<AgentDomainEntity>>.error(
                Exception('version load failed'),
              ),
            ),
            agentTemplatesProvider.overrideWith(
              (ref) async => <AgentDomainEntity>[],
            ),
            ..._aiConfigOverrides(),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentTemplateDetailPage));

      // Scroll to version history section
      await tester.scrollUntilVisible(
        find.text(context.messages.agentTemplateVersionHistoryTitle),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // The error state shows commonError text
      expect(find.text(context.messages.commonError), findsOneWidget);
    });

    testWidgets('shows active instances section when agents exist',
        (tester) async {
      final testAgent = makeTestIdentity(
        id: 'agent-for-tpl',
        agentId: 'agent-for-tpl',
        displayName: 'Agent From Template',
      );

      when(() => mockTemplateService.getAgentsForTemplate(any()))
          .thenAnswer((_) async => [testAgent]);

      await tester.pumpWidget(
        buildEditSubject(templateId: templateId),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentTemplateDetailPage));

      // Scroll to active instances section
      await tester.scrollUntilVisible(
        find.text(context.messages.agentTemplateActiveInstancesTitle),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(
        find.text(context.messages.agentTemplateActiveInstancesTitle),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.agentTemplateInstanceCount(1)),
        findsOneWidget,
      );
    });

    testWidgets('shows evolve action button in edit mode', (tester) async {
      when(() => mockTemplateService.getAgentsForTemplate(any()))
          .thenAnswer((_) async => []);

      await tester.pumpWidget(
        buildEditSubject(templateId: templateId),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentTemplateDetailPage));

      // Scroll to evolve button
      await tester.scrollUntilVisible(
        find.text(context.messages.agentTemplateEvolveAction),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(
        find.text(context.messages.agentTemplateEvolveAction),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    });
  });
}
