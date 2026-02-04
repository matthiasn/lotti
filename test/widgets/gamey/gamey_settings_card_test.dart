import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/themes/gamey/colors.dart';
import 'package:lotti/widgets/gamey/gamey_card.dart';
import 'package:lotti/widgets/gamey/gamey_icon_badge.dart';
import 'package:lotti/widgets/gamey/gamey_settings_card.dart';

void main() {
  Widget createTestableWidget({
    required Widget child,
    ThemeMode themeMode = ThemeMode.light,
  }) {
    return MaterialApp(
      themeMode: themeMode,
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );
  }

  group('GameySettingsCard', () {
    testWidgets('renders title correctly', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameySettingsCard(
            title: 'Settings Title',
          ),
        ),
      );

      expect(find.text('Settings Title'), findsOneWidget);
    });

    testWidgets('renders subtitle when provided', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameySettingsCard(
            title: 'Title',
            subtitle: 'Subtitle text',
          ),
        ),
      );

      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Subtitle text'), findsOneWidget);
    });

    testWidgets('does not render subtitle when not provided', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameySettingsCard(
            title: 'Title Only',
          ),
        ),
      );

      expect(find.text('Title Only'), findsOneWidget);
      // Only one text widget should be present
      expect(find.byType(Text), findsWidgets);
    });

    testWidgets('renders icon when provided', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameySettingsCard(
            title: 'With Icon',
            icon: Icons.settings,
          ),
        ),
      );

      expect(find.byIcon(Icons.settings), findsOneWidget);
      expect(find.byType(GameyIconBadge), findsOneWidget);
    });

    testWidgets('does not render icon badge when icon not provided',
        (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameySettingsCard(
            title: 'No Icon',
          ),
        ),
      );

      expect(find.byType(GameyIconBadge), findsNothing);
    });

    testWidgets('renders trailing widget when provided', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameySettingsCard(
            title: 'With Trailing',
            trailing: Icon(Icons.arrow_forward),
          ),
        ),
      );

      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    });

    testWidgets('renders chevron when onTap provided and no trailing',
        (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: GameySettingsCard(
            title: 'Tappable',
            onTap: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('does not render chevron when trailing provided',
        (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: GameySettingsCard(
            title: 'With Trailing',
            trailing: const Icon(Icons.check),
            onTap: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.chevron_right), findsNothing);
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('calls onTap callback when tapped', (tester) async {
      var tapCount = 0;

      await tester.pumpWidget(
        createTestableWidget(
          child: GameySettingsCard(
            title: 'Tappable',
            onTap: () => tapCount++,
          ),
        ),
      );

      await tester.tap(find.byType(GameySettingsCard));
      await tester.pump();

      expect(tapCount, equals(1));
    });

    testWidgets('uses custom accent color when provided', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameySettingsCard(
            title: 'Custom Accent',
            accentColor: Colors.orange,
          ),
        ),
      );

      final subtleCard =
          tester.widget<GameySubtleCard>(find.byType(GameySubtleCard));
      expect(subtleCard.accentColor, equals(Colors.orange));
    });

    testWidgets('uses gamey accent color by default', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameySettingsCard(
            title: 'Default Accent',
          ),
        ),
      );

      final subtleCard =
          tester.widget<GameySubtleCard>(find.byType(GameySubtleCard));
      expect(subtleCard.accentColor, equals(GameyColors.gameyAccent));
    });

    testWidgets('renders in dark mode', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          themeMode: ThemeMode.dark,
          child: const GameySettingsCard(
            title: 'Dark Mode Card',
            icon: Icons.dark_mode,
          ),
        ),
      );

      expect(find.text('Dark Mode Card'), findsOneWidget);
      expect(find.byIcon(Icons.dark_mode), findsOneWidget);
    });
  });

  group('GameySettingsSection', () {
    testWidgets('renders section title', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameySettingsSection(
            title: 'Section Title',
            children: [
              GameySettingsCard(title: 'Card 1'),
              GameySettingsCard(title: 'Card 2'),
            ],
          ),
        ),
      );

      expect(find.text('Section Title'), findsOneWidget);
    });

    testWidgets('renders all children', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameySettingsSection(
            title: 'Section',
            children: [
              GameySettingsCard(title: 'Card 1'),
              GameySettingsCard(title: 'Card 2'),
              GameySettingsCard(title: 'Card 3'),
            ],
          ),
        ),
      );

      expect(find.text('Card 1'), findsOneWidget);
      expect(find.text('Card 2'), findsOneWidget);
      expect(find.text('Card 3'), findsOneWidget);
    });

    testWidgets('applies custom accent color to title', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameySettingsSection(
            title: 'Colored Section',
            accentColor: Colors.red,
            children: [
              GameySettingsCard(title: 'Card'),
            ],
          ),
        ),
      );

      final titleText = tester.widget<Text>(find.text('Colored Section'));
      expect(titleText.style?.color, equals(Colors.red));
    });

    testWidgets('applies custom padding', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameySettingsSection(
            title: 'Padded Section',
            padding: EdgeInsets.all(32),
            children: [
              GameySettingsCard(title: 'Card'),
            ],
          ),
        ),
      );

      final padding = tester.widget<Padding>(
        find
            .descendant(
              of: find.byType(GameySettingsSection),
              matching: find.byType(Padding),
            )
            .first,
      );

      expect(padding.padding, equals(const EdgeInsets.all(32)));
    });
  });

  group('GameyToggleCard', () {
    testWidgets('renders title correctly', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: GameyToggleCard(
            title: 'Toggle Title',
            value: false,
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.text('Toggle Title'), findsOneWidget);
    });

    testWidgets('renders subtitle when provided', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: GameyToggleCard(
            title: 'Toggle',
            subtitle: 'Toggle description',
            value: false,
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.text('Toggle description'), findsOneWidget);
    });

    testWidgets('renders switch widget', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: GameyToggleCard(
            title: 'Toggle',
            value: false,
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('switch reflects value prop', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: GameyToggleCard(
            title: 'Toggle',
            value: true,
            onChanged: (_) {},
          ),
        ),
      );

      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, isTrue);
    });

    testWidgets('calls onChanged when switch is toggled', (tester) async {
      bool? newValue;

      await tester.pumpWidget(
        createTestableWidget(
          child: GameyToggleCard(
            title: 'Toggle',
            value: false,
            onChanged: (value) => newValue = value,
          ),
        ),
      );

      await tester.tap(find.byType(Switch));
      await tester.pump();

      expect(newValue, isTrue);
    });

    testWidgets('calls onChanged when card is tapped', (tester) async {
      bool? newValue;

      await tester.pumpWidget(
        createTestableWidget(
          child: GameyToggleCard(
            title: 'Toggle',
            value: false,
            onChanged: (value) => newValue = value,
          ),
        ),
      );

      await tester.tap(find.byType(GameyToggleCard));
      await tester.pump();

      expect(newValue, isTrue);
    });

    testWidgets('renders icon when provided', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: GameyToggleCard(
            title: 'Toggle with Icon',
            icon: Icons.notifications,
            value: true,
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.byIcon(Icons.notifications), findsOneWidget);
      expect(find.byType(GameyIconBadge), findsOneWidget);
    });

    testWidgets('icon badge has glow when value is true', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: GameyToggleCard(
            title: 'Toggle',
            icon: Icons.notifications,
            value: true,
            onChanged: (_) {},
          ),
        ),
      );

      final iconBadge =
          tester.widget<GameyIconBadge>(find.byType(GameyIconBadge));
      expect(iconBadge.showGlow, isTrue);
    });

    testWidgets('icon badge has no glow when value is false', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: GameyToggleCard(
            title: 'Toggle',
            icon: Icons.notifications,
            value: false,
            onChanged: (_) {},
          ),
        ),
      );

      final iconBadge =
          tester.widget<GameyIconBadge>(find.byType(GameyIconBadge));
      expect(iconBadge.showGlow, isFalse);
    });

    testWidgets('uses grey accent when value is false', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: GameyToggleCard(
            title: 'Toggle',
            value: false,
            onChanged: (_) {},
          ),
        ),
      );

      final subtleCard =
          tester.widget<GameySubtleCard>(find.byType(GameySubtleCard));
      expect(subtleCard.accentColor, equals(Colors.grey));
    });

    testWidgets('uses gamey accent when value is true', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: GameyToggleCard(
            title: 'Toggle',
            value: true,
            onChanged: (_) {},
          ),
        ),
      );

      final subtleCard =
          tester.widget<GameySubtleCard>(find.byType(GameySubtleCard));
      expect(subtleCard.accentColor, equals(GameyColors.gameyAccent));
    });

    testWidgets('uses custom accent color when provided and value is true',
        (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: GameyToggleCard(
            title: 'Toggle',
            value: true,
            accentColor: Colors.purple,
            onChanged: (_) {},
          ),
        ),
      );

      final subtleCard =
          tester.widget<GameySubtleCard>(find.byType(GameySubtleCard));
      expect(subtleCard.accentColor, equals(Colors.purple));
    });
  });

  group('GameyListTile', () {
    testWidgets('renders title correctly', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameyListTile(
            title: 'List Tile Title',
          ),
        ),
      );

      expect(find.text('List Tile Title'), findsOneWidget);
    });

    testWidgets('renders subtitle when provided', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameyListTile(
            title: 'Title',
            subtitle: 'Subtitle text',
          ),
        ),
      );

      expect(find.text('Subtitle text'), findsOneWidget);
    });

    testWidgets('renders leading widget when provided', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameyListTile(
            title: 'With Leading',
            leading: Icon(Icons.person),
          ),
        ),
      );

      expect(find.byIcon(Icons.person), findsOneWidget);
    });

    testWidgets('renders trailing widget when provided', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameyListTile(
            title: 'With Trailing',
            trailing: Icon(Icons.arrow_forward),
          ),
        ),
      );

      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    });

    testWidgets('calls onTap callback when tapped', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        createTestableWidget(
          child: GameyListTile(
            title: 'Tappable',
            onTap: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.byType(GameyListTile));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('applies custom accent color to inkwell', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: GameyListTile(
            title: 'Custom Accent',
            accentColor: Colors.teal,
            onTap: () {},
          ),
        ),
      );

      final inkWell = tester.widget<InkWell>(find.byType(InkWell));
      expect(inkWell.splashColor, equals(Colors.teal.withValues(alpha: 0.1)));
    });

    testWidgets('uses border radius of 16', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: const GameyListTile(
            title: 'Rounded',
          ),
        ),
      );

      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(GameyListTile),
          matching: find.byType(Material),
        ),
      );

      expect(material.borderRadius, equals(BorderRadius.circular(16)));
    });
  });
}
