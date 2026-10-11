import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_timer_pill.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('DesignSystemTimerPill.formatElapsed', () {
    test('mm:ss under an hour, hh:mm:ss from then on, without the '
        'fraction', () {
      String f(Duration d) => DesignSystemTimerPill.formatElapsed(d);
      expect(f(const Duration(seconds: 42, milliseconds: 730)), '00:42');
      expect(f(const Duration(minutes: 59, seconds: 59)), '59:59');
      expect(f(const Duration(hours: 1, minutes: 2, seconds: 3)), '01:02:03');
      expect(f(const Duration(hours: 12)), '12:00:00');
    });
  });

  final calls = <String>[];
  setUp(calls.clear);

  Future<void> pump(
    WidgetTester tester, {
    required bool running,
    String label = '00:09',
    String? widthLabel,
    String? stopSemanticLabel = 'Stop timer',
    bool enabled = true,
    ThemeData? theme,
  }) => tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      Center(
        child: DesignSystemTimerPill(
          running: running,
          label: label,
          widthLabel: widthLabel,
          semanticLabel: running ? 'Open timer' : 'Track time',
          semanticValue: running ? '9 seconds' : null,
          stopSemanticLabel: stopSemanticLabel,
          onTap: enabled ? () => calls.add('body') : null,
          onStop: enabled ? () => calls.add('stop') : null,
        ),
      ),
      theme: theme,
    ),
  );

  BoxDecoration fillOf(WidgetTester tester) =>
      tester
              .widget<Container>(
                find
                    .descendant(
                      of: find.byType(DesignSystemTimerPill),
                      matching: find.byType(Container),
                    )
                    .first,
              )
              .decoration!
          as BoxDecoration;

  for (final theme in [DesignSystemTheme.light, DesignSystemTheme.dark]) {
    testWidgets('idle it is the accent with its glyph; running, the alert red '
        'with a white stop glyph and white time (${theme().brightness})', (
      tester,
    ) async {
      await pump(tester, running: false, label: 'Track time', theme: theme());
      final tokens = tester
          .element(find.byType(DesignSystemTimerPill))
          .designTokens;
      expect(fillOf(tester).color, tokens.colors.interactive.enabled);
      expect(find.byIcon(LottiIcons.timer), findsOneWidget);
      expect(
        find.byKey(DesignSystemTimerPill.defaultStopKey),
        findsNothing,
      );

      await pump(tester, running: true, theme: theme());
      expect(fillOf(tester).color, tokens.colors.alert.error.defaultColor);
      final glyph = tester.widget<Icon>(find.byIcon(LottiIconsFilled.square));
      expect(glyph.color, Colors.white);
      expect(
        tester.widget<Text>(find.text('00:09')).style?.color,
        Colors.white,
      );
    });
  }

  testWidgets('running, the stop circle sits concentric in the round end', (
    tester,
  ) async {
    await pump(tester, running: true);
    final pill = tester.getRect(find.byType(DesignSystemTimerPill));
    final circle = tester.getRect(
      find.byKey(DesignSystemTimerPill.defaultStopKey),
    );
    final top = circle.top - pill.top;
    expect(circle.left - pill.left, closeTo(top, 0.5));
    expect(pill.bottom - circle.bottom, closeTo(top, 0.5));
  });

  testWidgets('the body and the stop circle are separate taps', (
    tester,
  ) async {
    await pump(tester, running: true);
    await tester.tap(find.text('00:09'));
    await tester.tap(find.byKey(DesignSystemTimerPill.defaultStopKey));
    expect(calls, ['body', 'stop']);
  });

  testWidgets('held to its idle width: it never shrinks when it starts, nor '
      'grows as the time ticks under the hour', (tester) async {
    await pump(tester, running: false, label: 'Track time');
    final idle = tester.getSize(find.byType(DesignSystemTimerPill)).width;
    await pump(tester, running: true, widthLabel: 'Track time');
    expect(
      tester.getSize(find.byType(DesignSystemTimerPill)).width,
      greaterThanOrEqualTo(idle - 0.5),
    );

    await pump(
      tester,
      running: true,
      widthLabel: DesignSystemTimerPill.elapsedWidthTemplate,
    );
    final early = tester.getSize(find.byType(DesignSystemTimerPill)).width;
    await pump(
      tester,
      running: true,
      label: '59:59',
      widthLabel: DesignSystemTimerPill.elapsedWidthTemplate,
    );
    expect(
      tester.getSize(find.byType(DesignSystemTimerPill)).width,
      closeTo(early, 0.5),
    );
  });

  testWidgets('a reader hears the body by its name and value, and the stop '
      'circle as its own button — or, unnamed, as part of the one button', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, running: true);
    expect(find.bySemanticsLabel('Open timer'), findsOneWidget);
    expect(find.bySemanticsLabel('Stop timer'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(DesignSystemTimerPill)).value,
      '9 seconds',
    );

    semantics.dispose();
  });

  testWidgets('with the stop circle unnamed, the pill is one button', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, running: true, stopSemanticLabel: null);
    final node = tester.getSemantics(find.byType(DesignSystemTimerPill));
    expect(node.label, 'Open timer');
    expect(node.childrenCount, 0, reason: 'no second button inside');
    semantics.dispose();
  });

  testWidgets('without callbacks nothing takes a tap', (tester) async {
    await pump(tester, running: true, enabled: false);
    await tester.tap(find.text('00:09'), warnIfMissed: false);
    await tester.tap(
      find.byKey(DesignSystemTimerPill.defaultStopKey),
      warnIfMissed: false,
    );
    expect(calls, isEmpty);
  });
}
