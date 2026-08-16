import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/design_system/components/inputs/design_system_text_input.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/features/keyboard/ui/app_command_controller.dart';
import 'package:lotti/features/keyboard/ui/app_command_host.dart';
import 'package:lotti/features/projects/state/project_detail_controller.dart';
import 'package:lotti/features/projects/ui/pages/project_detail_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/ui/error_state_widget.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

const _projectId = 'test-project-id';

class _TestProjectDetailController extends ProjectDetailController {
  _TestProjectDetailController(this._initialState) : super(_projectId);

  final ProjectDetailState _initialState;
  late ProjectDetailState _state;

  String? lastUpdatedTitle;
  DateTime? lastUpdatedTargetDate;
  ProjectStatus? lastUpdatedStatus;
  int saveChangesCalls = 0;
  int discardChangesCalls = 0;

  @override
  ProjectDetailState build() => _state = _initialState;

  @override
  void updateTitle(String title) {
    lastUpdatedTitle = title;
    final project = _state.project;
    if (project == null) return;
    _setProject(project.copyWith(data: project.data.copyWith(title: title)));
  }

  @override
  void updateTargetDate(DateTime? targetDate) {
    lastUpdatedTargetDate = targetDate;
    final project = _state.project;
    if (project == null) return;
    _setProject(
      project.copyWith(data: project.data.copyWith(targetDate: targetDate)),
    );
  }

  @override
  void updateStatus(ProjectStatus newStatus) {
    lastUpdatedStatus = newStatus;
    final project = _state.project;
    if (project == null) return;
    _setProject(
      project.copyWith(data: project.data.copyWith(status: newStatus)),
    );
  }

  void _setProject(ProjectEntry project) {
    _state = _state.copyWith(project: project, hasChanges: true);
    state = _state;
  }

  @override
  Future<void> saveChanges() async {
    saveChangesCalls++;
  }

  @override
  void discardChanges() {
    discardChangesCalls++;
    _state = _initialState.copyWith(hasChanges: false);
    state = _state;
  }
}

void main() {
  final testProject = makeTestProject(
    id: _projectId,
    title: 'My Test Project',
    createdAt: DateTime(2024, 3, 15),
    targetDate: DateTime(2024, 6, 30),
  );

  ProjectDetailState loadedState({
    bool isSaving = false,
    bool hasChanges = false,
    ProjectDetailError? error,
  }) => ProjectDetailState(
    project: testProject,
    linkedTasks: const [],
    isLoading: false,
    isSaving: isSaving,
    hasChanges: hasChanges,
    error: error,
  );

  setUpAll(registerAllFallbackValues);
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  Future<_TestProjectDetailController> pumpPage(
    WidgetTester tester, {
    required ProjectDetailState state,
    String? categoryId,
    String? returnPath,
  }) async {
    tester.view
      ..physicalSize = const Size(390, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = _TestProjectDetailController(state);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        AppCommandHost(
          handlers: const {},
          platform: TargetPlatform.windows,
          child: ProjectDetailPage(
            projectId: _projectId,
            categoryId: categoryId,
            returnPath: returnPath,
          ),
        ),
        overrides: [
          projectDetailControllerProvider(_projectId).overrideWith(
            () => controller,
          ),
        ],
      ),
    );
    await tester.pump();
    return controller;
  }

  group('ProjectDetailPage', () {
    testWidgets('renders the initial loading state', (tester) async {
      await pumpPage(
        tester,
        state: const ProjectDetailState(
          project: null,
          linkedTasks: [],
          isLoading: true,
          isSaving: false,
          hasChanges: false,
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders the not-found state without a spinner', (
      tester,
    ) async {
      await pumpPage(
        tester,
        state: const ProjectDetailState(
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

    testWidgets('uses one compact metadata card instead of stacked sections', (
      tester,
    ) async {
      await pumpPage(tester, state: loadedState());

      expect(find.byType(DesignSystemSectionCard), findsOneWidget);
      expect(find.byType(DesignSystemTextInput), findsOneWidget);
      expect(find.byType(DesignSystemSelectionRow), findsNWidgets(2));
      expect(find.text('Project health'), findsNothing);
      expect(find.text('Agent'), findsNothing);
      expect(find.text('Linked Tasks'), findsNothing);

      final cardRect = tester.getRect(find.byType(DesignSystemSectionCard));
      expect(
        cardRect.height,
        lessThan(360),
        reason: 'The editor should remain a compact metadata form.',
      );
    });

    testWidgets('syncs and edits the project title', (tester) async {
      final controller = await pumpPage(tester, state: loadedState());
      final field = find.descendant(
        of: find.byType(DesignSystemTextInput),
        matching: find.byType(TextField),
      );

      expect(
        tester.widget<TextField>(field).controller?.text,
        'My Test Project',
      );
      await tester.enterText(field, 'Updated title');
      await tester.pump();
      expect(controller.lastUpdatedTitle, 'Updated title');
    });

    testWidgets('does not overwrite an existing pending title draft', (
      tester,
    ) async {
      await pumpPage(tester, state: loadedState(hasChanges: true));
      final field = find.descendant(
        of: find.byType(DesignSystemTextInput),
        matching: find.byType(TextField),
      );
      expect(tester.widget<TextField>(field).controller?.text, isEmpty);
    });

    testWidgets('opens the shared status picker and applies the selection', (
      tester,
    ) async {
      final controller = await pumpPage(tester, state: loadedState());

      await tester.tap(find.text('Change status'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Completed'), findsOneWidget);

      await tester.tap(find.text('Completed'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(controller.lastUpdatedStatus, isA<ProjectCompleted>());
    });

    testWidgets('opens the target-date picker and applies its date', (
      tester,
    ) async {
      final controller = await pumpPage(tester, state: loadedState());

      await tester.tap(find.text('Target Date'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(CalendarDatePicker), findsOneWidget);

      await tester.tap(find.text('Done'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(controller.lastUpdatedTargetDate, isNotNull);
    });

    testWidgets('disables every editor control while saving', (tester) async {
      await pumpPage(
        tester,
        state: loadedState(isSaving: true, hasChanges: true),
      );

      expect(
        tester
            .widget<DesignSystemTextInput>(
              find.byType(DesignSystemTextInput),
            )
            .enabled,
        isFalse,
      );
      expect(
        tester
            .widgetList<DesignSystemSelectionRow>(
              find.byType(DesignSystemSelectionRow),
            )
            .every((row) => row.onTap == null),
        isTrue,
      );
      expect(
        tester
            .widget<DesignSystemButton>(
              find.widgetWithText(DesignSystemButton, 'Save'),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('disables Save when the draft has no changes', (tester) async {
      await pumpPage(tester, state: loadedState());
      expect(
        tester
            .widget<DesignSystemButton>(
              find.widgetWithText(DesignSystemButton, 'Save'),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('enables Save for a changed, idle draft', (tester) async {
      final controller = await pumpPage(
        tester,
        state: loadedState(hasChanges: true),
      );
      final save = find.widgetWithText(DesignSystemButton, 'Save');
      expect(tester.widget<DesignSystemButton>(save).onPressed, isNotNull);

      final context = tester.element(save);
      final commands = AppCommandControllerProvider.of(context);
      expect(commands.isAvailable(context, AppCommandId.save), isTrue);
      expect(await commands.invoke(context, AppCommandId.save), isTrue);
      expect(controller.saveChangesCalls, 1);
    });

    testWidgets('ignores the save shortcut when the draft cannot save', (
      tester,
    ) async {
      final controller = await pumpPage(tester, state: loadedState());

      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pump();
      expect(controller.saveChangesCalls, 0);
    });

    testWidgets('Cancel discards a draft and returns to the workspace', (
      tester,
    ) async {
      final nav = MockNavService();
      when(
        () => nav.beamToNamed(any(), data: any(named: 'data')),
      ).thenReturn(null);
      getIt.registerSingleton<NavService>(nav);
      final controller = await pumpPage(
        tester,
        state: loadedState(hasChanges: true),
        returnPath: '/projects/$_projectId',
      );

      await tester.tap(find.text('Cancel'));
      await tester.pump();
      verify(() => nav.beamToNamed('/projects/$_projectId')).called(1);
      expect(controller.discardChangesCalls, 1);
    });

    testWidgets('Back returns to the originating category', (tester) async {
      final nav = MockNavService();
      when(
        () => nav.beamToNamed(any(), data: any(named: 'data')),
      ).thenReturn(null);
      getIt.registerSingleton<NavService>(nav);
      await pumpPage(
        tester,
        state: loadedState(),
        categoryId: 'cat-123',
      );

      await tester.tap(find.text('Back'));
      await tester.pump();
      verify(() => nav.beamToNamed('/settings/categories/cat-123')).called(1);
    });

    testWidgets('surfaces localized controller errors without replacing form', (
      tester,
    ) async {
      await pumpPage(
        tester,
        state: loadedState(error: ProjectDetailError.updateFailed),
      );

      expect(find.byType(ErrorStateWidget), findsOneWidget);
      expect(
        find.text('Failed to update project. Please try again.'),
        findsOneWidget,
      );
      expect(find.byType(DesignSystemSectionCard), findsOneWidget);
    });

    testWidgets('distinguishes a load failure from a missing project', (
      tester,
    ) async {
      await pumpPage(
        tester,
        state: const ProjectDetailState(
          project: null,
          linkedTasks: [],
          isLoading: false,
          isSaving: false,
          hasChanges: false,
          error: ProjectDetailError.loadFailed,
        ),
      );

      expect(find.text('Failed to load project data.'), findsOneWidget);
      expect(find.text('Project not found'), findsNothing);
    });
  });
}
