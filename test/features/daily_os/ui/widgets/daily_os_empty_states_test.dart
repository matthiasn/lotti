import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os/ui/widgets/daily_os_empty_states.dart';

import '../../../../test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testDate = DateTime(2026, 1, 15);

  group('TimelineEmptyState', () {
    testWidgets('renders empty state message', (tester) async {
      await tester.pumpWidget(
        const RiverpodWidgetTestBench(
          child: SingleChildScrollView(
            child: TimelineEmptyState(),
          ),
        ),
      );
      // Let animation complete
      await tester.pumpAndSettle();

      expect(find.text('No timeline entries'), findsOneWidget);
    });

    testWidgets('renders hint text', (tester) async {
      await tester.pumpWidget(
        const RiverpodWidgetTestBench(
          child: SingleChildScrollView(
            child: TimelineEmptyState(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Start a timer or add planned blocks to see your day.'),
        findsOneWidget,
      );
    });

    testWidgets('animates in on mount', (tester) async {
      await tester.pumpWidget(
        const RiverpodWidgetTestBench(
          child: SingleChildScrollView(
            child: TimelineEmptyState(),
          ),
        ),
      );

      // Initially animating
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(TimelineEmptyState), findsOneWidget);

      // Animation completes
      await tester.pumpAndSettle();
      expect(find.byType(TimelineEmptyState), findsOneWidget);
    });

    testWidgets('renders custom paint illustration', (tester) async {
      await tester.pumpWidget(
        const RiverpodWidgetTestBench(
          child: SingleChildScrollView(
            child: TimelineEmptyState(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CustomPaint), findsWidgets);
    });
  });

  group('BudgetsEmptyState', () {
    testWidgets('renders empty state message', (tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: SingleChildScrollView(
            child: BudgetsEmptyState(date: testDate),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No time budgets'), findsOneWidget);
    });

    testWidgets('renders hint text', (tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: SingleChildScrollView(
            child: BudgetsEmptyState(date: testDate),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Add budgets to track how you spend your time across categories.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders add budget button', (tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: SingleChildScrollView(
            child: BudgetsEmptyState(date: testDate),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add Budget'), findsOneWidget);
    });

    testWidgets('add button is tappable', (tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: SingleChildScrollView(
            child: BudgetsEmptyState(date: testDate),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final buttonFinder = find.text('Add Budget');
      expect(buttonFinder, findsOneWidget);

      // Find the GestureDetector ancestor
      final gestureDetector = find.ancestor(
        of: buttonFinder,
        matching: find.byType(GestureDetector),
      );
      expect(gestureDetector, findsWidgets);
    });

    testWidgets('animates in on mount', (tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: SingleChildScrollView(
            child: BudgetsEmptyState(date: testDate),
          ),
        ),
      );

      // Initially animating
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(BudgetsEmptyState), findsOneWidget);

      // Animation completes
      await tester.pumpAndSettle();
      expect(find.byType(BudgetsEmptyState), findsOneWidget);
    });

    testWidgets('renders donut chart illustration', (tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: SingleChildScrollView(
            child: BudgetsEmptyState(date: testDate),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('renders add icon', (tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: SingleChildScrollView(
            child: BudgetsEmptyState(date: testDate),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    });
  });
}
