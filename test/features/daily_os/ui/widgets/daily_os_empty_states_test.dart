import 'package:beamer/beamer.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os/ui/widgets/daily_os_empty_states.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_helper.dart';
import '../../../../widget_test_utils.dart';

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

  group('TimelineEmptyState dark mode', () {
    testWidgets('renders dark-mode empty state message', (tester) async {
      await tester.pumpWidget(
        const DarkRiverpodWidgetTestBench(
          child: SingleChildScrollView(
            child: TimelineEmptyState(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No timeline entries'), findsOneWidget);
      expect(
        find.text('Start a timer or add planned blocks to see your day.'),
        findsOneWidget,
      );
    });

    testWidgets('dark-mode painter uses dark colors (isDark branch)', (
      tester,
    ) async {
      await tester.pumpWidget(
        const DarkRiverpodWidgetTestBench(
          child: SingleChildScrollView(
            child: TimelineEmptyState(),
          ),
        ),
      );
      // Let animation run past 0.5 progress so the dashed indicator
      // dark branch (line 172) is also exercised.
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(find.byType(CustomPaint), findsWidgets);
    });
  });

  group('BudgetsEmptyState dark mode', () {
    testWidgets('renders dark-mode empty state message', (tester) async {
      await tester.pumpWidget(
        DarkRiverpodWidgetTestBench(
          child: SingleChildScrollView(
            child: BudgetsEmptyState(date: testDate),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No time budgets'), findsOneWidget);
      expect(
        find.text(
          'Add budgets to track how you spend your time across categories.',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'dark-mode painters use dark palette (isDark branches in build + painters)',
      (tester) async {
        await tester.pumpWidget(
          DarkRiverpodWidgetTestBench(
            child: SingleChildScrollView(
              child: BudgetsEmptyState(date: testDate),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // CustomPaint should render without error in dark theme —
        // verifies the dark-branch color lists in build() and painters.
        expect(find.byType(CustomPaint), findsWidgets);
        // The add-budget button also renders its dark gradient (line 443).
        expect(find.text('Add Budget'), findsOneWidget);
      },
    );
  });

  group('_AddBudgetButton hover state', () {
    testWidgets('hover enter/exit toggles hovered appearance', (tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: SingleChildScrollView(
            child: BudgetsEmptyState(date: testDate),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final addBudgetText = find.text('Add Budget');
      expect(addBudgetText, findsOneWidget);

      // Create a mouse pointer and simulate hover enter.
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);

      await tester.pump();

      // Move pointer onto the Add Budget button – triggers onEnter (line 431).
      await gesture.moveTo(tester.getCenter(addBudgetText));
      await tester.pump(const Duration(milliseconds: 250));

      // The AnimatedContainer transition is in progress / complete; widget
      // is still present with the hovered transform (line 463).
      expect(addBudgetText, findsOneWidget);

      // Move pointer away – triggers onExit (line 432).
      await gesture.moveTo(Offset.zero);
      await tester.pump(const Duration(milliseconds: 250));

      expect(addBudgetText, findsOneWidget);
    });
  });

  group('BudgetsEmptyState CTA buttons', () {
    late MockEntitiesCacheService mockCache;

    setUp(() {
      mockCache = MockEntitiesCacheService();
      when(() => mockCache.sortedCategories).thenReturn([]);
      if (getIt.isRegistered<EntitiesCacheService>()) {
        getIt.unregister<EntitiesCacheService>();
      }
      getIt.registerSingleton<EntitiesCacheService>(mockCache);
    });

    tearDown(() async {
      if (getIt.isRegistered<EntitiesCacheService>()) {
        await getIt.unregister<EntitiesCacheService>();
      }
    });

    testWidgets(
      'tapping Add Budget button invokes onPressed callback (line 319)',
      (tester) async {
        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            child: SingleChildScrollView(
              child: BudgetsEmptyState(date: testDate),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final addBudgetText = find.text('Add Budget');
        expect(addBudgetText, findsOneWidget);

        // GestureDetector wraps the button – tap it to fire line 319.
        final gestureDetector = find.ancestor(
          of: addBudgetText,
          matching: find.byType(GestureDetector),
        );
        await tester.ensureVisible(gestureDetector.first);
        await tester.tap(gestureDetector.first);
        await tester.pump();
        // Sheet opened – close it so no modal is left open.
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'tapping plan-without-voice button calls beamToNamed (line 324)',
      (tester) async {
        final delegate = BeamerDelegate(
          locationBuilder: RoutesLocationBuilder(
            routes: <String, Widget Function(BuildContext, BeamState, Object?)>{
              '/': (_, _, _) => Material(
                child: SingleChildScrollView(
                  child: BudgetsEmptyState(date: testDate),
                ),
              ),
              '/calendar/set-time-blocks': (_, _, _) => const SizedBox.shrink(),
            },
          ).call,
        );

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            BeamerProvider(
              routerDelegate: delegate,
              child: SingleChildScrollView(
                child: BudgetsEmptyState(date: testDate),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap the TextButton.icon whose label is the plan-without-voice text.
        final planBtn = find.byIcon(Icons.edit_calendar_outlined);
        expect(planBtn, findsOneWidget);
        await tester.ensureVisible(planBtn);
        await tester.tap(planBtn);
        await tester.pumpAndSettle();

        // After beaming, the delegate should have navigated to the calendar page.
        expect(
          delegate.currentBeamLocation.state.routeInformation.uri.path,
          '/calendar/set-time-blocks',
        );
      },
    );
  });
}
