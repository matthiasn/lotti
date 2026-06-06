import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_token_usage.dart';
import 'package:lotti/features/agents/model/task_resolution_time_series.dart';
import 'package:lotti/features/agents/model/wake_run_time_series.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/ritual_review_providers.dart';
import 'package:lotti/features/agents/state/soul_query_providers.dart';
import 'package:lotti/features/agents/state/wake_run_chart_providers.dart';
import 'package:lotti/features/agents/ui/agent_report_section.dart';
import 'package:lotti/features/agents/ui/agent_template_detail_page.dart';
import 'package:lotti/features/agents/ui/soul_selector.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/inference_profile_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/ui/form_bottom_bar.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../test_utils.dart';

late MockNavService _mockNavService;

final _testDate = DateTime(2024, 3, 15);

final _testProfile = AiConfig.inferenceProfile(
  id: 'profile-1',
  name: 'Test Profile',
  thinkingModelId: 'models/test-thinking',
  createdAt: _testDate,
);

/// Shared overrides for the inference profile provider used by ProfileSelector.
List<Override> _profileOverrides({
  List<AiConfig> profiles = const [],
}) => [
  inferenceProfileControllerProvider.overrideWithBuild(
    (ref, notifier) => Stream.value(profiles),
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
  evolutionSessionsProvider.overrideWith(
    (ref, id) async => <AgentDomainEntity>[],
  ),
  evolutionSessionStatsProvider.overrideWith(
    (ref, id) async => const EvolutionSessionStats(
      totalSessions: 0,
      approvalRate: 0,
    ),
  ),
  templateWakeRunTimeSeriesProvider.overrideWith(
    (ref, id) async => const WakeRunTimeSeries(
      dailyBuckets: [],
      versionBuckets: [],
    ),
  ),
  templateTaskResolutionTimeSeriesProvider.overrideWith(
    (ref, id) async => const TaskResolutionTimeSeries(dailyBuckets: []),
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
    // Default: no agent instances bound to the template. Tests that need
    // instances re-stub this (later when() stubs win in mocktail).
    when(
      () => mockTemplateService.getAgentsForTemplate(any()),
    ).thenAnswer((_) async => []);
    _mockNavService = MockNavService();
    when(() => _mockNavService.currentPath).thenReturn('/settings/agents');
    when(() => _mockNavService.beamBack()).thenReturn(null);
    getIt.registerSingleton<NavService>(_mockNavService);
  });

  tearDown(tearDownTestGetIt);

  Widget buildCreateSubject({
    List<AiConfig> profiles = const [],
    List<Override> extraOverrides = const [],
  }) {
    return makeTestableWidgetNoScroll(
      const AgentTemplateDetailPage(),
      overrides: [
        agentTemplateServiceProvider.overrideWithValue(mockTemplateService),
        agentTemplatesProvider.overrideWith(
          (ref) async => <AgentDomainEntity>[],
        ),
        ..._profileOverrides(profiles: profiles),
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
        template ??
        makeTestTemplate(
          id: templateId,
          agentId: templateId,
          profileId: 'profile-1',
        );
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
        ..._profileOverrides(),
        ...extraOverrides,
      ],
    );
  }

  group('AgentTemplateDetailPage - Create mode', () {
    testWidgets('shows create title and empty form', (tester) async {
      await tester.pumpWidget(buildCreateSubject());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

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

    testWidgets('save is disabled without profile selection', (tester) async {
      await tester.pumpWidget(buildCreateSubject());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Enter a name — but no profile selected
      final nameField = find.byType(TextField).first;
      await tester.enterText(nameField, 'My Template');
      await tester.pump();

      // Create button should be disabled since no profile is selected
      final context = tester.element(find.byType(AgentTemplateDetailPage));
      final createButton = find.text(context.messages.createButton);
      expect(createButton, findsOneWidget);

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
          profileId: any(named: 'profileId'),
          generalDirective: any(named: 'generalDirective'),
          reportDirective: any(named: 'reportDirective'),
        ),
      ).thenAnswer((_) async => makeTestTemplate());

      await tester.pumpWidget(
        buildCreateSubject(
          profiles: [_testProfile],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Enter a name
      final nameField = find.byType(TextField).first;
      await tester.enterText(nameField, 'My Template');
      await tester.pump();

      // Select a profile via the profile picker
      final profileDropdown = find.byIcon(Icons.arrow_drop_down);
      await tester.tap(profileDropdown.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(find.text('Test Profile'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Tap create button
      final context = tester.element(find.byType(AgentTemplateDetailPage));
      await tester.tap(find.text(context.messages.createButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      verify(
        () => mockTemplateService.createTemplate(
          displayName: 'My Template',
          kind: AgentTemplateKind.taskAgent,
          modelId: 'models/gemini-3-flash-preview',
          directives: any(named: 'directives'),
          authoredBy: 'user',
          profileId: 'profile-1',
          generalDirective: any(named: 'generalDirective'),
          reportDirective: any(named: 'reportDirective'),
        ),
      ).called(1);
    });

    testWidgets('cancel button navigates back without saving', (tester) async {
      await tester.pumpWidget(
        buildCreateSubject(profiles: [_testProfile]),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Cancel is always present in create mode.
      final context = tester.element(find.byType(AgentTemplateDetailPage));
      await tester.tap(find.text(context.messages.cancelButton));
      await tester.pump();

      // The create-mode Cancel routes through navigateBackFromAgent, which
      // calls beamBack on the (settings-path) NavService.
      verify(() => _mockNavService.beamBack()).called(1);
      verifyNever(
        () => mockTemplateService.createTemplate(
          displayName: any(named: 'displayName'),
          kind: any(named: 'kind'),
          modelId: any(named: 'modelId'),
          directives: any(named: 'directives'),
          authoredBy: any(named: 'authoredBy'),
          profileId: any(named: 'profileId'),
          generalDirective: any(named: 'generalDirective'),
          reportDirective: any(named: 'reportDirective'),
        ),
      );
    });
  });

  group('AgentTemplateDetailPage - Edit mode', () {
    const templateId = 'tpl-edit-001';

    testWidgets('populates form fields from template', (tester) async {
      await tester.pumpWidget(
        buildEditSubject(
          templateId: templateId,
          template: makeTestTemplate(
            id: templateId,
            agentId: templateId,
            displayName: 'Laura',
            profileId: 'profile-1',
          ),
          activeVersion: makeTestTemplateVersion(
            agentId: templateId,
            generalDirective: 'Be helpful and kind.',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Name field populated
      expect(find.text('Laura'), findsOneWidget);
      // Directives populated
      expect(find.text('Be helpful and kind.'), findsOneWidget);
    });

    testWidgets('shows edit title and populated form fields', (tester) async {
      await tester.pumpWidget(
        buildEditSubject(templateId: templateId),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      final context = tester.element(find.byType(AgentTemplateDetailPage));
      expect(
        find.text(context.messages.agentTemplateEditTitle),
        findsOneWidget,
      );

      // Name field populated with template display name
      expect(find.text('Test Template'), findsOneWidget);
      // General directive field falls back to legacy directives when empty.
      expect(find.text('You are a helpful agent.'), findsOneWidget);
      // Form is clean, so 1-on-1 button should be shown (not save button)
      expect(
        find.text(context.messages.agentRitualReviewTitle),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.agentTemplateSaveNewVersion),
        findsNothing,
      );
    });

    testWidgets('uses generalDirective over legacy directives when non-empty', (
      tester,
    ) async {
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Should use the new field, not the legacy one.
      expect(find.text('Modern general directive'), findsOneWidget);
      expect(find.text('Legacy text'), findsNothing);
    });

    testWidgets('save calls updateTemplate and createVersion', (tester) async {
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Make form dirty so Save button appears
      final nameField = find.byType(TextField).first;
      await tester.enterText(nameField, 'Test Template Modified');
      await tester.pump();

      final context = tester.element(find.byType(AgentTemplateDetailPage));
      await tester.tap(
        find.text(context.messages.agentTemplateSaveNewVersion),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      verify(
        () => mockTemplateService.updateTemplate(
          templateId: templateId,
          displayName: 'Test Template Modified',
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

    testWidgets(
      'editing directive fields marks form dirty and saves new text',
      (tester) async {
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
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        final context = tester.element(find.byType(AgentTemplateDetailPage));

        // Initially clean: only the review button is shown, no Save.
        expect(
          find.text(context.messages.agentTemplateSaveNewVersion),
          findsNothing,
        );

        // Type into the general directive text area (the second multiline
        // field after the name TextField). Entering text fires the field's
        // onChanged -> setState, which recomputes _isDirty.
        final generalField = find.widgetWithText(
          TextField,
          'You are a helpful agent.',
        );
        expect(generalField, findsOneWidget);
        await tester.enterText(generalField, 'New general directive');
        await tester.pump();

        // The onChanged callback flipped the form to dirty -> Save appears.
        expect(
          find.text(context.messages.agentTemplateSaveNewVersion),
          findsOneWidget,
        );

        // Type into the report directive field as well (covers its onChanged).
        // It starts empty, so locate it by its label text.
        final reportField = find.ancestor(
          of: find.text(context.messages.agentTemplateReportDirectiveLabel),
          matching: find.byType(TextField),
        );
        expect(reportField, findsOneWidget);
        await tester.enterText(reportField, 'New report directive');
        await tester.pump();

        // Save the new version and assert the edited directive text is what
        // gets persisted.
        await tester.tap(
          find.text(context.messages.agentTemplateSaveNewVersion),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        verify(
          () => mockTemplateService.createVersion(
            templateId: templateId,
            directives: any(named: 'directives'),
            authoredBy: 'user',
            generalDirective: 'New general directive',
            reportDirective: 'New report directive',
          ),
        ).called(1);
      },
    );

    testWidgets('clean form review button beams to review route', (
      tester,
    ) async {
      final beamedPaths = <String>[];
      beamToNamedOverride = beamedPaths.add;
      addTearDown(() => beamToNamedOverride = null);

      await tester.pumpWidget(
        buildEditSubject(templateId: templateId),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      final context = tester.element(find.byType(AgentTemplateDetailPage));

      // Clean form -> review button shown. Tapping it triggers beamToNamed.
      await tester.tap(find.text(context.messages.agentRitualReviewTitle));
      await tester.pump();

      expect(
        beamedPaths,
        equals(['/settings/agents/templates/$templateId/review']),
      );
    });

    testWidgets('version history shows versions', (tester) async {
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      final context = tester.element(find.byType(AgentTemplateDetailPage));

      // Switch to Stats tab where version history now lives
      await tester.tap(find.text(context.messages.agentTemplateStatsTab));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Scroll to make version history visible
      await tester.scrollUntilVisible(
        find.text(context.messages.agentTemplateVersionHistoryTitle),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      final context = tester.element(find.byType(AgentTemplateDetailPage));

      // Switch to Stats tab where version history now lives
      await tester.tap(find.text(context.messages.agentTemplateStatsTab));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Scroll down to make the restore icon visible, then tap it
      await tester.scrollUntilVisible(
        find.byIcon(Icons.restore),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(find.byIcon(Icons.restore));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Confirm in dialog
      await tester.tap(
        find.text(context.messages.agentTemplateRollbackAction).last,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      verify(
        () => mockTemplateService.rollbackToVersion(
          templateId: templateId,
          versionId: 'v1',
        ),
      ).called(1);
    });

    testWidgets('rollback dialog cancel dismisses without rolling back', (
      tester,
    ) async {
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      final context = tester.element(find.byType(AgentTemplateDetailPage));

      await tester.tap(find.text(context.messages.agentTemplateStatsTab));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      await tester.scrollUntilVisible(
        find.byIcon(Icons.restore),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(find.byIcon(Icons.restore));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // The rollback confirmation dialog is open.
      expect(find.byType(AlertDialog), findsOneWidget);

      // Tap Cancel in the dialog (the dialog's cancelButton, not anywhere else).
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(context.messages.cancelButton),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Dialog dismissed and no rollback was performed.
      expect(find.byType(AlertDialog), findsNothing);
      verifyNever(
        () => mockTemplateService.rollbackToVersion(
          templateId: any(named: 'templateId'),
          versionId: any(named: 'versionId'),
        ),
      );
    });

    testWidgets('delete calls deleteTemplate', (tester) async {
      when(
        () => mockTemplateService.deleteTemplate(any()),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(
        buildEditSubject(templateId: templateId),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      final context = tester.element(find.byType(AgentTemplateDetailPage));

      // Navigate to Stats tab where delete button lives
      await tester.tap(find.text(context.messages.agentTemplateStatsTab));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Scroll to find delete button
      await tester.scrollUntilVisible(
        find.byIcon(Icons.delete_outline),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Tap delete button
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Confirm in dialog
      await tester.tap(find.text(context.messages.deleteButton).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      verify(
        () => mockTemplateService.deleteTemplate(templateId),
      ).called(1);
    });

    testWidgets('delete dialog cancel dismisses without deleting', (
      tester,
    ) async {
      when(
        () => mockTemplateService.deleteTemplate(any()),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(
        buildEditSubject(templateId: templateId),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      final context = tester.element(find.byType(AgentTemplateDetailPage));

      await tester.tap(find.text(context.messages.agentTemplateStatsTab));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      await tester.scrollUntilVisible(
        find.byIcon(Icons.delete_outline),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Confirmation dialog is open.
      expect(find.byType(AlertDialog), findsOneWidget);

      // Tap Cancel inside the dialog.
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(context.messages.cancelButton),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Dialog dismissed, nothing deleted.
      expect(find.byType(AlertDialog), findsNothing);
      verifyNever(() => mockTemplateService.deleteTemplate(any()));
    });

    testWidgets('shows error when deleting template with instances', (
      tester,
    ) async {
      when(() => mockTemplateService.deleteTemplate(any())).thenThrow(
        const TemplateInUseException(
          templateId: 'test',
          activeCount: 1,
        ),
      );

      await tester.pumpWidget(
        buildEditSubject(templateId: templateId),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      final context = tester.element(find.byType(AgentTemplateDetailPage));

      // Navigate to Stats tab where delete button lives
      await tester.tap(find.text(context.messages.agentTemplateStatsTab));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Scroll to find delete button
      await tester.scrollUntilVisible(
        find.byIcon(Icons.delete_outline),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Tap delete button
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Confirm in dialog
      await tester.tap(find.text(context.messages.deleteButton).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(
        find.text(context.messages.agentTemplateDeleteHasInstances),
        findsOneWidget,
      );
    });

    testWidgets('shows loading indicator when template is loading', (
      tester,
    ) async {
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
            ..._profileOverrides(),
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
            ..._profileOverrides(),
          ],
        ),
      );
      // Genuine settle: the sync-throwing provider override only surfaces
      // its error state through settle-style pumping.
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

    testWidgets('shows template not found when template is null', (
      tester,
    ) async {
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
            ..._profileOverrides(),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      final context = tester.element(find.byType(AgentTemplateDetailPage));
      expect(
        find.text(context.messages.agentTemplateNotFound),
        findsOneWidget,
      );
    });

    testWidgets('shows commonError snackbar when save fails', (tester) async {
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Make form dirty so Save button appears
      final nameField = find.byType(TextField).first;
      await tester.enterText(nameField, 'Test Template Changed');
      await tester.pump();

      final context = tester.element(find.byType(AgentTemplateDetailPage));
      await tester.tap(
        find.text(context.messages.agentTemplateSaveNewVersion),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text(context.messages.commonError), findsOneWidget);
    });

    testWidgets('shows commonError snackbar on generic delete error', (
      tester,
    ) async {
      when(
        () => mockTemplateService.deleteTemplate(any()),
      ).thenThrow(Exception('unexpected delete error'));

      await tester.pumpWidget(
        buildEditSubject(templateId: templateId),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      final context = tester.element(find.byType(AgentTemplateDetailPage));

      // Navigate to Stats tab where delete button lives
      await tester.tap(find.text(context.messages.agentTemplateStatsTab));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Scroll to find delete button
      await tester.scrollUntilVisible(
        find.byIcon(Icons.delete_outline),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Tap delete button
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Confirm in dialog
      await tester.tap(find.text(context.messages.deleteButton).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text(context.messages.commonError), findsOneWidget);
    });

    testWidgets('shows commonError snackbar on rollback error', (tester) async {
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      final context = tester.element(find.byType(AgentTemplateDetailPage));

      // Switch to Stats tab where version history now lives
      await tester.tap(find.text(context.messages.agentTemplateStatsTab));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Scroll to restore icon and tap
      await tester.scrollUntilVisible(
        find.byIcon(Icons.restore),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(find.byIcon(Icons.restore));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Confirm in dialog
      await tester.tap(
        find.text(context.messages.agentTemplateRollbackAction).last,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text(context.messages.commonError), findsOneWidget);
    });

    testWidgets('shows no versions text when version list is empty', (
      tester,
    ) async {
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
            ..._profileOverrides(),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      final context = tester.element(find.byType(AgentTemplateDetailPage));

      // Switch to Stats tab where version history now lives
      await tester.tap(find.text(context.messages.agentTemplateStatsTab));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Scroll to version history section
      await tester.scrollUntilVisible(
        find.text(context.messages.agentTemplateVersionHistoryTitle),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(
        find.text(context.messages.agentTemplateNoVersions),
        findsOneWidget,
      );
    });

    testWidgets('shows loading indicator in version history section', (
      tester,
    ) async {
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
            ..._profileOverrides(),
          ],
        ),
      );
      // Use pump with duration instead of pumpAndSettle because the
      // Completer never completes, so animations never settle.
      await tester.pump(const Duration(seconds: 1));

      final context = tester.element(find.byType(AgentTemplateDetailPage));

      // Switch to Stats tab where version history now lives
      await tester.tap(find.text(context.messages.agentTemplateStatsTab));
      // Pump multiple frames to complete tab switch animation
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Scroll to version history section using the last vertical Scrollable
      // (the Stats tab's ListView, not the NestedScrollView or TabBarView)
      await tester.scrollUntilVisible(
        find.text(context.messages.agentTemplateVersionHistoryTitle),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pump();

      // The version history section should show a loading indicator
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('shows error text in version history section', (tester) async {
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
            ..._profileOverrides(),
          ],
        ),
      );
      // Genuine settle: the erroring version-history provider needs
      // settle-style pumping to surface its error state (see the back-
      // chevron error test above).
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentTemplateDetailPage));

      // Switch to Stats tab where version history now lives
      await tester.tap(find.text(context.messages.agentTemplateStatsTab));
      await tester.pumpAndSettle();

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

    testWidgets('reseeds directives when active version changes', (
      tester,
    ) async {
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
          (ref, id) async => makeTestTemplate(
            id: templateId,
            agentId: templateId,
            profileId: 'profile-1',
          ),
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
        ..._profileOverrides(),
      ];

      final (:widget, :container) = makeTestableWidgetWithContainer(
        const AgentTemplateDetailPage(templateId: templateId),
        overrides: overrides,
        mediaQueryData: const MediaQueryData(size: Size(400, 800)),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(widget);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Verify v1 directives are shown.
      expect(find.text('Version 1 directives'), findsOneWidget);

      // Simulate evolution approval: switch to v2 and invalidate.
      currentVersion = v2;
      container.invalidate(activeTemplateVersionProvider(templateId));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Directive field should now show v2 directives.
      expect(find.text('Version 2 directives'), findsOneWidget);
      expect(find.text('Version 1 directives'), findsNothing);
    });

    testWidgets(
      'reseeds prefers generalDirective over legacy directives on change',
      (tester) async {
        final v1 = makeTestTemplateVersion(
          id: 'v1',
          agentId: templateId,
          generalDirective: 'V1 general directive',
        );
        // v2 carries BOTH a legacy directives blob and a modern
        // generalDirective; the re-seed must take the generalDirective.
        final v2 = makeTestTemplateVersion(
          id: 'v2',
          agentId: templateId,
          version: 2,
          directives: 'V2 legacy directives',
          generalDirective: 'V2 general directive',
        );

        var currentVersion = v1;

        final overrides = [
          agentTemplateServiceProvider.overrideWithValue(mockTemplateService),
          agentTemplateProvider.overrideWith(
            (ref, id) async => makeTestTemplate(
              id: templateId,
              agentId: templateId,
              profileId: 'profile-1',
            ),
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
          ..._templateStatsOverrides(),
          ..._profileOverrides(),
        ];

        final (:widget, :container) = makeTestableWidgetWithContainer(
          const AgentTemplateDetailPage(templateId: templateId),
          overrides: overrides,
          mediaQueryData: const MediaQueryData(size: Size(400, 800)),
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(widget);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.text('V1 general directive'), findsOneWidget);

        // Switch active version to v2 and invalidate to trigger the re-seed.
        currentVersion = v2;
        container.invalidate(activeTemplateVersionProvider(templateId));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // generalDirective wins over the legacy directives field.
        expect(find.text('V2 general directive'), findsOneWidget);
        expect(find.text('V2 legacy directives'), findsNothing);
      },
    );

    testWidgets('shows 1-on-1 review button when form is clean', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildEditSubject(templateId: templateId),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      final context = tester.element(find.byType(AgentTemplateDetailPage));

      // 1-on-1 button is in the bottom bar when form is clean
      final bottomBar = find.byType(FormBottomBar);
      expect(bottomBar, findsOneWidget);
      expect(
        find.descendant(
          of: bottomBar,
          matching: find.text(context.messages.agentRitualReviewTitle),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: bottomBar,
          matching: find.byIcon(Icons.rate_review),
        ),
        findsOneWidget,
      );
      // Save/Cancel should not be visible
      expect(
        find.text(context.messages.agentTemplateSaveNewVersion),
        findsNothing,
      );
      expect(find.text(context.messages.cancelButton), findsNothing);
    });

    testWidgets('shows Cancel and Save when form is dirty', (tester) async {
      await tester.pumpWidget(
        buildEditSubject(templateId: templateId),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      final context = tester.element(find.byType(AgentTemplateDetailPage));

      // Initially clean — shows 1-on-1 button
      expect(
        find.text(context.messages.agentRitualReviewTitle),
        findsOneWidget,
      );

      // Make form dirty by editing the name
      final nameField = find.byType(TextField).first;
      await tester.enterText(nameField, 'Modified Name');
      await tester.pump();

      // Now Cancel + Save should appear
      expect(
        find.text(context.messages.cancelButton),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.agentTemplateSaveNewVersion),
        findsOneWidget,
      );
      // 1-on-1 button should be gone
      expect(
        find.text(context.messages.agentRitualReviewTitle),
        findsNothing,
      );
    });

    testWidgets('delete button visible on Stats tab', (tester) async {
      await tester.pumpWidget(
        buildEditSubject(templateId: templateId),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      final context = tester.element(find.byType(AgentTemplateDetailPage));

      // Delete button should NOT be in the bottom bar
      final bottomBar = find.byType(FormBottomBar);
      expect(
        find.descendant(
          of: bottomBar,
          matching: find.byIcon(Icons.delete_outline),
        ),
        findsNothing,
      );

      // Navigate to Stats tab
      await tester.tap(find.text(context.messages.agentTemplateStatsTab));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Scroll to delete button
      await tester.scrollUntilVisible(
        find.byIcon(Icons.delete_outline),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      expect(find.text(context.messages.deleteButton), findsOneWidget);
    });

    testWidgets('shows three tabs in edit mode', (tester) async {
      await tester.pumpWidget(
        buildEditSubject(templateId: templateId),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

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
      await tester.pumpWidget(
        buildEditSubject(templateId: templateId),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      final context = tester.element(find.byType(AgentTemplateDetailPage));

      // Bottom bar visible on Settings tab (shows 1-on-1 when clean)
      expect(find.byType(FormBottomBar), findsOneWidget);
      expect(
        find.text(context.messages.agentRitualReviewTitle),
        findsOneWidget,
      );

      // Switch to Stats tab — bottom bar should disappear
      await tester.tap(find.text(context.messages.agentTemplateStatsTab));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(FormBottomBar), findsNothing);

      // Switch to Reports tab — bottom bar should still be hidden
      await tester.tap(find.text(context.messages.agentTemplateReportsTab));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(FormBottomBar), findsNothing);

      // Switch back to Settings tab — bottom bar should reappear
      await tester.tap(find.text(context.messages.agentTemplateSettingsTab));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(FormBottomBar), findsOneWidget);
    });

    testWidgets('Stats tab shows token usage section', (tester) async {
      await tester.pumpWidget(
        buildEditSubject(templateId: templateId),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      final context = tester.element(find.byType(AgentTemplateDetailPage));

      // Navigate to Stats tab
      await tester.tap(find.text(context.messages.agentTemplateStatsTab));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Should show the aggregate heading from TemplateTokenUsageSection
      expect(
        find.text(context.messages.agentTemplateAggregateTokenUsageHeading),
        findsOneWidget,
      );
    });

    testWidgets('Reports tab shows empty state when no reports', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildEditSubject(templateId: templateId),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      final context = tester.element(find.byType(AgentTemplateDetailPage));

      // Navigate to Reports tab. The tab content builds lazily, so after
      // the transition one more frame lets its async provider deliver data.
      await tester.tap(find.text(context.messages.agentTemplateReportsTab));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      expect(
        find.text(context.messages.agentTemplateReportsEmpty),
        findsOneWidget,
      );
    });

    testWidgets('Reports tab shows report cards with content', (tester) async {
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
            ..._profileOverrides(),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      final context = tester.element(find.byType(AgentTemplateDetailPage));

      // Navigate to Reports tab. The tab content builds lazily, so after
      // the transition one more frame lets its async provider deliver data.
      await tester.tap(find.text(context.messages.agentTemplateReportsTab));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      // Report content visible (rendered via GptMarkdown inside
      // AgentReportSection)
      expect(find.textContaining('Weekly summary'), findsOneWidget);
      expect(find.textContaining('Task progress'), findsOneWidget);

      // Each report renders inside a ModernBaseCard
      expect(find.byType(AgentReportSection), findsNWidgets(2));
    });

    testWidgets('Reports tab renders report with tldr field', (tester) async {
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
            ..._profileOverrides(),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      final context = tester.element(find.byType(AgentTemplateDetailPage));

      // Navigate to Reports tab. The tab content builds lazily, so after
      // the transition one more frame lets its async provider deliver data.
      await tester.tap(find.text(context.messages.agentTemplateReportsTab));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      // TLDR text should be visible (always shown)
      expect(find.textContaining('Brief summary'), findsOneWidget);
      expect(find.byType(AgentReportSection), findsOneWidget);
    });

    testWidgets('Reports tab skips non-AgentReportEntity items', (
      tester,
    ) async {
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
            ..._profileOverrides(),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      final context = tester.element(find.byType(AgentTemplateDetailPage));

      // Navigate to Reports tab. The tab content builds lazily, so after
      // the transition one more frame lets its async provider deliver data.
      await tester.tap(find.text(context.messages.agentTemplateReportsTab));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      // Valid report is shown (rendered via GptMarkdown inside
      // AgentReportSection)
      expect(find.textContaining('Valid report'), findsOneWidget);
      // Only one AgentReportSection for the valid report (non-report item
      // renders as SizedBox.shrink)
      expect(find.byType(AgentReportSection), findsOneWidget);
    });

    testWidgets('Reports tab shows loading indicator', (tester) async {
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
            ..._profileOverrides(),
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
            ..._profileOverrides(),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      final context = tester.element(find.byType(AgentTemplateDetailPage));

      // Navigate to Reports tab. The tab content builds lazily, so after
      // the transition one more frame lets its async provider deliver data.
      await tester.tap(find.text(context.messages.agentTemplateReportsTab));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      expect(
        find.text(context.messages.commonError),
        findsOneWidget,
      );
    });
  });

  group('AgentTemplateDetailPage - back navigation', () {
    const templateId = 'tpl-nav-001';

    testWidgets('back chevron calls beamBack when in settings path', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildEditSubject(templateId: templateId),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();

      verify(() => _mockNavService.beamBack()).called(1);
    });

    testWidgets('back chevron calls Navigator.pop when not in settings path', (
      tester,
    ) async {
      when(() => _mockNavService.currentPath).thenReturn('/tasks');
      await tester.pumpWidget(
        buildEditSubject(templateId: templateId),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();

      verifyNever(() => _mockNavService.beamBack());
    });

    testWidgets('back chevron works on create mode', (tester) async {
      await tester.pumpWidget(buildCreateSubject());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

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
            ..._profileOverrides(),
          ],
        ),
      );
      // Genuine settle: the sync-throwing provider override only surfaces
      // its error state through settle-style pumping (riverpod schedules
      // retry work between frames); bounded fixed pumps never reach it.
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
            ..._profileOverrides(),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();

      verify(() => _mockNavService.beamBack()).called(1);
    });

    testWidgets('cancel button navigates back when form is dirty', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildEditSubject(templateId: templateId),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Make form dirty so Cancel button appears
      final nameField = find.byType(TextField).first;
      await tester.enterText(nameField, 'Dirty Name');
      await tester.pump();

      final context = tester.element(find.byType(AgentTemplateDetailPage));
      await tester.tap(find.text(context.messages.cancelButton));
      await tester.pump();

      verify(() => _mockNavService.beamBack()).called(1);
    });
  });

  group('AgentTemplateDetailPage - soul assignment', () {
    late MockSoulDocumentService mockSoulService;
    const templateId = 'tpl-soul-001';

    final testSoul = makeTestSoulDocument(
      id: 'soul-1',
      displayName: 'Laura',
    );
    final testSoul2 = makeTestSoulDocument(
      id: 'soul-2',
      displayName: 'Tom',
    );
    final testSoulVersion = makeTestSoulDocumentVersion(
      id: 'soul-v1',
      agentId: 'soul-1',
    );

    setUp(() {
      mockSoulService = MockSoulDocumentService();
    });

    /// Common soul-related provider overrides.
    List<Override> soulOverrides({
      List<AgentDomainEntity> souls = const [],
      AgentDomainEntity? soulForTemplate,
    }) => [
      soulDocumentServiceProvider.overrideWithValue(mockSoulService),
      allSoulDocumentsProvider.overrideWith(
        (ref) async => souls,
      ),
      soulForTemplateProvider.overrideWith(
        (ref, id) async => soulForTemplate,
      ),
    ];

    testWidgets(
      'create mode persists soul selection via assignSoulToTemplate',
      (tester) async {
        final createdTemplate = makeTestTemplate(
          id: 'created-tpl-id',
          agentId: 'created-tpl-id',
        );

        when(
          () => mockTemplateService.createTemplate(
            displayName: any(named: 'displayName'),
            kind: any(named: 'kind'),
            modelId: any(named: 'modelId'),
            directives: any(named: 'directives'),
            authoredBy: any(named: 'authoredBy'),
            profileId: any(named: 'profileId'),
            generalDirective: any(named: 'generalDirective'),
            reportDirective: any(named: 'reportDirective'),
          ),
        ).thenAnswer((_) async => createdTemplate);

        when(
          () => mockSoulService.assignSoulToTemplate(any(), any()),
        ).thenAnswer((_) async {});

        await tester.pumpWidget(
          buildCreateSubject(
            profiles: [_testProfile],
            extraOverrides: soulOverrides(
              souls: [testSoul, testSoul2],
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Enter a name
        final nameField = find.byType(TextField).first;
        await tester.enterText(nameField, 'My Template');
        await tester.pump();

        // Select a profile via the profile picker
        final profileDropdown = find.byIcon(Icons.arrow_drop_down);
        await tester.tap(profileDropdown.first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        await tester.tap(find.text('Test Profile'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Select a soul via the SoulSelector picker
        final soulSelector = find.byType(SoulSelector);
        expect(soulSelector, findsOneWidget);
        await tester.tap(soulSelector);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        // Pick "Laura" in the modal
        await tester.tap(find.text('Laura').last);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Tap create button
        final context = tester.element(find.byType(AgentTemplateDetailPage));
        await tester.tap(find.text(context.messages.createButton));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        verify(
          () => mockSoulService.assignSoulToTemplate(
            'created-tpl-id',
            'soul-1',
          ),
        ).called(1);
      },
    );

    testWidgets(
      'edit mode calls assignSoulToTemplate when soul changes',
      (tester) async {
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
        when(
          () => mockSoulService.assignSoulToTemplate(any(), any()),
        ).thenAnswer((_) async {});

        await tester.pumpWidget(
          buildEditSubject(
            templateId: templateId,
            template: makeTestTemplate(
              id: templateId,
              agentId: templateId,
              profileId: 'profile-1',
            ),
            extraOverrides: soulOverrides(
              souls: [testSoul, testSoul2],
              // Template originally has soul-1 assigned
              soulForTemplate: testSoulVersion,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // The soul selector should show "Laura" (seeded from provider)
        expect(find.text('Laura'), findsWidgets);

        // Change soul to "Tom" by tapping the selector and picking Tom
        final soulSelector = find.byType(SoulSelector);
        await tester.tap(soulSelector);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        await tester.tap(find.text('Tom').last);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Form is now dirty (soul changed), save button appears
        final context = tester.element(find.byType(AgentTemplateDetailPage));
        await tester.tap(
          find.text(context.messages.agentTemplateSaveNewVersion),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        verify(
          () => mockSoulService.assignSoulToTemplate(
            templateId,
            'soul-2',
          ),
        ).called(1);
      },
    );

    testWidgets(
      'edit mode calls unassignSoul when soul is cleared',
      (tester) async {
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
        when(
          () => mockSoulService.unassignSoul(any()),
        ).thenAnswer((_) async {});

        await tester.pumpWidget(
          buildEditSubject(
            templateId: templateId,
            template: makeTestTemplate(
              id: templateId,
              agentId: templateId,
              profileId: 'profile-1',
            ),
            extraOverrides: soulOverrides(
              souls: [testSoul],
              // Template originally has soul-1 assigned
              soulForTemplate: testSoulVersion,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Verify soul is seeded: "Laura" visible
        expect(find.text('Laura'), findsWidgets);

        // Clear the soul by tapping the clear icon inside the SoulSelector
        final soulSelector = find.byType(SoulSelector);
        final clearIcon = find.descendant(
          of: soulSelector,
          matching: find.byIcon(Icons.clear),
        );
        expect(clearIcon, findsOneWidget);
        await tester.tap(clearIcon);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Form is now dirty (soul cleared), save button appears
        final context = tester.element(find.byType(AgentTemplateDetailPage));
        await tester.tap(
          find.text(context.messages.agentTemplateSaveNewVersion),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        verify(
          () => mockSoulService.unassignSoul(templateId),
        ).called(1);
      },
    );

    testWidgets(
      'edit mode seeds soul selection from soulForTemplateProvider',
      (tester) async {
        await tester.pumpWidget(
          buildEditSubject(
            templateId: templateId,
            template: makeTestTemplate(
              id: templateId,
              agentId: templateId,
              profileId: 'profile-1',
            ),
            extraOverrides: soulOverrides(
              souls: [testSoul, testSoul2],
              soulForTemplate: testSoulVersion,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // The SoulSelector should display "Laura" (from seeded soul-1)
        final soulSelector = find.byType(SoulSelector);
        expect(soulSelector, findsOneWidget);
        expect(
          find.descendant(of: soulSelector, matching: find.text('Laura')),
          findsOneWidget,
        );
      },
    );
  });
}
