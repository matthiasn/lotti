import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/projects/ui/model/project_list_detail_state.dart';
import 'package:lotti/features/projects/ui/widgets/project_list_pane.dart';

import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

void main() {
  Widget wrap(Widget child) {
    return makeTestableWidget2(
      Theme(
        data: DesignSystemTheme.dark(),
        child: Scaffold(
          body: SizedBox(width: 402, height: 900, child: child),
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
      expect(find.text('78'), findsOneWidget);
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
