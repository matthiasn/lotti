import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/features/projects/state/project_providers.dart';
import 'package:lotti/features/projects/ui/widgets/category_projects_section.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

void main() {
  final now = DateTime(2024, 3, 15);
  const categoryId = 'cat-section-1';

  late MockNavService mockNavService;

  setUpAll(registerAllFallbackValues);

  setUp(() async {
    await setUpTestGetIt(
      additionalSetup: () {
        mockNavService = MockNavService();
        when(
          () => mockNavService.beamToNamed(any(), data: any(named: 'data')),
        ).thenReturn(null);
        getIt.registerSingleton<NavService>(mockNavService);
      },
    );
  });

  tearDown(tearDownTestGetIt);

  group('CategoryProjectsSection', () {
    testWidgets('shows empty state message when no projects', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const CategoryProjectsSection(categoryId: categoryId),
          overrides: [
            projectsForCategoryProvider(categoryId).overrideWith(
              (ref) async => <ProjectEntry>[],
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('Projects'), findsOneWidget);
      expect(find.text('No projects yet'), findsOneWidget);
    });

    testWidgets('shows project titles and status chips', (tester) async {
      final projects = [
        makeTestProject(
          id: 'p-1',
          title: 'Frontend Redesign',
          categoryId: categoryId,
        ),
        makeTestProject(
          id: 'p-2',
          title: 'API Migration',
          categoryId: categoryId,
          status: ProjectStatus.active(
            id: uuid.v1(),
            createdAt: now,
            utcOffset: 0,
          ),
        ),
      ];

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const CategoryProjectsSection(categoryId: categoryId),
          overrides: [
            projectsForCategoryProvider(categoryId).overrideWith(
              (ref) async => projects,
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('Frontend Redesign'), findsOneWidget);
      expect(find.text('API Migration'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      // 1 from LottiFormSection header + 2 from project list tiles
      expect(find.byIcon(Icons.folder_outlined), findsNWidgets(3));
    });

    testWidgets('shows "New Project" button', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const CategoryProjectsSection(categoryId: categoryId),
          overrides: [
            projectsForCategoryProvider(categoryId).overrideWith(
              (ref) async => <ProjectEntry>[],
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('New Project'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('navigates to create page on "New Project" tap', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const CategoryProjectsSection(categoryId: categoryId),
          overrides: [
            projectsForCategoryProvider(categoryId).overrideWith(
              (ref) async => <ProjectEntry>[],
            ),
          ],
        ),
      );
      await tester.pump();

      await tester.tap(find.text('New Project'));
      await tester.pump();

      verify(
        () => mockNavService.beamToNamed(
          '/settings/projects/create?categoryId=$categoryId',
        ),
      ).called(1);
    });

    testWidgets('navigates to detail page on project tap', (tester) async {
      final project = makeTestProject(
        id: 'proj-detail',
        title: 'Tap Me',
        categoryId: categoryId,
      );

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const CategoryProjectsSection(categoryId: categoryId),
          overrides: [
            projectsForCategoryProvider(categoryId).overrideWith(
              (ref) async => [project],
            ),
          ],
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Tap Me'));
      await tester.pump();

      verify(
        () => mockNavService.beamToNamed('/settings/projects/proj-detail'),
      ).called(1);
    });
  });
}
