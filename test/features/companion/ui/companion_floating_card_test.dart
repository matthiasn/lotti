import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/state/companion_card_controller.dart';
import 'package:lotti/features/companion/ui/companion_floating_card.dart';
import 'package:lotti/features/design_system/components/glass_action_bar.dart';
import 'package:lotti/features/design_system/components/glass_chip_surface.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../widget_test_utils.dart';

/// The area the card floats over, as a conversation's thread gives it.
const _area = Size(390, 600);
const _margin = 16.0;

void main() {
  late TestGetItMocks mocks;
  late int behindTaps;
  late int customizes;
  late int hides;

  setUp(() async {
    mocks = await setUpTestGetIt();
    behindTaps = 0;
    customizes = 0;
    hides = 0;
  });
  tearDown(tearDownTestGetIt);

  final card = find.byKey(CompanionFloatingCardKeys.card);
  Rect cardRect(WidgetTester tester) => tester.getRect(card);
  final aspect = CompanionFloatingCard.aspectRatio;

  Future<void> pumpCard(
    WidgetTester tester, {
    CompanionCardForm form = CompanionCardForm.phone,
    bool speaking = false,
    bool hideable = false,
    Size area = _area,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox.fromSize(
            size: area,
            child: Stack(
              children: [
                Positioned.fill(
                  child: TextButton(
                    onPressed: () => behindTaps++,
                    child: const SizedBox.expand(),
                  ),
                ),
                Positioned.fill(
                  child: CompanionFloatingCard(
                    form: form,
                    speaking: speaking,
                    onCustomize: () => customizes++,
                    onHide: hideable ? () => hides++ : null,
                    figure: const ColoredBox(
                      key: Key('figure'),
                      color: Color(0xFF808080),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    // The saved placement's load.
    await tester.pump();
  }

  Future<void> doubleTap(WidgetTester tester) async {
    await tester.tap(card);
    await tester.pump(kDoubleTapMinTime);
    await tester.tap(card);
    await tester.pump(kDoubleTapTimeout);
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.longPress(card);
    await tester.pump();
  }

  testWidgets('first run: small, in the bottom-right corner, a margin in from '
      'the edges', (tester) async {
    await pumpCard(tester);

    final rect = cardRect(tester);
    expect(rect.height, 172);
    expect(rect.width, closeTo(172 * aspect, 1e-6));
    expect(rect.right, _area.width - _margin);
    expect(rect.bottom, _area.height - _margin);
    expect(find.byKey(const Key('figure')), findsOneWidget);
  });

  testWidgets('a tap away from the card reaches what is under it', (
    tester,
  ) async {
    await pumpCard(tester);

    await tester.tapAt(const Offset(60, 60));
    expect(behindTaps, 1);
  });

  testWidgets('a drag that starts on the card moves it, within the area, and '
      'the placement is saved once it stops', (tester) async {
    await pumpCard(tester);
    final before = cardRect(tester);

    final gesture = await tester.startGesture(before.center);
    // Past the slop, so the next move is applied whole.
    await gesture.moveBy(const Offset(-30, -30));
    await tester.pump();
    final start = cardRect(tester);
    await gesture.moveBy(const Offset(-100, -150));
    await tester.pump();
    await gesture.up();
    final after = cardRect(tester);

    expect(after.left - start.left, closeTo(-100, 1e-6));
    expect(after.top - start.top, closeTo(-150, 1e-6));
    expect(behindTaps, 0);

    await tester.pump(companionCardPersistDebounce);
    final saved =
        verify(
              () => mocks.settingsDb.saveSettingsItem(
                CompanionCardForm.phone.settingsKey,
                captureAny(),
              ),
            ).captured.single
            as String;
    final travelX = _area.width - 2 * _margin - after.width;
    final travelY = _area.height - 2 * _margin - after.height;
    final json = jsonDecode(saved) as Map<String, dynamic>;
    expect(json['x'], closeTo((after.left - _margin) / travelX, 1e-9));
    expect(json['y'], closeTo((after.top - _margin) / travelY, 1e-9));
    expect(json['h'], 172);
  });

  testWidgets('a drag past the edge stops at the margin', (tester) async {
    await pumpCard(tester);

    final gesture = await tester.startGesture(cardRect(tester).center);
    await gesture.moveBy(const Offset(-30, -30));
    await gesture.moveBy(const Offset(-1000, -1000));
    await tester.pump();
    await gesture.up();

    expect(cardRect(tester).topLeft, const Offset(_margin, _margin));
    await tester.pump(companionCardPersistDebounce);
  });

  testWidgets('double-tap grows it to large and back to small', (
    tester,
  ) async {
    await pumpCard(tester);

    await doubleTap(tester);
    expect(cardRect(tester).height, CompanionCardForm.phone.largeHeight);
    expect(cardRect(tester).bottomRight, cardRect(tester).bottomRight);

    await doubleTap(tester);
    expect(cardRect(tester).height, CompanionCardForm.phone.smallHeight);
  });

  testWidgets('a pinch on the card scales it', (tester) async {
    await pumpCard(tester);
    final center = cardRect(tester).center;

    final a = await tester.startGesture(center - const Offset(0, 20));
    final b = await tester.startGesture(center + const Offset(0, 20));
    await tester.pump();
    // Each finger 20 further out: the span 40 → 80, twice the size.
    await a.moveBy(const Offset(0, -10));
    await b.moveBy(const Offset(0, 10));
    await tester.pump();
    final start = cardRect(tester).height;
    await a.moveBy(const Offset(0, -20));
    await b.moveBy(const Offset(0, 20));
    await tester.pump();
    await a.up();
    await b.up();

    // Spread apart, it grows by the fingers' span since the pinch took.
    final grown = cardRect(tester).height;
    expect(grown, greaterThan(start * 1.2));

    final c = await tester.startGesture(center - const Offset(0, 40));
    final d = await tester.startGesture(center + const Offset(0, 40));
    await c.moveBy(const Offset(0, 20));
    await d.moveBy(const Offset(0, -20));
    await tester.pump();
    await c.moveBy(const Offset(0, 10));
    await d.moveBy(const Offset(0, -10));
    await tester.pump();
    await c.up();
    await d.up();
    // Pinched in, it shrinks.
    expect(cardRect(tester).height, lessThan(grown));
    await tester.pump(companionCardPersistDebounce);
  });

  testWidgets('a saved size bigger than the area is drawn as big as fits', (
    tester,
  ) async {
    when(
      () => mocks.settingsDb.itemByKey(CompanionCardForm.phone.settingsKey),
    ).thenAnswer((_) async => jsonEncode({'x': 0, 'y': 0, 'h': 1500}));
    await pumpCard(tester);

    final rect = cardRect(tester);
    // The area's width binds first: 358 wide at her shape.
    expect(rect.width, closeTo(_area.width - 2 * _margin, 1e-6));
    expect(rect.topLeft, const Offset(_margin, _margin));
  });

  group('a host that can put it away', () {
    testWidgets('has it hidden by a single tap, never by a double tap', (
      tester,
    ) async {
      await pumpCard(tester, hideable: true);

      await doubleTap(tester);
      expect(hides, 0);
      expect(cardRect(tester).height, CompanionCardForm.phone.largeHeight);

      await tester.tap(card);
      await tester.pump(kDoubleTapTimeout);
      expect(hides, 1);
      expect(behindTaps, 0);
    });

    testWidgets('a keyboard hides it too: focused, Space puts it away', (
      tester,
    ) async {
      await pumpCard(tester, hideable: true);
      Focus.of(tester.element(find.byKey(const Key('figure')))).requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();

      expect(hides, 1);
    });

    testWidgets('has a Hide row last in its menu', (tester) async {
      await pumpCard(tester, hideable: true);
      await openMenu(tester);
      await tester.tap(find.byKey(CompanionFloatingCardKeys.hide));
      await tester.pump();

      expect(hides, 1);
    });

    testWidgets('a screen reader hides it with the tap action', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpCard(tester, hideable: true);
      final label = find.semantics.byLabel(
        'Companion. Drag to move; change the size from its options.',
      );

      tester.semantics.tap(label);
      await tester.pump();

      expect(hides, 1);
      semantics.dispose();
    });

    testWidgets('without one, a tap does nothing and the menu has no Hide', (
      tester,
    ) async {
      await pumpCard(tester);
      await tester.tap(card);
      await tester.pump(kDoubleTapTimeout);
      await openMenu(tester);

      expect(find.byKey(CompanionFloatingCardKeys.hide), findsNothing);
      expect(behindTaps, 0);
    });
  });

  group('its menu', () {
    testWidgets('opens on a long press with the sizes, customize and reset', (
      tester,
    ) async {
      await pumpCard(tester);
      await openMenu(tester);

      for (final label in [
        'Small',
        'Large',
        'Demo size',
        'Customize',
        'Reset position and size',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('Large and Small set the size', (tester) async {
      await pumpCard(tester);
      await openMenu(tester);
      await tester.tap(find.byKey(CompanionFloatingCardKeys.large));
      await tester.pump();
      expect(cardRect(tester).height, CompanionCardForm.phone.largeHeight);

      await openMenu(tester);
      await tester.tap(find.byKey(CompanionFloatingCardKeys.small));
      await tester.pump();
      expect(cardRect(tester).height, CompanionCardForm.phone.smallHeight);
    });

    testWidgets('Customize asks the host to open her settings', (
      tester,
    ) async {
      await pumpCard(tester);
      await openMenu(tester);
      await tester.tap(find.byKey(CompanionFloatingCardKeys.customize));
      await tester.pump();

      expect(customizes, 1);
    });

    testWidgets('Demo size fills the area, unsaved, until Usual size', (
      tester,
    ) async {
      await pumpCard(tester);
      await openMenu(tester);
      await tester.tap(find.byKey(CompanionFloatingCardKeys.demo));
      await tester.pump();

      final demo = cardRect(tester);
      expect(demo.width, closeTo(_area.width - 2 * _margin, 1e-6));
      expect(demo.center.dx, _area.width / 2);
      expect(demo.center.dy, _area.height / 2);
      // Fixed while it lasts: a drag does not move it.
      await tester.drag(card, const Offset(-50, -50));
      await tester.pump();
      expect(cardRect(tester), demo);

      await tester.tap(find.byKey(CompanionFloatingCardKeys.usualSize));
      // The card's double-tap holds a tap inside it until it times out.
      await tester.pump(kDoubleTapTimeout);
      expect(cardRect(tester).height, 172);
      await tester.pump(companionCardPersistDebounce);
      verifyNever(() => mocks.settingsDb.saveSettingsItem(any(), any()));
    });

    testWidgets('a double-tap also ends Demo size', (tester) async {
      await pumpCard(tester);
      await openMenu(tester);
      await tester.tap(find.byKey(CompanionFloatingCardKeys.demo));
      await tester.pump();

      await doubleTap(tester);
      expect(cardRect(tester).height, 172);
      expect(find.byKey(CompanionFloatingCardKeys.usualSize), findsNothing);
    });

    testWidgets('Reset puts it back small in the corner', (tester) async {
      when(
        () => mocks.settingsDb.itemByKey(CompanionCardForm.phone.settingsKey),
      ).thenAnswer((_) async => jsonEncode({'x': 0, 'y': 0, 'h': 300}));
      await pumpCard(tester);
      expect(cardRect(tester).topLeft, const Offset(_margin, _margin));

      await openMenu(tester);
      await tester.tap(find.byKey(CompanionFloatingCardKeys.reset));
      await tester.pump();

      expect(cardRect(tester).height, 172);
      expect(cardRect(tester).bottomRight, const Offset(374, 584));
    });
  });

  testWidgets('a screen reader opens its menu with the long-press action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpCard(tester);
    expect(find.text('Demo size'), findsNothing);

    tester.semantics.longPress(
      find.semantics.byLabel(
        'Companion. Drag to move; change the size from its options.',
      ),
    );
    await tester.pump();

    expect(find.text('Demo size'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('its glass is the see-through card fill, and its edge takes '
      'the interactive accent while she speaks', (tester) async {
    BoxDecoration glass() =>
        tester
                .widgetList<DecoratedBox>(
                  find.descendant(
                    of: card,
                    matching: find.byType(DecoratedBox),
                  ),
                )
                .firstWhere(
                  (b) => (b.decoration as BoxDecoration?)?.border != null,
                )
                .decoration
            as BoxDecoration;
    Color edge() => (glass().border! as Border).top.color;

    await pumpCard(tester);
    final tokens = tester.element(card).designTokens;
    expect(glass().color, dsGlassCardFill(tokens));
    expect(
      tester
          .widget<DsGlassChipSurface>(
            find.descendant(
              of: card,
              matching: find.byType(DsGlassChipSurface),
            ),
          )
          .blurSigma,
      DsGlassChipSurface.cardBlurSigma,
    );
    expect(edge(), tokens.colors.decorative.level02);

    await pumpCard(tester, speaking: true);
    expect(
      edge(),
      tokens.colors.interactive.enabled.withValues(
        alpha: SurfaceAlphas.linework,
      ),
    );
  });

  group('on a desktop', () {
    Future<TestGesture> hover(WidgetTester tester) async {
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(cardRect(tester).center);
      await tester.pump();
      return mouse;
    }

    final grip = find.byKey(CompanionFloatingCardKeys.resizeGrip);

    testWidgets('starts larger than on a phone, the grip hidden until hover', (
      tester,
    ) async {
      await pumpCard(tester, form: CompanionCardForm.desktop);
      expect(cardRect(tester).height, 240);
      expect(grip, findsNothing);

      await hover(tester);
      expect(grip, findsOneWidget);
      // In the corner facing the open screen: top-left, from bottom-right.
      final g = tester.getCenter(grip);
      expect(g.dx, lessThan(cardRect(tester).center.dx));
      expect(g.dy, lessThan(cardRect(tester).center.dy));
    });

    testWidgets('the grip drags it bigger and keeps its corner', (
      tester,
    ) async {
      await pumpCard(tester, form: CompanionCardForm.desktop);
      await hover(tester);
      final before = cardRect(tester);

      final drag = await tester.startGesture(tester.getCenter(grip));
      await drag.moveBy(const Offset(0, -30));
      await tester.pump();
      final start = cardRect(tester).height;
      await drag.moveBy(const Offset(0, -60));
      await tester.pump();
      await drag.up();

      expect(cardRect(tester).height - start, closeTo(60, 1e-6));
      expect(cardRect(tester).bottomRight, before.bottomRight);
      await tester.pump(companionCardPersistDebounce);
    });

    testWidgets('the grip hides again once the pointer leaves the card', (
      tester,
    ) async {
      await pumpCard(tester, form: CompanionCardForm.desktop);
      final mouse = await hover(tester);
      expect(grip, findsOneWidget);

      await mouse.moveTo(const Offset(1, 1));
      await tester.pump();

      expect(grip, findsNothing);
    });

    testWidgets('a card capped by a small window shrinks from the size it '
        'is shown at, not the larger saved one', (tester) async {
      when(
        () => mocks.settingsDb.itemByKey(
          CompanionCardForm.desktop.settingsKey,
        ),
      ).thenAnswer((_) async => jsonEncode({'x': 1, 'y': 1, 'h': 1500}));
      await pumpCard(tester, form: CompanionCardForm.desktop);
      await hover(tester);
      final shown = cardRect(tester).height;
      expect(shown, lessThan(1500));

      // The grip sits top-left; dragging it down and in shrinks the card.
      final drag = await tester.startGesture(tester.getCenter(grip));
      await drag.moveBy(const Offset(0, 40));
      await tester.pump();
      await drag.up();

      expect(cardRect(tester).height, closeTo(shown - 40, 1e-6));
      await tester.pump(companionCardPersistDebounce);
    });

    testWidgets('a cancelled press on the grip lets the card be dragged '
        'again', (tester) async {
      await pumpCard(tester, form: CompanionCardForm.desktop);
      await hover(tester);
      final press = await tester.startGesture(tester.getCenter(grip));
      await press.cancel();
      await tester.pump();

      final before = cardRect(tester);
      final drag = await tester.startGesture(before.center);
      await drag.moveBy(const Offset(-30, 0));
      await drag.moveBy(const Offset(-50, 0));
      await tester.pump();
      await drag.up();

      expect(cardRect(tester).left, lessThan(before.left));
      await tester.pump(companionCardPersistDebounce);
    });

    testWidgets('Ctrl + scroll scales it; a plain scroll does not', (
      tester,
    ) async {
      await pumpCard(tester, form: CompanionCardForm.desktop);
      await hover(tester);

      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: cardRect(tester).center,
          scrollDelta: const Offset(0, -40),
        ),
      );
      await tester.pump();
      expect(cardRect(tester).height, 240);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: cardRect(tester).center,
          scrollDelta: const Offset(0, -40),
        ),
      );
      await tester.pump();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      expect(
        cardRect(tester).height,
        closeTo(240 * (1 + 40 * CompanionFloatingCard.scrollScale), 1e-6),
      );
      await tester.pump(companionCardPersistDebounce);
    });

    testWidgets('a right-click opens the menu', (tester) async {
      await pumpCard(tester, form: CompanionCardForm.desktop);

      await tester.tap(card, buttons: kSecondaryButton);
      await tester.pump();

      expect(find.text('Demo size'), findsOneWidget);
    });
  });
}
