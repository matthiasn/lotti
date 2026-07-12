import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/daily_os_onboarding_spotlight.dart';

import '../../../../widget_test_utils.dart';

void main() {
  // A phone-sized surface with a target near the bottom, matching the real
  // check-in CTA's home. 400 wide keeps the card comfortably inside.
  const surface = Size(400, 800);
  const target = Rect.fromLTWH(50, 720, 300, 48);

  Widget spotlight({
    required VoidCallback onAction,
    required VoidCallback onDismiss,
    bool reduceMotion = false,
  }) => makeTestableWidgetNoScroll(
    DailyOsOnboardingSpotlight(
      targetRect: target,
      title: 'Make your first task',
      message: 'Say what is on your mind and I will turn it into a task.',
      actionLabel: 'Try it',
      dismissLabel: 'Not now',
      onAction: onAction,
      onDismiss: onDismiss,
    ),
    mediaQueryData: const MediaQueryData(
      size: surface,
    ).copyWith(disableAnimations: reduceMotion),
  );

  Future<void> pumpSpotlight(
    WidgetTester tester, {
    required VoidCallback onAction,
    required VoidCallback onDismiss,
    bool reduceMotion = false,
  }) async {
    // Keep the render surface and MediaQuery size in agreement so the
    // bottom-anchored target actually lays out on-screen.
    tester.view
      ..physicalSize = surface
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      spotlight(
        onAction: onAction,
        onDismiss: onDismiss,
        reduceMotion: reduceMotion,
      ),
    );
  }

  group('DailyOsOnboardingSpotlight', () {
    testWidgets('renders the title, message, and both actions', (tester) async {
      await pumpSpotlight(tester, onAction: () {}, onDismiss: () {});

      expect(find.text('Make your first task'), findsOneWidget);
      expect(
        find.text('Say what is on your mind and I will turn it into a task.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, 'Try it'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Not now'), findsOneWidget);
    });

    testWidgets('the primary action button fires onAction', (tester) async {
      var actions = 0;
      var dismisses = 0;
      await pumpSpotlight(
        tester,
        onAction: () => actions++,
        onDismiss: () => dismisses++,
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Try it'));
      await tester.pump();

      expect(actions, 1);
      expect(dismisses, 0);
    });

    testWidgets('the dismiss button fires onDismiss', (tester) async {
      var actions = 0;
      var dismisses = 0;
      await pumpSpotlight(
        tester,
        onAction: () => actions++,
        onDismiss: () => dismisses++,
      );

      await tester.tap(find.widgetWithText(TextButton, 'Not now'));
      await tester.pump();

      expect(dismisses, 1);
      expect(actions, 0);
    });

    testWidgets('tapping inside the highlighted target fires onAction', (
      tester,
    ) async {
      var actions = 0;
      var dismisses = 0;
      await pumpSpotlight(
        tester,
        onAction: () => actions++,
        onDismiss: () => dismisses++,
      );

      await tester.tapAt(target.center);
      await tester.pump();

      expect(actions, 1);
      expect(dismisses, 0);
    });

    testWidgets('tapping the dim scrim away from the target fires onDismiss', (
      tester,
    ) async {
      var actions = 0;
      var dismisses = 0;
      await pumpSpotlight(
        tester,
        onAction: () => actions++,
        onDismiss: () => dismisses++,
      );

      // Top of the screen: dim scrim, clear of both the hole and the card
      // (which sits just above the bottom-anchored target).
      await tester.tapAt(const Offset(200, 80));
      await tester.pump();

      expect(dismisses, 1);
      expect(actions, 0);
    });

    testWidgets('tapping the card background fires neither callback', (
      tester,
    ) async {
      var actions = 0;
      var dismisses = 0;
      await pumpSpotlight(
        tester,
        onAction: () => actions++,
        onDismiss: () => dismisses++,
      );

      // A point on the card's own surface (its title) must be swallowed, not
      // fall through to the scrim's dismiss handler.
      await tester.tap(find.text('Make your first task'));
      await tester.pump();

      expect(actions, 0);
      expect(dismisses, 0);
    });

    testWidgets('places the card below a target in the upper half', (
      tester,
    ) async {
      tester.view
        ..physicalSize = surface
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const DailyOsOnboardingSpotlight(
            targetRect: Rect.fromLTWH(50, 40, 300, 48),
            title: 'Top target',
            message: 'Coaching for a target near the top.',
            actionLabel: 'Try it',
            dismissLabel: 'Not now',
            onAction: _noop,
            onDismiss: _noop,
          ),
          mediaQueryData: const MediaQueryData(size: surface),
        ),
      );

      // Card is placed below the top-anchored target, so its top edge sits
      // beneath the target's bottom (88).
      final cardTop = tester.getTopLeft(find.text('Top target')).dy;
      expect(cardTop, greaterThan(88));
    });

    testWidgets('runs and repaints the attention pulse under normal motion', (
      tester,
    ) async {
      await pumpSpotlight(tester, onAction: () {}, onDismiss: () {});

      // Advancing frames drives the repeating pulse, which rebuilds the scrim
      // painter (exercising shouldRepaint) without settling.
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Make your first task'), findsOneWidget);
      expect(tester.hasRunningAnimations, isTrue);
    });

    testWidgets('settles (no infinite animation) under reduced motion', (
      tester,
    ) async {
      await pumpSpotlight(
        tester,
        onAction: () {},
        onDismiss: () {},
        reduceMotion: true,
      );

      // The pulse must not run under reduced motion — pumpAndSettle would time
      // out if it did. The spotlight still renders its content statically.
      await tester.pumpAndSettle();
      expect(find.text('Make your first task'), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}

void _noop() {}
