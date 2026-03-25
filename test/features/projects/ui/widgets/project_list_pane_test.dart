import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/projects/ui/model/project_list_detail_state.dart';
import 'package:lotti/features/projects/ui/widgets/project_list_pane.dart';
import 'package:lotti/l10n/app_localizations.dart';

import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

void main() {
  Finder richTextContaining(String text) => find.byWidgetPredicate(
    (widget) => widget is RichText && widget.text.toPlainText().contains(text),
  );

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
        searchQuery: '',
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
      final filteredState = state.copyWith(searchQuery: 'zzz');

      await tester.pumpWidget(
        wrap(
          ProjectListPane(
            state: filteredState,
            onProjectSelected: (_) {},
            onSearchChanged: (_) {},
            onSearchCleared: () {},
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
        searchQuery: '',
        selectedProjectId: 'p1',
      );

      await tester.pumpWidget(
        wrap(
          ProjectListPane(
            state: localizedState,
            onProjectSelected: (_) {},
            onSearchChanged: (_) {},
            onSearchCleared: () {},
          ),
          locale: const Locale('de'),
        ),
      );
      await tester.pump();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(ProjectListPane)),
      )!;
      final expectedDate = DateFormat.MMMd('de').format(targetDate);
      final expectedSummary =
          '${l10n.settingsCategoriesTaskCount(datedRecord.totalTaskCount)} · ${l10n.projectShowcaseDueDate(expectedDate)}';

      expect(richTextContaining(expectedSummary), findsOneWidget);
    });
  });

  group('ProjectGroupSection', () {
    testWidgets('renders category tag and project count', (tester) async {
      final data = makeTestProjectListData();
      final group = ProjectListDetailState(
        data: data,
        searchQuery: '',
        selectedProjectId: 'p1',
      ).visibleGroups.first;

      await tester.pumpWidget(
        wrap(
          ProjectGroupSection(
            group: group,
            selectedProjectId: 'p1',
            onProjectSelected: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Work'), findsOneWidget);
      expect(find.text('1 project'), findsOneWidget);
    });
  });

  group('ProjectRow', () {
    testWidgets('renders title, health score, and status', (tester) async {
      final record = makeTestProjectRecord();

      await tester.pumpWidget(
        wrap(
          ProjectRow(
            record: record,
            selected: false,
            hovered: false,
            onHoverChanged: (_) {},
            onTap: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Test Project'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('project-row-health-ring')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.format_list_bulleted_rounded), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      final record = makeTestProjectRecord();

      await tester.pumpWidget(
        wrap(
          ProjectRow(
            record: record,
            selected: false,
            hovered: false,
            onHoverChanged: (_) {},
            onTap: () => tapped = true,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Test Project'));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });
}
