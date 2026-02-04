import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/theming/state/theming_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/widgets/gamey/gamey_fab.dart';

import '../../widget_test_utils.dart';

void main() {
  setUp(() async {
    ensureThemingServicesRegistered();
  });

  tearDown(() async {
    await getIt.reset();
  });

  Widget createTestableWidget({
    required Widget child,
    bool isGameyTheme = false,
    ThemeMode themeMode = ThemeMode.light,
  }) {
    return ProviderScope(
      overrides: [
        themingControllerProvider.overrideWith(
          () => ThemingControllerTestNotifier(isGameyTheme: isGameyTheme),
        ),
      ],
      child: MaterialApp(
        themeMode: themeMode,
        theme: ThemeData.light(useMaterial3: true),
        darkTheme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: const Center(child: Text('Content')),
          floatingActionButton: child,
        ),
      ),
    );
  }

  group('GameyFab - Standard FAB (non-gamey theme)', () {
    testWidgets('renders FloatingActionButton when not gamey theme',
        (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: GameyFab(
            onPressed: () {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('renders default add icon when no child provided',
        (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: GameyFab(
            onPressed: () {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('renders custom child widget when provided', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: GameyFab(
            onPressed: () {},
            child: const Icon(Icons.edit),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.edit), findsOneWidget);
      expect(find.byIcon(Icons.add), findsNothing);
    });

    testWidgets('calls onPressed callback when tapped', (tester) async {
      var tapCount = 0;

      await tester.pumpWidget(
        createTestableWidget(
          child: GameyFab(
            onPressed: () => tapCount++,
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();

      expect(tapCount, equals(1));
    });

    testWidgets('applies semanticLabel as tooltip', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: GameyFab(
            onPressed: () {},
            semanticLabel: 'Add new item',
          ),
        ),
      );

      await tester.pumpAndSettle();

      final fab = tester
          .widget<FloatingActionButton>(find.byType(FloatingActionButton));
      expect(fab.tooltip, equals('Add new item'));
    });
  });

  group('GameyFab - Gamey styled FAB', () {
    testWidgets('renders gamey image FAB when gamey theme is active',
        (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          isGameyTheme: true,
          child: GameyFab(
            onPressed: () {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should not render standard FAB
      expect(find.byType(FloatingActionButton), findsNothing);
      // Should render the gamey FAB with GestureDetector
      expect(find.byType(GestureDetector), findsOneWidget);
    });

    testWidgets('has Semantics widget with button: true', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          isGameyTheme: true,
          child: GameyFab(
            onPressed: () {},
            semanticLabel: 'Create new entry',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify the semantics label is rendered by finding the GestureDetector
      // that contains the gamey FAB
      expect(find.byType(GestureDetector), findsOneWidget);

      // Check that the widget with semantic label exists via bySemanticsLabel
      expect(
        find.bySemanticsLabel('Create new entry'),
        findsOneWidget,
      );
    });

    testWidgets('calls onPressed exactly once when tapped', (tester) async {
      var tapCount = 0;

      await tester.pumpWidget(
        createTestableWidget(
          isGameyTheme: true,
          child: GameyFab(
            onPressed: () => tapCount++,
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byType(GestureDetector));
      await tester.pump();

      expect(tapCount, equals(1));
    });

    testWidgets('handles tap down and up states', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          isGameyTheme: true,
          child: GameyFab(
            onPressed: () {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Start tap
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(GestureDetector)),
      );
      await tester.pump();

      // Release
      await gesture.up();
      await tester.pump();

      // Should still render correctly
      expect(find.byType(GestureDetector), findsOneWidget);
    });

    testWidgets('handles tap cancel', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          isGameyTheme: true,
          child: GameyFab(
            onPressed: () {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Start tap then cancel
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(GestureDetector)),
      );
      await tester.pump();

      await gesture.cancel();
      await tester.pump();

      // Should still render correctly
      expect(find.byType(GestureDetector), findsOneWidget);
    });

    testWidgets('renders container with fixed size', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          isGameyTheme: true,
          child: GameyFab(
            onPressed: () {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find Container that is a descendant of GestureDetector
      final containerFinder = find.descendant(
        of: find.byType(GestureDetector),
        matching: find.byType(Container),
      );

      expect(containerFinder, findsWidgets);

      // Get the first container that has constraints
      final containers = tester.widgetList<Container>(containerFinder);
      final containerWithSize = containers.firstWhere(
        (c) => c.constraints?.maxWidth == 64.0,
        orElse: () => containers.first,
      );

      expect(containerWithSize.constraints?.maxWidth, equals(64.0));
      expect(containerWithSize.constraints?.maxHeight, equals(64.0));
    });
  });
}

/// A test notifier that allows controlling the gamey theme state
class ThemingControllerTestNotifier extends ThemingController {
  ThemingControllerTestNotifier({this.isGameyTheme = false});

  final bool isGameyTheme;

  @override
  ThemingState build() {
    // gameyThemeName is '🎮 Gamey' - must match exactly for isGameyTheme() check
    return ThemingState(
      lightThemeName: isGameyTheme ? '🎮 Gamey' : 'Blue Whale',
      darkThemeName: isGameyTheme ? '🎮 Gamey' : 'Blue Whale',
    );
  }
}
