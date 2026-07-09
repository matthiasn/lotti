import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/misc/sidebar_live_card.dart';

import '../../widget_test_utils.dart';

void main() {
  const accent = Color(0xFF5ED4B7);
  const title = 'A long task title that the row truncates but keeps available';

  bool isCircleDot(Widget w) =>
      w is Container &&
      w.decoration is BoxDecoration &&
      (w.decoration! as BoxDecoration).shape == BoxShape.circle;

  // The pulsing record dot is the only circular-decoration Container in the
  // card, so this uniquely locates it.
  Finder recordDot() => find.byWidgetPredicate(isCircleDot);

  // The pulse wraps the dot directly in a FadeTransition; matching on the
  // direct child avoids the app/Tooltip FadeTransitions higher in the tree.
  Finder pulseFade() => find.byWidgetPredicate(
    (w) => w is FadeTransition && w.child != null && isCircleDot(w.child!),
  );

  Widget build({
    required bool pulse,
    VoidCallback? onTap,
    bool reduceMotion = false,
    bool actionable = true,
  }) {
    return makeTestableWidgetWithScaffold(
      SidebarLiveCard(
        accent: accent,
        glyph: Icons.timer_outlined,
        statusLabel: 'Running timer',
        title: title,
        timeText: '01:35:32',
        pulse: pulse,
        onTap: actionable ? (onTap ?? () {}) : null,
        trailing: const Icon(Icons.stop_rounded),
        semanticsLabel: 'Running timer',
      ),
      mediaQueryData: reduceMotion
          ? phoneMediaQueryData.copyWith(disableAnimations: true)
          : null,
    );
  }

  testWidgets('renders glyph, title, accent-coloured time, and trailing', (
    tester,
  ) async {
    await tester.pumpWidget(build(pulse: false));
    await tester.pump();

    expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
    expect(find.text(title), findsOneWidget);
    expect(find.byIcon(Icons.stop_rounded), findsOneWidget);

    // The elapsed time is rendered in the accent colour (the card's single
    // accent: rail + glyph + time all share it).
    final timeText = tester.widget<Text>(find.text('01:35:32'));
    expect(timeText.style?.color, accent);
  });

  testWidgets('tapping the card body fires onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(build(pulse: false, onTap: () => taps++));
    await tester.pump();

    await tester.tap(find.text('01:35:32'));
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('keyboard focus activates the card body', (tester) async {
    var taps = 0;
    await tester.pumpWidget(build(pulse: false, onTap: () => taps++));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('pulse=false shows no record dot', (tester) async {
    await tester.pumpWidget(build(pulse: false));
    await tester.pump();

    expect(recordDot(), findsNothing);
  });

  testWidgets('pulse=true overlays an animated (FadeTransition) record dot', (
    tester,
  ) async {
    await tester.pumpWidget(build(pulse: true));
    await tester.pump();

    expect(recordDot(), findsOneWidget);
    expect(pulseFade(), findsOneWidget);
    // Advance the repeating pulse a frame so it is exercised, then let the
    // controller dispose with the tree at teardown.
    await tester.pump(const Duration(milliseconds: 120));
  });

  testWidgets('reduce-motion keeps the record dot static (no pulse fade)', (
    tester,
  ) async {
    await tester.pumpWidget(build(pulse: true, reduceMotion: true));
    await tester.pump();

    expect(recordDot(), findsOneWidget);
    expect(pulseFade(), findsNothing);
  });

  testWidgets('exposes actionable card semantics', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(build(pulse: false));
    await tester.pump();

    final node = tester.getSemantics(find.byType(SidebarLiveCard));
    expect(node.label, contains('Running timer'));
    expect(node.value, contains(title));
    expect(node.value, contains('01:35:32'));
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    expect(node.flagsCollection.isButton, isTrue);
    handle.dispose();
  });

  testWidgets('presentational card does not expose button semantics', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(build(pulse: false, actionable: false));
    await tester.pump();

    final node = tester.getSemantics(find.byType(SidebarLiveCard));
    expect(node.label, contains('Running timer'));
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
    expect(node.flagsCollection.isButton, isFalse);

    handle.dispose();
  });
}
