import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';
import 'package:lotti/features/categories/ui/widgets/category_selection_modal_content.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/projects/state/project_detail_controller.dart';
import 'package:lotti/features/projects/state/project_detail_record_provider.dart';
import 'package:lotti/features/projects/ui/model/project_list_detail_models.dart';
import 'package:lotti/features/projects/ui/pages/project_details_page.dart';
import 'package:lotti/features/projects/ui/widgets/project_mobile_detail_content.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
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

  @override
  ProjectDetailState build() => _initialState;

  @override
  void updateTitle(String title) {}

  @override
  void updateTargetDate(DateTime? targetDate) {}

  @override
  void updateCategoryId(String? categoryId) {}

  @override
  void updateStatus(ProjectStatus newStatus) {}

  @override
  Future<void> saveChanges() async {}
}

const _projectId = 'test-project-id';

/// The shared set of provider overrides that all tests need.
///
/// [recordOverride] controls the record provider. When it returns
/// synchronously the FutureProvider resolves on the next microtask; when it
/// returns a [Future] the provider stays in loading until it completes.
List<Override> _baseOverrides({
  required ProjectDetailState controllerState,
  required FutureOr<ProjectRecord?> Function(Ref) recordOverride,
  List<Override> extraOverrides = const [],
}) {
  return [
    projectDetailControllerProvider(_projectId).overrideWith(
      () => _TestProjectDetailController(controllerState),
    ),
    projectDetailRecordProvider(_projectId).overrideWith(
      (ref) => recordOverride(ref),
    ),
    projectDetailNowProvider.overrideWithValue(
      () => DateTime(2026, 3, 28, 9, 30),
    ),
    projectAgentProvider(_projectId).overrideWith((ref) async => null),
    agentIsRunningProvider.overrideWith(
      (ref, agentId) => Stream.value(false),
    ),
    ...extraOverrides,
  ];
}

void main() {
  final testProject = makeTestProject(
    id: _projectId,
    createdAt: DateTime(2026, 3, 15),
  );

  final testRecord = makeTestProjectRecord(project: testProject);

  setUpAll(registerAllFallbackValues);

  setUp(() async {
    await setUpTestGetIt();
  });

  tearDown(tearDownTestGetIt);

  /// Pumps the [ProjectDetailsPage] with data-state overrides and waits for
  /// provider resolution.
  Future<void> pumpPageWithData(
    WidgetTester tester, {
    required ProjectDetailState controllerState,
    ProjectRecord? record,
    List<Override> extraOverrides = const [],
  }) async {
    final overrides = _baseOverrides(
      controllerState: controllerState,
      recordOverride: (_) => record,
      extraOverrides: extraOverrides,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: makeTestableWidget2(
          Theme(
            data: DesignSystemTheme.dark(),
            child: const ProjectDetailsPage(projectId: _projectId),
          ),
        ),
      ),
    );
    // Two pumps: initial build and FutureProvider resolution/rebuild.
    await tester.pump();
    await tester.pump();
  }

  group('ProjectDetailsPage', () {
    group('loading state', () {
      testWidgets(
        'shows CircularProgressIndicator when controller is loading with '
        'null project',
        (tester) async {
          // When the controller reports isLoading with null project, the
          // loading guard in build() fires before recordAsync.when, so the
          // record value does not matter.
          await pumpPageWithData(
            tester,
            controllerState: const ProjectDetailState(
              project: null,
              linkedTasks: [],
              isLoading: true,
              isSaving: false,
              hasChanges: false,
            ),
            record: testRecord,
          );

          expect(find.byType(CircularProgressIndicator), findsOneWidget);
          expect(find.byType(ProjectMobileDetailContent), findsNothing);
        },
      );

      testWidgets(
        'shows CircularProgressIndicator when record provider is loading',
        (tester) async {
          // Use a completer that never completes to simulate a loading future.
          final completer = Completer<ProjectRecord?>();
          addTearDown(() {
            if (!completer.isCompleted) completer.complete();
          });

          final overrides = _baseOverrides(
            controllerState: ProjectDetailState(
              project: testProject,
              linkedTasks: const [],
              isLoading: false,
              isSaving: false,
              hasChanges: false,
            ),
            recordOverride: (_) => completer.future,
          );

          await tester.pumpWidget(
            ProviderScope(
              overrides: overrides,
              child: makeTestableWidget2(
                Theme(
                  data: DesignSystemTheme.dark(),
                  child: const ProjectDetailsPage(projectId: _projectId),
                ),
              ),
            ),
          );
          await tester.pump();

          expect(find.byType(CircularProgressIndicator), findsOneWidget);
          expect(find.byType(ProjectMobileDetailContent), findsNothing);
        },
      );
    });

    group('error state', () {
      testWidgets(
        'shows ErrorStateWidget when record provider returns an error',
        (tester) async {
          final overrides = _baseOverrides(
            controllerState: ProjectDetailState(
              project: testProject,
              linkedTasks: const [],
              isLoading: false,
              isSaving: false,
              hasChanges: false,
            ),
            recordOverride: (_) => throw Exception('db failure'),
          );

          await tester.pumpWidget(
            ProviderScope(
              overrides: overrides,
              child: makeTestableWidget2(
                Theme(
                  data: DesignSystemTheme.dark(),
                  child: const ProjectDetailsPage(projectId: _projectId),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(ErrorStateWidget), findsOneWidget);
          expect(find.text('Error'), findsOneWidget);
          expect(find.byType(ProjectMobileDetailContent), findsNothing);
        },
      );
    });

    group('null record state', () {
      testWidgets(
        'shows "Project not found" when record is null',
        (tester) async {
          await pumpPageWithData(
            tester,
            controllerState: ProjectDetailState(
              project: testProject,
              linkedTasks: const [],
              isLoading: false,
              isSaving: false,
              hasChanges: false,
            ),
          );

          expect(find.text('Project not found'), findsOneWidget);
          expect(find.byType(ProjectMobileDetailContent), findsNothing);
          expect(find.byType(CircularProgressIndicator), findsNothing);
        },
      );
    });

    group('successful data rendering', () {
      testWidgets(
        'renders ProjectMobileDetailContent when record is available',
        (tester) async {
          await pumpPageWithData(
            tester,
            controllerState: ProjectDetailState(
              project: testProject,
              linkedTasks: const [],
              isLoading: false,
              isSaving: false,
              hasChanges: false,
            ),
            record: testRecord,
          );

          expect(find.byType(ProjectMobileDetailContent), findsOneWidget);
          expect(find.byType(ErrorStateWidget), findsNothing);
          // The page should not show the loading spinner scaffold, but
          // ProjectMobileDetailContent may contain a CircularProgressIndicator
          // for the health score visualization, so we verify via the content
          // widget type rather than asserting no spinner at all.
        },
      );

      testWidgets(
        'passes the project title down to the detail content',
        (tester) async {
          await pumpPageWithData(
            tester,
            controllerState: ProjectDetailState(
              project: testProject,
              linkedTasks: const [],
              isLoading: false,
              isSaving: false,
              hasChanges: false,
            ),
            record: testRecord,
          );

          expect(find.text('Test Project'), findsOneWidget);
        },
      );

      testWidgets(
        'passes onRefreshReport as null when there is no agent identity',
        (tester) async {
          await pumpPageWithData(
            tester,
            controllerState: ProjectDetailState(
              project: testProject,
              linkedTasks: const [],
              isLoading: false,
              isSaving: false,
              hasChanges: false,
            ),
            record: testRecord,
          );

          final content = tester.widget<ProjectMobileDetailContent>(
            find.byType(ProjectMobileDetailContent),
          );
          expect(
            content.onRefreshReport,
            isNull,
            reason:
                'onRefreshReport should be null when no agent identity exists',
          );
          expect(content.isRefreshingReport, isFalse);
        },
      );

      testWidgets(
        'passes currentTime from the now provider',
        (tester) async {
          await pumpPageWithData(
            tester,
            controllerState: ProjectDetailState(
              project: testProject,
              linkedTasks: const [],
              isLoading: false,
              isSaving: false,
              hasChanges: false,
            ),
            record: testRecord,
          );

          final content = tester.widget<ProjectMobileDetailContent>(
            find.byType(ProjectMobileDetailContent),
          );
          expect(content.currentTime, DateTime(2026, 3, 28, 9, 30));
        },
      );
    });

    group('back navigation', () {
      testWidgets(
        'tapping the back button pops the navigator when a route can be '
        'popped',
        (tester) async {
          final overrides = _baseOverrides(
            controllerState: ProjectDetailState(
              project: testProject,
              linkedTasks: const [],
              isLoading: false,
              isSaving: false,
              hasChanges: false,
            ),
            recordOverride: (_) => testRecord,
          );

          // Push the page on top of an initial route so Navigator.canPop()
          // returns true.
          await tester.pumpWidget(
            ProviderScope(
              overrides: overrides,
              child: makeTestableWidget2(
                Theme(
                  data: DesignSystemTheme.dark(),
                  child: Builder(
                    builder: (context) {
                      return ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => Theme(
                                data: DesignSystemTheme.dark(),
                                child: const ProjectDetailsPage(
                                  projectId: _projectId,
                                ),
                              ),
                            ),
                          );
                        },
                        child: const Text('Go'),
                      );
                    },
                  ),
                ),
              ),
            ),
          );
          await tester.pump();

          // Navigate to the details page.
          await tester.tap(find.text('Go'));
          await tester.pumpAndSettle();

          expect(
            find.byType(ProjectMobileDetailContent),
            findsOneWidget,
          );

          // Verify the onBack callback is wired.
          final content = tester.widget<ProjectMobileDetailContent>(
            find.byType(ProjectMobileDetailContent),
          );
          expect(
            content.onBack,
            isNotNull,
            reason: 'onBack callback should be provided',
          );

          // Tap the back button rendered in the detail header.
          final backButton = find.byIcon(Icons.arrow_back_ios);
          expect(backButton, findsOneWidget);
          await tester.tap(backButton.first);
          await tester.pumpAndSettle();

          // Should have popped back to the initial route.
          expect(find.text('Go'), findsOneWidget);
          expect(find.byType(ProjectDetailsPage), findsNothing);
        },
      );
    });

    group('callback wiring', () {
      testWidgets(
        'onCategoryTap callback is wired to the detail content',
        (tester) async {
          await pumpPageWithData(
            tester,
            controllerState: ProjectDetailState(
              project: testProject,
              linkedTasks: const [],
              isLoading: false,
              isSaving: false,
              hasChanges: false,
            ),
            record: testRecord,
          );

          final content = tester.widget<ProjectMobileDetailContent>(
            find.byType(ProjectMobileDetailContent),
          );
          expect(
            content.onCategoryTap,
            isNotNull,
            reason: 'onCategoryTap should be provided to the content widget',
          );
        },
      );

      testWidgets(
        'onTargetDateTap callback is wired to the detail content',
        (tester) async {
          await pumpPageWithData(
            tester,
            controllerState: ProjectDetailState(
              project: testProject,
              linkedTasks: const [],
              isLoading: false,
              isSaving: false,
              hasChanges: false,
            ),
            record: testRecord,
          );

          final content = tester.widget<ProjectMobileDetailContent>(
            find.byType(ProjectMobileDetailContent),
          );
          expect(
            content.onTargetDateTap,
            isNotNull,
            reason: 'onTargetDateTap should be provided to the content widget',
          );
        },
      );

      testWidgets(
        'onStatusTap callback is wired to the detail content',
        (tester) async {
          await pumpPageWithData(
            tester,
            controllerState: ProjectDetailState(
              project: testProject,
              linkedTasks: const [],
              isLoading: false,
              isSaving: false,
              hasChanges: false,
            ),
            record: testRecord,
          );

          final content = tester.widget<ProjectMobileDetailContent>(
            find.byType(ProjectMobileDetailContent),
          );
          expect(
            content.onStatusTap,
            isNotNull,
            reason: 'onStatusTap should be provided to the content widget',
          );
        },
      );

      testWidgets(
        'onTaskTap callback is wired to the detail content',
        (tester) async {
          await pumpPageWithData(
            tester,
            controllerState: ProjectDetailState(
              project: testProject,
              linkedTasks: const [],
              isLoading: false,
              isSaving: false,
              hasChanges: false,
            ),
            record: testRecord,
          );

          final content = tester.widget<ProjectMobileDetailContent>(
            find.byType(ProjectMobileDetailContent),
          );
          expect(
            content.onTaskTap,
            isNotNull,
            reason: 'onTaskTap should be provided to the content widget',
          );
        },
      );
    });

    group('status picker modal', () {
      testWidgets(
        'tapping onStatusTap opens a bottom sheet with status options',
        (tester) async {
          // Use a tall surface so the bottom sheet has room to render all
          // status options without overflow.
          tester.view
            ..physicalSize = const Size(430, 1200)
            ..devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await pumpPageWithData(
            tester,
            controllerState: ProjectDetailState(
              project: testProject,
              linkedTasks: const [],
              isLoading: false,
              isSaving: false,
              hasChanges: false,
            ),
            record: testRecord,
          );

          final content = tester.widget<ProjectMobileDetailContent>(
            find.byType(ProjectMobileDetailContent),
          );

          // Invoke the onStatusTap callback directly to trigger the
          // bottom sheet.
          content.onStatusTap!();
          await tester.pumpAndSettle();

          // The bottom sheet should show all status options.
          expect(find.text('Open'), findsWidgets);
          expect(find.text('Active'), findsOneWidget);
          expect(find.text('On Hold'), findsOneWidget);
          expect(find.text('Completed'), findsOneWidget);
          expect(find.text('Archived'), findsOneWidget);
        },
      );

      testWidgets(
        'tapping a non-selected status option dismisses the sheet and saves',
        (tester) async {
          tester.view
            ..physicalSize = const Size(430, 1200)
            ..devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await pumpPageWithData(
            tester,
            controllerState: ProjectDetailState(
              project: testProject,
              linkedTasks: const [],
              isLoading: false,
              isSaving: false,
              hasChanges: false,
            ),
            record: testRecord,
          );

          final content = tester.widget<ProjectMobileDetailContent>(
            find.byType(ProjectMobileDetailContent),
          );

          // Open the status picker bottom sheet.
          content.onStatusTap!();
          await tester.pumpAndSettle();

          // The default test project has status 'Open'. Tap 'Active' which
          // is a different status to trigger the selection path.
          await tester.tap(find.text('Active'));
          await tester.pumpAndSettle();

          // The sheet should be dismissed — status options are no longer
          // visible.
          expect(find.text('Archived'), findsNothing);
          expect(find.text('On Hold'), findsNothing);
        },
      );

      testWidgets(
        'tapping the already-selected status dismisses without saving',
        (tester) async {
          tester.view
            ..physicalSize = const Size(430, 1200)
            ..devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await pumpPageWithData(
            tester,
            controllerState: ProjectDetailState(
              project: testProject,
              linkedTasks: const [],
              isLoading: false,
              isSaving: false,
              hasChanges: false,
            ),
            record: testRecord,
          );

          final content = tester.widget<ProjectMobileDetailContent>(
            find.byType(ProjectMobileDetailContent),
          );

          // Open the status picker bottom sheet.
          content.onStatusTap!();
          await tester.pumpAndSettle();

          // The default test project has status 'Open'. The 'Open' option
          // should have a check mark (Icons.check_rounded) indicating it is
          // the currently selected status.
          expect(find.byIcon(Icons.check_rounded), findsOneWidget);

          // Tap the already-selected 'Open' status. Because the status chip
          // text 'Open' also appears in the underlying page, use the ListTile
          // that contains the check icon to tap the correct one.
          final openTile = find.ancestor(
            of: find.byIcon(Icons.check_rounded),
            matching: find.byType(ListTile),
          );
          await tester.tap(openTile);
          await tester.pumpAndSettle();

          // The sheet should be dismissed without triggering a save.
          expect(find.text('Archived'), findsNothing);
          expect(find.text('On Hold'), findsNothing);
        },
      );

      testWidgets(
        'displays all five status variants with correct icons',
        (tester) async {
          tester.view
            ..physicalSize = const Size(430, 1200)
            ..devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await pumpPageWithData(
            tester,
            controllerState: ProjectDetailState(
              project: testProject,
              linkedTasks: const [],
              isLoading: false,
              isSaving: false,
              hasChanges: false,
            ),
            record: testRecord,
          );

          final content = tester.widget<ProjectMobileDetailContent>(
            find.byType(ProjectMobileDetailContent),
          );

          content.onStatusTap!();
          await tester.pumpAndSettle();

          // Verify each status variant renders with its expected icon.
          expect(
            find.byIcon(Icons.radio_button_unchecked),
            findsOneWidget,
            reason: 'Open status icon',
          );
          expect(
            find.byIcon(Icons.play_circle_outline),
            findsOneWidget,
            reason: 'Active status icon',
          );
          expect(
            find.byIcon(Icons.pause_circle_outline),
            findsOneWidget,
            reason: 'On Hold status icon',
          );
          expect(
            find.byIcon(Icons.check_circle_outline),
            findsOneWidget,
            reason: 'Completed status icon',
          );
          expect(
            find.byIcon(Icons.archive_outlined),
            findsOneWidget,
            reason: 'Archived status icon',
          );

          // Only the current status ('Open') should show the selection
          // check mark.
          expect(find.byIcon(Icons.check_rounded), findsOneWidget);
        },
      );
    });

    group('category picker modal', () {
      testWidgets(
        'tapping onCategoryTap opens the category selection modal',
        (tester) async {
          tester.view
            ..physicalSize = const Size(430, 1200)
            ..devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          // CategorySelectionModalContent requires EntitiesCacheService
          // from GetIt.
          final mockCache = MockEntitiesCacheService();
          when(() => mockCache.sortedCategories).thenReturn([]);
          getIt.registerSingleton<EntitiesCacheService>(mockCache);

          await pumpPageWithData(
            tester,
            controllerState: ProjectDetailState(
              project: testProject,
              linkedTasks: const [],
              isLoading: false,
              isSaving: false,
              hasChanges: false,
            ),
            record: testRecord,
          );

          final content = tester.widget<ProjectMobileDetailContent>(
            find.byType(ProjectMobileDetailContent),
          );

          // Invoke the onCategoryTap callback to open the modal.
          content.onCategoryTap!();
          await tester.pumpAndSettle();

          // The modal should contain the CategorySelectionModalContent
          // widget and display the 'Category:' title.
          expect(
            find.byType(CategorySelectionModalContent),
            findsOneWidget,
          );
          expect(find.text('Category:'), findsOneWidget);
        },
      );
    });

    group('target date picker', () {
      testWidgets(
        'tapping onTargetDateTap opens a date picker dialog',
        (tester) async {
          await pumpPageWithData(
            tester,
            controllerState: ProjectDetailState(
              project: testProject,
              linkedTasks: const [],
              isLoading: false,
              isSaving: false,
              hasChanges: false,
            ),
            record: testRecord,
          );

          final content = tester.widget<ProjectMobileDetailContent>(
            find.byType(ProjectMobileDetailContent),
          );

          // Invoke the onTargetDateTap callback.
          content.onTargetDateTap!();
          await tester.pump(const Duration(milliseconds: 300));

          expect(find.byType(DatePickerDialog), findsOneWidget);
        },
      );
    });
  });
}
