import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_speech_bubble.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_stage.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  const her = ColoredBox(key: ValueKey('her'), color: Color(0xFF000000));

  Future<void> pumpStage(
    WidgetTester tester,
    OnboardingStage stage, {
    double? stageHeight,
    double bottomInset = 0,
  }) async {
    final Widget sized = SizedBox(width: 390, child: stage);
    await tester.pumpWidget(
      makeTestableWidget(
        Material(
          type: MaterialType.transparency,
          child: stageHeight == null
              ? sized
              : OnboardingStageHeight(minHeight: stageHeight, child: sized),
        ),
        mediaQueryData: MediaQueryData(
          size: const Size(390, 2000),
          padding: EdgeInsets.only(bottom: bottomInset),
          disableAnimations: true,
        ),
      ),
    );
    await tester.pump();
  }

  DsTokens tokensOf(WidgetTester tester) =>
      tester.element(find.byType(OnboardingStage)).designTokens;

  group('OnboardingProgress', () {
    test('names the thing in progress, and the last once all are done', () {
      expect(const OnboardingProgress(done: 0).step, 1);
      expect(const OnboardingProgress(done: 1, current: 0.5).step, 2);
      expect(const OnboardingProgress(done: 2).step, 3);
      expect(const OnboardingProgress(done: 3).step, 3);
    });

    test('is equal by what is done and how far the next is', () {
      const a = OnboardingProgress(done: 1, current: 0.5);
      expect(a, const OnboardingProgress(done: 1, current: 0.5));
      expect(
        a.hashCode,
        const OnboardingProgress(done: 1, current: 0.5).hashCode,
      );
      expect(a, isNot(const OnboardingProgress(done: 2, current: 0.5)));
      expect(a, isNot(const OnboardingProgress(done: 1, current: 0.25)));
    });

    test('refuses a count or a fraction out of range', () {
      expect(() => OnboardingProgress(done: 4), throwsAssertionError);
      expect(() => OnboardingProgress(done: -1), throwsAssertionError);
      expect(
        () => OnboardingProgress(done: 0, current: 1.5),
        throwsAssertionError,
      );
    });
  });

  group('OnboardingProgressBar', () {
    testWidgets('fills the finished segments, part of the one in progress '
        'and none of the rest, and says the step', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const OnboardingProgressBar(
            progress: OnboardingProgress(done: 1, current: 0.5),
          ),
        ),
      );

      final fills = tester
          .widgetList<FractionallySizedBox>(
            find.descendant(
              of: find.byType(OnboardingProgressBar),
              matching: find.byType(FractionallySizedBox),
            ),
          )
          .map((box) => box.widthFactor)
          .toList();
      expect(fills, [1, 0.5, 0]);
      expect(find.bySemanticsLabel('Step 2 of 3'), findsOneWidget);
    });
  });

  group('OnboardingStage', () {
    testWidgets('stacks the bar, her, her bubble and the tray, with the '
        "actions at the tray's foot in order", (tester) async {
      await pumpStage(
        tester,
        OnboardingStage(
          companion: her,
          title: 'Headline',
          text: 'What she adds',
          progress: const OnboardingProgress(done: 0, current: 0.5),
          onBack: () {},
          caption: 'Caption',
          helper: const Text('Helper'),
          secondary: OnboardingStageAction(label: 'Link', onPressed: () {}),
          primary: OnboardingStageAction(label: 'Go', onPressed: () {}),
          child: const Text('Content'),
        ),
      );
      final tokens = tokensOf(tester);

      double top(Finder f) => tester.getTopLeft(f).dy;
      double bottom(Finder f) => tester.getBottomLeft(f).dy;
      final herFinder = find.byKey(const ValueKey('her'));
      final bubble = find.byType(OnboardingSpeechBubble);

      expect(
        bottom(find.byType(OnboardingProgressBar)),
        lessThanOrEqualTo(top(herFinder)),
      );
      expect(
        tester.getSize(herFinder).height,
        OnboardingStage.companionHeight(tokens, stageHeight: 0),
      );
      expect(bottom(herFinder), lessThanOrEqualTo(top(bubble)));
      // Her bubble says the headline and what she adds, at one size.
      final said = tester.widget<OnboardingSpeechBubble>(bubble);
      expect(said.title, 'Headline');
      expect(said.text, 'What she adds');
      expect(
        said.minHeight,
        OnboardingStage.bubbleHeight(tokens, TextScaler.noScaling),
      );

      final order = [
        bubble,
        find.text('Caption'),
        find.text('Content'),
        find.text('Helper'),
        find.text('Link'),
        find.text('Go'),
      ];
      for (var i = 0; i < order.length - 1; i++) {
        expect(
          bottom(order[i]),
          lessThanOrEqualTo(top(order[i + 1])),
          reason: 'item $i sits above item ${i + 1}',
        );
      }
    });

    testWidgets('without her the headline and the line are a plain header, '
        'and nothing but the content is in the tray unless given', (
      tester,
    ) async {
      await pumpStage(
        tester,
        const OnboardingStage(
          title: 'Headline',
          text: 'A line',
          child: Text('Content'),
        ),
      );
      final tokens = tokensOf(tester);

      expect(find.byType(OnboardingSpeechBubble), findsNothing);
      expect(find.byType(OnboardingProgressBar), findsNothing);
      expect(find.byType(DesignSystemButton), findsNothing);
      expect(find.byIcon(LottiIcons.back), findsNothing);
      expect(
        tester.widget<Text>(find.text('Headline')).style?.color,
        tokens.colors.text.highEmphasis,
      );
      expect(
        tester.widget<Text>(find.text('A line')).style?.color,
        tokens.colors.text.mediumEmphasis,
      );
      expect(
        tester.getBottomLeft(find.text('A line')).dy,
        lessThan(tester.getTopLeft(find.text('Content')).dy),
      );
    });

    testWidgets('the back arrow, the link and the main button each call '
        'their own action', (tester) async {
      final calls = <String>[];
      await pumpStage(
        tester,
        OnboardingStage(
          title: 'Headline',
          onBack: () => calls.add('back'),
          secondary: OnboardingStageAction(
            label: 'Link',
            onPressed: () => calls.add('link'),
          ),
          primary: OnboardingStageAction(
            label: 'Go',
            onPressed: () => calls.add('go'),
            icon: LottiIcons.forward,
          ),
          child: const Text('Content'),
        ),
      );

      await tester.tap(find.byIcon(LottiIcons.back));
      await tester.tap(find.text('Link'), warnIfMissed: false);
      await tester.tap(find.text('Go'), warnIfMissed: false);
      expect(calls, ['back', 'link', 'go']);
      expect(find.byIcon(LottiIcons.forward), findsOneWidget);
    });

    testWidgets('a main button without an action is disabled, and a busy '
        'one says so', (tester) async {
      await pumpStage(
        tester,
        const OnboardingStage(
          title: 'Headline',
          primary: OnboardingStageAction(label: 'Go', onPressed: null),
          child: Text('Content'),
        ),
      );
      expect(
        tester
            .widget<DesignSystemButton>(find.byType(DesignSystemButton))
            .onPressed,
        isNull,
      );

      await pumpStage(
        tester,
        OnboardingStage(
          title: 'Headline',
          primary: OnboardingStageAction(label: 'Go', onPressed: () {}),
          primaryLoading: true,
          child: const Text('Content'),
        ),
      );
      expect(
        tester
            .widget<DesignSystemButton>(find.byType(DesignSystemButton))
            .isLoading,
        isTrue,
      );
    });

    testWidgets('the close button sits at the end of the bar, clear of the '
        'progress, named for a screen reader, and is left out without an '
        'action', (tester) async {
      var left = 0;
      await pumpStage(
        tester,
        OnboardingStage(
          title: 'Headline',
          progress: const OnboardingProgress(done: 1),
          onClose: () => left++,
          child: const Text('Content'),
        ),
      );
      expect(find.bySemanticsLabel('Close'), findsOneWidget);
      await tester.tap(find.byIcon(LottiIcons.close));
      expect(left, 1);
      expect(
        tester.getTopLeft(find.byIcon(LottiIcons.close)).dx,
        greaterThan(
          tester.getTopRight(find.byType(OnboardingProgressBar)).dx,
        ),
      );

      await pumpStage(
        tester,
        const OnboardingStage(title: 'Headline', child: Text('Content')),
      );
      expect(find.byIcon(LottiIcons.close), findsNothing);
    });

    testWidgets('the caption over the content is the shared tray caption, a '
        'size below what it names', (tester) async {
      await pumpStage(
        tester,
        const OnboardingStage(
          title: 'Headline',
          caption: 'Caption',
          child: Text('Content'),
        ),
      );
      final tokens = tokensOf(tester);

      expect(find.byType(OnboardingTrayCaption), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('Caption')).style?.color,
        tokens.colors.text.mediumEmphasis,
      );
      expect(
        tester.widget<Text>(find.text('Caption')).style?.fontSize,
        tokens.typography.styles.others.caption.fontSize,
      );
    });
  });

  group('system back', () {
    Future<NavigatorState> pushStage(
      WidgetTester tester,
      OnboardingStage stage,
    ) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        makeTestableWidget(
          Navigator(
            key: navigator,
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => const Text('Under'),
            ),
          ),
          mediaQueryData: const MediaQueryData(size: Size(390, 2000)),
        ),
      );
      navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => Material(child: stage)),
      );
      await tester.pumpAndSettle();
      return navigator.currentState!;
    }

    testWidgets('on a step with a back arrow it goes back with it and keeps '
        'the flow open', (tester) async {
      var back = 0;
      final navigator = await pushStage(
        tester,
        OnboardingStage(
          title: 'Headline',
          onBack: () => back++,
          child: const Text('Content'),
        ),
      );

      await navigator.maybePop();
      await tester.pumpAndSettle();
      expect(back, 1);
      expect(find.text('Content'), findsOneWidget);
    });

    testWidgets('while the arrow is disabled it does nothing', (tester) async {
      final navigator = await pushStage(
        tester,
        const OnboardingStage(
          title: 'Headline',
          showBack: true,
          child: Text('Content'),
        ),
      );

      await navigator.maybePop();
      await tester.pumpAndSettle();
      expect(find.text('Content'), findsOneWidget);
    });

    testWidgets('on a step without one it closes as before', (tester) async {
      final navigator = await pushStage(
        tester,
        const OnboardingStage(title: 'Headline', child: Text('Content')),
      );

      await navigator.maybePop();
      await tester.pumpAndSettle();
      expect(find.text('Content'), findsNothing);
      expect(find.text('Under'), findsOneWidget);
    });
  });

  group('the frame every step keeps', () {
    testWidgets('a step past the first shows the back arrow even when it '
        'cannot go back, disabled; a step being saved shows the close '
        'button disabled', (tester) async {
      await pumpStage(
        tester,
        const OnboardingStage(
          title: 'Headline',
          showBack: true,
          showClose: true,
          child: Text('Content'),
        ),
      );
      final tokens = tokensOf(tester);

      for (final icon in [LottiIcons.back, LottiIcons.close]) {
        final button = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, icon),
        );
        expect(button.onPressed, isNull, reason: '$icon');
        expect(button.disabledColor, tokens.colors.text.lowEmphasis);
      }
    });

    testWidgets('the main button is at one height with a link or without; '
        'a step without one gives the room to its content, and the link is '
        'a size below the main button', (tester) async {
      Future<double> buttonTop({required bool withLink}) async {
        await pumpStage(
          tester,
          OnboardingStage(
            title: 'Headline',
            secondary: withLink
                ? OnboardingStageAction(label: 'Link', onPressed: () {})
                : null,
            primary: OnboardingStageAction(label: 'Go', onPressed: () {}),
            child: const Text('Content'),
          ),
          stageHeight: 900,
        );
        return tester
            .getTopLeft(find.widgetWithText(DesignSystemButton, 'Go'))
            .dy;
      }

      final withLink = await buttonTop(withLink: true);
      expect(
        tester
            .widget<DesignSystemButton>(
              find.widgetWithText(DesignSystemButton, 'Link'),
            )
            .size,
        DesignSystemButtonSize.medium,
      );
      final without = await buttonTop(withLink: false);
      expect(without, closeTo(withLink, 0.5));
      expect(find.text('Link'), findsNothing);
      expect(find.byType(DesignSystemButton), findsOneWidget);
    });

    testWidgets('her bubble is one measured height whatever she says; '
        'larger text makes it taller, and the wider dialog takes a line '
        'less', (tester) async {
      Future<double> bubbleOf(String text, {double scale = 1}) async {
        await tester.pumpWidget(
          makeTestableWidget(
            SizedBox(
              width: 390,
              child: OnboardingStage(
                companion: her,
                title: 'Headline',
                text: text,
                child: const Text('Content'),
              ),
            ),
            mediaQueryData: MediaQueryData(
              size: const Size(390, 2000),
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
            ),
          ),
        );
        await tester.pump();
        return tester.getSize(find.byType(OnboardingSpeechBubble)).height;
      }

      final short = await bubbleOf('One line.');
      final long = await bubbleOf('Two lines of words, which wrap once.');
      expect(long, short);
      final larger = await bubbleOf('One line.', scale: 1.3);
      expect(larger, greaterThan(short));

      final tokens = tokensOf(tester);
      expect(
        OnboardingStage.bubbleHeight(tokens, TextScaler.noScaling, lines: 2),
        lessThan(OnboardingStage.bubbleHeight(tokens, TextScaler.noScaling)),
      );
    });
  });

  group('the height of a stage', () {
    OnboardingStage stage({
      Widget child = const Text('Content'),
      bool centered = false,
      String? caption,
    }) => OnboardingStage(
      companion: her,
      title: 'Headline',
      caption: caption,
      centered: centered,
      primary: OnboardingStageAction(label: 'Go', onPressed: () {}),
      child: child,
    );

    double buttonBottom(WidgetTester tester) =>
        tester.getBottomLeft(find.byType(DesignSystemButton)).dy;

    testWidgets('with no height from the host, the tray still keeps its '
        'least height, the main button at its foot', (tester) async {
      await pumpStage(tester, stage());
      final tokens = tokensOf(tester);

      final content = tester.getTopLeft(find.text('Content')).dy;
      // The tray's inside is its least height tall: the content at its top,
      // the button's foot that far below.
      expect(
        buttonBottom(tester) - content,
        closeTo(OnboardingStage.trayMinHeight(tokens), 0.01),
      );
    });

    testWidgets('fills the height the host gives, the tray taking what the '
        'top leaves and the main button at the foot', (tester) async {
      await pumpStage(tester, stage(), stageHeight: 900);
      final tokens = tokensOf(tester);

      final panel = tester.getRect(find.byType(OnboardingStage));
      expect(panel.height, 900);
      expect(
        buttonBottom(tester),
        closeTo(panel.bottom - tokens.spacing.step5, 0.01),
      );
      // She is in the same place whatever the tray holds.
      final herTop = tester.getTopLeft(find.byKey(const ValueKey('her'))).dy;

      await pumpStage(
        tester,
        stage(child: const SizedBox(height: 300, child: Text('Content'))),
        stageHeight: 900,
      );
      expect(tester.getSize(find.byType(OnboardingStage)).height, 900);
      expect(tester.getTopLeft(find.byKey(const ValueKey('her'))).dy, herTop);
      expect(
        buttonBottom(tester),
        closeTo(panel.bottom - tokens.spacing.step5, 0.01),
      );
    });

    testWidgets("keeps the host's height when the tray holds more: the "
        'content scrolls and the main button stays at the foot', (
      tester,
    ) async {
      await pumpStage(
        tester,
        stage(
          child: const SizedBox(
            height: 900,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Text('Last'),
            ),
          ),
        ),
        stageHeight: 900,
      );
      final tokens = tokensOf(tester);

      expect(tester.takeException(), isNull);
      final panel = tester.getRect(find.byType(OnboardingStage));
      expect(panel.height, 900);
      expect(
        buttonBottom(tester),
        closeTo(panel.bottom - tokens.spacing.step5, 0.01),
      );
      // The end of the content is out of view until it is scrolled to,
      // and the button does not move when it is.
      final scroll = find.descendant(
        of: find.byType(OnboardingStage),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.text('Last'),
        200,
        scrollable: scroll,
      );
      expect(
        tester.getBottomLeft(find.text('Last')).dy,
        lessThanOrEqualTo(
          tester.getTopLeft(find.byType(DesignSystemButton)).dy,
        ),
      );
      expect(
        buttonBottom(tester),
        closeTo(panel.bottom - tokens.spacing.step5, 0.01),
      );
    });

    testWidgets('centred content sits midway over the actions; listed '
        'content sits at the top', (tester) async {
      Future<double> contentMid({required bool centered}) async {
        await pumpStage(
          tester,
          stage(
            centered: centered,
            caption: 'Caption',
            child: const SizedBox(height: 40, child: Text('Content')),
          ),
          stageHeight: 900,
        );
        return tester.getCenter(find.text('Content')).dy;
      }

      final top = await contentMid(centered: false);
      final mid = await contentMid(centered: true);
      final caption = tester.getBottomLeft(find.text('Caption')).dy;
      // With no link, the foot is the main button.
      final foot = tester.getTopLeft(find.byType(DesignSystemButton)).dy;
      expect(mid, greaterThan(top));
      // Equal room above and below, give or take the gap over the foot.
      final above = mid - caption;
      final below = foot - mid;
      expect((above - below).abs(), lessThan(tokensOf(tester).spacing.step6));
    });

    testWidgets('measures the same without laying out: its dry size and '
        'its intrinsic height are the size it takes', (tester) async {
      for (final host in <double?>[null, 900]) {
        await pumpStage(tester, stage(), stageHeight: host);
        final box = tester.allRenderObjects
            .whereType<RenderStageColumn>()
            .single;
        final size = box.size;

        expect(
          box.getDryLayout(BoxConstraints.tightFor(width: size.width)),
          size,
          reason: 'dry layout, host $host',
        );
        expect(
          box.getMinIntrinsicHeight(size.width),
          closeTo(size.height, 0.01),
          reason: 'min intrinsic height, host $host',
        );
        expect(
          box.getMaxIntrinsicHeight(size.width),
          closeTo(size.height, 0.01),
          reason: 'max intrinsic height, host $host',
        );
        // As wide as its widest part asks to be, and no wider than fits.
        expect(
          box.getMinIntrinsicWidth(double.infinity),
          lessThanOrEqualTo(box.getMaxIntrinsicWidth(double.infinity)),
        );
        expect(box.getMinIntrinsicWidth(double.infinity), greaterThan(0));
      }
    });

    testWidgets('on a window too short for both, the tray keeps room for its '
        'foot and the stage grows past the host to be scrolled', (
      tester,
    ) async {
      await pumpStage(tester, stage(), stageHeight: 300);
      final tokens = tokensOf(tester);

      final panel = tester.getRect(find.byType(OnboardingStage));
      expect(panel.height, greaterThan(300));
      final button = tester.getRect(find.byType(DesignSystemButton));
      expect(button.height, greaterThan(0));
      expect(button.bottom, lessThanOrEqualTo(panel.bottom));
      // The tray keeps its least room under the top.
      final tray =
          panel.bottom -
          tester
              .getBottomLeft(
                find.byType(OnboardingSpeechBubble),
              )
              .dy;
      expect(
        tray,
        greaterThanOrEqualTo(
          OnboardingStage.trayMinHeight(tokens) / 2 + 2 * tokens.spacing.step5,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('follows the host when its height changes', (tester) async {
      await pumpStage(tester, stage(), stageHeight: 900);
      expect(tester.getSize(find.byType(OnboardingStage)).height, 900);

      await pumpStage(tester, stage(), stageHeight: 1000);
      expect(tester.getSize(find.byType(OnboardingStage)).height, 1000);
    });

    testWidgets('keeps the main button clear of the home indicator', (
      tester,
    ) async {
      await pumpStage(tester, stage(), stageHeight: 900, bottomInset: 34);
      final tokens = tokensOf(tester);

      final panel = tester.getRect(find.byType(OnboardingStage));
      expect(
        buttonBottom(tester),
        closeTo(panel.bottom - tokens.spacing.step5 - 34, 0.01),
      );
    });

    testWidgets('she stands small on a short screen, a size down on most '
        'phones, and full size only on a tall one', (tester) async {
      await pumpStage(tester, stage(), stageHeight: 812);
      final tokens = tokensOf(tester);
      expect(
        tester.getSize(find.byKey(const ValueKey('her'))).height,
        tokens.spacing.step13,
      );
      final tallHost = OnboardingStage.fullFrom(tokens);
      await pumpStage(tester, stage(), stageHeight: tallHost);
      expect(
        tester.getSize(find.byKey(const ValueKey('her'))).height,
        tokens.spacing.step13 + tokens.spacing.step9,
      );
      // No height from the host: full size.
      expect(
        OnboardingStage.companionHeight(tokens, stageHeight: 0),
        tokens.spacing.step13 + tokens.spacing.step9,
      );
    });

    testWidgets('she stands small on a short screen and full size on a '
        'tall one', (tester) async {
      await pumpStage(tester, stage(), stageHeight: 900);
      final tokens = tokensOf(tester);
      final tall = tester.getSize(find.byKey(const ValueKey('her'))).height;
      expect(tall, OnboardingStage.companionHeight(tokens, stageHeight: 900));

      final short = OnboardingStage.compactBelow(tokens) - 1;
      await pumpStage(tester, stage(), stageHeight: short);
      final small = tester.getSize(find.byKey(const ValueKey('her'))).height;
      expect(
        small,
        OnboardingStage.companionHeight(tokens, stageHeight: short),
      );
      expect(small, lessThan(tall));
    });
  });
}
