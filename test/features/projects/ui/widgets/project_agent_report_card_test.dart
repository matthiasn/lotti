import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/change_set_providers.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';
import 'package:lotti/features/ai/model/ai_config.dart' show AiConfig;
import 'package:lotti/features/ai/state/inference_profile_controller.dart';
import 'package:lotti/features/projects/ui/widgets/project_agent_report_card.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../../agents/test_utils.dart';

void main() {
  const projectId = 'proj-agent-1';
  const projectTitle = 'My Project';
  const categoryId = 'cat-1';

  final testAgent =
      AgentDomainEntity.agent(
            id: 'agent-1',
            agentId: 'agent-1',
            kind: 'project_agent',
            displayName: 'My Project Agent',
            lifecycle: AgentLifecycle.active,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: 'state-1',
            config: const AgentConfig(),
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          )
          as AgentIdentityEntity;
  final testProfile = testInferenceProfile(id: 'profile-1', name: 'Profile 1');

  Widget buildSubject({
    List<Override> overrides = const [],
  }) {
    return makeTestableWidgetWithScaffold(
      const ProjectAgentReportCard(
        projectId: projectId,
        projectTitle: projectTitle,
        categoryId: categoryId,
      ),
      overrides: overrides,
    );
  }

  setUpAll(registerAllFallbackValues);

  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  group('ProjectAgentReportCard', () {
    testWidgets('shows nothing when loading', (tester) async {
      final completer = Completer<AgentDomainEntity?>();

      await tester.pumpWidget(
        buildSubject(
          overrides: [
            projectAgentProvider(projectId).overrideWith(
              (ref) => completer.future,
            ),
          ],
        ),
      );
      await tester.pump();

      // Loading state renders SizedBox.shrink — verify no agent content
      expect(find.text('My Project Agent'), findsNothing);
      expect(find.byIcon(Icons.smart_toy_outlined), findsNothing);
    });

    testWidgets('shows nothing when error', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          overrides: [
            projectAgentProvider(projectId).overrideWith(
              (ref) => Future<AgentDomainEntity?>.error(
                Exception('test error'),
              ),
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('Agent'), findsNothing);
    });

    testWidgets('shows explicit empty state when no project agent exists', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          overrides: [
            projectAgentProvider(projectId).overrideWith(
              (ref) async => null,
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('Agent'), findsOneWidget);
      expect(
        find.text(
          'No project agent has been provisioned for this project yet.',
        ),
        findsOneWidget,
      );
      expect(find.text('Create Agent'), findsOneWidget);
    });

    testWidgets('shows agent display name when data is AgentIdentityEntity', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          overrides: [
            projectAgentProvider(projectId).overrideWith(
              (ref) async => testAgent,
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('Agent'), findsOneWidget);
      expect(find.text('My Project Agent'), findsOneWidget);
      expect(find.byIcon(Icons.smart_toy_outlined), findsWidgets);
    });

    testWidgets('renders the latest project report', (tester) async {
      final report = makeTestReport(
        agentId: 'agent-1',
        content:
            '## TLDR\nProject is on track.\n\n'
            '## Details\n- Milestone review is ready.\n',
      );

      await tester.pumpWidget(
        buildSubject(
          overrides: [
            projectAgentProvider(projectId).overrideWith(
              (ref) async => testAgent,
            ),
            agentReportProvider.overrideWith(
              (ref, agentId) async => agentId == 'agent-1' ? report : null,
            ),
            agentIsRunningProvider.overrideWith(
              (ref, agentId) => Stream.value(false),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Project is on track'), findsOneWidget);
      expect(find.textContaining('Milestone review is ready'), findsNothing);
    });

    testWidgets('refresh button triggers project reanalysis', (tester) async {
      final mockService = MockProjectAgentService();
      when(() => mockService.triggerReanalysis(any())).thenReturn(null);

      await tester.pumpWidget(
        buildSubject(
          overrides: [
            projectAgentProvider(projectId).overrideWith(
              (ref) async => testAgent,
            ),
            agentReportProvider.overrideWith((ref, agentId) async => null),
            agentIsRunningProvider.overrideWith(
              (ref, agentId) => Stream.value(false),
            ),
            projectAgentServiceProvider.overrideWithValue(mockService),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Refresh'));
      await tester.pump();

      verify(() => mockService.triggerReanalysis('agent-1')).called(1);
    });

    testWidgets('shows running indicator while the project agent is running', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          overrides: [
            projectAgentProvider(projectId).overrideWith(
              (ref) async => testAgent,
            ),
            agentReportProvider.overrideWith((ref, agentId) async => null),
            agentIsRunningProvider.overrideWith(
              (ref, agentId) => Stream.value(true),
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows report loading spinner while report is loading', (
      tester,
    ) async {
      final completer = Completer<AgentDomainEntity?>();

      await tester.pumpWidget(
        buildSubject(
          overrides: [
            projectAgentProvider(projectId).overrideWith(
              (ref) async => testAgent,
            ),
            agentReportProvider.overrideWith(
              (ref, agentId) => completer.future,
            ),
            agentIsRunningProvider.overrideWith(
              (ref, agentId) => Stream.value(false),
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows placeholder when no project report exists', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          overrides: [
            projectAgentProvider(projectId).overrideWith(
              (ref) async => testAgent,
            ),
            agentReportProvider.overrideWith((ref, agentId) async => null),
            agentIsRunningProvider.overrideWith(
              (ref, agentId) => Stream.value(false),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(ProjectAgentReportCard));
      expect(find.text(context.messages.agentReportNone), findsOneWidget);
    });

    testWidgets('create agent button provisions a missing project agent', (
      tester,
    ) async {
      final mockService = MockProjectAgentService();
      final mockTemplateService = MockAgentTemplateService();
      final template = makeTestTemplate(
        id: 'project-template-1',
        agentId: 'project-template-1',
        displayName: 'Project Template',
        kind: AgentTemplateKind.projectAgent,
      );

      when(
        () => mockTemplateService.listTemplatesForCategory(categoryId),
      ).thenAnswer((_) async => [template]);
      when(
        () => mockService.createProjectAgent(
          projectId: any(named: 'projectId'),
          templateId: any(named: 'templateId'),
          displayName: any(named: 'displayName'),
          allowedCategoryIds: any(named: 'allowedCategoryIds'),
          profileId: any(named: 'profileId'),
        ),
      ).thenAnswer((_) async => testAgent);

      await tester.pumpWidget(
        buildSubject(
          overrides: [
            projectAgentProvider(projectId).overrideWith((ref) async => null),
            projectAgentServiceProvider.overrideWithValue(mockService),
            agentTemplateServiceProvider.overrideWithValue(mockTemplateService),
            inferenceProfileControllerProvider.overrideWith(
              () => _FakeInferenceProfileController([testProfile]),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create Agent'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(testProfile.name));
      await tester.pumpAndSettle();

      verify(
        () => mockService.createProjectAgent(
          projectId: projectId,
          templateId: 'project-template-1',
          displayName: projectTitle,
          allowedCategoryIds: {categoryId},
          profileId: testProfile.id,
        ),
      ).called(1);
    });

    testWidgets('create agent button shows snackbar when no templates exist', (
      tester,
    ) async {
      final mockService = MockProjectAgentService();
      final mockTemplateService = MockAgentTemplateService();

      when(
        () => mockTemplateService.listTemplatesForCategory(categoryId),
      ).thenAnswer((_) async => []);
      when(mockTemplateService.listTemplates).thenAnswer((_) async => []);

      await tester.pumpWidget(
        buildSubject(
          overrides: [
            projectAgentProvider(projectId).overrideWith((ref) async => null),
            projectAgentServiceProvider.overrideWithValue(mockService),
            agentTemplateServiceProvider.overrideWithValue(mockTemplateService),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(ProjectAgentReportCard));
      await tester.tap(find.text('Create Agent'));
      await tester.pumpAndSettle();

      expect(
        find.text(context.messages.agentTemplateNoTemplates),
        findsOneWidget,
      );
    });

    testWidgets(
      'create agent falls back to global templates without category',
      (
        tester,
      ) async {
        final mockService = MockProjectAgentService();
        final mockTemplateService = MockAgentTemplateService();
        final template = makeTestTemplate(
          id: 'project-template-global',
          agentId: 'project-template-global',
          displayName: 'Global Project Template',
          kind: AgentTemplateKind.projectAgent,
        );

        when(
          mockTemplateService.listTemplates,
        ).thenAnswer((_) async => [template]);
        when(
          () => mockService.createProjectAgent(
            projectId: any(named: 'projectId'),
            templateId: any(named: 'templateId'),
            displayName: any(named: 'displayName'),
            allowedCategoryIds: any(named: 'allowedCategoryIds'),
            profileId: any(named: 'profileId'),
          ),
        ).thenAnswer((_) async => testAgent);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            const ProjectAgentReportCard(
              projectId: projectId,
              projectTitle: projectTitle,
            ),
            overrides: [
              projectAgentProvider(projectId).overrideWith((ref) async => null),
              projectAgentServiceProvider.overrideWithValue(mockService),
              agentTemplateServiceProvider.overrideWithValue(
                mockTemplateService,
              ),
              inferenceProfileControllerProvider.overrideWith(
                () => _FakeInferenceProfileController([testProfile]),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Create Agent'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(testProfile.name));
        await tester.pumpAndSettle();

        verifyNever(() => mockTemplateService.listTemplatesForCategory(any()));
        verify(
          () => mockService.createProjectAgent(
            projectId: projectId,
            templateId: 'project-template-global',
            displayName: projectTitle,
            allowedCategoryIds: const {},
            profileId: testProfile.id,
          ),
        ).called(1);
      },
    );

    testWidgets('create agent shows snackbar when provisioning fails', (
      tester,
    ) async {
      final mockService = MockProjectAgentService();
      final mockTemplateService = MockAgentTemplateService();
      final template = makeTestTemplate(
        id: 'project-template-1',
        agentId: 'project-template-1',
        displayName: 'Project Template',
        kind: AgentTemplateKind.projectAgent,
      );

      when(
        () => mockTemplateService.listTemplatesForCategory(categoryId),
      ).thenAnswer((_) async => [template]);
      when(
        () => mockService.createProjectAgent(
          projectId: any(named: 'projectId'),
          templateId: any(named: 'templateId'),
          displayName: any(named: 'displayName'),
          allowedCategoryIds: any(named: 'allowedCategoryIds'),
          profileId: any(named: 'profileId'),
        ),
      ).thenThrow(Exception('boom'));

      await tester.pumpWidget(
        buildSubject(
          overrides: [
            projectAgentProvider(projectId).overrideWith((ref) async => null),
            projectAgentServiceProvider.overrideWithValue(mockService),
            agentTemplateServiceProvider.overrideWithValue(mockTemplateService),
            inferenceProfileControllerProvider.overrideWith(
              () => _FakeInferenceProfileController([testProfile]),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create Agent'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(testProfile.name));
      await tester.pumpAndSettle();

      expect(find.textContaining('boom'), findsOneWidget);
    });

    testWidgets('shows active project recommendations', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          overrides: [
            projectAgentProvider(
              projectId,
            ).overrideWith((ref) async => testAgent),
            projectRecommendationsProvider(projectId).overrideWith(
              (ref) async => [
                makeTestProjectRecommendation(
                  id: 'rec-1',
                  agentId: 'agent-1',
                  projectId: projectId,
                  title: 'Unblock QA',
                  rationale: 'Staging data is missing',
                ),
                makeTestProjectRecommendation(
                  id: 'rec-2',
                  agentId: 'agent-1',
                  projectId: projectId,
                  title: 'Write launch checklist',
                  rationale: 'Avoid release drift',
                  priority: null,
                ),
              ],
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Recommended next steps'), findsOneWidget);
      expect(find.text('Unblock QA'), findsOneWidget);
      expect(find.text('Staging data is missing'), findsOneWidget);
      expect(find.text('HIGH'), findsOneWidget);
      expect(find.text('Write launch checklist'), findsOneWidget);
      expect(find.text('Avoid release drift'), findsOneWidget);
    });

    testWidgets('recommendation actions call the service', (tester) async {
      final mockService = MockProjectRecommendationService();
      when(() => mockService.markResolved(any())).thenAnswer((_) async => true);
      when(
        () => mockService.dismissRecommendation(any()),
      ).thenAnswer((_) async => true);

      await tester.pumpWidget(
        buildSubject(
          overrides: [
            projectAgentProvider(
              projectId,
            ).overrideWith((ref) async => testAgent),
            projectRecommendationsProvider(projectId).overrideWith(
              (ref) async => [
                makeTestProjectRecommendation(
                  id: 'rec-1',
                  agentId: 'agent-1',
                  projectId: projectId,
                  title: 'Unblock QA',
                ),
              ],
            ),
            projectRecommendationServiceProvider.overrideWithValue(mockService),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Mark resolved'));
      await tester.pump();
      await tester.tap(find.byTooltip('Dismiss'));
      await tester.pump();

      verify(() => mockService.markResolved('rec-1')).called(1);
      verify(() => mockService.dismissRecommendation('rec-1')).called(1);
    });

    testWidgets('recommendation action failures show an error snackbar', (
      tester,
    ) async {
      final mockService = MockProjectRecommendationService();
      when(
        () => mockService.markResolved(any()),
      ).thenAnswer((_) async => false);
      when(
        () => mockService.dismissRecommendation(any()),
      ).thenAnswer((_) async => false);

      await tester.pumpWidget(
        buildSubject(
          overrides: [
            projectAgentProvider(projectId).overrideWith(
              (ref) async => testAgent,
            ),
            projectRecommendationsProvider(projectId).overrideWith(
              (ref) async => [
                makeTestProjectRecommendation(
                  id: 'rec-1',
                  agentId: 'agent-1',
                  projectId: projectId,
                  title: 'Unblock QA',
                ),
              ],
            ),
            projectRecommendationServiceProvider.overrideWithValue(mockService),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(ProjectAgentReportCard));

      await tester.tap(find.byTooltip('Mark resolved'));
      await tester.pumpAndSettle();
      expect(
        find.text(context.messages.projectRecommendationUpdateError),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Dismiss'));
      await tester.pumpAndSettle();
      expect(
        find.text(context.messages.projectRecommendationUpdateError),
        findsOneWidget,
      );
    });
  });
}

class _FakeInferenceProfileController extends InferenceProfileController {
  _FakeInferenceProfileController(this._profiles);

  final List<AiConfig> _profiles;

  @override
  Stream<List<AiConfig>> build() => Stream.value(_profiles);
}
