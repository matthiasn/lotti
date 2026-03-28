import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/projects/model/projects_overview_models.dart';
import 'package:lotti/features/projects/ui/model/project_list_detail_state.dart';
import 'package:lotti/features/projects/ui/widgets/project_list_pane.dart';
import 'package:lotti/l10n/app_localizations.dart';

import '../../../../helpers/test_finders.dart';
import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

void main() {
  Widget wrap(Widget child, {Locale? locale}) {
    final themedChild = Theme(
      data: DesignSystemTheme.dark(),
      child: Scaffold(
        body: SizedBox(width: 402, height: 900, child: child),
      ),
    );

    return makeTestableWidget2(
      Builder(
        builder: (context) => locale == null
            ? themedChild
            : Localizations.override(
                context: context,
                locale: locale,
                child: themedChild,
              ),
      ),
      mediaQueryData: const MediaQueryData(size: Size(500, 1000)),
    );
  }

  group('ProjectListPane', () {
    late ProjectListDetailState state;
    String? lastSelectedProjectId;

    setUp(() {
      state = ProjectListDetailState(
        data: makeTestProjectListData(),
        filter: const ProjectsFilter(
          searchMode: ProjectsSearchMode.localText,
        ),
        selectedProjectId: 'p1',
      );
      lastSelectedProjectId = null;
    });

    testWidgets('renders search and grouped project rows', (tester) async {
      await tester.pumpWidget(
        wrap(
          ProjectListPane(
            state: state,
            onProjectSelected: (id) => lastSelectedProjectId = id,
            onSearchChanged: (_) {},
            onSearchCleared: () {},
            onFilterPressed: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Project Alpha'), findsOneWidget);
      expect(find.text('Project Beta'), findsOneWidget);
      expect(find.text('Work'), findsOneWidget);
      expect(find.text('Study'), findsOneWidget);
    });

    testWidgets('shows no-results pane when search filters everything', (
      tester,
    ) async {
      final filteredState = state.copyWith(
        filter: state.filter.copyWith(textQuery: 'zzz'),
      );

      await tester.pumpWidget(
        wrap(
          ProjectListPane(
            state: filteredState,
            onProjectSelected: (_) {},
            onSearchChanged: (_) {},
            onSearchCleared: () {},
            onFilterPressed: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('No projects match your search.'), findsOneWidget);
    });

    testWidgets('tapping a row calls onProjectSelected', (tester) async {
      await tester.pumpWidget(
        wrap(
          ProjectListPane(
            state: state,
            onProjectSelected: (id) => lastSelectedProjectId = id,
            onSearchChanged: (_) {},
            onSearchCleared: () {},
            onFilterPressed: () {},
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Project Beta'));
      await tester.pump();

      expect(lastSelectedProjectId, 'p2');
    });

    testWidgets('renders due dates with the active locale format', (
      tester,
    ) async {
      final targetDate = DateTime(2026, 4, 15);
      final baseData = makeTestProjectListData();
      final datedRecord = makeTestProjectRecord(
        category: baseData.categories.first,
        project: makeTestProject(
          id: 'p1',
          title: 'Project Alpha',
          categoryId: baseData.categories.first.id,
          targetDate: targetDate,
        ),
      );
      final localizedState = ProjectListDetailState(
        data: makeTestProjectListData(
          categories: [baseData.categories.first],
          projects: [datedRecord],
          currentTime: baseData.currentTime,
        ),
        filter: const ProjectsFilter(
          searchMode: ProjectsSearchMode.localText,
        ),
        selectedProjectId: 'p1',
      );

      await tester.pumpWidget(
        wrap(
          ProjectListPane(
            state: localizedState,
            onProjectSelected: (_) {},
            onSearchChanged: (_) {},
            onSearchCleared: () {},
            onFilterPressed: () {},
          ),
          locale: const Locale('de'),
        ),
      );
      await tester.pump();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(ProjectListPane)),
      )!;
      final expectedDate = DateFormat.MMMd('de').format(targetDate);
      expect(
        findRichTextContaining(
          l10n.settingsCategoriesTaskCount(datedRecord.totalTaskCount),
        ),
        findsOneWidget,
      );
      expect(
        findRichTextContaining(l10n.projectShowcaseDueDate(expectedDate)),
        findsOneWidget,
      );
    });
  });
}
