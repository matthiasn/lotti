import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/services/connection_verifier_service.dart';
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
          if (probeResult != null)
            connectionProbeRegistryProvider.overrideWith(
              (ref) => {type: _FakeProbe(probeResult)},
            ),
        ],
      ),
    );
    await tester.pump();
  }

  /// Enters [key] and advances past the verification debounce so the canned
  /// probe result is reflected in the UI.
  Future<void> enterKeyAndSettle(WidgetTester tester, String key) async {
    await tester.enterText(find.byType(TextField), key);
    await tester.pump(); // process onChanged → schedule debounce
    await tester.pump(const Duration(milliseconds: 600)); // fire debounce timer
    await tester.pump(); // resolve probe future → rebuild
  }

  testWidgets('idle key step shows a tappable "get a key" link', (
    tester,
  ) async {
    await pumpPanel(tester, type: InferenceProviderType.gemini);

    expect(
      find.textContaining('Get a key at aistudio.google.com'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.open_in_new_rounded), findsOneWidget);
  });

  testWidgets('a valid key verifies and shows the confirmation', (
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

    await enterKeyAndSettle(tester, 'good-key');

    expect(find.text('Connection verified'), findsOneWidget);
    // The "get a key" link gives way to the live status once a probe resolves.
    expect(find.textContaining('Get a key at'), findsNothing);
  });

  testWidgets('an invalid key surfaces the provider rejection inline', (
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
  });

  testWidgets('pressing Connect with an unverified key does not connect', (
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

    // Tap Connect before the debounce fires: _connect must verify first and
    // bail on rejection rather than creating a half-working provider.
    await tester.enterText(find.byType(TextField), 'bad-key');
    await tester.pump();
    await tester.tap(find.text('Connect'));
    await tester.pump(); // _connect sets busy + starts verify
    await tester.pump(); // probe resolves → rejection

    expect(connected, isFalse);
    expect(find.text('Invalid API key provided'), findsOneWidget);
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
    // initState fires the reachability probe post-frame; let it resolve.
    await tester.pump();
    await tester.pump();

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
