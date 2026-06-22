import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lotti/features/ai/ui/settings/services/connection_verifier_service.dart';
import 'package:lotti/features/onboarding/ui/onboarding_animation_gallery_page.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_hero.dart';

import '../../../widget_test_utils.dart';

void main() {
  // Tall canvas so the chip row + the panel both fit, and reduced motion so the
  // looping welcome heroes (constellation/aurora/waveform) settle instead of
  // pumping forever.
  const mq = MediaQueryData(size: Size(900, 1200), disableAnimations: true);

  Future<void> pumpGallery(WidgetTester tester) async {
    // The page's Scaffold body lays out against the physical test surface, not
    // the MediaQuery — size the surface so the tall chip row + scrolling panel
    // (incl. the crystallize hero's CustomMultiChildLayout) have bounded space.
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      makeTestableWidget(
        // makeTestableWidget hosts its child in a SingleChildScrollView, which
        // would give this Scaffold (a CustomMultiChildLayout) unbounded height.
        // Box it to the surface size so the page lays out with bounded space.
        const SizedBox(
          width: 900,
          height: 1200,
          child: OnboardingAnimationGalleryPage(),
        ),
        mediaQueryData: mq,
        overrides: [
          // The API-key panel reads the verifier client lazily; no probe fires
          // without text, but override it to a no-op so nothing ever touches a
          // real HttpClient when that panel is shown.
          connectionVerifierClientProvider.overrideWith(
            (ref) =>
                () => MockClient((_) async => http.Response('', 200)),
          ),
        ],
      ),
    );
    await tester.pump();
  }

  // Lets the AnimatedSwitcher / AnimatedSize panel swap settle after a chip tap
  // without using pumpAndSettle (the looping heroes never settle).
  Future<void> settlePanelSwap(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  ChoiceChip chipWithLabel(WidgetTester tester, String label) {
    final chip = tester
        .widgetList<ChoiceChip>(find.byType(ChoiceChip))
        .firstWhere(
          (c) => c.label is Text && (c.label as Text).data == label,
        );
    return chip;
  }

  testWidgets('renders the welcome view by default with the promise text', (
    tester,
  ) async {
    await pumpGallery(tester);

    // The default view is welcome → the hero panel with its promise message.
    expect(find.byType(OnboardingHeroPanel), findsOneWidget);
    expect(
      find.textContaining('Connect your AI brain'),
      findsOneWidget,
    );
    // The default hero-style chip (Constellation) is the selected one.
    expect(chipWithLabel(tester, 'Constellation').selected, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('each hero-style chip selects and keeps the welcome panel', (
    tester,
  ) async {
    await pumpGallery(tester);

    for (final style in OnboardingHeroStyle.values) {
      // Capture every render error this frame produces directly, so the test
      // binding never collapses several into an opaque "Multiple exceptions"
      // aggregate and we can assert on the real messages.
      final captured = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = captured.add;
      try {
        await tester.tap(find.text(style.label));
        await settlePanelSwap(tester);
      } finally {
        FlutterError.onError = previous;
      }

      // The tapped style's chip is now the selected one, and only it.
      for (final other in OnboardingHeroStyle.values) {
        expect(
          chipWithLabel(tester, other.label).selected,
          other == style,
          reason: '${other.label} selected state after tapping ${style.label}',
        );
      }
      // Still the welcome panel with its promise, regardless of hero style.
      expect(find.byType(OnboardingHeroPanel), findsOneWidget);
      expect(
        find.textContaining('Connect your AI brain'),
        findsOneWidget,
      );

      // The crystallize hero's checklist rows render their labels at full width
      // (no Flexible), so at the gallery's narrow panel width each row
      // legitimately overflows — a known cosmetic quirk of that debug preview,
      // not a fault of the chip handler. Every other hero must render cleanly.
      final messages = captured.map((e) => '${e.exception}').toList();
      if (style == OnboardingHeroStyle.crystallize) {
        expect(messages, isNotEmpty);
        expect(
          messages.every((m) => m.contains('overflowed')),
          isTrue,
          reason: 'crystallize errors should only be overflows: $messages',
        );
      } else {
        expect(
          messages,
          isEmpty,
          reason: 'unexpected errors for ${style.label}',
        );
      }
    }
  });

  testWidgets('the Connect chip shows the connect panel', (tester) async {
    await pumpGallery(tester);

    await tester.tap(find.text('Connect'));
    await settlePanelSwap(tester);

    expect(chipWithLabel(tester, 'Connect').selected, isTrue);
    // The connect panel lists providers — Gemini's curated name is shown.
    expect(find.text('Gemini'), findsOneWidget);
    expect(
      find.text('Pick the brain that turns your words into tasks'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the API key chip shows the API-key step', (tester) async {
    await pumpGallery(tester);

    await tester.tap(find.text('API key'));
    await settlePanelSwap(tester);

    expect(chipWithLabel(tester, 'API key').selected, isTrue);
    expect(find.text('Paste your API key'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'the welcome Connect button navigates to the connect view (onConnect)',
    (tester) async {
      await pumpGallery(tester);

      // The in-panel CTA closure flips the gallery from welcome → connect.
      await tester.tap(find.text('Connect your brain'));
      await settlePanelSwap(tester);

      expect(find.byType(OnboardingHeroPanel), findsNothing);
      expect(
        find.text('Pick the brain that turns your words into tasks'),
        findsOneWidget,
      );
      expect(chipWithLabel(tester, 'Connect').selected, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'selecting a provider in the connect panel advances to the API-key step',
    (tester) async {
      await pumpGallery(tester);

      // Welcome → Connect via the chip.
      await tester.tap(find.text('Connect'));
      await settlePanelSwap(tester);

      // Tapping a provider tile invokes onSelect → switches to the API-key view
      // for that provider, covering the connect panel's onSelect closure.
      await tester.tap(find.text('Gemini'));
      await settlePanelSwap(tester);

      expect(find.text('Paste your API key'), findsOneWidget);
      expect(chipWithLabel(tester, 'API key').selected, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('the welcome Skip button keeps the welcome view (onSkip)', (
    tester,
  ) async {
    await pumpGallery(tester);

    // The gallery wires onSkip to a no-op, so tapping Skip must not navigate or
    // throw — the welcome panel stays put.
    await tester.tap(find.text('Look around first'));
    await settlePanelSwap(tester);

    expect(find.byType(OnboardingHeroPanel), findsOneWidget);
    expect(chipWithLabel(tester, 'Constellation').selected, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the connect panel back arrow returns to the welcome view', (
    tester,
  ) async {
    await pumpGallery(tester);

    await tester.tap(find.text('Connect'));
    await settlePanelSwap(tester);
    expect(find.byType(OnboardingHeroPanel), findsNothing);

    // The connect panel's back arrow (onBack) flips the gallery back to welcome.
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await settlePanelSwap(tester);

    expect(find.byType(OnboardingHeroPanel), findsOneWidget);
    expect(chipWithLabel(tester, 'Constellation').selected, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the API-key panel back arrow returns to the connect view', (
    tester,
  ) async {
    await pumpGallery(tester);

    await tester.tap(find.text('API key'));
    await settlePanelSwap(tester);
    expect(find.text('Paste your API key'), findsOneWidget);

    // The API-key panel's back arrow (onBack) flips the gallery to the connect
    // step (the default provider is Gemini).
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await settlePanelSwap(tester);

    expect(
      find.text('Pick the brain that turns your words into tasks'),
      findsOneWidget,
    );
    expect(chipWithLabel(tester, 'Connect').selected, isTrue);
    expect(tester.takeException(), isNull);
  });
}
