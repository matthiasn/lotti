import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:showcaseview/showcaseview.dart';

// Simple showcase widget implementation for testing
class SimpleShowcase extends StatelessWidget {
  const SimpleShowcase({
    required this.showcaseKey,
    required this.child,
    required this.description,
    this.startNav = false,
    this.endNav = false,
    super.key,
  });

  final GlobalKey showcaseKey;
  final Widget child;
  final bool startNav;
  final bool endNav;
  final Widget description;

  @override
  Widget build(BuildContext context) {
    return Showcase.withWidget(
      key: showcaseKey,
      height: 150,
      width: 300,
      targetShapeBorder: const CircleBorder(),
      targetPadding: const EdgeInsets.all(8),
      container: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade100,
            child: description,
          ),
          if (startNav)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton(
                  onPressed: () {
                    ShowCaseWidget.of(context).dismiss();
                  },
                  child: const Text('close'),
                ),
                OutlinedButton(
                  onPressed: () {
                    ShowCaseWidget.of(context).next();
                  },
                  child: const Text('next'),
                ),
              ],
            )
          else if (endNav)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton(
                  onPressed: () {
                    ShowCaseWidget.of(context).previous();
                  },
                  child: const Text('Previous'),
                ),
                OutlinedButton(
                  onPressed: () {
                    ShowCaseWidget.of(context).dismiss();
                  },
                  child: const Text('close'),
                ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton(
                  onPressed: () {
                    ShowCaseWidget.of(context).previous();
                  },
                  child: const Text('Previous'),
                ),
                OutlinedButton(
                  onPressed: () {
                    ShowCaseWidget.of(context).next();
                  },
                  child: const Text('Next'),
                ),
              ],
            ),
        ],
      ),
      child: child,
    );
  }
}

class ThemingPageTest extends StatefulWidget {
  const ThemingPageTest({super.key});

  @override
  State<ThemingPageTest> createState() => _ThemingPageTestState();
}

class _ThemingPageTestState extends State<ThemingPageTest> {
  final _themeModeSelectorKey = GlobalKey();
  final _lightThemeKey = GlobalKey();
  final _darkThemeKey = GlobalKey();
  Set<int> _selectedThemeMode = {1}; // 0: Dark, 1: System, 2: Light

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Theming'),
        actions: [
          IconButton(
            onPressed: () {
              ShowCaseWidget.of(context).startShowCase([
                _themeModeSelectorKey,
                _lightThemeKey,
                _darkThemeKey,
              ]);
            },
            icon: const Icon(Icons.info_outline_rounded),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SimpleShowcase(
              showcaseKey: _themeModeSelectorKey,
              startNav: true,
              description: const Text(
                'Choose your preferred theme mode: dark, system, or light.',
              ),
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Dark')),
                  ButtonSegment(value: 1, label: Text('System')),
                  ButtonSegment(value: 2, label: Text('Light')),
                ],
                selected: _selectedThemeMode,
                onSelectionChanged: (Set<int> newSelection) {
                  setState(() {
                    _selectedThemeMode = newSelection;
                  });
                },
              ),
            ),
            const SizedBox(height: 24),
            SimpleShowcase(
              showcaseKey: _lightThemeKey,
              description: const Text('Select your preferred light theme.'),
              child: const TextField(
                decoration: InputDecoration(
                  labelText: 'Light Theme',
                  border: OutlineInputBorder(),
                ),
                readOnly: true,
              ),
            ),
            const SizedBox(height: 24),
            SimpleShowcase(
              showcaseKey: _darkThemeKey,
              endNav: true,
              description: const Text('Select your preferred dark theme.'),
              child: const TextField(
                decoration: InputDecoration(
                  labelText: 'Dark Theme',
                  border: OutlineInputBorder(),
                ),
                readOnly: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  testWidgets('Theming page showcase functionality', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ShowCaseWidget(
          builder: (context) => const ThemingPageTest(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Find the info icon
    final infoIcon = find.byIcon(Icons.info_outline_rounded);
    expect(infoIcon, findsOneWidget);

    // Tap the info icon to start the showcase
    await tester.tap(infoIcon);
    await tester.pumpAndSettle();

    // Verify first showcase is visible
    expect(
      find.text('Choose your preferred theme mode: dark, system, or light.'),
      findsOneWidget,
    );
    expect(find.text('next'), findsOneWidget);
    expect(find.text('close'), findsOneWidget);

    // Navigate to next showcase
    await tester.tap(find.text('next'));
    await tester.pumpAndSettle();

    // Verify second showcase is visible
    expect(find.text('Select your preferred light theme.'), findsOneWidget);

    // Navigate to next showcase
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Verify third showcase is visible
    expect(find.text('Select your preferred dark theme.'), findsOneWidget);
    expect(find.text('close'), findsOneWidget);

    // Close showcase
    await tester.tap(find.text('close'));
    await tester.pumpAndSettle();

    // Verify showcase is closed
    expect(
      find.text('Select your preferred dark theme.'),
      findsOneWidget,
    ); // Still on screen, but not in showcase
    expect(find.text('Previous'), findsNothing); // Navigation buttons are gone
  });
}
