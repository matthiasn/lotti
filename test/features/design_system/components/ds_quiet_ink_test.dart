import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/ds_quiet_ink.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  /// The builder's `highlighted` flag rendered as a probe: teal when
  /// highlighted, black at rest — so tests assert the state the content
  /// would actually paint with.
  Widget probe({VoidCallback? onTap}) => DsQuietInk(
    onTap: onTap,
    builder: (context, highlighted) => Text(
      highlighted ? 'highlighted' : 'rest',
      style: TextStyle(
        color: highlighted ? Colors.teal : Colors.black,
      ),
    ),
  );

  group('DsQuietInk', () {
    testWidgets('reports rest state, then highlights on hover and back', (
      tester,
    ) async {
      await tester.pumpWidget(host(probe(onTap: () {})));
      expect(find.text('rest'), findsOneWidget);

      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.byType(DsQuietInk)));
      await tester.pump();
      expect(find.text('highlighted'), findsOneWidget);

      await gesture.moveTo(Offset.zero);
      await tester.pump();
      expect(find.text('rest'), findsOneWidget);
    });

    testWidgets('highlights while keyboard focus rests on the target', (
      tester,
    ) async {
      await tester.pumpWidget(host(probe(onTap: () {})));

      // The nearest enclosing Focus node above the content is the InkWell's
      // own; with focusColor transparent, the builder's ink shift is the only
      // visible focus cue keyboard users get — so it must fire.
      Focus.of(tester.element(find.text('rest'))).requestFocus();
      await tester.pump();

      expect(find.text('highlighted'), findsOneWidget);
    });

    testWidgets('fires onTap and silences every Material overlay', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(host(probe(onTap: () => taps++)));

      await tester.tap(find.byType(DsQuietInk));
      await tester.pump();
      expect(taps, 1);

      // The whole point of the widget: no hover/splash/highlight/focus fill
      // may ever paint, so the phantom-button rectangle cannot appear.
      final inkWell = tester.widget<InkWell>(find.byType(InkWell));
      expect(inkWell.hoverColor, Colors.transparent);
      expect(inkWell.splashColor, Colors.transparent);
      expect(inkWell.highlightColor, Colors.transparent);
      expect(inkWell.focusColor, Colors.transparent);
      expect(
        inkWell.overlayColor?.resolve({WidgetState.hovered}),
        Colors.transparent,
      );
      expect(
        inkWell.overlayColor?.resolve({WidgetState.pressed}),
        Colors.transparent,
      );
    });

    testWidgets('renders inert content without any InkWell when not tappable', (
      tester,
    ) async {
      await tester.pumpWidget(host(probe()));

      expect(find.text('rest'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(DsQuietInk),
          matching: find.byType(InkWell),
        ),
        findsNothing,
      );

      // An inert target must not stall on a stale highlight either — the
      // builder is always handed `false`.
      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.byType(DsQuietInk)));
      await tester.pump();
      expect(find.text('rest'), findsOneWidget);
    });

    testWidgets(
      'highlights for the duration of a press so touch keeps feedback',
      (tester) async {
        await tester.pumpWidget(host(probe(onTap: () {})));

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(DsQuietInk)),
        );
        await tester.pump();
        expect(find.text('highlighted'), findsOneWidget);

        await gesture.up();
        // Let the tap settle and the highlight decay.
        await tester.pumpAndSettle();
        expect(find.text('rest'), findsOneWidget);
      },
    );

    testWidgets('long-press target keeps the quiet contract', (tester) async {
      var longPresses = 0;
      await tester.pumpWidget(
        host(
          DsQuietInk(
            onLongPress: () => longPresses++,
            builder: (context, highlighted) =>
                Text(highlighted ? 'highlighted' : 'rest'),
          ),
        ),
      );

      await tester.longPress(find.byType(DsQuietInk));
      await tester.pumpAndSettle();
      expect(longPresses, 1);
      expect(find.text('rest'), findsOneWidget);
    });

    testWidgets('focusRing outlines keyboard focus only — hover stays as '
        'quiet as the builder made it', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: DesignSystemTheme.dark(),
          home: Scaffold(
            body: Center(
              child: DsQuietInk(
                onTap: () {},
                focusRing: true,
                borderRadius: BorderRadius.circular(8),
                builder: (context, highlighted) => const Text('cell'),
              ),
            ),
          ),
        ),
      );

      Finder ring() => find.ancestor(
        of: find.text('cell'),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is DecoratedBox &&
              widget.position == DecorationPosition.foreground &&
              (widget.decoration as BoxDecoration).border != null,
        ),
      );

      expect(ring(), findsNothing);

      // Hover draws nothing: the pointer path is the builder's business.
      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.byType(DsQuietInk)));
      await tester.pump();
      expect(ring(), findsNothing);
      await gesture.moveTo(Offset.zero);
      await tester.pump();

      // Keyboard focus draws the interactive-ink outline. Real Tab
      // traversal, not requestFocus: after a mouse interaction in the same
      // test a programmatic requestFocus never reaches the InkWell's node.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(ring(), findsOneWidget);
      final tokens = tester.element(find.text('cell')).designTokens;
      final border =
          (tester.widget<DecoratedBox>(ring()).decoration as BoxDecoration)
                  .border!
              as Border;
      expect(border.top.color, tokens.colors.interactive.enabled);
      expect(border.top.width, BorderWidths.emphasis);
    });
  });
}
