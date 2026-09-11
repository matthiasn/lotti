import 'dart:ui' show Tristate;

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/semantics.dart' show SemanticsNode;
import 'package:flutter/services.dart'
    show
        KeyDownEvent,
        KeyEvent,
        KeyRepeatEvent,
        KeyUpEvent,
        LogicalKeyboardKey,
        PhysicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/world_chrome_tokens.dart';
import 'package:lotti/features/plaza/ui/plaza_style.dart';
import 'package:lotti/features/plaza/ui/plaza_top_bar.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widget_test_utils.dart';

const _toolbarText = 'Morning walk · Overview · Home';
const _backTip = 'Back';
const _toggleTip = 'Show / hide toolbar';

/// Whether the control published under [tooltip] currently holds focus.
bool _focusIsOn(WidgetTester tester, String tooltip) {
  final focused = tester.binding.focusManager.primaryFocus?.context;
  if (focused == null) return false;
  return find
      .descendant(
        of: find.byTooltip(tooltip),
        matching: find.byWidget(focused.widget),
      )
      .evaluate()
      .isNotEmpty;
}

void main() {
  late int toggles;
  late int exits;

  setUp(() {
    toggles = 0;
    exits = 0;
  });

  Widget host({
    required bool open,
    bool canExit = true,
    bool reduceMotion = false,
  }) => makeTestableWidget2(
    Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: PlazaTopBar(
          open: open,
          onToggle: () => toggles++,
          onExit: canExit ? () => exits++ : null,
          toolbar: const Text(_toolbarText),
        ),
      ),
    ),
    mediaQueryData: MediaQueryData(
      size: const Size(1200, 800),
      disableAnimations: reduceMotion,
    ),
  );

  Finder button(IconData icon) => find.widgetWithIcon(PlazaHudIconButton, icon);

  Color fillOf(WidgetTester tester, IconData icon) => tester
      .widget<ColoredBox>(
        find.descendant(of: button(icon), matching: find.byType(ColoredBox)),
      )
      .color;

  Color inkOf(WidgetTester tester, IconData icon) =>
      tester.widget<Icon>(find.byIcon(icon)).color!;

  // ───────────────────────────────────────────────── the keyboard contract

  test('only T and Esc belong to the toolbar', () {
    expect(PlazaToolbarKey.of(LogicalKeyboardKey.keyT), PlazaToolbarKey.toggle);
    expect(
      PlazaToolbarKey.of(LogicalKeyboardKey.escape),
      PlazaToolbarKey.close,
    );
    for (final key in [
      LogicalKeyboardKey.keyW,
      LogicalKeyboardKey.keyH,
      LogicalKeyboardKey.tab,
      LogicalKeyboardKey.slash,
      LogicalKeyboardKey.backquote,
    ]) {
      expect(
        PlazaToolbarKey.of(key),
        isNull,
        reason: '$key drives the world; the toolbar must not swallow it',
      );
    }
  });

  test('T flips the toolbar; Esc only ever shuts it', () {
    expect(PlazaToolbarKey.toggle.applyTo(open: false), isTrue);
    expect(PlazaToolbarKey.toggle.applyTo(open: true), isFalse);
    expect(
      PlazaToolbarKey.close.applyTo(open: true),
      isFalse,
      reason: 'Esc is the key for getting a thing out of the way',
    );
    expect(
      PlazaToolbarKey.close.applyTo(open: false),
      isFalse,
      reason: 'and pressing it twice must not bring it back',
    );
  });

  test('a held key does not strobe the toolbar', () {
    KeyEvent down(LogicalKeyboardKey key) => KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.keyT,
      logicalKey: key,
      timeStamp: Duration.zero,
    );
    KeyEvent repeat(LogicalKeyboardKey key) => KeyRepeatEvent(
      physicalKey: PhysicalKeyboardKey.keyT,
      logicalKey: key,
      timeStamp: Duration.zero,
    );

    expect(
      PlazaToolbarKey.pressed(down(LogicalKeyboardKey.keyT)),
      PlazaToolbarKey.toggle,
    );
    expect(
      PlazaToolbarKey.pressed(repeat(LogicalKeyboardKey.keyT)),
      isNull,
      reason:
          'holding T would otherwise flip the toolbar once per repeat, '
          'landing wherever the user happened to let go',
    );
    expect(
      PlazaToolbarKey.pressed(
        const KeyUpEvent(
          physicalKey: PhysicalKeyboardKey.keyT,
          logicalKey: LogicalKeyboardKey.keyT,
          timeStamp: Duration.zero,
        ),
      ),
      isNull,
      reason: 'letting go is not a second press',
    );
  });

  // ────────────────────────────────────────── who the keyboard belongs to

  group('key routing', () {
    KeyEvent press(LogicalKeyboardKey key) => KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.tab,
      logicalKey: key,
      timeStamp: Duration.zero,
    );
    PlazaKeyRouting route(
      LogicalKeyboardKey key, {
      required bool worldHasFocus,
      required bool toolbarOpen,
    }) => PlazaKeyRouting.of(
      press(key),
      worldHasFocus: worldHasFocus,
      toolbarOpen: toolbarOpen,
    );

    test('a shut toolbar leaves every key to the world', () {
      for (final key in [
        LogicalKeyboardKey.tab,
        LogicalKeyboardKey.keyW,
        LogicalKeyboardKey.space,
        LogicalKeyboardKey.enter,
        LogicalKeyboardKey.keyH,
      ]) {
        expect(
          route(key, worldHasFocus: true, toolbarOpen: false),
          PlazaKeyRouting.world,
          reason: '$key drives the world for nearly the whole visit',
        );
      }
    });

    test('an open toolbar lends Tab — and only Tab — to the chrome', () {
      expect(
        route(LogicalKeyboardKey.tab, worldHasFocus: true, toolbarOpen: true),
        PlazaKeyRouting.chrome,
        reason: 'this is the only way a keyboard reaches the controls',
      );
      expect(
        route(LogicalKeyboardKey.keyW, worldHasFocus: true, toolbarOpen: true),
        PlazaKeyRouting.world,
        reason: 'the toolbar being open must not stop you walking',
      );
    });

    test('once the chrome holds focus, every press is its own', () {
      for (final key in [
        LogicalKeyboardKey.tab,
        LogicalKeyboardKey.enter,
        LogicalKeyboardKey.space,
        LogicalKeyboardKey.keyW,
      ]) {
        expect(
          route(key, worldHasFocus: false, toolbarOpen: true),
          PlazaKeyRouting.chrome,
          reason: 'the world must not answer $key over a focused control',
        );
      }
    });

    test('the toolbar keys outrank focus, wherever the keyboard is', () {
      // The regression: `T` is advertised in the control legend, and used to
      // stop working the moment you tabbed into the toolbar — which is
      // exactly when you want to put it away again.
      for (final key in [LogicalKeyboardKey.escape, LogicalKeyboardKey.keyT]) {
        for (final worldHasFocus in [true, false]) {
          for (final toolbarOpen in [true, false]) {
            expect(
              route(
                key,
                worldHasFocus: worldHasFocus,
                toolbarOpen: toolbarOpen,
              ),
              PlazaKeyRouting.toolbar,
              reason: '$key with focus $worldHasFocus / open $toolbarOpen',
            );
          }
        }
      }
    });

    test('a key repeat is not a toolbar binding', () {
      // Held keys are how walking works, so repeats reach the routing. Only
      // the first press of `T` may claim the toolbar; otherwise leaning on it
      // strobes the panel and a focused control never gets its own repeats.
      expect(
        PlazaKeyRouting.of(
          const KeyRepeatEvent(
            physicalKey: PhysicalKeyboardKey.keyT,
            logicalKey: LogicalKeyboardKey.keyT,
            timeStamp: Duration.zero,
          ),
          worldHasFocus: false,
          toolbarOpen: true,
        ),
        PlazaKeyRouting.chrome,
      );
    });
  });

  // ───────────────────────────────────────────────────────── what is shown

  testWidgets('a fresh world shows two buttons and nothing else', (
    tester,
  ) async {
    await tester.pumpWidget(host(open: false));
    expect(find.byType(PlazaHudIconButton), findsNWidgets(2));
    expect(find.byTooltip(_backTip), findsOneWidget);
    expect(find.byTooltip(_toggleTip), findsOneWidget);
    expect(
      find.text(_toolbarText),
      findsNothing,
      reason: 'the toolbar is not merely transparent, it is not built',
    );
  });

  testWidgets('the toggle asks the host to flip, and the toolbar follows', (
    tester,
  ) async {
    await tester.pumpWidget(host(open: false));
    await tester.tap(find.byTooltip(_toggleTip));
    expect(toggles, 1);
    expect(
      find.text(_toolbarText),
      findsNothing,
      reason: 'the bar holds no state of its own; the host owns `open`',
    );

    await tester.pumpWidget(host(open: true));
    await tester.pumpAndSettle();
    expect(find.text(_toolbarText), findsOneWidget);

    await tester.tap(find.byTooltip(_toggleTip));
    expect(toggles, 2);
    await tester.pumpWidget(host(open: false));
    await tester.pumpAndSettle();
    expect(find.text(_toolbarText), findsNothing);
  });

  testWidgets('Back leaves, and is absent when there is nowhere to go', (
    tester,
  ) async {
    await tester.pumpWidget(host(open: false));
    await tester.tap(find.byTooltip(_backTip));
    expect(exits, 1);
    expect(toggles, 0, reason: 'the two buttons are not the same target');

    await tester.pumpWidget(host(open: false, canExit: false));
    expect(find.byTooltip(_backTip), findsNothing);
    expect(
      find.byType(PlazaHudIconButton),
      findsOneWidget,
      reason: 'the toggle stands alone in the standalone harness',
    );
  });

  testWidgets('the corner reads as one mirrored pair of arrows', (
    tester,
  ) async {
    IconData glyph(String tooltip) => tester
        .widget<Icon>(
          find.descendant(
            of: find.byTooltip(tooltip),
            matching: find.byType(Icon),
          ),
        )
        .icon!;

    await tester.pumpWidget(host(open: false));
    expect(glyph(_backTip), LottiIcons.back);
    expect(
      glyph(_toggleTip),
      LottiIcons.forward,
      reason: 'the toggle is the mirror of Back, not a window-chrome glyph',
    );
    expect(
      glyph(_backTip).codePoint,
      isNot(glyph(_toggleTip).codePoint),
      reason: 'two buttons that look identical at 18px are one button',
    );

    await tester.pumpWidget(host(open: true));
    await tester.pumpAndSettle();
    expect(
      glyph(_toggleTip),
      LottiIcons.forward,
      reason:
          'the arrow names the button; teal is what says open or shut, '
          'so a flip would leave the pair pointing at each other',
    );
  });

  // ───────────────────────────────────────────────────────────── geometry

  testWidgets('the buttons are a fixed pair that revealing never moves', (
    tester,
  ) async {
    await tester.pumpWidget(host(open: false));
    final back = tester.getRect(button(LottiIcons.back));
    final toggle = tester.getRect(button(LottiIcons.forward));
    final tokens = tester.element(find.byType(PlazaTopBar)).designTokens;

    // What you see is the glass chip; what you have to hit is the tap
    // target around it. A glyph-only control has no label to borrow hit
    // area from, so the floor is not optional.
    expect(
      back.size,
      const Size(TapTargets.minimum, TapTargets.minimum),
      reason: 'the pressable square, not the glass',
    );
    expect(
      tester.getSize(
        find.descendant(
          of: button(LottiIcons.back),
          matching: find.byType(ClipOval),
        ),
      ),
      const Size(ControlSizes.iconChip, ControlSizes.iconChip),
      reason: 'the glass chip stays compact inside the larger target',
    );
    expect(toggle.size, back.size);
    expect(toggle.left - back.right, tokens.spacing.step3);
    expect(toggle.top, back.top, reason: 'one row, top-aligned');

    await tester.pumpWidget(host(open: true));
    await tester.pump(PlazaTopBar.motion ~/ 2);
    expect(tester.getRect(button(LottiIcons.back)), back);
    expect(tester.getRect(button(LottiIcons.forward)), toggle);

    await tester.pumpAndSettle();
    expect(tester.getRect(button(LottiIcons.back)), back);
    expect(
      tester.getRect(button(LottiIcons.forward)),
      toggle,
      reason: 'the toggle must not walk away from the pointer that pressed it',
    );
    expect(
      tester.getRect(find.text(_toolbarText)).left,
      greaterThan(toggle.right),
      reason: 'the toolbar unfolds to the right of the pair, on the same row',
    );
  });

  testWidgets('the toolbar unfolds from the toggle rather than blinking on', (
    tester,
  ) async {
    await tester.pumpWidget(host(open: false));
    await tester.pumpWidget(host(open: true));
    await tester.pump();
    await tester.pump(PlazaTopBar.motion ~/ 2);

    final fading = tester.widget<Opacity>(
      find.ancestor(
        of: find.text(_toolbarText),
        matching: find.byType(Opacity),
      ),
    );
    expect(fading.opacity, greaterThan(0));
    expect(fading.opacity, lessThan(1));
    final midway = tester.getRect(find.text(_toolbarText));

    await tester.pump(PlazaTopBar.motion);
    final settled = tester.getRect(find.text(_toolbarText));
    expect(
      midway.left,
      lessThan(settled.left),
      reason: 'it arrives from the left, where the toggle is',
    );
    expect(
      midway.width,
      lessThan(settled.width),
      reason: 'and widens into place instead of appearing full size',
    );
    expect(
      tester
          .widget<Opacity>(
            find.ancestor(
              of: find.text(_toolbarText),
              matching: find.byType(Opacity),
            ),
          )
          .opacity,
      1,
    );
  });

  // ────────────────────────────────────────────────────────────── the ink

  testWidgets('the toggle wears the brand teal only while open', (
    tester,
  ) async {
    await tester.pumpWidget(host(open: false));
    final tokens = tester.element(find.byType(PlazaTopBar)).designTokens;
    expect(fillOf(tester, LottiIcons.forward), WorldGlass.fill);
    expect(inkOf(tester, LottiIcons.forward), tokens.colors.text.highEmphasis);

    await tester.pumpWidget(host(open: true));
    await tester.pumpAndSettle();
    expect(fillOf(tester, LottiIcons.forward), PlazaStyle.teal);
    expect(
      inkOf(tester, LottiIcons.forward),
      tokens.colors.text.onInteractiveAlert,
      reason: 'white glyph on teal does not read',
    );
    expect(
      fillOf(tester, LottiIcons.back),
      WorldGlass.fill,
      reason: 'Back controls nothing that is showing, so it never lights',
    );
  });

  testWidgets('the glass lifts under the pointer, lit or not', (tester) async {
    await tester.pumpWidget(host(open: false));
    final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await pointer.addPointer(location: Offset.zero);
    addTearDown(pointer.removePointer);
    await tester.pump();

    await pointer.moveTo(tester.getCenter(button(LottiIcons.forward)));
    await tester.pump();
    expect(fillOf(tester, LottiIcons.forward), WorldGlass.fillHover);
    expect(
      fillOf(tester, LottiIcons.back),
      WorldGlass.fill,
      reason: 'only the button under the pointer lifts',
    );

    await tester.pumpWidget(host(open: true));
    await tester.pumpAndSettle();
    expect(fillOf(tester, LottiIcons.forward), PlazaStyle.tealHover);

    await pointer.moveTo(Offset.zero);
    await tester.pump();
    expect(fillOf(tester, LottiIcons.forward), PlazaStyle.teal);
  });

  testWidgets('reduced motion puts the toolbar there in one frame', (
    tester,
  ) async {
    await tester.pumpWidget(host(open: false, reduceMotion: true));
    await tester.pumpWidget(host(open: true, reduceMotion: true));
    await tester.pump();

    // No settle: whatever the first frame drew is all the user ever sees.
    expect(
      tester
          .widget<Opacity>(
            find.ancestor(
              of: find.text(_toolbarText),
              matching: find.byType(Opacity),
            ),
          )
          .opacity,
      1,
      reason: 'a reveal nobody asked to watch has no midpoint',
    );
    final arrived = tester.getRect(find.text(_toolbarText));

    await tester.pumpWidget(host(open: false, reduceMotion: true));
    await tester.pump();
    expect(find.text(_toolbarText), findsNothing);

    // The same reveal with motion allowed is demonstrably not there yet.
    await tester.pumpWidget(host(open: false));
    await tester.pumpWidget(host(open: true));
    await tester.pump();
    await tester.pump(PlazaTopBar.motion ~/ 2);
    expect(
      tester.getRect(find.text(_toolbarText)).width,
      lessThan(arrived.width),
    );
    await tester.pumpAndSettle();
  });

  testWidgets(
    'the blur survives the reveal instead of snapping on at the end',
    (
      tester,
    ) async {
      await tester.pumpWidget(host(open: false));
      await tester.pumpWidget(host(open: true));
      await tester.pump();
      await tester.pump(PlazaTopBar.motion ~/ 2);

      // An Opacity layer is a save layer, and a BackdropFilter inside one has
      // no backdrop to sample. Mid-reveal the filter must therefore sit above
      // every Opacity in the panel, not below one.
      final filter = find.descendant(
        of: find.byType(PlazaTopBar),
        matching: find.byType(BackdropFilter),
      );
      expect(
        find.ancestor(of: filter.last, matching: find.byType(Opacity)),
        findsNothing,
        reason: 'a blur nested in an opacity layer renders flat, then pops',
      );
      expect(
        find.descendant(of: filter.last, matching: find.byType(Opacity)),
        findsOneWidget,
        reason: 'the fade belongs to the contents, under the filter',
      );
    },
  );

  testWidgets('a screen reader is told whether the toolbar is showing', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    SemanticsNode node(String tooltip) =>
        tester.getSemantics(find.byTooltip(tooltip));

    await tester.pumpWidget(host(open: false));
    expect(node(_toggleTip).label, _toggleTip, reason: 'an icon has no name');
    expect(node(_toggleTip).flagsCollection.isButton, isTrue);
    expect(
      node(_toggleTip).flagsCollection.isToggled,
      Tristate.isFalse,
      reason: 'a closed toolbar is an off toggle, not an absent one',
    );

    await tester.pumpWidget(host(open: true));
    await tester.pumpAndSettle();
    expect(
      node(_toggleTip).flagsCollection.isToggled,
      Tristate.isTrue,
      reason: 'teal is no answer to a screen reader',
    );
    expect(
      node(_backTip).flagsCollection.isToggled,
      Tristate.none,
      reason: 'Back toggles nothing, so it must not announce an off state',
    );
    semantics.dispose();
  });

  testWidgets('the pair is reachable and pressable without a pointer', (
    tester,
  ) async {
    await tester.pumpWidget(host(open: false));

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(
      tester.binding.focusManager.primaryFocus?.context,
      isNotNull,
      reason: 'Tab has to land somewhere for any of this to matter',
    );

    // Walk the traversal order until Back has focus, then press it.
    var guard = 0;
    while (!_focusIsOn(tester, _backTip) && guard++ < 8) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(
      _focusIsOn(tester, _backTip),
      isTrue,
      reason: 'Back is a button; Tab must be able to get to it',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(exits, 1, reason: 'Enter activates a focused button');

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(exits, 2, reason: 'and so does Space');
    expect(toggles, 0, reason: 'the press went to the focused button alone');
  });

  testWidgets('a focused button wears a ring, and says so', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(host(open: false));

    /// The colour of the focus ring drawn over [icon]'s glass.
    Color ringOf(IconData icon) => tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: button(icon),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .map((decoration) => decoration.border)
        .whereType<BoxBorder>()
        .single
        .top
        .color;

    expect(
      ringOf(LottiIcons.forward),
      Colors.transparent,
      reason: 'an unfocused button is bare glass',
    );

    var guard = 0;
    while (!_focusIsOn(tester, _toggleTip) && guard++ < 8) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(_focusIsOn(tester, _toggleTip), isTrue);

    final tokens = tester.element(find.byType(PlazaTopBar)).designTokens;
    expect(
      ringOf(LottiIcons.forward),
      tokens.colors.interactive.enabled,
      reason: 'a keyboard user has to be able to see where they are',
    );
    expect(
      tester.getSemantics(find.byTooltip(_toggleTip)).flagsCollection.isFocused,
      Tristate.isTrue,
      reason: 'the ring is for eyes; this is the same news for everyone else',
    );

    // A lit button is already wearing the interactive teal, so the ring has
    // to leave it: teal on teal is no ring at all, and focus would vanish at
    // the exact moment the toolbar it opens is on screen.
    await tester.pumpWidget(host(open: true));
    await tester.pumpAndSettle();
    expect(_focusIsOn(tester, _toggleTip), isTrue, reason: 'focus survives');
    expect(
      ringOf(LottiIcons.forward),
      tokens.colors.text.onInteractiveAlert,
      reason: 'the ring on a lit button is the ink, not the fill it sits on',
    );
    expect(
      ringOf(LottiIcons.forward),
      isNot(tokens.colors.interactive.enabled),
    );
    semantics.dispose();
  });

  // ──────────────────────────────────────────────── the street underneath

  testWidgets('a hidden toolbar takes neither space nor pointers', (
    tester,
  ) async {
    var street = 0;
    var tools = 0;
    Widget scene({required bool open}) => makeTestableWidget2(
      Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => street++,
              ),
            ),
            Align(
              alignment: Alignment.topLeft,
              child: PlazaTopBar(
                open: open,
                onToggle: () {},
                toolbar: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => tools++,
                  child: const SizedBox(width: 420, height: 72),
                ),
              ),
            ),
          ],
        ),
      ),
      mediaQueryData: const MediaQueryData(size: Size(1200, 800)),
    );

    await tester.pumpWidget(scene(open: true));
    await tester.pumpAndSettle();
    final over = tester.getCenter(find.byType(SizedBox).last);
    await tester.tapAt(over);
    expect((tools, street), (1, 0));

    await tester.pumpWidget(scene(open: false));
    await tester.pump(PlazaTopBar.motion ~/ 2);
    await tester.tapAt(over);
    expect(
      (tools, street),
      (1, 1),
      reason:
          'a toolbar on its way out must not eat the drag that dismissed it',
    );

    await tester.pumpAndSettle();
    await tester.tapAt(over);
    expect((tools, street), (1, 2));
  });
}
