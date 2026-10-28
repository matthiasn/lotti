import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/legacy_material_bridge.dart';
import 'package:lotti/widgets/selection/unified_toggle.dart';
import 'package:material_ui/material_ui.dart';

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
            builder: LegacyMaterialBridge.builder,
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
        // Every material variant shares FormSwitch's inactive styling.
        final outline = Theme.of(context).colorScheme.outline;
        expect(switchWidget.inactiveThumbColor, outline);
        expect(
          switchWidget.inactiveTrackColor,
          outline.withValues(alpha: 51 / 255),
        );
      });
    }

    testWidgets('renders cupertino variant as CupertinoSwitch', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: LegacyMaterialBridge.builder,
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
    testWidgets('toggle changes value when tapped', (
      WidgetTester tester,
    ) async {
      var value = false;

      await tester.pumpWidget(
        MaterialApp(
          builder: LegacyMaterialBridge.builder,
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
          builder: LegacyMaterialBridge.builder,
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
          builder: LegacyMaterialBridge.builder,
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

  group('UnifiedAiToggleField', () {
    testWidgets(
      "has the settings selector's frame without a fill of its own, and the "
      'frame does not change '
      'with the value',
      (WidgetTester tester) async {
        Future<BoxDecoration> frame({required bool value}) async {
          await tester.pumpWidget(
            MaterialApp(
              builder: LegacyMaterialBridge.builder,
              theme: ThemeData.light().copyWith(
                extensions: const [dsTokensLight],
              ),
              home: Scaffold(
                body: UnifiedAiToggleField(
                  label: 'AI Feature',
                  value: value,
                  onChanged: (_) {},
                ),
              ),
            ),
          );
          final container = tester.widget<Container>(
            find
                .descendant(
                  of: find.byType(UnifiedAiToggleField),
                  matching: find.byType(Container),
                )
                .first,
          );
          return container.decoration! as BoxDecoration;
        }

        final off = await frame(value: false);
        // No fill of its own: the surrounding card's surface shows through.
        expect(off.color, isNull);
        expect(off.borderRadius, BorderRadius.circular(dsTokensLight.radii.m));
        expect(
          tester.widget<UnifiedToggle>(find.byType(UnifiedToggle)).variant,
          UnifiedToggleVariant.normal,
        );

        final on = await frame(value: true);
        expect(on.border, off.border);
        expect(on.color, off.color);
      },
    );

    testWidgets('reflects the initial value on the inner toggle', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: LegacyMaterialBridge.builder,
          theme: ThemeData.light().copyWith(
            extensions: const [dsTokensLight],
          ),
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
          builder: LegacyMaterialBridge.builder,
          theme: ThemeData.light().copyWith(
            extensions: const [dsTokensLight],
          ),
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
          builder: LegacyMaterialBridge.builder,
          theme: ThemeData.light().copyWith(
            extensions: const [dsTokensLight],
          ),
          home: Scaffold(
            body: UnifiedAiToggleField(
              label: 'AI Feature',
              icon: LottiIcons.aiSpark,
              value: value,
              onChanged: (newValue) {
                value = newValue;
              },
            ),
          ),
        ),
      );

      expect(find.byIcon(LottiIcons.aiSpark), findsOneWidget);
    });

    testWidgets(
      'the icon shares the headline row and the description runs full '
      'width beneath it',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            builder: LegacyMaterialBridge.builder,
            theme: ThemeData.light().copyWith(
              extensions: const [dsTokensLight],
            ),
            home: Scaffold(
              body: UnifiedAiToggleField(
                label: 'AI Feature',
                description: 'Enable AI assistance',
                icon: LottiIcons.aiSpark,
                value: false,
                onChanged: (_) {},
              ),
            ),
          ),
        );

        final icon = tester.getRect(find.byIcon(LottiIcons.aiSpark));
        final label = tester.getRect(find.text('AI Feature'));
        final description = tester.getRect(find.text('Enable AI assistance'));
        expect(description.left, lessThan(icon.right));
        expect(description.left, lessThan(label.left));
        expect(description.top, greaterThanOrEqualTo(icon.bottom));
      },
    );

    testWidgets('tap toggles value', (WidgetTester tester) async {
      var value = false;

      await tester.pumpWidget(
        MaterialApp(
          builder: LegacyMaterialBridge.builder,
          theme: ThemeData.light().copyWith(
            extensions: const [dsTokensLight],
          ),
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
        MaterialApp(
          builder: LegacyMaterialBridge.builder,
          theme: ThemeData.light().copyWith(
            extensions: const [dsTokensLight],
          ),
          home: const Scaffold(
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
          builder: LegacyMaterialBridge.builder,
          theme: ThemeData.light().copyWith(
            extensions: const [dsTokensLight],
          ),
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
