import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/projects/ui/widgets/project_detail_pane.dart';
import 'package:lotti/l10n/app_localizations.dart';

import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

void main() {
  final testCurrentTime = DateTime(2026, 4, 2, 9, 30);

  Widget wrap(
    Widget child, {
    Locale? locale,
    double width = 700,
    Size viewportSize = const Size(800, 1000),
  }) {
    final themedChild = Theme(
      data: DesignSystemTheme.dark(),
      child: Scaffold(
        body: SizedBox(width: width, height: 900, child: child),
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
      mediaQueryData: MediaQueryData(size: viewportSize),
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

      final l10n = AppLocalizations.of(
        tester.element(find.byType(ProjectDetailPane)),
      )!;
      expect(
        find.text(l10n.projectShowcaseUpdatedHoursAgo(2)),
        findsOneWidget,
      );
    });

    testWidgets('renders updated minutes ago label for sub-hour delta', (
      tester,
    ) async {
      final record = makeTestProjectRecord(
        reportUpdatedAt: DateTime(2026, 4, 2, 9, 15),
      );

      await tester.pumpWidget(
        wrap(ProjectDetailPane(record: record, currentTime: testCurrentTime)),
      );
      await tester.pump();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(ProjectDetailPane)),
      )!;
      expect(
        find.text(l10n.projectShowcaseUpdatedMinutesAgo(15)),
        findsOneWidget,
      );
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

    testWidgets('renders target date using the active locale format', (
      tester,
    ) async {
      final targetDate = DateTime(2026, 4, 15);
      final record = makeTestProjectRecord(
        project: makeTestProject(
          id: 'p1',
          title: 'Dated',
          categoryId: 'cat-1',
          targetDate: targetDate,
        ),
      );

      await tester.pumpWidget(
        wrap(
          ProjectDetailPane(record: record, currentTime: testCurrentTime),
          locale: const Locale('de'),
        ),
      );
      await tester.pump();

      expect(
        find.text(DateFormat.yMMMd('de').format(targetDate)),
        findsOneWidget,
      );
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

    testWidgets('does not overflow with long project titles', (tester) async {
      final record = makeTestProjectRecord(
        project: makeTestProject(
          id: 'p1',
          title:
              'A very long project title that should be truncated before it collides with the trailing menu icon in the detail header',
          categoryId: 'cat-1',
        ),
      );

      await tester.pumpWidget(
        wrap(
          ProjectDetailPane(record: record, currentTime: testCurrentTime),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
