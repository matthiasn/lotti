import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/projects/ui/model/project_list_detail_models.dart';
import 'package:lotti/features/projects/ui/widgets/review_sessions_panel.dart';

import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

void main() {
  Widget wrap(Widget child) {
    return makeTestableWidget2(
      Theme(
        data: DesignSystemTheme.dark(),
        child: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(width: 400, child: child),
          ),
        ),
      ),
    );
  }

  group('ReviewSessionsPanel', () {
    testWidgets('renders header with title, badge, and session count', (
      tester,
    ) async {
      final record = makeTestProjectRecord(
        reviewSessions: [
          makeTestReviewSession(id: 'r1'),
          makeTestReviewSession(id: 'r2', summaryLabel: 'Week 10 · Mar 3'),
        ],
      );

      await tester.pumpWidget(wrap(ReviewSessionsPanel(record: record)));
      await tester.pump();

      expect(find.text('One-on-one Reviews'), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // count badge
    });

    testWidgets('renders each session summary label', (tester) async {
      final record = makeTestProjectRecord(
        reviewSessions: [
          makeTestReviewSession(
            id: 'r1',
          ),
          makeTestReviewSession(
            id: 'r2',
            summaryLabel: 'Week 10 · Mar 3',
            rating: 5,
          ),
        ],
      );

      await tester.pumpWidget(wrap(ReviewSessionsPanel(record: record)));
      await tester.pump();

      expect(find.text('Week 11 · Mar 10'), findsOneWidget);
      expect(find.text('Week 10 · Mar 3'), findsOneWidget);
    });

    testWidgets('renders empty when no review sessions', (tester) async {
      final record = makeTestProjectRecord();

      await tester.pumpWidget(wrap(ReviewSessionsPanel(record: record)));
      await tester.pump();

      expect(find.text('One-on-one Reviews'), findsOneWidget);
      expect(find.text('0'), findsOneWidget); // count badge
    });
  });

  group('ReviewSessionBlock', () {
    testWidgets('renders summary label and stars', (tester) async {
      const session = ReviewSession(
        id: 'r1',
        summaryLabel: 'Week 5 · Feb 3',
        rating: 4,
      );

      await tester.pumpWidget(
        wrap(const ReviewSessionBlock(session: session)),
      );
      await tester.pump();

      expect(find.text('Week 5 · Feb 3'), findsOneWidget);
      // 4 filled + 1 empty = 5 star icons
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(4));
      expect(find.byIcon(Icons.star_border_rounded), findsOneWidget);
    });

    testWidgets('shows expanded metrics and note', (tester) async {
      const session = ReviewSession(
        id: 'r1',
        summaryLabel: 'Week 11',
        rating: 4,
        expanded: true,
        metrics: [
          ReviewMetric(type: ReviewMetricType.communication, rating: 5),
          ReviewMetric(type: ReviewMetricType.accuracy, rating: 3),
        ],
        note: 'Good progress this week.',
      );

      await tester.pumpWidget(
        wrap(const ReviewSessionBlock(session: session)),
      );
      await tester.pump();

      expect(find.text('Communication'), findsOneWidget);
      expect(find.text('Accuracy'), findsOneWidget);
      expect(find.text('Good progress this week.'), findsOneWidget);
    });

    testWidgets('hides metrics when not expanded', (tester) async {
      const session = ReviewSession(
        id: 'r2',
        summaryLabel: 'Week 10',
        rating: 5,
        metrics: [
          ReviewMetric(type: ReviewMetricType.usefulness, rating: 4),
        ],
        note: 'Should be hidden',
      );

      await tester.pumpWidget(
        wrap(const ReviewSessionBlock(session: session)),
      );
      await tester.pump();

      expect(find.text('Week 10'), findsOneWidget);
      expect(find.text('Usefulness'), findsNothing);
      expect(find.text('Should be hidden'), findsNothing);
    });
  });
}
