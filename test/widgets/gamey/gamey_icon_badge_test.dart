import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/themes/gamey/gradients.dart';
import 'package:lotti/widgets/gamey/gamey_icon_badge.dart';

void main() {
  Widget createTestableWidget({
    required Widget child,
    ThemeMode themeMode = ThemeMode.light,
  }) {
    return MaterialApp(
      themeMode: themeMode,
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(body: Center(child: child)),
    );
  }

  group('GameyIconBadge', () {
    testWidgets('renders icon correctly', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameyIconBadge(
            icon: Icons.star,
          ),
        ),
      );

      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('applies default size', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameyIconBadge(
            icon: Icons.star,
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(GameyIconBadge),
          matching: find.byType(Container).first,
        ),
      );

      expect(container.constraints?.maxWidth, equals(56.0));
      expect(container.constraints?.maxHeight, equals(56.0));
    });

    testWidgets('applies custom size', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameyIconBadge(
            icon: Icons.star,
            size: 80,
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(GameyIconBadge),
          matching: find.byType(Container).first,
        ),
      );

      expect(container.constraints?.maxWidth, equals(80.0));
    });

    testWidgets('applies custom icon size', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameyIconBadge(
            icon: Icons.star,
            iconSize: 30,
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.star));
      expect(icon.size, equals(30.0));
    });

    testWidgets('calculates icon size from badge size when not specified',
        (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameyIconBadge(
            icon: Icons.star,
            size: 100,
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.star));
      // Icon size should be size * 0.45 = 45
      expect(icon.size, equals(45.0));
    });

    testWidgets('applies custom gradient', (tester) async {
      const customGradient = LinearGradient(
        colors: [Colors.red, Colors.orange],
      );

      await tester.pumpWidget(
        createTestableWidget(
          child: const GameyIconBadge(
            icon: Icons.star,
            gradient: customGradient,
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(GameyIconBadge),
          matching: find.byType(Container).first,
        ),
      );

      final decoration = container.decoration as BoxDecoration?;
      expect(decoration?.gradient, isNotNull);
    });

    testWidgets('applies background color when no gradient', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameyIconBadge(
            icon: Icons.star,
            backgroundColor: Colors.purple,
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(GameyIconBadge),
          matching: find.byType(Container).first,
        ),
      );

      final decoration = container.decoration as BoxDecoration?;
      expect(decoration?.color, equals(Colors.purple));
    });

    testWidgets('applies custom icon color', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameyIconBadge(
            icon: Icons.star,
            iconColor: Colors.yellow,
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.star));
      expect(icon.color, equals(Colors.yellow));
    });

    testWidgets('calls onTap callback when tapped', (tester) async {
      var tapCount = 0;

      await tester.pumpWidget(
        createTestableWidget(
          child: GameyIconBadge(
            icon: Icons.star,
            onTap: () => tapCount++,
          ),
        ),
      );

      await tester.tap(
        find.descendant(
          of: find.byType(GameyIconBadge),
          matching: find.byType(InkWell),
        ),
      );
      await tester.pump();

      expect(tapCount, equals(1));
    });

    testWidgets('shows glow shadow by default', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameyIconBadge(
            icon: Icons.star,
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(GameyIconBadge),
          matching: find.byType(Container).first,
        ),
      );

      final decoration = container.decoration as BoxDecoration?;
      expect(decoration?.boxShadow, isNotNull);
      expect(decoration?.boxShadow, isNotEmpty);
    });

    testWidgets('hides glow shadow when showGlow is false', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameyIconBadge(
            icon: Icons.star,
            showGlow: false,
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(GameyIconBadge),
          matching: find.byType(Container).first,
        ),
      );

      final decoration = container.decoration as BoxDecoration?;
      expect(decoration?.boxShadow, isNull);
    });

    testWidgets('applies custom border radius', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameyIconBadge(
            icon: Icons.star,
            borderRadius: 8,
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(GameyIconBadge),
          matching: find.byType(Container).first,
        ),
      );

      final decoration = container.decoration as BoxDecoration?;
      expect(decoration?.borderRadius, equals(BorderRadius.circular(8)));
    });

    testWidgets('starts pulse animation when isPulsing is true',
        (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameyIconBadge(
            icon: Icons.star,
            isPulsing: true,
          ),
        ),
      );

      // Pump a few frames to let animation start
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Widget should render without error
      expect(find.byType(GameyIconBadge), findsOneWidget);
    });

    testWidgets('stops pulse animation when isPulsing changes to false',
        (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameyIconBadge(
            icon: Icons.star,
            isPulsing: true,
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Change isPulsing to false
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameyIconBadge(
            icon: Icons.star,
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(GameyIconBadge), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          themeMode: ThemeMode.dark,
          child: const GameyIconBadge(
            icon: Icons.star,
          ),
        ),
      );

      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('handles tap down and up states', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: GameyIconBadge(
            icon: Icons.star,
            onTap: () {},
          ),
        ),
      );

      // Simulate tap down
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(GameyIconBadge)),
      );
      await tester.pump();

      // Release
      await gesture.up();
      await tester.pump();

      expect(find.byType(GameyIconBadge), findsOneWidget);
    });
  });

  group('GameyFeatureIconBadge', () {
    testWidgets('renders icon correctly', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameyFeatureIconBadge(
            feature: 'journal',
            icon: Icons.book,
          ),
        ),
      );

      expect(find.byIcon(Icons.book), findsOneWidget);
    });

    testWidgets('uses journal gradient for journal feature', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameyFeatureIconBadge(
            feature: 'journal',
            icon: Icons.book,
          ),
        ),
      );

      final iconBadge =
          tester.widget<GameyIconBadge>(find.byType(GameyIconBadge));
      expect(iconBadge.gradient, equals(GameyGradients.forFeature('journal')));
    });

    testWidgets('uses habit gradient for habit feature', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameyFeatureIconBadge(
            feature: 'habit',
            icon: Icons.repeat,
          ),
        ),
      );

      final iconBadge =
          tester.widget<GameyIconBadge>(find.byType(GameyIconBadge));
      expect(iconBadge.gradient, equals(GameyGradients.forFeature('habit')));
    });

    testWidgets('uses task gradient for task feature', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameyFeatureIconBadge(
            feature: 'task',
            icon: Icons.check,
          ),
        ),
      );

      final iconBadge =
          tester.widget<GameyIconBadge>(find.byType(GameyIconBadge));
      expect(iconBadge.gradient, equals(GameyGradients.forFeature('task')));
    });

    testWidgets('applies custom size', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameyFeatureIconBadge(
            feature: 'journal',
            icon: Icons.book,
            size: 72,
          ),
        ),
      );

      final iconBadge =
          tester.widget<GameyIconBadge>(find.byType(GameyIconBadge));
      expect(iconBadge.size, equals(72.0));
    });

    testWidgets('passes isPulsing to inner badge', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameyFeatureIconBadge(
            feature: 'journal',
            icon: Icons.book,
            isPulsing: true,
          ),
        ),
      );

      final iconBadge =
          tester.widget<GameyIconBadge>(find.byType(GameyIconBadge));
      expect(iconBadge.isPulsing, isTrue);
    });

    testWidgets('passes isActive to inner badge', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameyFeatureIconBadge(
            feature: 'journal',
            icon: Icons.book,
            isActive: true,
          ),
        ),
      );

      final iconBadge =
          tester.widget<GameyIconBadge>(find.byType(GameyIconBadge));
      expect(iconBadge.isActive, isTrue);
    });

    testWidgets('calls onTap callback', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        createTestableWidget(
          child: GameyFeatureIconBadge(
            feature: 'journal',
            icon: Icons.book,
            onTap: () => tapped = true,
          ),
        ),
      );

      await tester.tap(
        find.descendant(
          of: find.byType(GameyFeatureIconBadge),
          matching: find.byType(InkWell),
        ),
      );
      await tester.pump();

      expect(tapped, isTrue);
    });
  });

  group('GameyCircleIconBadge', () {
    testWidgets('renders icon correctly', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameyCircleIconBadge(
            icon: Icons.add,
          ),
        ),
      );

      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('uses circular border radius (size / 2)', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameyCircleIconBadge(
            icon: Icons.add,
          ),
        ),
      );

      final iconBadge =
          tester.widget<GameyIconBadge>(find.byType(GameyIconBadge));
      expect(iconBadge.borderRadius, equals(24.0)); // size / 2
    });

    testWidgets('applies default size of 48', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameyCircleIconBadge(
            icon: Icons.add,
          ),
        ),
      );

      final iconBadge =
          tester.widget<GameyIconBadge>(find.byType(GameyIconBadge));
      expect(iconBadge.size, equals(48.0));
    });

    testWidgets('applies custom gradient', (tester) async {
      const customGradient = LinearGradient(
        colors: [Colors.green, Colors.teal],
      );

      await tester.pumpWidget(
        createTestableWidget(
          child: const GameyCircleIconBadge(
            icon: Icons.add,
            gradient: customGradient,
          ),
        ),
      );

      final iconBadge =
          tester.widget<GameyIconBadge>(find.byType(GameyIconBadge));
      expect(iconBadge.gradient, equals(customGradient));
    });

    testWidgets('applies background color', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameyCircleIconBadge(
            icon: Icons.add,
            backgroundColor: Colors.amber,
          ),
        ),
      );

      final iconBadge =
          tester.widget<GameyIconBadge>(find.byType(GameyIconBadge));
      expect(iconBadge.backgroundColor, equals(Colors.amber));
    });

    testWidgets('passes all props to inner GameyIconBadge', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameyCircleIconBadge(
            icon: Icons.add,
            iconColor: Colors.white,
            size: 60,
            iconSize: 30,
            showGlow: false,
            isPulsing: true,
            isActive: true,
          ),
        ),
      );

      final iconBadge =
          tester.widget<GameyIconBadge>(find.byType(GameyIconBadge));
      expect(iconBadge.iconColor, equals(Colors.white));
      expect(iconBadge.size, equals(60.0));
      expect(iconBadge.iconSize, equals(30.0));
      expect(iconBadge.showGlow, isFalse);
      expect(iconBadge.isPulsing, isTrue);
      expect(iconBadge.isActive, isTrue);
      expect(iconBadge.borderRadius, equals(30.0)); // size / 2 = 30
    });
  });
}
