import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/state/change_set_providers.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';
import 'package:lotti/features/agents/ui/change_set_summary_card.dart';
import 'package:lotti/features/projects/state/project_detail_controller.dart';
import 'package:lotti/features/projects/ui/pages/project_detail_page.dart';
import 'package:lotti/features/projects/ui/widgets/project_agent_report_card.dart';
import 'package:lotti/features/projects/ui/widgets/project_status_picker.dart';
import 'package:lotti/features/projects/ui/widgets/project_target_date_field.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/ui/error_state_widget.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

/// Test controller that allows direct state manipulation without a repository.
class _TestProjectDetailController extends ProjectDetailController {
  _TestProjectDetailController(this._initialState) : super(_projectId);

  final ProjectDetailState _initialState;
  late ProjectDetailState _state;

  String? lastUpdatedTitle;
  DateTime? lastUpdatedTargetDate;
  bool updateTargetDateCalledWithNull = false;
  int saveChangesCalls = 0;

  @override
  ProjectDetailState build() => _state = _initialState;

  @override
  void updateTitle(String title) {
    lastUpdatedTitle = title;
    if (_state.project == null) return;
    _state = _state.copyWith(
      project: _state.project!.copyWith(
        data: _state.project!.data.copyWith(title: title),
      ),
      hasChanges: true,
    );
    state = _state;
  }

  @override
  void updateTargetDate(DateTime? targetDate) {
    lastUpdatedTargetDate = targetDate;
    if (targetDate == null) updateTargetDateCalledWithNull = true;
    if (_state.project == null) return;
    _state = _state.copyWith(
      project: _state.project!.copyWith(
        data: _state.project!.data.copyWith(targetDate: targetDate),
      ),
      hasChanges: true,
    );
    state = _state;
  }

  @override
  void updateStatus(ProjectStatus newStatus) {}

  @override
  Future<void> saveChanges() async {
    saveChangesCalls++;
  }
}

const _projectId = 'test-project-id';

void main() {
  final now = DateTime(2024, 3, 15);
  final targetDate = DateTime(2024, 6, 30);

  final testProject = makeTestProject(
    id: _projectId,
    title: 'My Test Project',
    createdAt: now,
    targetDate: targetDate,
  );

  setUpAll(registerAllFallbackValues);

  setUp(() async {
    await setUpTestGetIt();
  });

  tearDown(tearDownTestGetIt);

  /// Pumps the [ProjectDetailPage] with the given [controllerState] and
  /// optional [agentOverride].
  Future<_TestProjectDetailController> pumpPage(
    WidgetTester tester, {
    required ProjectDetailState controllerState,
    AgentDomainEntity? projectAgent,
    String? categoryId,
    List<Override> extraOverrides = const [],
  }) async {
    // Use a tall surface so that all sliver children are laid out.
    tester.view
      ..physicalSize = const Size(390, 2400)
      ..devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final controller = _TestProjectDetailController(controllerState);

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        ProjectDetailPage(
          projectId: 'test-project-id',
          categoryId: categoryId,
        ),
        overrides: [
          projectDetailControllerProvider('test-project-id').overrideWith(
            () => controller,
          ),
          projectAgentProvider('test-project-id').overrideWith(
            (ref) async => projectAgent,
          ),
          ...extraOverrides,
        ],
      ),
    );
    await tester.pump();
    await tester.pump();

    return controller;
  }

  group('ProjectDetailPage', () {
    group('loading state', () {
      testWidgets('shows CircularProgressIndicator when loading with null '
          'project', (tester) async {
        await pumpPage(
          tester,
          controllerState: const ProjectDetailState(
            project: null,
            linkedTasks: [],
            isLoading: true,
            isSaving: false,
            hasChanges: false,
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });

    group('not-found state', () {
      testWidgets('shows "project not found" when project is null and not '
          'loading', (tester) async {
        await pumpPage(
          tester,
          controllerState: const ProjectDetailState(
            project: null,
            linkedTasks: [],
            isLoading: false,
            isSaving: false,
            hasChanges: false,
          ),
        );

        expect(find.text('Project not found'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });
    });

    group('loaded state', () {
      testWidgets('shows project title in text field', (tester) async {
        await pumpPage(
          tester,
          controllerState: ProjectDetailState(
            project: testProject,
            linkedTasks: const [],
            isLoading: false,
            isSaving: false,
            hasChanges: false,
          ),
        );

        // The title controller should be synced with the project title
        final textField = tester.widget<TextFormField>(
          find.byType(TextFormField),
        );
        expect(textField.controller?.text, 'My Test Project');
      });

      testWidgets('shows ProjectStatusPicker with current status label', (
        tester,
      ) async {
        await pumpPage(
          tester,
          controllerState: ProjectDetailState(
            project: testProject,
            linkedTasks: const [],
            isLoading: false,
            isSaving: false,
            hasChanges: false,
          ),
        );

        expect(find.byType(ProjectStatusPicker), findsOneWidget);
        // Verify the picker reflects the project's current Open status.
        expect(find.text('Open'), findsOneWidget);
      });

      testWidgets('tapping status picker opens bottom sheet', (
        tester,
      ) async {
        await pumpPage(
          tester,
          controllerState: ProjectDetailState(
            project: testProject,
            linkedTasks: const [],
            isLoading: false,
            isSaving: false,
            hasChanges: false,
          ),
        );

        // The picker shows the current status text ("Open")
        final picker = find.byType(ProjectStatusPicker);
        await tester.tap(picker);
        await tester.pumpAndSettle();

        // Bottom sheet should appear with status options
        // "Change Status" appears twice: section title + sheet title
        expect(find.text('Active'), findsOneWidget);
        expect(find.text('Completed'), findsOneWidget);
        expect(find.text('Archived'), findsOneWidget);
      });

      testWidgets('selecting a status in the sheet dismisses it', (
        tester,
      ) async {
        await pumpPage(
          tester,
          controllerState: ProjectDetailState(
            project: testProject,
            linkedTasks: const [],
            isLoading: false,
            isSaving: false,
            hasChanges: false,
          ),
        );

        final picker = find.byType(ProjectStatusPicker);
        await tester.tap(picker);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Active'));
        await tester.pumpAndSettle();

        // Sheet should be dismissed — only section title remains
        expect(find.text('Active'), findsNothing);
      });

      testWidgets('shows ProjectTargetDateField with target date', (
        tester,
      ) async {
        await pumpPage(
          tester,
          controllerState: ProjectDetailState(
            project: testProject,
            linkedTasks: const [],
            isLoading: false,
            isSaving: false,
            hasChanges: false,
          ),
        );

        expect(find.byType(ProjectTargetDateField), findsOneWidget);
        // Verify the field shows the project's target date in ymd format.
        expect(find.text('2024-06-30'), findsOneWidget);
      });

      testWidgets('shows ProjectAgentReportCard', (tester) async {
        await pumpPage(
          tester,
          controllerState: ProjectDetailState(
            project: testProject,
            linkedTasks: const [],
            isLoading: false,
            isSaving: false,
            hasChanges: false,
          ),
        );

        expect(find.byType(ProjectAgentReportCard), findsOneWidget);
      });

      testWidgets(
        'shows active project recommendations',
        (tester) async {
          final agent =
              AgentDomainEntity.agent(
                    id: 'agent-001',
                    agentId: 'agent-001',
                    kind: 'project_agent',
                    displayName: 'Project Agent',
                    lifecycle: AgentLifecycle.active,
                    mode: AgentInteractionMode.autonomous,
                    allowedCategoryIds: const {},
                    currentStateId: 'state-001',
                    config: const AgentConfig(),
                    createdAt: DateTime(2024, 3, 15),
                    updatedAt: DateTime(2024, 3, 15),
                    vectorClock: null,
                  )
                  as AgentIdentityEntity;
          await pumpPage(
            tester,
            controllerState: ProjectDetailState(
              project: testProject,
              linkedTasks: const [],
              isLoading: false,
              isSaving: false,
              hasChanges: false,
            ),
            projectAgent: agent,
            extraOverrides: [
              projectRecommendationsProvider(_projectId).overrideWith(
                (ref) async => [
                  AgentDomainEntity.projectRecommendation(
                        id: 'rec-001',
                        agentId: 'agent-001',
                        projectId: _projectId,
                        title: 'Prepare beta rollout',
                        position: 0,
                        status: ProjectRecommendationStatus.active,
                        createdAt: DateTime(2024, 3, 16),
                        updatedAt: DateTime(2024, 3, 16),
                        vectorClock: const VectorClock({}),
                        rationale: 'The release branch is nearly ready',
                        priority: 'HIGH',
                      )
                      as ProjectRecommendationEntity,
                ],
              ),
            ],
          );

          expect(find.text('Recommended next steps'), findsOneWidget);
          expect(find.text('Prepare beta rollout'), findsOneWidget);
          expect(
            find.text('The release branch is nearly ready'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'shows project change proposals when pending change sets exist',
        (
          tester,
        ) async {
          final changeSet =
              AgentDomainEntity.changeSet(
                    id: 'cs-001',
                    agentId: 'agent-001',
                    taskId: _projectId,
                    threadId: 'thread-001',
                    runKey: 'run-001',
                    status: ChangeSetStatus.pending,
                    items: const [
                      ChangeItem(
                        toolName: 'update_project_status',
                        args: {
                          'status': 'active',
                          'reason': 'Work is back on track',
                        },
                        humanSummary: 'Update project status to active',
                      ),
                    ],
                    createdAt: DateTime(2024, 3, 15),
                    vectorClock: null,
                  )
                  as ChangeSetEntity;

          await pumpPage(
            tester,
            controllerState: ProjectDetailState(
              project: testProject,
              linkedTasks: const [],
              isLoading: false,
              isSaving: false,
              hasChanges: false,
            ),
            extraOverrides: [
              projectPendingChangeSetsProvider(_projectId).overrideWith(
                (ref) async => [changeSet],
              ),
            ],
          );

          expect(find.byType(ChangeSetSummaryCard), findsOneWidget);
          expect(find.text('Proposed changes'), findsOneWidget);
          expect(find.text('Update project status to active'), findsOneWidget);
        },
      );

      testWidgets('shows linked tasks content when loaded', (tester) async {
        await pumpPage(
          tester,
          controllerState: ProjectDetailState(
            project: testProject,
            linkedTasks: const [],
            isLoading: false,
            isSaving: false,
            hasChanges: false,
          ),
        );

        // Verify the empty-state message from ProjectLinkedTasksSection
        expect(find.text('No tasks linked yet'), findsOneWidget);
      });
    });

    group('title sync', () {
      testWidgets('syncs title controller when hasChanges is false', (
        tester,
      ) async {
        await pumpPage(
          tester,
          controllerState: ProjectDetailState(
            project: testProject,
            linkedTasks: const [],
            isLoading: false,
            isSaving: false,
            hasChanges: false,
          ),
        );

        final textField = tester.widget<TextFormField>(
          find.byType(TextFormField),
        );
        expect(
          textField.controller?.text,
          'My Test Project',
          reason: 'Title should sync from project when hasChanges is false',
        );
      });

      testWidgets(
        'does not overwrite title controller when hasChanges is true',
        (tester) async {
          final controller = _TestProjectDetailController(
            ProjectDetailState(
              project: testProject,
              linkedTasks: const [],
              isLoading: false,
              isSaving: false,
              hasChanges: true,
            ),
          );

          await tester.pumpWidget(
            makeTestableWidgetNoScroll(
              const ProjectDetailPage(projectId: 'test-project-id'),
              overrides: [
                projectDetailControllerProvider('test-project-id').overrideWith(
                  () => controller,
                ),
                projectAgentProvider('test-project-id').overrideWith(
                  (ref) async => null,
                ),
              ],
            ),
          );
          await tester.pump(const Duration(milliseconds: 300));

          // When hasChanges is true, the sync should not overwrite the
          // controller text. The controller text starts empty because no sync
          // happens.
          final textField = tester.widget<TextFormField>(
            find.byType(TextFormField),
          );
          expect(
            textField.controller?.text,
            isEmpty,
            reason:
                'Title controller should not be synced when hasChanges '
                'is true',
          );
        },
      );
    });

    group('save button', () {
      testWidgets('save button is disabled when isSaving', (tester) async {
        await pumpPage(
          tester,
          controllerState: ProjectDetailState(
            project: testProject,
            linkedTasks: const [],
            isLoading: false,
            isSaving: true,
            hasChanges: true,
          ),
        );

        final saveButton = find.widgetWithText(FilledButton, 'Save');
        final button = tester.widget<FilledButton>(saveButton);
        expect(
          button.onPressed,
          isNull,
          reason: 'Save button should be disabled when isSaving',
        );
      });

      testWidgets('save button is disabled when no changes', (tester) async {
        await pumpPage(
          tester,
          controllerState: ProjectDetailState(
            project: testProject,
            linkedTasks: const [],
            isLoading: false,
            isSaving: false,
            hasChanges: false,
          ),
        );

        final saveButton = find.widgetWithText(FilledButton, 'Save');
        final button = tester.widget<FilledButton>(saveButton);
        expect(
          button.onPressed,
          isNull,
          reason: 'Save button should be disabled when no changes',
        );
      });

      testWidgets('save button is enabled when hasChanges and not saving', (
        tester,
      ) async {
        await pumpPage(
          tester,
          controllerState: ProjectDetailState(
            project: testProject,
            linkedTasks: const [],
            isLoading: false,
            isSaving: false,
            hasChanges: true,
          ),
        );

        final saveButton = find.widgetWithText(FilledButton, 'Save');
        final button = tester.widget<FilledButton>(saveButton);
        expect(
          button.onPressed,
          isNotNull,
          reason:
              'Save button should be enabled when hasChanges and not '
              'saving',
        );
      });

      testWidgets(
        'successful save falls back to NavService.beamBack on settings project routes',
        (tester) async {
          final mockNavService = MockNavService();
          when(() => mockNavService.currentPath).thenReturn(
            '/settings/projects/test-project-id',
          );
          when(mockNavService.beamBack).thenReturn(null);
          getIt.registerSingleton<NavService>(mockNavService);

          final controller = await pumpPage(
            tester,
            controllerState: ProjectDetailState(
              project: testProject,
              linkedTasks: const [],
              isLoading: false,
              isSaving: false,
              hasChanges: true,
            ),
          );

          await tester.tap(find.text('Save'));
          await tester.pumpAndSettle();

          expect(controller.saveChangesCalls, 1);
          verify(mockNavService.beamBack).called(1);
        },
      );
    });

    group('cancel button', () {
      testWidgets('pops the navigator when tapped', (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ProjectDetailPage(
                          projectId: 'test-project-id',
                        ),
                      ),
                    );
                  },
                  child: const Text('Go'),
                );
              },
            ),
            overrides: [
              projectDetailControllerProvider('test-project-id').overrideWith(
                () => _TestProjectDetailController(
                  ProjectDetailState(
                    project: testProject,
                    linkedTasks: const [],
                    isLoading: false,
                    isSaving: false,
                    hasChanges: false,
                  ),
                ),
              ),
              projectAgentProvider('test-project-id').overrideWith(
                (ref) async => null,
              ),
            ],
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        // Navigate to the detail page
        await tester.tap(find.text('Go'));
        await tester.pumpAndSettle();

        expect(find.text('Project Details'), findsOneWidget);

        // Tap Cancel
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        // Should have popped back to the initial route
        expect(find.text('Go'), findsOneWidget);
        expect(find.byType(ProjectDetailPage), findsNothing);
      });

      testWidgets(
        'back button returns to the originating category when categoryId exists',
        (tester) async {
          final mockNavService = MockNavService();
          when(
            () => mockNavService.beamToNamed(any(), data: any(named: 'data')),
          ).thenReturn(null);
          getIt.registerSingleton<NavService>(mockNavService);

          await pumpPage(
            tester,
            controllerState: ProjectDetailState(
              project: testProject,
              linkedTasks: const [],
              isLoading: false,
              isSaving: false,
              hasChanges: false,
            ),
            categoryId: 'cat-123',
          );

          await tester.tap(find.byTooltip('Back'));
          await tester.pump();

          verify(
            () => mockNavService.beamToNamed('/settings/categories/cat-123'),
          ).called(1);
        },
      );
    });

    group('error display', () {
      testWidgets('shows ErrorStateWidget for loadFailed error', (
        tester,
      ) async {
        await pumpPage(
          tester,
          controllerState: ProjectDetailState(
            project: testProject,
            linkedTasks: const [],
            isLoading: false,
            isSaving: false,
            hasChanges: false,
            error: ProjectDetailError.loadFailed,
          ),
        );

        expect(find.byType(ErrorStateWidget), findsOneWidget);
        expect(find.text('Failed to load project data.'), findsOneWidget);
      });

      testWidgets('shows ErrorStateWidget for updateFailed error', (
        tester,
      ) async {
        await pumpPage(
          tester,
          controllerState: ProjectDetailState(
            project: testProject,
            linkedTasks: const [],
            isLoading: false,
            isSaving: false,
            hasChanges: false,
            error: ProjectDetailError.updateFailed,
          ),
        );

        expect(find.byType(ErrorStateWidget), findsOneWidget);
        expect(
          find.text('Failed to update project. Please try again.'),
          findsOneWidget,
        );
      });

      testWidgets('shows ErrorStateWidget for titleRequired error', (
        tester,
      ) async {
        await pumpPage(
          tester,
          controllerState: ProjectDetailState(
            project: testProject,
            linkedTasks: const [],
            isLoading: false,
            isSaving: false,
            hasChanges: true,
            error: ProjectDetailError.titleRequired,
          ),
        );

        expect(find.byType(ErrorStateWidget), findsOneWidget);
        expect(
          find.text('Project title cannot be empty'),
          findsOneWidget,
        );
      });

      testWidgets('does not show ErrorStateWidget when error is null', (
        tester,
      ) async {
        await pumpPage(
          tester,
          controllerState: ProjectDetailState(
            project: testProject,
            linkedTasks: const [],
            isLoading: false,
            isSaving: false,
            hasChanges: false,
          ),
        );

        expect(find.byType(ErrorStateWidget), findsNothing);
      });
    });

    group('load-failure vs not-found', () {
      testWidgets('shows load-failed message when error is loadFailed and '
          'project is null', (tester) async {
        await pumpPage(
          tester,
          controllerState: const ProjectDetailState(
            project: null,
            linkedTasks: [],
            isLoading: false,
            isSaving: false,
            hasChanges: false,
            error: ProjectDetailError.loadFailed,
          ),
        );

        expect(
          find.text('Failed to load project data.'),
          findsOneWidget,
        );
        // Should NOT show the generic "not found" message
        expect(find.text('Project not found'), findsNothing);
      });

      testWidgets('shows not-found message when no error and project is null', (
        tester,
      ) async {
        await pumpPage(
          tester,
          controllerState: const ProjectDetailState(
            project: null,
            linkedTasks: [],
            isLoading: false,
            isSaving: false,
            hasChanges: false,
          ),
        );

        expect(find.text('Project not found'), findsOneWidget);
        expect(
          find.text('Failed to load project data.'),
          findsNothing,
        );
      });
    });

    group('_handleSave guard', () {
      testWidgets('does not call saveChanges when hasChanges is false', (
        tester,
      ) async {
        final controller = await pumpPage(
          tester,
          controllerState: ProjectDetailState(
            project: testProject,
            linkedTasks: const [],
            isLoading: false,
            isSaving: false,
            hasChanges: false,
          ),
        );

        // The save button should be disabled (null onPressed), but let's
        // also try invoking _handleSave via keyboard shortcut to cover the
        // guard logic.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.keyS);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.keyS);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
        await tester.pump();

        expect(
          controller.saveChangesCalls,
          0,
          reason: '_handleSave should early-return when hasChanges is false',
        );
      });

      testWidgets('does not call saveChanges when isSaving is true', (
        tester,
      ) async {
        final controller = await pumpPage(
          tester,
          controllerState: ProjectDetailState(
            project: testProject,
            linkedTasks: const [],
            isLoading: false,
            isSaving: true,
            hasChanges: true,
          ),
        );

        await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.keyS);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.keyS);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
        await tester.pump();

        expect(
          controller.saveChangesCalls,
          0,
          reason: '_handleSave should early-return when isSaving is true',
        );
      });

      testWidgets('calls saveChanges when hasChanges is true and not saving', (
        tester,
      ) async {
        final controller = await pumpPage(
          tester,
          controllerState: ProjectDetailState(
            project: testProject,
            linkedTasks: const [],
            isLoading: false,
            isSaving: false,
            hasChanges: true,
          ),
        );

        // Tap the save button
        final saveButton = find.widgetWithText(FilledButton, 'Save');
        await tester.tap(saveButton);
        await tester.pump();

        expect(
          controller.saveChangesCalls,
          1,
          reason: 'saveChanges should be called when hasChanges and not saving',
        );
      });
    });

    group('title editing', () {
      testWidgets('changing text field triggers updateTitle on controller', (
        tester,
      ) async {
        final controller = await pumpPage(
          tester,
          controllerState: ProjectDetailState(
            project: testProject,
            linkedTasks: const [],
            isLoading: false,
            isSaving: false,
            hasChanges: false,
          ),
        );

        // Enter text into the title field
        await tester.enterText(find.byType(TextFormField), 'Updated Title');
        await tester.pump();

        expect(
          controller.lastUpdatedTitle,
          'Updated Title',
          reason: 'updateTitle should be called with the new text',
        );
      });
    });

    group('target date pick', () {
      testWidgets('tapping date field opens date picker', (tester) async {
        await pumpPage(
          tester,
          controllerState: ProjectDetailState(
            project: testProject,
            linkedTasks: const [],
            isLoading: false,
            isSaving: false,
            hasChanges: false,
          ),
        );

        // Tap the date display area (the InkWell in ProjectTargetDateField)
        final targetDateField = find.byType(ProjectTargetDateField);
        expect(targetDateField, findsOneWidget);

        // The date field has an InkWell for picking dates
        final inkWell = find.descendant(
          of: targetDateField,
          matching: find.byType(InkWell),
        );
        await tester.tap(inkWell.first);
        await tester.pump(const Duration(milliseconds: 300));

        // A date picker dialog should appear
        expect(find.byType(DatePickerDialog), findsOneWidget);
      });

      testWidgets(
        'selecting a date in picker calls updateTargetDate',
        (tester) async {
          final controller = await pumpPage(
            tester,
            controllerState: ProjectDetailState(
              project: testProject,
              linkedTasks: const [],
              isLoading: false,
              isSaving: false,
              hasChanges: false,
            ),
          );

          // Tap the date display area
          final targetDateField = find.byType(ProjectTargetDateField);
          final inkWell = find.descendant(
            of: targetDateField,
            matching: find.byType(InkWell),
          );
          await tester.tap(inkWell.first);
          await tester.pump(const Duration(milliseconds: 300));

          // Tap OK in the date picker to confirm
          await tester.tap(find.text('OK'));
          await tester.pump(const Duration(milliseconds: 300));

          // updateTargetDate should have been called
          expect(controller.lastUpdatedTargetDate, isNotNull);
        },
      );
    });

    group('target date clear', () {
      testWidgets('tapping clear icon calls updateTargetDate(null)', (
        tester,
      ) async {
        final controller = await pumpPage(
          tester,
          controllerState: ProjectDetailState(
            project: testProject,
            linkedTasks: const [],
            isLoading: false,
            isSaving: false,
            hasChanges: false,
          ),
        );

        // The clear icon is only shown when targetDate is not null.
        // Our test project has a targetDate set.
        final clearIcon = find.byIcon(Icons.clear);
        expect(clearIcon, findsOneWidget);

        await tester.tap(clearIcon);
        await tester.pump();

        expect(
          controller.updateTargetDateCalledWithNull,
          isTrue,
          reason:
              'updateTargetDate should be called with null when clear '
              'icon is tapped',
        );
      });

      testWidgets('clear icon is not shown when targetDate is null', (
        tester,
      ) async {
        final projectWithoutDate = makeTestProject(
          id: _projectId,
          title: 'No Date Project',
          createdAt: now,
        );

        await pumpPage(
          tester,
          controllerState: ProjectDetailState(
            project: projectWithoutDate,
            linkedTasks: const [],
            isLoading: false,
            isSaving: false,
            hasChanges: false,
          ),
        );

        // The clear icon within ProjectTargetDateField should not be present
        // when targetDate is null.
        final targetDateField = find.byType(ProjectTargetDateField);
        expect(targetDateField, findsOneWidget);

        final clearIcon = find.descendant(
          of: targetDateField,
          matching: find.byIcon(Icons.clear),
        );
        expect(clearIcon, findsNothing);
      });
    });
  });
}
