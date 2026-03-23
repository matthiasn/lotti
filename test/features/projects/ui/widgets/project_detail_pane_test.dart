import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/projects/ui/widgets/project_detail_pane.dart';

import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

void main() {
  final testCurrentTime = DateTime(2026, 4, 2, 9, 30);

  Widget wrap(Widget child) {
    return makeTestableWidget2(
      Theme(
        data: DesignSystemTheme.dark(),
        child: Scaffold(
          body: SizedBox(width: 700, height: 900, child: child),
        ),
      ),
      mediaQueryData: const MediaQueryData(size: Size(800, 1000)),
    );
  }

  group('ProjectDetailPane', () {
    testWidgets('renders project title and category tag', (tester) async {
      final record = makeTestProjectRecord();

      await tester.pumpWidget(
        wrap(ProjectDetailPane(record: record, currentTime: testCurrentTime)),
      );
      await tester.pump();

      expect(find.text('Test Project'), findsOneWidget);
      expect(find.text('Work'), findsOneWidget);
    });

    testWidgets('renders health panel with score', (tester) async {
      final record = makeTestProjectRecord(healthScore: 85);

      await tester.pumpWidget(
        wrap(ProjectDetailPane(record: record, currentTime: testCurrentTime)),
      );
      await tester.pump();

      expect(find.text('Health Score'), findsOneWidget);
      expect(find.text('85'), findsOneWidget);
    });

    testWidgets('renders AI summary section', (tester) async {
      final record = makeTestProjectRecord(
        aiSummary: 'Project is on track.',
      );

      await tester.pumpWidget(
        wrap(ProjectDetailPane(record: record, currentTime: testCurrentTime)),
      );
      await tester.pump();

      expect(find.text('AI Report'), findsOneWidget);
      expect(find.text('Project is on track.'), findsOneWidget);
    });

    testWidgets('renders recommendations', (tester) async {
      final record = makeTestProjectRecord(
        recommendations: ['Fix bug A', 'Add test B'],
      );

      await tester.pumpWidget(
        wrap(ProjectDetailPane(record: record, currentTime: testCurrentTime)),
      );
      await tester.pump();

      expect(find.text('Recommendations'), findsOneWidget);
      expect(find.text('Fix bug A'), findsOneWidget);
      expect(find.text('Add test B'), findsOneWidget);
    });

    testWidgets('renders task and review panels', (tester) async {
      final record = makeTestProjectRecord(
        highlightedTaskSummaries: [makeTestTaskSummary()],
        reviewSessions: [
          makeTestReviewSession(),
        ],
      );

      await tester.pumpWidget(
        wrap(ProjectDetailPane(record: record, currentTime: testCurrentTime)),
      );
      await tester.pump();

      expect(find.text('Project Tasks'), findsOneWidget);
      expect(find.text('One-on-one Reviews'), findsOneWidget);
    });

    testWidgets('renders updated hours ago label', (tester) async {
      final record = makeTestProjectRecord(
        reportUpdatedAt: DateTime(2026, 4, 2, 7, 30),
      );

      await tester.pumpWidget(
        wrap(ProjectDetailPane(record: record, currentTime: testCurrentTime)),
      );
      await tester.pump();

      expect(find.textContaining('2'), findsAtLeastNWidgets(1));
    });

    testWidgets('renders target date when present', (tester) async {
      final record = makeTestProjectRecord(
        project: makeTestProject(
          id: 'p1',
          title: 'Dated',
          categoryId: 'cat-1',
          targetDate: DateTime(2026, 4, 15),
        ),
      );

      await tester.pumpWidget(
        wrap(ProjectDetailPane(record: record, currentTime: testCurrentTime)),
      );
      await tester.pump();

      expect(find.text('Apr 15, 2026'), findsOneWidget);
    });

    testWidgets('renders status pill', (tester) async {
      final record = makeTestProjectRecord();

      await tester.pumpWidget(
        wrap(ProjectDetailPane(record: record, currentTime: testCurrentTime)),
      );
      await tester.pump();

      // Status pill in large mode shows unfold icon
      expect(find.byIcon(Icons.unfold_more_rounded), findsOneWidget);
    });

    testWidgets('renders description section', (tester) async {
      final record = makeTestProjectRecord(
        project: makeTestProject(id: 'p1', title: 'Test', categoryId: 'cat-1'),
      );

      await tester.pumpWidget(
        wrap(ProjectDetailPane(record: record, currentTime: testCurrentTime)),
      );
      await tester.pump();

      expect(find.text('Description'), findsOneWidget);
    });
  });
}
