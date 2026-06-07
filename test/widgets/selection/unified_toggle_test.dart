import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/widgets/selection/unified_toggle.dart';

void main() {
  group('UnifiedToggle', () {
    // The material variants differ only in the variant parameter and the
    // expected activeTrackColor — parameterised to avoid copy-paste bodies.
    for (final (variant, colorOf) in [
      (
        UnifiedToggleVariant.normal,
        (BuildContext c) => Theme.of(c).colorScheme.primary,
      ),
      (
        UnifiedToggleVariant.warning,
        (BuildContext c) => Theme.of(c).colorScheme.error,
      ),
      (UnifiedToggleVariant.priority, (BuildContext c) => starredGold),
      (
        UnifiedToggleVariant.archived,
        (BuildContext c) => Theme.of(c).colorScheme.outline,
      ),
    ]) {
      testWidgets('renders $variant with its active track color', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(
              body: UnifiedToggle(
                value: false,
                onChanged: (_) {},
                variant: variant,
              ),
            ),
          ),
        );

        final switchWidget = tester.widget<Switch>(find.byType(Switch));
        expect(switchWidget.value, false);
        final context = tester.element(find.byType(Switch));
        expect(switchWidget.activeTrackColor, colorOf(context));
      });
    }

    testWidgets('renders cupertino variant as CupertinoSwitch', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: UnifiedToggle(
              value: false,
              onChanged: (_) {},
              variant: UnifiedToggleVariant.cupertino,
            ),
          ),
        ),
      );

      expect(find.byType(CupertinoSwitch), findsOneWidget);
      expect(find.byType(Switch), findsNothing);
      expect(
        tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch)).value,
        false,
      );
    });
    testWidgets('UnifiedToggleField renders with title and subtitle', (
      WidgetTester tester,
    ) async {
      var value = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: UnifiedToggleField(
              value: value,
              onChanged: (newValue) {
                value = newValue;
              },
              title: 'Test Toggle',
              subtitle: 'This is a test description',
            ),
          ),
        ),
      );

      expect(find.text('Test Toggle'), findsOneWidget);
      expect(find.text('This is a test description'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('toggle changes value when tapped', (
      WidgetTester tester,
    ) async {
      var value = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return UnifiedToggle(
                  value: value,
                  onChanged: (newValue) {
                    setState(() {
                      value = newValue;
                    });
                  },
                );
              },
            ),
          ),
        ),
      );

      expect(find.byType(Switch), findsOneWidget);

      // Initial state
      var switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, false);

      // Tap to toggle
      await tester.tap(find.byType(Switch));
      await tester.pump(const Duration(milliseconds: 150));

      // Verify state changed
      switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, true);
    });

    testWidgets('disabled toggle does not respond to taps', (
      WidgetTester tester,
    ) async {
      const value = false;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UnifiedToggle(
              value: value,
              onChanged: null, // Disabled
              enabled: false,
            ),
          ),
        ),
      );

      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.onChanged, null);
    });

    testWidgets('custom active color overrides variant color', (
      WidgetTester tester,
    ) async {
      const customColor = Colors.purple;
      var value = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: UnifiedToggle(
              value: value,
              onChanged: (newValue) {
                value = newValue;
              },
              variant: UnifiedToggleVariant.warning,
              activeColor: customColor,
            ),
          ),
        ),
      );

      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.activeTrackColor, customColor);
    });
  });

  group('UnifiedToggleField', () {
    testWidgets('with leading widget', (WidgetTester tester) async {
      var value = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: UnifiedToggleField(
              value: value,
              onChanged: (newValue) {
                value = newValue;
              },
              title: 'Test Toggle',
              leading: const Icon(Icons.settings),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.settings), findsOneWidget);
      expect(find.text('Test Toggle'), findsOneWidget);
    });

    testWidgets('dense layout', (WidgetTester tester) async {
      var value = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: UnifiedToggleField(
              value: value,
              onChanged: (newValue) {
                value = newValue;
              },
              title: 'Dense Toggle',
              dense: true,
            ),
          ),
        ),
      );

      expect(find.text('Dense Toggle'), findsOneWidget);
      // Dense layout will have reduced padding
    });

    testWidgets('tap on field toggles value', (WidgetTester tester) async {
      var value = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return UnifiedToggleField(
                  value: value,
                  onChanged: (newValue) {
                    setState(() {
                      value = newValue;
                    });
                  },
                  title: 'Tap Me',
                );
              },
            ),
          ),
        ),
      );

      expect(value, false);

      // Tap on the text area (not just the switch)
      await tester.tap(find.text('Tap Me'));
      await tester.pump(const Duration(milliseconds: 150));

      expect(value, true);
    });

    // Drives the enabled/disabled text-color branches for both the title
    // (lib lines 252-256) and subtitle (lines 264-268). When disabled, both
    // texts are dimmed to alpha 0.38; when enabled they use the full-strength
    // scheme colors. We assert the real resolved Text style colors here.
    for (final enabled in [true, false]) {
      testWidgets(
        'title/subtitle colors honor enabled=$enabled',
        (WidgetTester tester) async {
          const title = 'Field Title';
          const subtitle = 'Field Subtitle';

          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.light(),
              home: Scaffold(
                body: UnifiedToggleField(
                  value: false,
                  onChanged: enabled ? (_) {} : null,
                  title: title,
                  subtitle: subtitle,
                  enabled: enabled,
                ),
              ),
            ),
          );

          final scheme = Theme.of(
            tester.element(find.text(title)),
          ).colorScheme;

          final titleColor = tester.widget<Text>(find.text(title)).style?.color;
          final subtitleColor = tester
              .widget<Text>(find.text(subtitle))
              .style
              ?.color;

          if (enabled) {
            expect(titleColor, scheme.onSurface);
            expect(subtitleColor, scheme.onSurfaceVariant);
          } else {
            expect(titleColor, scheme.onSurface.withValues(alpha: 0.38));
            expect(
              subtitleColor,
              scheme.onSurfaceVariant.withValues(alpha: 0.38),
            );
          }
        },
      );
    }

    testWidgets('disabled field does not toggle on tap', (
      WidgetTester tester,
    ) async {
      var changed = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: UnifiedToggleField(
              value: false,
              onChanged: (_) => changed = true,
              title: 'Disabled Field',
              enabled: false,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Disabled Field'));
      await tester.pump();

      expect(changed, false);
      // The underlying InkWell is disabled (no onTap).
      final inkWell = tester.widget<InkWell>(find.byType(InkWell));
      expect(inkWell.onTap, isNull);
    });
  });

  group('UnifiedAiToggleField', () {
    testWidgets('renders with AI-specific styling', (
      WidgetTester tester,
    ) async {
      var value = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: UnifiedAiToggleField(
              label: 'AI Feature',
              value: value,
              onChanged: (newValue) {
                value = newValue;
              },
            ),
          ),
        ),
      );

      expect(find.text('AI Feature'), findsOneWidget);
      expect(find.byType(UnifiedToggle), findsOneWidget);

      // Verify it uses normal variant
      final toggle = tester.widget<UnifiedToggle>(find.byType(UnifiedToggle));
      expect(toggle.variant, UnifiedToggleVariant.normal);

      // AI-specific container chrome: gradient backdrop and rounded corners.
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(UnifiedAiToggleField),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.gradient, isA<LinearGradient>());
      expect(decoration.borderRadius, BorderRadius.circular(12));
    });

    testWidgets('reflects the initial value on the inner toggle', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: UnifiedAiToggleField(
              label: 'AI Feature',
              value: true,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      final toggle = tester.widget<UnifiedToggle>(find.byType(UnifiedToggle));
      expect(toggle.value, true);
    });

    testWidgets('with description', (WidgetTester tester) async {
      var value = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: UnifiedAiToggleField(
              label: 'AI Feature',
              description: 'Enable AI assistance',
              value: value,
              onChanged: (newValue) {
                value = newValue;
              },
            ),
          ),
        ),
      );

      expect(find.text('AI Feature'), findsOneWidget);
      expect(find.text('Enable AI assistance'), findsOneWidget);
    });

    testWidgets('with icon', (WidgetTester tester) async {
      var value = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: UnifiedAiToggleField(
              label: 'AI Feature',
              icon: Icons.auto_awesome,
              value: value,
              onChanged: (newValue) {
                value = newValue;
              },
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    });

    testWidgets('tap toggles value', (WidgetTester tester) async {
      var value = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return UnifiedAiToggleField(
                  label: 'AI Feature',
                  value: value,
                  onChanged: (newValue) {
                    setState(() {
                      value = newValue;
                    });
                  },
                );
              },
            ),
          ),
        ),
      );

      expect(value, false);

      await tester.tap(find.text('AI Feature'));
      await tester.pump(const Duration(milliseconds: 150));

      expect(value, true);
    });

    testWidgets('disabled state', (WidgetTester tester) async {
      const value = false;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UnifiedAiToggleField(
              label: 'AI Feature',
              value: value,
              onChanged: null,
              enabled: false,
            ),
          ),
        ),
      );

      final toggle = tester.widget<UnifiedToggle>(find.byType(UnifiedToggle));
      // UnifiedAiToggleField now properly forwards the enabled flag
      expect(toggle.onChanged, null);
      expect(toggle.enabled, false);
    });

    testWidgets('semantic label is properly set', (WidgetTester tester) async {
      var value = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: UnifiedAiToggleField(
              label: 'Enable AI suggestions',
              value: value,
              onChanged: (newValue) {
                value = newValue;
              },
            ),
          ),
        ),
      );

      final toggle = tester.widget<UnifiedToggle>(find.byType(UnifiedToggle));
      expect(toggle.semanticLabel, 'Enable AI suggestions');
    });
  });
}
