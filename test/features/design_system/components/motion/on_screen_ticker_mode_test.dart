import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/motion/on_screen_ticker_mode.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  const top = ValueKey('top');
  const bottom = ValueKey('bottom');

  bool animating(WidgetTester tester, Key key) => TickerMode.valuesOf(
    tester.element(find.byKey(key, skipOffstage: false)),
  ).enabled;

  /// A resident scroll column: one gated child on screen, one far below the
  /// fold — both mounted, as an eagerly built page keeps them.
  Widget column({
    required Map<Key, List<bool>> transitions,
    bool tabVisible = true,
  }) => MaterialApp(
    home: TickerMode(
      enabled: tabVisible,
      child: SingleChildScrollView(
        child: Column(
          children: [
            OnScreenTickerMode(
              onVisibilityChanged: (v) => transitions[top]!.add(v),
              child: const SizedBox(key: top, height: 100),
            ),
            const SizedBox(height: 3000),
            OnScreenTickerMode(
              onVisibilityChanged: (v) => transitions[bottom]!.add(v),
              child: const SizedBox(key: bottom, height: 100),
            ),
          ],
        ),
      ),
    ),
  );

  Map<Key, List<bool>> fresh() => {top: [], bottom: []};

  testWidgets('animates what is on screen and holds what is below the fold, '
      'flipping both as they scroll', (tester) async {
    final transitions = fresh();
    await tester.pumpWidget(column(transitions: transitions));
    await tester.pump();

    expect(animating(tester, top), isTrue);
    expect(animating(tester, bottom), isFalse);

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -3000),
    );
    await tester.pumpAndSettle();

    expect(animating(tester, top), isFalse);
    expect(animating(tester, bottom), isTrue);
    // Each transition reported once; the never-shown state never reported.
    expect(transitions[top], [true, false]);
    expect(transitions[bottom], [true]);
  });

  testWidgets('a hidden tab keeps everything still, even what would be on '
      'screen', (tester) async {
    final transitions = fresh();
    await tester.pumpWidget(
      column(transitions: transitions, tabVisible: false),
    );
    await tester.pump();

    expect(animating(tester, top), isFalse);
    expect(transitions[top], isEmpty);

    // The tab comes forward: what is on screen starts, without a scroll.
    await tester.pumpWidget(column(transitions: transitions));
    await tester.pump();

    expect(animating(tester, top), isTrue);
    expect(transitions[top], [true]);
  });

  testWidgets('a backgrounded app counts as hidden until it resumes', (
    tester,
  ) async {
    final transitions = fresh();
    await tester.pumpWidget(column(transitions: transitions));
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(transitions[top], [true, false]);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(transitions[top], [true, false, true]);
    expect(animating(tester, top), isTrue);
  });

  testWidgets('outside any scroll view, mounted on a visible tab means on '
      'screen — but never on its very first frame', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: OnScreenTickerMode(child: SizedBox(key: top)),
      ),
    );

    // The first layout-safe sample is after the frame.
    expect(animating(tester, top), isFalse);
    await tester.pump();
    expect(animating(tester, top), isTrue);
  });
}
