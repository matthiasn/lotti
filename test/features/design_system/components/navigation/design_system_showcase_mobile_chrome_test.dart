import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/navigation/design_system_showcase_mobile_chrome.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Widget wrap(Widget child, {required ThemeData theme}) {
    return makeTestableWidget2(
      Theme(
        data: theme,
        child: Scaffold(body: Center(child: child)),
      ),
    );
  }

  BoxDecoration frameDecoration(WidgetTester tester) {
    final box = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(DesignSystemShowcaseMobileShell),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    return box.decoration as BoxDecoration;
  }

  group('DesignSystemShowcaseMobileShell', () {
    testWidgets('renders the fixed 402×874 phone frame', (tester) async {
      // The frame is taller than the default 800×600 test viewport.
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        wrap(
          const DesignSystemShowcaseMobileShell(child: SizedBox.shrink()),
          theme: DesignSystemTheme.dark(),
        ),
      );

      expect(
        tester.getSize(find.byType(DesignSystemShowcaseMobileShell)),
        const Size(402, 874),
      );
    });

    testWidgets('light theme uses level01 frame with decorative border', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const DesignSystemShowcaseMobileShell(child: SizedBox.shrink()),
          theme: DesignSystemTheme.light(),
        ),
      );

      final decoration = frameDecoration(tester);
      expect(decoration.color, dsTokensLight.colors.background.level01);
      expect(
        decoration.border!.top.color,
        dsTokensLight.colors.decorative.level02,
      );
    });

    testWidgets('dark theme uses level03 frame with black border', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const DesignSystemShowcaseMobileShell(child: SizedBox.shrink()),
          theme: DesignSystemTheme.dark(),
        ),
      );

      final decoration = frameDecoration(tester);
      expect(decoration.color, dsTokensDark.colors.background.level03);
      expect(
        decoration.border!.top.color,
        Colors.black.withValues(alpha: 0.6),
      );
    });

    testWidgets('screen background defaults to level01 and is overridable', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const DesignSystemShowcaseMobileShell(child: Text('Screen')),
          theme: DesignSystemTheme.dark(),
        ),
      );

      BoxDecoration screenDecoration() {
        // Nearest DecoratedBox above the screen child is the screen surface.
        final inner = tester.widget<DecoratedBox>(
          find
              .ancestor(
                of: find.text('Screen'),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        return inner.decoration as BoxDecoration;
      }

      expect(
        screenDecoration().color,
        dsTokensDark.colors.background.level01,
      );

      await tester.pumpWidget(
        wrap(
          const DesignSystemShowcaseMobileShell(
            backgroundColor: Colors.purple,
            child: Text('Screen'),
          ),
          theme: DesignSystemTheme.dark(),
        ),
      );

      expect(screenDecoration().color, Colors.purple);
    });
  });

  group('DesignSystemShowcaseMobileStatusBar', () {
    testWidgets('renders clock and status icons tinted with the theme', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const DesignSystemShowcaseMobileStatusBar(),
          theme: DesignSystemTheme.dark(),
        ),
      );

      final clock = tester.widget<Text>(find.text('9:41'));
      expect(clock.style?.color, dsTokensDark.colors.text.highEmphasis);

      for (final icon in [
        Icons.signal_cellular_alt_rounded,
        Icons.wifi_rounded,
        Icons.battery_full_rounded,
      ]) {
        expect(
          tester.widget<Icon>(find.byIcon(icon)).color,
          dsTokensDark.colors.text.highEmphasis,
          reason: '$icon',
        );
      }
    });

    testWidgets('foregroundColor overrides the default tint', (tester) async {
      await tester.pumpWidget(
        wrap(
          const DesignSystemShowcaseMobileStatusBar(
            foregroundColor: Colors.amber,
          ),
          theme: DesignSystemTheme.dark(),
        ),
      );

      expect(
        tester.widget<Text>(find.text('9:41')).style?.color,
        Colors.amber,
      );
      expect(
        tester.widget<Icon>(find.byIcon(Icons.wifi_rounded)).color,
        Colors.amber,
      );
    });
  });

  group('DesignSystemShowcaseMobileHomeIndicator', () {
    testWidgets('renders the 175×5 pill at 40% opacity of the tint', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const DesignSystemShowcaseMobileHomeIndicator(
            foregroundColor: Colors.white,
          ),
          theme: DesignSystemTheme.dark(),
        ),
      );

      final indicator = find.byType(DesignSystemShowcaseMobileHomeIndicator);
      expect(tester.getSize(indicator), const Size(175, 5));

      final container = tester.widget<Container>(
        find.descendant(of: indicator, matching: find.byType(Container)),
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, Colors.white.withValues(alpha: 0.4));
    });
  });
}
