import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/ui/settings/services/connection_verifier_service.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_api_key_panel.dart';
import 'package:mocktail/mocktail.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
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

/// A probe whose result is supplied later via [completer], so a test can let
/// the "checking" dwell elapse *before* the probe resolves.
class _DeferredProbe extends ConnectionProbe {
  final completer = Completer<ConnectionCheckState>();

  @override
  Future<ConnectionCheckState> probe({
    required Uri baseUri,
    required String apiKey,
    required Duration timeout,
    required http.Client client,
  }) => completer.future;
}

void main() {
  setUpAll(registerAllFallbackValues);

  // Reduced motion so the constellation/aurora controllers stop and the panel
  // settles deterministically.
  const mq = MediaQueryData(size: Size(390, 844), disableAnimations: true);

  Future<void> pumpPanel(
    WidgetTester tester, {
    required InferenceProviderType type,
    ConnectionCheckState? probeResult,
    VoidCallback? onConnected,
    VoidCallback? onBack,
    List<Override> extraOverrides = const [],
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
          ...extraOverrides,
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
    await tester.pump(const Duration(milliseconds: 1100)); // dwell → result
    await tester.pumpAndSettle(); // settle the status crossfade
  }

  /// The Connect CTA's current `onPressed` — null means disabled.
  VoidCallback? connectOnPressed(WidgetTester tester) => tester
      .widget<DesignSystemButton>(find.byType(DesignSystemButton))
      .onPressed;

  const verified = ConnectionCheckVerified(
    modelCount: 12,
    latency: Duration(milliseconds: 120),
  );

  testWidgets('idle key step shows a tappable "get a key" link, Connect off', (
    tester,
  ) async {
    await pumpPanel(tester, type: InferenceProviderType.gemini);

    expect(
      find.textContaining('Get a key at aistudio.google.com'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.open_in_new_rounded), findsOneWidget);
    expect(connectOnPressed(tester), isNull);
    // The disabled CTA narrates why it's inert at rest.
    expect(find.text('Enter a valid key to continue.'), findsOneWidget);
  });

  testWidgets('the button shows Verifying… while a probe is in flight', (
    tester,
  ) async {
    final probe = _DeferredProbe();
    await pumpPanel(
      tester,
      type: InferenceProviderType.gemini,
      extraOverrides: [
        connectionProbeRegistryProvider.overrideWith(
          (ref) => {InferenceProviderType.gemini: probe},
        ),
      ],
    );

    await tester.enterText(find.byType(TextField), 'some-key');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900)); // debounce → checking

    // Probe still pending → the gate narrates as Verifying… and stays disabled.
    expect(find.text('Verifying…'), findsOneWidget);
    expect(connectOnPressed(tester), isNull);
    // The at-rest hint gives way to the live status.
    expect(find.text('Enter a valid key to continue.'), findsNothing);

    probe.completer.complete(
      const ConnectionCheckVerified(
        modelCount: 3,
        latency: Duration(milliseconds: 5),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1100)); // dwell → result
    await tester.pumpAndSettle();
    expect(connectOnPressed(tester), isNotNull);
  });

  testWidgets('a valid key verifies, confirms, and enables Connect', (
    tester,
  ) async {
    await pumpPanel(
      tester,
      type: InferenceProviderType.gemini,
      probeResult: verified,
    );
    expect(connectOnPressed(tester), isNull);

    await enterKeyAndSettle(tester, 'good-key');

    expect(find.text('Connection verified'), findsOneWidget);
    // The "get a key" guidance is persistent now (no longer in the status
    // slot), so it stays visible alongside the verified status.
    expect(find.textContaining('Get a key at'), findsOneWidget);
    expect(connectOnPressed(tester), isNotNull);
  });

  testWidgets('a rejected key shows a clean message and keeps Connect off', (
    tester,
  ) async {
    var connected = false;
    await pumpPanel(
      tester,
      type: InferenceProviderType.gemini,
      onConnected: () => connected = true,
      // The provider's raw body (JSON / echoes the key) must NOT be shown.
      probeResult: const ConnectionCheckFailedHttp(
        status: 401,
        message: '{"error":{"message":"Incorrect API key provided: sk-bad"}}',
      ),
    );

    await enterKeyAndSettle(tester, 'bad-key');

    expect(find.textContaining('That key was rejected'), findsOneWidget);
    expect(find.textContaining('sk-bad'), findsNothing); // never echo the key
    expect(connectOnPressed(tester), isNull);
    await tester.tap(find.text('Connect'), warnIfMissed: false);
    await tester.pump();
    expect(connected, isFalse);
  });

  testWidgets('a non-auth HTTP failure shows the unreachable message', (
    tester,
  ) async {
    await pumpPanel(
      tester,
      type: InferenceProviderType.gemini,
      probeResult: const ConnectionCheckFailedHttp(
        status: 500,
        message: 'oops',
      ),
    );

    await enterKeyAndSettle(tester, 'some-key');

    expect(find.textContaining("Couldn't reach Gemini"), findsOneWidget);
    expect(connectOnPressed(tester), isNull);
  });

  testWidgets('a network failure shows the unreachable message', (
    tester,
  ) async {
    await pumpPanel(
      tester,
      type: InferenceProviderType.gemini,
      probeResult: const ConnectionCheckFailedNetwork(
        message: 'SocketException',
        code: ConnectionFailureCode.timeout,
      ),
    );

    await enterKeyAndSettle(tester, 'some-key');

    expect(find.textContaining("Couldn't reach Gemini"), findsOneWidget);
  });

  testWidgets('checking stays visible for the minimum dwell', (tester) async {
    await pumpPanel(
      tester,
      type: InferenceProviderType.gemini,
      probeResult: const ConnectionCheckFailedHttp(status: 401, message: ''),
    );

    await tester.enterText(find.byType(TextField), 'bad-key');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900)); // debounce → checking
    await tester.pump(); // probe resolves immediately, but the result is parked

    // Before the dwell elapses the "checking" line is still shown, not the
    // (already-resolved) rejection.
    expect(find.textContaining('Checking key'), findsOneWidget);
    expect(find.textContaining('That key was rejected'), findsNothing);

    // Once the dwell elapses the held result appears.
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pumpAndSettle();
    expect(find.textContaining('Checking key'), findsNothing);
    expect(find.textContaining('That key was rejected'), findsOneWidget);
  });

  testWidgets('typing clears a prior rejection (neutral while editing)', (
    tester,
  ) async {
    await pumpPanel(
      tester,
      type: InferenceProviderType.gemini,
      probeResult: const ConnectionCheckFailedHttp(status: 401, message: ''),
    );
    await enterKeyAndSettle(tester, 'bad-key');
    expect(find.textContaining('That key was rejected'), findsOneWidget);

    // Editing the key clears the stale rejection (it crossfades out) rather
    // than leaving it on screen between keystrokes.
    await tester.enterText(find.byType(TextField), 'bad-key2');
    await tester.pump(); // rebuild → start the crossfade
    await tester.pump(const Duration(milliseconds: 300)); // advance past it
    expect(find.textContaining('That key was rejected'), findsNothing);

    // Clear the field so the pending debounce timer doesn't outlive the test.
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
  });

  testWidgets('a verified key creates the provider and connects', (
    tester,
  ) async {
    final repo = MockAiConfigRepository();
    when(() => repo.saveConfig(any())).thenAnswer((_) async {});
    var connected = false;

    await pumpPanel(
      tester,
      // genericOpenAi requires a key and has a probe, but is not wired into
      // runFtueSetupForType (→ null), so the success path runs end-to-end
      // without invoking a real per-provider setup.
      type: InferenceProviderType.genericOpenAi,
      onConnected: () => connected = true,
      probeResult: verified,
      extraOverrides: [aiConfigRepositoryProvider.overrideWith((ref) => repo)],
    );

    await enterKeyAndSettle(tester, 'good-key');
    expect(connectOnPressed(tester), isNotNull);

    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();

    verify(() => repo.saveConfig(any())).called(1);
    expect(connected, isTrue);
  });

  testWidgets('a failed save surfaces the connect error and does not connect', (
    tester,
  ) async {
    final repo = MockAiConfigRepository();
    when(() => repo.saveConfig(any())).thenThrow(Exception('boom'));
    var connected = false;

    await pumpPanel(
      tester,
      type: InferenceProviderType.gemini,
      onConnected: () => connected = true,
      probeResult: verified,
      extraOverrides: [aiConfigRepositoryProvider.overrideWith((ref) => repo)],
    );

    await enterKeyAndSettle(tester, 'good-key');
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();

    expect(
      find.text("Couldn't connect. Check your key and try again."),
      findsOneWidget,
    );
    expect(connected, isFalse);
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

  testWidgets('a result resolving after the dwell is applied immediately', (
    tester,
  ) async {
    final probe = _DeferredProbe();
    await pumpPanel(
      tester,
      type: InferenceProviderType.gemini,
      extraOverrides: [
        connectionProbeRegistryProvider.overrideWith(
          (ref) => {InferenceProviderType.gemini: probe},
        ),
      ],
    );

    await tester.enterText(find.byType(TextField), 'slow-key');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900)); // debounce → checking
    // Let the dwell fully elapse while the probe is still pending.
    await tester.pump(const Duration(milliseconds: 1100));
    expect(find.textContaining('Checking key'), findsOneWidget);

    // Probe now resolves — past the dwell, so it applies without parking.
    probe.completer.complete(verified);
    await tester.pumpAndSettle();
    expect(find.text('Connection verified'), findsOneWidget);
    expect(connectOnPressed(tester), isNotNull);
  });

  testWidgets('Enter forces an immediate check when not yet verified', (
    tester,
  ) async {
    await pumpPanel(
      tester,
      type: InferenceProviderType.gemini,
      probeResult: verified,
    );

    await tester.enterText(find.byType(TextField), 'good-key');
    // Submit before the debounce fires — should verify immediately.
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(); // checking
    await tester.pump(); // probe resolves → parked
    await tester.pump(const Duration(milliseconds: 1100)); // dwell → result
    await tester.pumpAndSettle();

    expect(find.text('Connection verified'), findsOneWidget);
  });

  testWidgets('Enter connects when already verified', (tester) async {
    final repo = MockAiConfigRepository();
    when(() => repo.saveConfig(any())).thenAnswer((_) async {});
    var connected = false;

    await pumpPanel(
      tester,
      type: InferenceProviderType.genericOpenAi,
      onConnected: () => connected = true,
      probeResult: verified,
      extraOverrides: [aiConfigRepositoryProvider.overrideWith((ref) => repo)],
    );

    await enterKeyAndSettle(tester, 'good-key');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(connected, isTrue);
  });

  testWidgets('the "get a key" link launches the provider console', (
    tester,
  ) async {
    final original = UrlLauncherPlatform.instance;
    final launcher = MockUrlLauncher();
    UrlLauncherPlatform.instance = launcher;
    // FakeLaunchOptions fallback is registered centrally via
    // registerAllFallbackValues() in setUpAll.
    when(() => launcher.launchUrl(any(), any())).thenAnswer((_) async => true);
    addTearDown(() => UrlLauncherPlatform.instance = original);

    await pumpPanel(tester, type: InferenceProviderType.gemini);

    await tester.tap(find.byIcon(Icons.open_in_new_rounded));
    await tester.pump();

    verify(
      () => launcher.launchUrl('https://aistudio.google.com', any()),
    ).called(1);
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
