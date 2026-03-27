import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/features/projects/model/projects_overview_models.dart';
import 'package:lotti/features/projects/state/project_providers.dart';
import 'package:lotti/features/projects/ui/pages/projects_tab_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_finders.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../../categories/test_utils.dart';
import '../../test_utils.dart';

void main() {
  late MockUserActivityService mockUserActivityService;

  ProjectCategoryGroup buildWorkGroup() {
    final category = CategoryTestUtils.createTestCategory(
      id: 'work',
      name: 'Work',
    );

    return ProjectCategoryGroup(
      categoryId: category.id,
      category: category,
      projects: [
        ProjectListItemData(
          project: makeTestProject(
            id: 'project-1',
            title: 'Device Sync',
            status: ProjectStatus.active(
              id: 'status-1',
              createdAt: DateTime(2024, 3, 15),
              utcOffset: 0,
            ),
            categoryId: category.id,
            targetDate: DateTime(2024, 3, 27),
          ),
          category: category,
          taskRollup: const ProjectTaskRollupData(
            totalTaskCount: 5,
            completedTaskCount: 3,
            blockedTaskCount: 1,
          ),
        ),
        ProjectListItemData(
          project: makeTestProject(
            id: 'project-2',
            title: 'API Migration',
            status: ProjectStatus.completed(
              id: 'status-2',
              createdAt: DateTime(2024, 3, 16),
              utcOffset: 0,
            ),
            categoryId: category.id,
            targetDate: DateTime(2024, 3, 30),
          ),
          category: category,
          taskRollup: const ProjectTaskRollupData(
            totalTaskCount: 3,
            completedTaskCount: 3,
          ),
        ),
      ],
    );
  }

  ProjectCategoryGroup buildStudyGroup() {
    final category = CategoryTestUtils.createTestCategory(
      id: 'study',
      name: 'Study',
    );

    return ProjectCategoryGroup(
      categoryId: category.id,
      category: category,
      projects: [
        ProjectListItemData(
          project: makeTestProject(
            id: 'project-3',
            title: 'React Course',
            categoryId: category.id,
          ),
          category: category,
          taskRollup: const ProjectTaskRollupData(totalTaskCount: 2),
        ),
      ],
    );
  }

  Future<void> pumpPage(
    WidgetTester tester, {
    required List<ProjectCategoryGroup> groups,
    MediaQueryData? mediaQueryData,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const ProjectsTabPage(),
        mediaQueryData: mediaQueryData,
        theme: withOverrides(ThemeData.dark(useMaterial3: true)),
        overrides: [
          visibleProjectGroupsProvider.overrideWith(
            (ref) => AsyncValue.data(groups),
          ),
        ],
      ),
    );
    await tester.pump();
  }

  setUp(() async {
    mockUserActivityService = MockUserActivityService();
    when(() => mockUserActivityService.updateActivity()).thenReturn(null);

    await setUpTestGetIt(
      additionalSetup: () {
        getIt.registerSingleton<UserActivityService>(mockUserActivityService);
      },
    );
  });

  tearDown(() async {
    beamToNamedOverride = null;
    await tearDownTestGetIt();
  });

  testWidgets('renders grouped projects with a disabled search bar', (
    tester,
  ) async {
    await pumpPage(
      tester,
      groups: [buildWorkGroup(), buildStudyGroup()],
    );

    expect(find.text('Projects'), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);
    expect(find.text('2 projects'), findsOneWidget);
    expect(find.text('Device Sync'), findsOneWidget);
    expect(find.text('API Migration'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(findRichTextContaining('5 tasks'), findsOneWidget);
    expect(findRichTextContaining('Due Mar 27'), findsOneWidget);
    expect(find.bySemanticsLabel('New Project'), findsOneWidget);

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.enabled, isFalse);
  });

  testWidgets('row tap opens the existing settings project detail route', (
    tester,
  ) async {
    var navigatedPath = '';
    beamToNamedOverride = (path) => navigatedPath = path;

    await pumpPage(
      tester,
      groups: [buildWorkGroup()],
    );

    await tester.tap(find.text('Device Sync'));
    await tester.pump();

    expect(
      navigatedPath,
      '/settings/projects/project-1?categoryId=work',
    );
  });

  testWidgets('create button opens the project create route', (
    tester,
  ) async {
    var navigatedPath = '';
    beamToNamedOverride = (path) => navigatedPath = path;

    await pumpPage(
      tester,
      groups: [buildWorkGroup()],
    );

    await tester.tap(find.bySemanticsLabel('New Project'));
    await tester.pump();

    expect(
      navigatedPath,
      '/settings/projects/create',
    );
  });

  testWidgets('renders the same grouped data on phone and desktop widths', (
    tester,
  ) async {
    final groups = [buildWorkGroup(), buildStudyGroup()];

    await pumpPage(
      tester,
      groups: groups,
      mediaQueryData: phoneMediaQueryData,
    );
    expect(find.text('Device Sync'), findsOneWidget);
    expect(find.text('React Course'), findsOneWidget);

    await pumpPage(
      tester,
      groups: groups,
      mediaQueryData: const MediaQueryData(size: Size(1280, 800)),
    );
    expect(find.text('Device Sync'), findsOneWidget);
    expect(find.text('React Course'), findsOneWidget);
  });

  testWidgets('shows no-results message when groups are empty', (
    tester,
  ) async {
    await pumpPage(tester, groups: []);

    expect(
      find.text('No projects match your search.'),
      findsOneWidget,
    );
  });

  testWidgets('shows loading indicator while data is loading', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const ProjectsTabPage(),
        theme: withOverrides(ThemeData.dark(useMaterial3: true)),
        overrides: [
          visibleProjectGroupsProvider.overrideWith(
            (ref) => const AsyncValue<List<ProjectCategoryGroup>>.loading(),
          ),
        ],
      ),
    );
    await tester.pump();

    expect(
      find.byType(CircularProgressIndicator),
      findsOneWidget,
    );
  });

  testWidgets('shows localized error message on failure', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const ProjectsTabPage(),
        theme: withOverrides(ThemeData.dark(useMaterial3: true)),
        overrides: [
          visibleProjectGroupsProvider.overrideWith(
            (ref) => AsyncValue<List<ProjectCategoryGroup>>.error(
              Exception('test'),
              StackTrace.empty,
            ),
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.text('Error'), findsOneWidget);
  });
}
