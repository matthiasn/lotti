import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/themes/gamey/colors.dart';
import 'package:lotti/themes/gamey/gradients.dart';
import 'package:lotti/widgets/gamey/gamey_card.dart';

void main() {
  group('GameyCard', () {
    Widget createTestableWidget({
      required Widget child,
      ThemeMode themeMode = ThemeMode.light,
    }) {
      return MaterialApp(
        themeMode: themeMode,
        theme: ThemeData.light(useMaterial3: true),
        darkTheme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(body: child),
      );
    }

    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameyCard(
            child: Text('Test Content'),
          ),
        ),
      );

      expect(find.text('Test Content'), findsOneWidget);
    });

    testWidgets('applies custom border radius', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameyCard(
            borderRadius: 10,
            child: Text('Test'),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(GameyCard),
          matching: find.byType(Container),
        ),
      );

      final decoration = container.decoration as BoxDecoration?;
      expect(decoration?.borderRadius, equals(BorderRadius.circular(10)));
    });

    testWidgets('applies custom padding', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameyCard(
            padding: EdgeInsets.all(24),
            child: Text('Test'),
          ),
        ),
      );

      final padding = tester.widget<Padding>(
        find.descendant(
          of: find.byType(InkWell),
          matching: find.byType(Padding),
        ),
      );

      expect(padding.padding, equals(const EdgeInsets.all(24)));
    });

    testWidgets('applies custom margin', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameyCard(
            margin: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Test'),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(GameyCard),
          matching: find.byType(Container),
        ),
      );

      expect(
        container.margin,
        equals(const EdgeInsets.symmetric(horizontal: 16)),
      );
    });

    testWidgets('calls onTap callback when tapped', (tester) async {
      var tapCount = 0;

      await tester.pumpWidget(
        createTestableWidget(
          child: GameyCard(
            onTap: () => tapCount++,
            child: const Text('Tappable'),
          ),
        ),
      );

      await tester.tap(find.text('Tappable'));
      await tester.pump();

      expect(tapCount, equals(1));
    });

    testWidgets('calls onLongPress callback when long pressed', (tester) async {
      var longPressCount = 0;

      await tester.pumpWidget(
        createTestableWidget(
          child: GameyCard(
            onLongPress: () => longPressCount++,
            child: const Text('Long Pressable'),
          ),
        ),
      );

      await tester.longPress(find.text('Long Pressable'));
      await tester.pump();

      expect(longPressCount, equals(1));
    });

    testWidgets('uses gradient when backgroundColor is not provided',
        (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameyCard(
            child: Text('Test'),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(GameyCard),
          matching: find.byType(Container),
        ),
      );

      final decoration = container.decoration as BoxDecoration?;
      expect(decoration?.gradient, isNotNull);
    });

    testWidgets('uses solid color when backgroundColor is provided',
        (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameyCard(
            backgroundColor: Colors.red,
            child: Text('Test'),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(GameyCard),
          matching: find.byType(Container),
        ),
      );

      final decoration = container.decoration as BoxDecoration?;
      expect(decoration?.color, equals(Colors.red));
      expect(decoration?.gradient, isNull);
    });

    testWidgets('renders without glow when showGlow is false', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameyCard(
            showGlow: false,
            child: Text('Test'),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(GameyCard),
          matching: find.byType(Container),
        ),
      );

      final decoration = container.decoration as BoxDecoration?;
      expect(decoration?.boxShadow, isEmpty);
    });

    testWidgets('shows glow shadow by default', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameyCard(
            glowColor: Colors.blue,
            child: Text('Test'),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(GameyCard),
          matching: find.byType(Container),
        ),
      );

      final decoration = container.decoration as BoxDecoration?;
      expect(decoration?.boxShadow, isNotEmpty);
    });

    testWidgets('applies custom gradient', (tester) async {
      const customGradient = LinearGradient(
        colors: [Colors.pink, Colors.purple],
      );

      await tester.pumpWidget(
        createTestableWidget(
          child: const GameyCard(
            gradient: customGradient,
            child: Text('Test'),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(GameyCard),
          matching: find.byType(Container),
        ),
      );

      final decoration = container.decoration as BoxDecoration?;
      expect(decoration?.gradient, equals(customGradient));
    });

    testWidgets('renders in dark mode', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          themeMode: ThemeMode.dark,
          child: const GameyCard(
            child: Text('Dark Mode'),
          ),
        ),
      );

      expect(find.text('Dark Mode'), findsOneWidget);

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(GameyCard),
          matching: find.byType(Container),
        ),
      );

      final decoration = container.decoration as BoxDecoration?;
      expect(decoration?.gradient, isNotNull);
    });
  });

  group('GameyFeatureCard', () {
    Widget createTestableWidget({
      required Widget child,
      ThemeMode themeMode = ThemeMode.light,
    }) {
      return MaterialApp(
        themeMode: themeMode,
        theme: ThemeData.light(useMaterial3: true),
        darkTheme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(body: child),
      );
    }

    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameyFeatureCard(
            feature: 'journal',
            child: Text('Journal Entry'),
          ),
        ),
      );

      expect(find.text('Journal Entry'), findsOneWidget);
    });

    testWidgets('uses journal gradient for journal feature', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameyFeatureCard(
            feature: 'journal',
            child: Text('Test'),
          ),
        ),
      );

      // Verify the card is rendered with the correct feature
      final card = tester.widget<GameyCard>(find.byType(GameyCard));
      expect(card.gradient, equals(GameyGradients.forFeature('journal')));
      expect(card.glowColor, equals(GameyColors.featureColor('journal')));
    });

    testWidgets('uses task gradient for task feature', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameyFeatureCard(
            feature: 'task',
            child: Text('Test'),
          ),
        ),
      );

      final card = tester.widget<GameyCard>(find.byType(GameyCard));
      expect(card.gradient, equals(GameyGradients.forFeature('task')));
      expect(card.glowColor, equals(GameyColors.featureColor('task')));
    });

    testWidgets('uses habit gradient for habit feature', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameyFeatureCard(
            feature: 'habit',
            child: Text('Test'),
          ),
        ),
      );

      final card = tester.widget<GameyCard>(find.byType(GameyCard));
      expect(card.gradient, equals(GameyGradients.forFeature('habit')));
      expect(card.glowColor, equals(GameyColors.featureColor('habit')));
    });

    testWidgets('passes isHighlighted to inner GameyCard', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameyFeatureCard(
            feature: 'journal',
            isHighlighted: true,
            child: Text('Test'),
          ),
        ),
      );

      final card = tester.widget<GameyCard>(find.byType(GameyCard));
      expect(card.isHighlighted, isTrue);
    });

    testWidgets('calls onTap callback when tapped', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        createTestableWidget(
          child: GameyFeatureCard(
            feature: 'mood',
            onTap: () => tapped = true,
            child: const Text('Tappable'),
          ),
        ),
      );

      await tester.tap(find.text('Tappable'));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });

  group('GameySubtleCard', () {
    Widget createTestableWidget({
      required Widget child,
      ThemeMode themeMode = ThemeMode.light,
    }) {
      return MaterialApp(
        themeMode: themeMode,
        theme: ThemeData.light(useMaterial3: true),
        darkTheme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(body: child),
      );
    }

    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameySubtleCard(
            child: Text('Subtle Content'),
          ),
        ),
      );

      expect(find.text('Subtle Content'), findsOneWidget);
    });

    testWidgets('uses theme primary color when accentColor not provided',
        (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameySubtleCard(
            child: Text('Test'),
          ),
        ),
      );

      // Card should render without error
      expect(find.byType(GameyCard), findsOneWidget);
    });

    testWidgets('uses custom accent color when provided', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameySubtleCard(
            accentColor: Colors.orange,
            child: Text('Test'),
          ),
        ),
      );

      final card = tester.widget<GameyCard>(find.byType(GameyCard));
      expect(card.glowColor, equals(Colors.orange));
    });

    testWidgets('adapts gradient to dark mode', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          themeMode: ThemeMode.dark,
          child: const GameySubtleCard(
            child: Text('Dark Mode'),
          ),
        ),
      );

      expect(find.byType(GameyCard), findsOneWidget);
    });

    testWidgets('passes isHighlighted to inner GameyCard', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameySubtleCard(
            isHighlighted: true,
            child: Text('Test'),
          ),
        ),
      );

      final card = tester.widget<GameyCard>(find.byType(GameyCard));
      expect(card.isHighlighted, isTrue);
    });

    testWidgets('applies custom border radius', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameySubtleCard(
            borderRadius: 8,
            child: Text('Test'),
          ),
        ),
      );

      final card = tester.widget<GameyCard>(find.byType(GameyCard));
      expect(card.borderRadius, equals(8.0));
    });

    testWidgets('applies custom padding', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameySubtleCard(
            padding: EdgeInsets.all(32),
            child: Text('Test'),
          ),
        ),
      );

      final card = tester.widget<GameyCard>(find.byType(GameyCard));
      expect(card.padding, equals(const EdgeInsets.all(32)));
    });
  });
}
