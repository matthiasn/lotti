import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/services/connection_verifier_service.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_api_key_panel.dart';

import '../../../../widget_test_utils.dart';

/// Canned [ConnectionProbe] so verification resolves deterministically without
/// touching the network — the real probes hit the provider's `/models`
/// endpoint, which we never want in a widget test.
class _FakeProbe extends ConnectionProbe {
  _FakeProbe(this.result);

  final ConnectionCheckState result;

  @override
  Future<ConnectionCheckState> probe({
    required Uri baseUri,
    required String apiKey,
    required Duration timeout,
    required http.Client client,
  }) async => result;
}

void main() {
  // Reduced motion so the constellation/aurora controllers stop and the panel
  // settles deterministically.
  const mq = MediaQueryData(size: Size(390, 844), disableAnimations: true);

  Future<void> pumpPanel(
    WidgetTester tester, {
    required InferenceProviderType type,
    ConnectionCheckState? probeResult,
    VoidCallback? onConnected,
    VoidCallback? onBack,
  }) async {
    await tester.pumpWidget(
      makeTestableWidget(
        Material(
          type: MaterialType.transparency,
          child: OnboardingApiKeyPanel(
            type: type,
            onBack: onBack ?? () {},
            onConnected: onConnected ?? () {},
          ),
        ),
        mediaQueryData: mq,
        overrides: [
          // Never construct a real HttpClient in the verifier (the fake probe
          // ignores it, but the default factory would still create one).
          connectionVerifierClientProvider.overrideWith(
            (ref) =>
                () => MockClient((_) async => http.Response('', 200)),
          ),
          if (probeResult != null)
            connectionProbeRegistryProvider.overrideWith(
              (ref) => {type: _FakeProbe(probeResult)},
            ),
        ],
      ),
    );
    await tester.pump();
  }

  /// Enters [key] and advances past the debounce, the probe, and the minimum
  /// "checking" dwell so the canned probe result is reflected in the UI.
  Future<void> enterKeyAndSettle(WidgetTester tester, String key) async {
    await tester.enterText(find.byType(TextField), key);
    await tester.pump(); // process onChanged → schedule debounce
    await tester.pump(const Duration(milliseconds: 900)); // debounce → checking
    await tester.pump(); // probe resolves → parked behind the dwell
    await tester.pump(
      const Duration(milliseconds: 1100),
    ); // dwell → apply result
    await tester.pumpAndSettle(); // settle the status crossfade
  }

  /// The Connect CTA's current `onPressed` — null means disabled.
  VoidCallback? connectOnPressed(WidgetTester tester) => tester
      .widget<DesignSystemButton>(find.byType(DesignSystemButton))
      .onPressed;

  testWidgets('idle key step shows a tappable "get a key" link', (
    tester,
  ) async {
    await pumpPanel(tester, type: InferenceProviderType.gemini);

    expect(
      find.textContaining('Get a key at aistudio.google.com'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.open_in_new_rounded), findsOneWidget);
    // Nothing verified yet → Connect is disabled.
    expect(connectOnPressed(tester), isNull);
  });

  testWidgets('a valid key verifies, shows confirmation, enables Connect', (
    tester,
  ) async {
    await pumpPanel(
      tester,
      type: InferenceProviderType.gemini,
      probeResult: const ConnectionCheckVerified(
        modelCount: 12,
        latency: Duration(milliseconds: 120),
      ),
    );
    expect(connectOnPressed(tester), isNull);

    await enterKeyAndSettle(tester, 'good-key');

    expect(find.text('Connection verified'), findsOneWidget);
    // The "get a key" link gives way to the live status once a probe resolves.
    expect(find.textContaining('Get a key at'), findsNothing);
    // Verified → Connect is now enabled.
    expect(connectOnPressed(tester), isNotNull);
  });

  testWidgets('a rejected key shows the error and keeps Connect disabled', (
    tester,
  ) async {
    var connected = false;
    await pumpPanel(
      tester,
      type: InferenceProviderType.gemini,
      onConnected: () => connected = true,
      probeResult: const ConnectionCheckFailedHttp(
        status: 401,
        message: 'Invalid API key provided',
      ),
    );

    await enterKeyAndSettle(tester, 'bad-key');

    expect(find.text('Invalid API key provided'), findsOneWidget);
    // Rejected → Connect stays disabled; tapping it cannot connect.
    expect(connectOnPressed(tester), isNull);
    await tester.tap(find.text('Connect'), warnIfMissed: false);
    await tester.pump();
    expect(connected, isFalse);
  });

  testWidgets('checking stays visible for the minimum dwell', (tester) async {
    await pumpPanel(
      tester,
      type: InferenceProviderType.gemini,
      probeResult: const ConnectionCheckFailedHttp(
        status: 401,
        message: 'Invalid API key provided',
      ),
    );

    await tester.enterText(find.byType(TextField), 'bad-key');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900)); // debounce → checking
    await tester.pump(); // probe resolves immediately, but the result is parked

    // Before the dwell elapses the "checking" line is still shown, not the
    // (already-resolved) rejection.
    expect(find.textContaining('Checking key'), findsOneWidget);
    expect(find.text('Invalid API key provided'), findsNothing);

    // Once the dwell elapses the held result appears.
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pumpAndSettle();
    expect(find.textContaining('Checking key'), findsNothing);
    expect(find.text('Invalid API key provided'), findsOneWidget);
  });

  testWidgets('typing clears a prior rejection (neutral while editing)', (
    tester,
  ) async {
    await pumpPanel(
      tester,
      type: InferenceProviderType.gemini,
      probeResult: const ConnectionCheckFailedHttp(
        status: 401,
        message: 'Invalid API key provided',
      ),
    );
    await enterKeyAndSettle(tester, 'bad-key');
    expect(find.text('Invalid API key provided'), findsOneWidget);

    // Editing the key clears the stale rejection (it crossfades out) rather
    // than leaving it on screen between keystrokes.
    await tester.enterText(find.byType(TextField), 'bad-key2');
    await tester.pump(); // rebuild → start the crossfade
    await tester.pump(const Duration(milliseconds: 300)); // advance past it
    expect(find.text('Invalid API key provided'), findsNothing);

    // Clear the field so the pending debounce timer doesn't outlive the test.
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
  });

  testWidgets('local provider needs no key and probes on open', (tester) async {
    await pumpPanel(
      tester,
      type: InferenceProviderType.ollama,
      probeResult: const ConnectionCheckVerified(
        modelCount: 3,
        latency: Duration(milliseconds: 8),
      ),
    );
    // initState fires the reachability probe post-frame; advance past the
    // probe and the minimum checking dwell.
    await tester.pump(); // probe resolves → parked behind the dwell
    await tester.pump(const Duration(milliseconds: 1100)); // dwell → result
    await tester.pumpAndSettle();

    expect(find.text('Runs on your device — no key needed.'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Connection verified'), findsOneWidget);
  });

  testWidgets('back arrow invokes onBack', (tester) async {
    var backed = false;
    await pumpPanel(
      tester,
      type: InferenceProviderType.gemini,
      onBack: () => backed = true,
    );

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pump();

    expect(backed, isTrue);
  });
}
