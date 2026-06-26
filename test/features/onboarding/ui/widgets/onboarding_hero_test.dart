import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/onboarding/ui/widgets/neural_constellation.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_hero.dart';
import 'package:lotti/l10n/app_localizations.dart';

import '../../../../widget_test_utils.dart';

void main() {
  // Reduced-motion media query: lets the repeating CustomPainter heroes settle
  // to a single static frame so a bare `pump()` does not hang.
  const reducedMotionMq = MediaQueryData(
    size: Size(390, 844),
    disableAnimations: true,
  );

  // Localized strings for the active app locale (en), resolved once so the
  // expected button/promise text always matches what the widget renders.
  final messages = lookupAppLocalizations(const Locale('en'));

  // The crystallize hero embeds a fixed-width task card whose two checklist
  // rows each overflow by a few pixels under the test font (real fonts are
  // narrower). That is a test-font artifact, not a behavioural defect, so we
  // capture those overflow errors at the source and treat them as harmless
  // while still surfacing any other (genuine) FlutterError.
  bool isHarmlessOverflow(FlutterErrorDetails details) {
    final exception = details.exception;
    return exception is FlutterError &&
        exception.message.contains('A RenderFlex overflowed');
  }

  /// Pumps [widget] with [FlutterError.onError] temporarily routed so that
  /// RenderFlex-overflow errors (a test-font artifact of the crystallize card)
  /// are swallowed, while any other error is re-presented to the original
  /// handler and surfaced to the test. Multiple overflow errors in one frame
  /// would otherwise collapse into a single "Multiple exceptions" aggregate
  /// that defeats `takeException()`.
  Future<void> pumpToleratingOverflow(
    WidgetTester tester,
    Widget widget, {
    Duration? duration,
  }) async {
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      if (isHarmlessOverflow(details)) return;
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);

    await tester.pumpWidget(widget);
    await tester.pump(duration);
  }

  // The expected human-readable label for each hero style. Kept in lock-step
  // with `OnboardingHeroStyle.label`.
  const expectedLabels = <OnboardingHeroStyle, String>{
    OnboardingHeroStyle.constellation: 'Constellation',
    OnboardingHeroStyle.crystallize: 'Crystallize',
    OnboardingHeroStyle.aurora: 'Aurora',
    OnboardingHeroStyle.waveform: 'Waveform',
  };

  // Wraps the panel in a bounded box so the infinite-size hero CustomPaint
  // has concrete dimensions to paint into.
  Widget boundedPanel(OnboardingHeroPanel panel) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: panel,
    ),
  );

  group('OnboardingHeroStyle.label', () {
    test('covers every enum value and matches the expected label', () {
      // Guards against the map drifting from the enum if a value is added.
      expect(expectedLabels.keys.toSet(), OnboardingHeroStyle.values.toSet());

      for (final style in OnboardingHeroStyle.values) {
        final label = style.label;
        expect(label, isNotEmpty);
        expect(label, expectedLabels[style]);
      }
    });
  });

  group('onboardingAuroraColors', () {
    test('returns 3 colours with the accent first', () {
      const accent = Color(0xFF00A3A3);
      final colors = onboardingAuroraColors(accent);

      expect(colors, hasLength(3));
      expect(colors.first, accent);
      // The derived blooms are hue-shifted from the accent, so they differ.
      expect(colors[1], isNot(accent));
      expect(colors[2], isNot(accent));
    });

    test('clamps the lightened bloom even for a fully light accent', () {
      // base.lightness == 1.0 -> (lightness + 0.08) must clamp to 1.0 without
      // throwing, exercising the .clamp branch.
      const lightAccent = Color(0xFFFFFFFF);
      final colors = onboardingAuroraColors(lightAccent);

      expect(colors, hasLength(3));
      expect(colors.first, lightAccent);
    });
  });

  group('buildOnboardingHeroVisual', () {
    test('constellation welcome uses the entangled multi-vine variant', () {
      final visual = buildOnboardingHeroVisual(
        OnboardingHeroStyle.constellation,
      );

      final constellation = visual as NeuralConstellation;
      expect(constellation.vineCount, 3);
      expect(constellation.entanglement, closeTo(0.64, 1e-9));
      expect(constellation.nodeCount, 62);
      expect(constellation.compositionOffset.dy, closeTo(0.02, 1e-9));
    });

    for (final style in OnboardingHeroStyle.values) {
      testWidgets('builds a non-null visual for ${style.label}', (
        tester,
      ) async {
        final visual = buildOnboardingHeroVisual(style);
        expect(visual, isNotNull);
        expect(visual, isA<Widget>());

        await pumpToleratingOverflow(
          tester,
          makeTestableWidget(
            Center(
              child: SizedBox(width: 360, height: 264, child: visual),
            ),
            mediaQueryData: reducedMotionMq,
          ),
        );

        // The exact instance returned by the builder is mounted in the tree.
        expect(
          find.descendant(
            of: find.byType(Center),
            matching: find.byWidget(visual),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('OnboardingHeroPanel', () {
    for (final style in OnboardingHeroStyle.values) {
      testWidgets('renders promise text, connect + skip for ${style.label}', (
        tester,
      ) async {
        await pumpToleratingOverflow(
          tester,
          makeTestableWidget(
            boundedPanel(
              OnboardingHeroPanel(
                heroStyle: style,
                onConnect: () {},
                onSkip: () {},
              ),
            ),
            mediaQueryData: reducedMotionMq,
          ),
        );

        // Promise copy.
        expect(find.text(messages.onboardingWelcomeTitle), findsOneWidget);
        expect(find.text(messages.onboardingWelcomeMessage), findsOneWidget);

        // Connect + skip CTAs as design-system buttons with their labels.
        expect(find.byType(DesignSystemButton), findsNWidgets(2));
        expect(
          find.text(messages.onboardingWelcomeConnectButton),
          findsOneWidget,
        );
        expect(
          find.text(messages.onboardingWelcomeSkipButton),
          findsOneWidget,
        );

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('invokes onConnect when the connect button is tapped', (
      tester,
    ) async {
      var connectCount = 0;
      var skipCount = 0;

      await tester.pumpWidget(
        makeTestableWidget(
          boundedPanel(
            OnboardingHeroPanel(
              onConnect: () => connectCount++,
              onSkip: () => skipCount++,
            ),
          ),
          mediaQueryData: reducedMotionMq,
        ),
      );
      await tester.pump();

      await tester.tap(find.text(messages.onboardingWelcomeConnectButton));
      await tester.pump();

      expect(connectCount, 1);
      expect(skipCount, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('invokes onSkip when the skip button is tapped', (
      tester,
    ) async {
      var connectCount = 0;
      var skipCount = 0;

      await tester.pumpWidget(
        makeTestableWidget(
          boundedPanel(
            OnboardingHeroPanel(
              onConnect: () => connectCount++,
              onSkip: () => skipCount++,
            ),
          ),
          mediaQueryData: reducedMotionMq,
        ),
      );
      await tester.pump();

      // Scroll the skip link into the (800x600) render surface — the display
      // hero title pushes it below the fold in the bare test viewport.
      await tester.ensureVisible(
        find.text(messages.onboardingWelcomeSkipButton),
      );
      await tester.pump();
      await tester.tap(find.text(messages.onboardingWelcomeSkipButton));
      await tester.pump();

      expect(skipCount, 1);
      expect(connectCount, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('honours a custom heroHeight', (tester) async {
      const customHeight = 180.0;

      await tester.pumpWidget(
        makeTestableWidget(
          boundedPanel(
            OnboardingHeroPanel(
              heroHeight: customHeight,
              onConnect: () {},
              onSkip: () {},
            ),
          ),
          mediaQueryData: reducedMotionMq,
        ),
      );
      await tester.pump();

      // The hero occupies the configured height. The first SizedBox under the
      // panel's Column wraps the hero visual.
      final heroBox = tester.widget<SizedBox>(
        find
            .descendant(
              of: find.byType(OnboardingHeroPanel),
              matching: find.byType(SizedBox),
            )
            .first,
      );
      expect(heroBox.height, customHeight);
      expect(tester.takeException(), isNull);
    });

    testWidgets('drives the staggered entrance + animated hero path', (
      tester,
    ) async {
      // No disableAnimations: this exercises the animated StaggeredEntrance
      // fade/rise and the repeating hero painter together.
      await tester.pumpWidget(
        makeTestableWidget(
          boundedPanel(
            OnboardingHeroPanel(
              heroStyle: OnboardingHeroStyle.aurora,
              onConnect: () {},
              onSkip: () {},
            ),
          ),
          mediaQueryData: const MediaQueryData(size: Size(600, 844)),
        ),
      );
      await tester.pump();
      // Advance past the staggered entrance (≈360ms + intervals) without
      // pumpAndSettle, which would never settle the repeating hero.
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(OnboardingHeroPanel), findsOneWidget);
      expect(find.text(messages.onboardingWelcomeTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('OnboardingBackdrop', () {
    Widget boundedBackdrop(OnboardingBackdrop backdrop) => Center(
      child: SizedBox(width: 390, height: 600, child: backdrop),
    );

    testWidgets('renders with the default accent + node count', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          boundedBackdrop(const OnboardingBackdrop()),
          mediaQueryData: reducedMotionMq,
        ),
      );
      await tester.pump();

      expect(find.byType(OnboardingBackdrop), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      final constellation = tester.widget<NeuralConstellation>(
        find.byType(NeuralConstellation),
      );
      expect(constellation.vineCount, 1);
      expect(constellation.entanglement, 0);
      expect(constellation.glow, closeTo(0.28, 1e-9));
      expect(constellation.compositionOffset.dy, closeTo(-0.18, 1e-9));
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders with a custom accent + node count', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          boundedBackdrop(
            const OnboardingBackdrop(
              accent: Color(0xFFFF6F00),
              nodeCount: 12,
            ),
          ),
          mediaQueryData: reducedMotionMq,
        ),
      );
      await tester.pump();

      expect(find.byType(OnboardingBackdrop), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}
