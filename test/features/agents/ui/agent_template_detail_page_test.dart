import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_token_usage.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_report_section.dart';
import 'package:lotti/features/agents/ui/agent_template_detail_page.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/ui/form_bottom_bar.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../test_utils.dart';

late MockNavService _mockNavService;

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

/// Common overrides for template stats/reports providers (empty data).
List<Override> _templateStatsOverrides() => [
      templateTokenUsageSummariesProvider.overrideWith(
        (ref, id) async => <AgentTokenUsageSummary>[],
      ),
      templateInstanceTokenBreakdownProvider.overrideWith(
        (ref, id) async => <InstanceTokenBreakdown>[],
      ),
      templateRecentReportsProvider.overrideWith(
        (ref, id) async => <AgentDomainEntity>[],
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
    _mockNavService = MockNavService();
    when(() => _mockNavService.currentPath).thenReturn('/settings/agents');
    when(() => _mockNavService.beamBack()).thenReturn(null);
    getIt.registerSingleton<NavService>(_mockNavService);
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
        ..._templateStatsOverrides(),
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

    testWidgets('save is enabled with default model pre-selected',
        (tester) async {
      await tester.pumpWidget(buildCreateSubject());
      await tester.pumpAndSettle();

      // Enter a name — model is pre-selected to Gemini Flash
      final nameField = find.byType(TextField).first;
      await tester.enterText(nameField, 'My Template');
      await tester.pump();

      // Create button should be enabled since model defaults to Flash
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
      expect(button.onPressed, isNotNull);
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
            generalDirective: 'Be helpful and kind.',
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
      // General directive field falls back to legacy directives when empty.
      expect(find.text('You are a helpful agent.'), findsOneWidget);
      // Save-as-new-version button present
      expect(
        find.text(context.messages.agentTemplateSaveNewVersion),
        findsOneWidget,
      );
    });

    testWidgets('uses generalDirective over legacy directives when non-empty',
        (tester) async {
      when(() => mockTemplateService.getAgentsForTemplate(any()))
          .thenAnswer((_) async => []);

      await tester.pumpWidget(
        buildEditSubject(
          templateId: templateId,
          activeVersion: makeTestTemplateVersion(
            agentId: templateId,
            directives: 'Legacy text',
            generalDirective: 'Modern general directive',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should use the new field, not the legacy one.
      expect(find.text('Modern general directive'), findsOneWidget);
      expect(find.text('Legacy text'), findsNothing);
    });

    testWidgets('save calls updateTemplate and createVersion', (tester) async {
      when(() => mockTemplateService.getAgentsForTemplate(any()))
          .thenAnswer((_) async => []);
      when(
        () => mockTemplateService.updateTemplate(
          templateId: any(named: 'templateId'),
          displayName: any(named: 'displayName'),
          modelId: any(named: 'modelId'),
          profileId: any(named: 'profileId'),
          clearProfileId: any(named: 'clearProfileId'),
        ),
      ).thenAnswer((_) async => makeTestTemplate(id: templateId));
      when(
        () => mockTemplateService.createVersion(
          templateId: any(named: 'templateId'),
          directives: any(named: 'directives'),
          authoredBy: any(named: 'authoredBy'),
          generalDirective: any(named: 'generalDirective'),
          reportDirective: any(named: 'reportDirective'),
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
        () => mockTemplateService.updateTemplate(
          templateId: templateId,
          displayName: 'Test Template',
          modelId: 'models/gemini-3-flash-preview',
          profileId: any(named: 'profileId'),
          clearProfileId: any(named: 'clearProfileId'),
        ),
      ).called(1);
      verify(
        () => mockTemplateService.createVersion(
          templateId: templateId,
          directives: any(named: 'directives'),
          authoredBy: 'user',
          generalDirective: any(named: 'generalDirective'),
          reportDirective: any(named: 'reportDirective'),
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

      // Tap delete icon button
      await tester.tap(find.byIcon(Icons.delete_outline));
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

      // Tap delete icon button
      await tester.tap(find.byIcon(Icons.delete_outline));
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
        () => mockTemplateService.updateTemplate(
          templateId: any(named: 'templateId'),
          displayName: any(named: 'displayName'),
          modelId: any(named: 'modelId'),
          profileId: any(named: 'profileId'),
          clearProfileId: any(named: 'clearProfileId'),
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

      // Tap delete icon button
      await tester.tap(find.byIcon(Icons.delete_outline));
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
            ..._templateStatsOverrides(),
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
            ..._templateStatsOverrides(),
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
            ..._templateStatsOverrides(),
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

    testWidgets('reseeds directives when active version changes',
        (tester) async {
      when(() => mockTemplateService.getAgentsForTemplate(any()))
          .thenAnswer((_) async => []);

      final v1 = makeTestTemplateVersion(
        id: 'v1',
        agentId: templateId,
        directives: 'Version 1 directives',
      );
      final v2 = makeTestTemplateVersion(
        id: 'v2',
        agentId: templateId,
        version: 2,
        directives: 'Version 2 directives',
      );

      // Start with v1 as active version.
      var currentVersion = v1;

      final overrides = [
        agentTemplateServiceProvider.overrideWithValue(mockTemplateService),
        agentTemplateProvider.overrideWith(
          (ref, id) async =>
              makeTestTemplate(id: templateId, agentId: templateId),
        ),
        activeTemplateVersionProvider.overrideWith(
          (ref, id) async => currentVersion,
        ),
        templateVersionHistoryProvider.overrideWith(
          (ref, id) async => <AgentDomainEntity>[currentVersion],
        ),
        agentTemplatesProvider.overrideWith(
          (ref) async => <AgentDomainEntity>[],
        ),
        templateTokenUsageSummariesProvider.overrideWith(
          (ref, id) async => <AgentTokenUsageSummary>[],
        ),
        templateInstanceTokenBreakdownProvider.overrideWith(
          (ref, id) async => <InstanceTokenBreakdown>[],
        ),
        templateRecentReportsProvider.overrideWith(
          (ref, id) async => <AgentDomainEntity>[],
        ),
        ..._aiConfigOverrides(),
      ];

      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MediaQuery(
            data: MediaQueryData(
              size: Size(400, 800),
            ),
            child: MaterialApp(
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              home: AgentTemplateDetailPage(templateId: templateId),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify v1 directives are shown.
      expect(find.text('Version 1 directives'), findsOneWidget);

      // Simulate evolution approval: switch to v2 and invalidate.
      currentVersion = v2;
      container.invalidate(activeTemplateVersionProvider(templateId));
      await tester.pumpAndSettle();

      // Directive field should now show v2 directives.
      expect(find.text('Version 2 directives'), findsOneWidget);
      expect(find.text('Version 1 directives'), findsNothing);
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

    testWidgets('shows three tabs in edit mode', (tester) async {
      when(() => mockTemplateService.getAgentsForTemplate(any()))
          .thenAnswer((_) async => []);

      await tester.pumpWidget(
        buildEditSubject(templateId: templateId),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentTemplateDetailPage));

      expect(
        find.text(context.messages.agentTemplateSettingsTab),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.agentTemplateStatsTab),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.agentTemplateReportsTab),
        findsOneWidget,
      );
    });

    testWidgets('bottom bar hidden on Stats and Reports tabs', (tester) async {
      when(() => mockTemplateService.getAgentsForTemplate(any()))
          .thenAnswer((_) async => []);

      await tester.pumpWidget(
        buildEditSubject(templateId: templateId),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentTemplateDetailPage));

      // Bottom bar visible on Settings tab
      expect(find.byType(FormBottomBar), findsOneWidget);
      expect(
        find.text(context.messages.agentTemplateSaveNewVersion),
        findsOneWidget,
      );

      // Switch to Stats tab — bottom bar should disappear
      await tester.tap(find.text(context.messages.agentTemplateStatsTab));
      await tester.pumpAndSettle();
      expect(find.byType(FormBottomBar), findsNothing);

      // Switch to Reports tab — bottom bar should still be hidden
      await tester.tap(find.text(context.messages.agentTemplateReportsTab));
      await tester.pumpAndSettle();
      expect(find.byType(FormBottomBar), findsNothing);

      // Switch back to Settings tab — bottom bar should reappear
      await tester.tap(find.text(context.messages.agentTemplateSettingsTab));
      await tester.pumpAndSettle();
      expect(find.byType(FormBottomBar), findsOneWidget);
    });

    testWidgets('Stats tab shows token usage section', (tester) async {
      when(() => mockTemplateService.getAgentsForTemplate(any()))
          .thenAnswer((_) async => []);

      await tester.pumpWidget(
        buildEditSubject(templateId: templateId),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentTemplateDetailPage));

      // Navigate to Stats tab
      await tester.tap(find.text(context.messages.agentTemplateStatsTab));
      await tester.pumpAndSettle();

      // Should show the aggregate heading from TemplateTokenUsageSection
      expect(
        find.text(context.messages.agentTemplateAggregateTokenUsageHeading),
        findsOneWidget,
      );
    });

    testWidgets('Reports tab shows empty state when no reports',
        (tester) async {
      when(() => mockTemplateService.getAgentsForTemplate(any()))
          .thenAnswer((_) async => []);

      await tester.pumpWidget(
        buildEditSubject(templateId: templateId),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentTemplateDetailPage));

      // Navigate to Reports tab
      await tester.tap(find.text(context.messages.agentTemplateReportsTab));
      await tester.pumpAndSettle();

      expect(
        find.text(context.messages.agentTemplateReportsEmpty),
        findsOneWidget,
      );
    });

    testWidgets('Reports tab shows report cards with content', (tester) async {
      when(() => mockTemplateService.getAgentsForTemplate(any()))
          .thenAnswer((_) async => []);

      final report1 = makeTestReport(
        id: 'r1',
        agentId: 'agent-a',
        content: 'Weekly summary: all good.',
        createdAt: DateTime(2025, 6, 15, 10, 30),
      );
      final report2 = makeTestReport(
        id: 'r2',
        agentId: 'agent-b',
        content: 'Task progress update.',
        createdAt: DateTime(2025, 6, 14, 8),
      );

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const AgentTemplateDetailPage(templateId: templateId),
          overrides: [
            agentTemplateServiceProvider.overrideWithValue(mockTemplateService),
            agentTemplateProvider.overrideWith(
              (ref, id) async => makeTestTemplate(
                id: templateId,
                agentId: templateId,
              ),
            ),
            activeTemplateVersionProvider.overrideWith(
              (ref, id) async => makeTestTemplateVersion(
                agentId: templateId,
              ),
            ),
            templateVersionHistoryProvider.overrideWith(
              (ref, id) async => <AgentDomainEntity>[
                makeTestTemplateVersion(agentId: templateId),
              ],
            ),
            agentTemplatesProvider.overrideWith(
              (ref) async => <AgentDomainEntity>[],
            ),
            templateTokenUsageSummariesProvider.overrideWith(
              (ref, id) async => <AgentTokenUsageSummary>[],
            ),
            templateInstanceTokenBreakdownProvider.overrideWith(
              (ref, id) async => <InstanceTokenBreakdown>[],
            ),
            templateRecentReportsProvider.overrideWith(
              (ref, id) async => <AgentDomainEntity>[report1, report2],
            ),
            ..._aiConfigOverrides(),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentTemplateDetailPage));

      // Navigate to Reports tab
      await tester.tap(find.text(context.messages.agentTemplateReportsTab));
      await tester.pumpAndSettle();

      // Report content visible (rendered via GptMarkdown inside
      // AgentReportSection)
      expect(find.textContaining('Weekly summary'), findsOneWidget);
      expect(find.textContaining('Task progress'), findsOneWidget);

      // Each report renders inside a ModernBaseCard
      expect(find.byType(AgentReportSection), findsNWidgets(2));
    });

    testWidgets('Reports tab renders report with tldr field', (tester) async {
      when(() => mockTemplateService.getAgentsForTemplate(any()))
          .thenAnswer((_) async => []);

      final report = makeTestReport(
        id: 'r1',
        agentId: 'agent-a',
        content: '# Full Report\n\nDetailed analysis here.',
        tldr: 'Brief summary of findings.',
        createdAt: DateTime(2025, 6, 15, 10, 30),
      );

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const AgentTemplateDetailPage(templateId: templateId),
          overrides: [
            agentTemplateServiceProvider.overrideWithValue(mockTemplateService),
            agentTemplateProvider.overrideWith(
              (ref, id) async => makeTestTemplate(
                id: templateId,
                agentId: templateId,
              ),
            ),
            activeTemplateVersionProvider.overrideWith(
              (ref, id) async => makeTestTemplateVersion(
                agentId: templateId,
              ),
            ),
            templateVersionHistoryProvider.overrideWith(
              (ref, id) async => <AgentDomainEntity>[
                makeTestTemplateVersion(agentId: templateId),
              ],
            ),
            agentTemplatesProvider.overrideWith(
              (ref) async => <AgentDomainEntity>[],
            ),
            templateTokenUsageSummariesProvider.overrideWith(
              (ref, id) async => <AgentTokenUsageSummary>[],
            ),
            templateInstanceTokenBreakdownProvider.overrideWith(
              (ref, id) async => <InstanceTokenBreakdown>[],
            ),
            templateRecentReportsProvider.overrideWith(
              (ref, id) async => <AgentDomainEntity>[report],
            ),
            ..._aiConfigOverrides(),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentTemplateDetailPage));

      // Navigate to Reports tab
      await tester.tap(find.text(context.messages.agentTemplateReportsTab));
      await tester.pumpAndSettle();

      // TLDR text should be visible (always shown)
      expect(find.textContaining('Brief summary'), findsOneWidget);
      expect(find.byType(AgentReportSection), findsOneWidget);
    });

    testWidgets('Reports tab skips non-AgentReportEntity items',
        (tester) async {
      when(() => mockTemplateService.getAgentsForTemplate(any()))
          .thenAnswer((_) async => []);

      final report = makeTestReport(
        id: 'r1',
        agentId: 'agent-a',
        content: 'Valid report.',
        createdAt: DateTime(2025, 6, 15, 10, 30),
      );
      // A non-report entity mixed in (e.g. an agent message)
      final nonReport = makeTestMessage(
        id: 'msg-1',
        agentId: 'agent-a',
      );

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const AgentTemplateDetailPage(templateId: templateId),
          overrides: [
            agentTemplateServiceProvider.overrideWithValue(mockTemplateService),
            agentTemplateProvider.overrideWith(
              (ref, id) async => makeTestTemplate(
                id: templateId,
                agentId: templateId,
              ),
            ),
            activeTemplateVersionProvider.overrideWith(
              (ref, id) async => makeTestTemplateVersion(
                agentId: templateId,
              ),
            ),
            templateVersionHistoryProvider.overrideWith(
              (ref, id) async => <AgentDomainEntity>[
                makeTestTemplateVersion(agentId: templateId),
              ],
            ),
            agentTemplatesProvider.overrideWith(
              (ref) async => <AgentDomainEntity>[],
            ),
            templateTokenUsageSummariesProvider.overrideWith(
              (ref, id) async => <AgentTokenUsageSummary>[],
            ),
            templateInstanceTokenBreakdownProvider.overrideWith(
              (ref, id) async => <InstanceTokenBreakdown>[],
            ),
            templateRecentReportsProvider.overrideWith(
              (ref, id) async => <AgentDomainEntity>[report, nonReport],
            ),
            ..._aiConfigOverrides(),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentTemplateDetailPage));

      // Navigate to Reports tab
      await tester.tap(find.text(context.messages.agentTemplateReportsTab));
      await tester.pumpAndSettle();

      // Valid report is shown (rendered via GptMarkdown inside
      // AgentReportSection)
      expect(find.textContaining('Valid report'), findsOneWidget);
      // Only one AgentReportSection for the valid report (non-report item
      // renders as SizedBox.shrink)
      expect(find.byType(AgentReportSection), findsOneWidget);
    });

    testWidgets('Reports tab shows loading indicator', (tester) async {
      when(() => mockTemplateService.getAgentsForTemplate(any()))
          .thenAnswer((_) async => []);

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const AgentTemplateDetailPage(templateId: templateId),
          overrides: [
            agentTemplateServiceProvider.overrideWithValue(mockTemplateService),
            agentTemplateProvider.overrideWith(
              (ref, id) async => makeTestTemplate(
                id: templateId,
                agentId: templateId,
              ),
            ),
            activeTemplateVersionProvider.overrideWith(
              (ref, id) async => makeTestTemplateVersion(
                agentId: templateId,
              ),
            ),
            templateVersionHistoryProvider.overrideWith(
              (ref, id) async => <AgentDomainEntity>[
                makeTestTemplateVersion(agentId: templateId),
              ],
            ),
            agentTemplatesProvider.overrideWith(
              (ref) async => <AgentDomainEntity>[],
            ),
            templateTokenUsageSummariesProvider.overrideWith(
              (ref, id) async => <AgentTokenUsageSummary>[],
            ),
            templateInstanceTokenBreakdownProvider.overrideWith(
              (ref, id) async => <InstanceTokenBreakdown>[],
            ),
            templateRecentReportsProvider.overrideWith(
              (ref, id) => Completer<List<AgentDomainEntity>>().future,
            ),
            ..._aiConfigOverrides(),
          ],
        ),
      );
      // Use pump with duration (not pumpAndSettle) so we can navigate
      // while keeping the reports provider in loading state.
      await tester.pump(const Duration(seconds: 1));

      final context = tester.element(find.byType(AgentTemplateDetailPage));

      // Navigate to Reports tab
      await tester.tap(find.text(context.messages.agentTemplateReportsTab));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('Reports tab shows error state', (tester) async {
      when(() => mockTemplateService.getAgentsForTemplate(any()))
          .thenAnswer((_) async => []);

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const AgentTemplateDetailPage(templateId: templateId),
          overrides: [
            agentTemplateServiceProvider.overrideWithValue(mockTemplateService),
            agentTemplateProvider.overrideWith(
              (ref, id) async => makeTestTemplate(
                id: templateId,
                agentId: templateId,
              ),
            ),
            activeTemplateVersionProvider.overrideWith(
              (ref, id) async => makeTestTemplateVersion(
                agentId: templateId,
              ),
            ),
            templateVersionHistoryProvider.overrideWith(
              (ref, id) async => <AgentDomainEntity>[
                makeTestTemplateVersion(agentId: templateId),
              ],
            ),
            agentTemplatesProvider.overrideWith(
              (ref) async => <AgentDomainEntity>[],
            ),
            templateTokenUsageSummariesProvider.overrideWith(
              (ref, id) async => <AgentTokenUsageSummary>[],
            ),
            templateInstanceTokenBreakdownProvider.overrideWith(
              (ref, id) async => <InstanceTokenBreakdown>[],
            ),
            templateRecentReportsProvider(templateId).overrideWithValue(
              AsyncValue<List<AgentDomainEntity>>.error(
                Exception('reports fetch failed'),
                StackTrace.current,
              ),
            ),
            ..._aiConfigOverrides(),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentTemplateDetailPage));

      // Navigate to Reports tab
      await tester.tap(find.text(context.messages.agentTemplateReportsTab));
      await tester.pumpAndSettle();

      expect(
        find.text(context.messages.commonError),
        findsOneWidget,
      );
    });
  });

  group('AgentTemplateDetailPage - back navigation', () {
    const templateId = 'tpl-nav-001';

    testWidgets('back chevron calls beamBack when in settings path',
        (tester) async {
      when(() => mockTemplateService.getAgentsForTemplate(any()))
          .thenAnswer((_) async => []);

      await tester.pumpWidget(
        buildEditSubject(templateId: templateId),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();

      verify(() => _mockNavService.beamBack()).called(1);
    });

    testWidgets('back chevron calls Navigator.pop when not in settings path',
        (tester) async {
      when(() => _mockNavService.currentPath).thenReturn('/tasks');
      when(() => mockTemplateService.getAgentsForTemplate(any()))
          .thenAnswer((_) async => []);

      await tester.pumpWidget(
        buildEditSubject(templateId: templateId),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();

      verifyNever(() => _mockNavService.beamBack());
    });

    testWidgets('back chevron works on create mode', (tester) async {
      await tester.pumpWidget(buildCreateSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();

      verify(() => _mockNavService.beamBack()).called(1);
    });

    testWidgets('back chevron works on error state', (tester) async {
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

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();

      verify(() => _mockNavService.beamBack()).called(1);
    });

    testWidgets('back chevron works on not-found state', (tester) async {
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

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();

      verify(() => _mockNavService.beamBack()).called(1);
    });

    testWidgets('cancel button navigates back', (tester) async {
      when(() => mockTemplateService.getAgentsForTemplate(any()))
          .thenAnswer((_) async => []);

      await tester.pumpWidget(
        buildEditSubject(templateId: templateId),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentTemplateDetailPage));
      await tester.tap(find.text(context.messages.cancelButton));
      await tester.pump();

      verify(() => _mockNavService.beamBack()).called(1);
    });
  });
}
