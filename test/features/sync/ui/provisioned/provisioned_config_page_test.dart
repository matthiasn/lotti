import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/progress_bars/design_system_progress_bar.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/features/sync/models/sync_device_info.dart';
import 'package:lotti/features/sync/state/matrix_unverified_provider.dart';
import 'package:lotti/features/sync/state/matrix_verification_modal_lock_provider.dart';
import 'package:lotti/features/sync/state/matrix_verification_relaunch_provider.dart';
import 'package:lotti/features/sync/state/provisioning_controller.dart';
import 'package:lotti/features/sync/state/provisioning_error.dart';
import 'package:lotti/features/sync/state/sync_devices_provider.dart';
import 'package:lotti/features/sync/ui/provisioned/bundle_import_page.dart';
import 'package:lotti/features/sync/ui/provisioned/provisioned_config_page.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/verification_modal.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import 'provisioned_status_page_test_helpers.dart';

/// Holds the app-wide modal lock so `AutoVerificationLauncher` yields instead
/// of opening a sheet over the widget under test.
class _PreAcquiredLock extends MatrixVerificationModalLock {
  @override
  bool build() => true;
}

/// A fake provisioning controller that provides a fixed state.
class _FakeProvisioningController extends ProvisioningController {
  _FakeProvisioningController(this.initialState, {this.rotates = false});

  final ProvisioningState initialState;

  /// Stands in for the bundle kind the real controller derives this from.
  final bool rotates;

  /// How often the bar's Retry invoked the controller.
  int retryCalls = 0;

  @override
  ProvisioningState build() => initialState;

  @override
  bool get rotatesPassword => rotates;

  @override
  Future<void> retry() async {
    retryCalls++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMatrixService mockMatrixService;
  late ValueNotifier<int> pageIndexNotifier;

  /// A peer awaiting the emoji ceremony. The launcher keys devices by
  /// `(userId, deviceId)`, so both have to be stubbed.
  MockDeviceKeys unverifiedPeer() {
    final keys = MockDeviceKeys();
    when(() => keys.deviceId).thenReturn('PEERDEVICE');
    when(() => keys.userId).thenReturn('@alice:example.com');
    when(() => keys.deviceDisplayName).thenReturn('Peer');
    return keys;
  }

  const testBundle = SyncProvisioningBundle(
    v: 2,
    kind: SyncBundleKind.provisioned,
    homeServer: 'https://matrix.example.com',
    user: '@alice:example.com',
    password: 'secret123',
    roomId: '!room123:example.com',
  );

  setUpAll(() {
    registerFallbackValue(
      const MatrixConfig(homeServer: '', user: '', password: ''),
    );
  });

  setUp(() {
    mockMatrixService = MockMatrixService();
    pageIndexNotifier = ValueNotifier(1);

    when(() => mockMatrixService.setConfig(any())).thenAnswer((_) async {});
    when(
      () => mockMatrixService.login(
        waitForLifecycle: any(named: 'waitForLifecycle'),
      ),
    ).thenAnswer((_) async => true);
    when(
      () => mockMatrixService.joinRoom(any()),
    ).thenAnswer((_) async => '!room:example.com');
    when(() => mockMatrixService.saveRoom(any())).thenAnswer((_) async {});
    when(() => mockMatrixService.clearPersistedRoom()).thenAnswer((_) async {});
    when(
      () => mockMatrixService.getRoom(),
    ).thenAnswer((_) async => '!room:example.com');
    when(
      () => mockMatrixService.changePassword(
        oldPassword: any(named: 'oldPassword'),
        newPassword: any(named: 'newPassword'),
      ),
    ).thenAnswer((_) async {});
    when(() => mockMatrixService.loadConfig()).thenAnswer(
      (_) async => const MatrixConfig(
        homeServer: 'https://matrix.example.com',
        user: '@alice:example.com',
        password: 'secret123',
      ),
    );
    when(() => mockMatrixService.getUnverifiedDevices()).thenReturn([]);
    when(
      () => mockMatrixService.keyVerificationStream,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => mockMatrixService.incomingKeyVerificationRunnerStream,
    ).thenAnswer((_) => const Stream.empty());
  });

  tearDown(() {
    pageIndexNotifier.dispose();
  });

  /// Pumps the widget under test with the standard matrix-service
  /// override and the provisioning controller seeded to [state].
  Future<void> pumpConfigWidget(
    WidgetTester tester,
    ProvisioningState state, {
    List<Override> extraOverrides = const [],
    bool rotates = false,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        ProvisionedConfigWidget(pageIndexNotifier: pageIndexNotifier),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
          provisioningControllerProvider.overrideWith(
            () => _FakeProvisioningController(state, rotates: rotates),
          ),
          ...extraOverrides,
        ],
      ),
    );
    await tester.pump();
  }

  group('ProvisionedConfigWidget', () {
    testWidgets('shows spinner when in initial state', (tester) async {
      await pumpConfigWidget(
        tester,
        const ProvisioningState.initial(),
      );

      expect(find.byType(DesignSystemSpinner), findsOneWidget);
    });

    testWidgets('shows spinner when in bundleDecoded state', (tester) async {
      await pumpConfigWidget(
        tester,
        const ProvisioningState.bundleDecoded(testBundle),
      );

      expect(find.byType(DesignSystemSpinner), findsOneWidget);
    });

    testWidgets('shows progress when in loggingIn state', (tester) async {
      await pumpConfigWidget(
        tester,
        const ProvisioningState.loggingIn(),
      );

      final context = tester.element(find.byType(ProvisionedConfigWidget));
      expect(
        find.text(context.messages.provisionedSyncLoggingIn),
        findsOneWidget,
      );
      expect(find.byType(DesignSystemSpinner), findsOneWidget);
      // One indicator: the determinate bar under the spinner mapped internal
      // phases onto a fraction the step eyebrow already carried, so the
      // screen showed two disagreeing measures of the same wait.
      expect(find.byType(DesignSystemProgressBar), findsNothing);
    });

    testWidgets('shows progress when in joiningRoom state', (tester) async {
      await pumpConfigWidget(
        tester,
        const ProvisioningState.joiningRoom(),
      );

      final context = tester.element(find.byType(ProvisionedConfigWidget));
      expect(
        find.text(context.messages.provisionedSyncJoiningRoom),
        findsOneWidget,
      );
    });

    testWidgets('shows progress when in rotatingPassword state', (
      tester,
    ) async {
      await pumpConfigWidget(
        tester,
        const ProvisioningState.rotatingPassword(),
      );

      final context = tester.element(find.byType(ProvisionedConfigWidget));
      expect(
        find.text(context.messages.provisionedSyncRotatingPassword),
        findsOneWidget,
      );
      expect(find.byType(DesignSystemSpinner), findsOneWidget);
      expect(find.byType(DesignSystemProgressBar), findsNothing);
    });

    testWidgets(
      'does not auto-advance on mobile when verification completes',
      (tester) async {
        final wasDesktop = isDesktop;
        isDesktop = false;
        addTearDown(() => isDesktop = wasDesktop);

        final keyVerification = MockKeyVerification();
        final runner = MockKeyVerificationRunner();
        final outgoingController =
            StreamController<KeyVerificationRunner>.broadcast();
        addTearDown(outgoingController.close);

        when(() => keyVerification.isDone).thenReturn(true);
        when(() => runner.lastStep).thenReturn('m.key.verification.done');
        when(() => runner.keyVerification).thenReturn(keyVerification);
        when(
          () => mockMatrixService.keyVerificationStream,
        ).thenAnswer((_) => outgoingController.stream);
        when(() => mockMatrixService.getUnverifiedDevices()).thenReturn([]);

        await pumpConfigWidget(
          tester,
          const ProvisioningState.ready('dGVzdC1oYW5kb3Zlci1kYXRh'),
        );

        outgoingController.add(runner);
        await tester.pump(const Duration(seconds: 2));

        // Should not auto-advance on mobile
        expect(pageIndexNotifier.value, 1);
      },
    );

    testWidgets('shows success when in done state', (tester) async {
      await pumpConfigWidget(
        tester,
        const ProvisioningState.done(),
      );

      final context = tester.element(find.byType(ProvisionedConfigWidget));
      expect(
        find.text(context.messages.provisionedSyncDone),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets(
      'auto-triggers verification modal when unverified devices exist',
      (tester) async {
        final mockDevice = MockDeviceKeys();
        when(() => mockDevice.deviceDisplayName).thenReturn('Other Device');
        when(() => mockDevice.deviceId).thenReturn('OTHERDEVICE');
        when(() => mockDevice.userId).thenReturn('@alice:example.com');

        when(
          () => mockMatrixService.getUnverifiedDevices(),
        ).thenReturn([mockDevice]);
        when(
          () => mockMatrixService.verifyDevice(mockDevice),
        ).thenAnswer((_) async {});
        when(
          () => mockMatrixService.keyVerificationStream,
        ).thenAnswer((_) => const Stream.empty());

        await pumpConfigWidget(
          tester,
          const ProvisioningState.done(),
        );

        // Before the 3s delay, no modal should be shown
        expect(find.byType(VerificationModal), findsNothing);

        // Advance past the 3 second delay
        await tester.pump(const Duration(seconds: 3));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // VerificationModal should be displayed in a bottom sheet
        expect(find.byType(VerificationModal), findsOneWidget);
      },
    );

    testWidgets(
      'does not trigger verification when no unverified devices',
      (tester) async {
        when(() => mockMatrixService.getUnverifiedDevices()).thenReturn([]);

        await pumpConfigWidget(
          tester,
          const ProvisioningState.done(),
        );

        // Advance past the 3 second delay
        await tester.pump(const Duration(seconds: 3));
        await tester.pump();

        // No verification modal should be shown
        expect(find.byType(VerificationModal), findsNothing);
      },
    );

    testWidgets('shows the error card without its own button', (tester) async {
      await pumpConfigWidget(
        tester,
        const ProvisioningState.error(ProvisioningError.loginFailed),
      );

      final context = tester.element(find.byType(ProvisionedConfigWidget));
      expect(
        find.text(context.messages.provisionedSyncError),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.provisionedSyncErrorLoginFailed),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      // The remedy lives in the sticky bar's accent slot — the position the
      // rest of the wizard trained the user on — not as a grey pill inside
      // the card.
      expect(
        find.text(context.messages.provisionedSyncRetry),
        findsNothing,
      );
    });

    testWidgets(
      'shows configuration error message for configurationError',
      (tester) async {
        await pumpConfigWidget(
          tester,
          const ProvisioningState.error(
            ProvisioningError.configurationError,
          ),
        );

        final context = tester.element(find.byType(ProvisionedConfigWidget));
        expect(
          find.text(context.messages.provisionedSyncErrorConfigurationFailed),
          findsOneWidget,
        );
      },
    );

    testWidgets('the bar retry invokes the controller in error state', (
      tester,
    ) async {
      final controller = _FakeProvisioningController(
        const ProvisioningState.error(ProvisioningError.loginFailed),
      );
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          _ConfigActionBarTestWrapper(pageIndexNotifier: pageIndexNotifier),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
            provisioningControllerProvider.overrideWith(() => controller),
          ],
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('provisioned_config_retry')));
      await tester.pump();
      expect(controller.retryCalls, 1);
    });

    void expectNextSteps(WidgetTester tester) {
      final context = tester.element(find.byType(ProvisionedConfigWidget));
      expect(find.text(context.messages.syncPairedVerifyStep), findsOneWidget);
      expect(
        find.text(context.messages.syncPairedSettingsStep),
        findsOneWidget,
      );
      // The handover QR belongs to "Add device" on the roster now; showing one
      // here handed the user a code seconds after they had scanned one.
      expect(find.byKey(const Key('provisionedQrImage')), findsNothing);
      expect(find.text('dGVzdC1oYW5kb3Zlci1kYXRh'), findsNothing);
    }

    testWidgets('the ready state ends a first-device setup, not a handover', (
      tester,
    ) async {
      // `ready` follows a fresh CLI bundle, so this is usually the only device
      // on the account: telling it to compare emoji with a peer and to go
      // press Send settings on another device names two steps that cannot be
      // performed. `done` — a peer handover — is the state that can.
      await pumpConfigWidget(
        tester,
        const ProvisioningState.ready('dGVzdC1oYW5kb3Zlci1kYXRh'),
      );

      final context = tester.element(find.byType(ProvisionedConfigWidget));
      expect(find.byKey(const Key('paired_first_device')), findsOneWidget);
      expect(
        find.text(context.messages.syncPairedFirstDeviceTitle),
        findsOneWidget,
      );
      expect(find.text(context.messages.syncPairedVerifyStep), findsNothing);
      expect(
        find.text(context.messages.syncPairedSettingsStep),
        findsNothing,
      );
      // And still no second QR handed to a device that just consumed one.
      expect(find.byKey(const Key('provisionedQrImage')), findsNothing);
      expect(find.text('dGVzdC1oYW5kb3Zlci1kYXRh'), findsNothing);
      expect(find.text(context.messages.syncPairStepDone), findsOneWidget);
    });

    testWidgets('the done state renders next steps', (tester) async {
      await pumpConfigWidget(tester, const ProvisioningState.done());
      expectNextSteps(tester);
    });

    testWidgets('says where in the journey this screen sits', (tester) async {
      // The scan and confirm screens carry the same line; without it the
      // device with the least context never learned how much was left.
      await pumpConfigWidget(tester, const ProvisioningState.done());

      final context = tester.element(find.byType(ProvisionedConfigWidget));
      expect(find.byType(SyncPairStepIndicator), findsOneWidget);
      expect(find.text(context.messages.syncPairStepAlmost), findsOneWidget);
    });

    testWidgets('the page lead holds the only title rank', (
      tester,
    ) async {
      await pumpConfigWidget(tester, const ProvisioningState.done());

      final context = tester.element(find.byType(ProvisionedConfigWidget));
      final tokens = context.designTokens;
      final done = tester.widget<Text>(
        find.text(context.messages.provisionedSyncDone),
      );
      final step = tester.widget<Text>(
        find.text(context.messages.syncPairedVerifyStep),
      );

      // The lead carries the page's one title; the card's meta-title
      // ("Two things left") is gone, so its steps sit at body rank and the
      // reader's first fixation lands on the actionable imperative.
      expect(
        done.style?.fontWeight,
        tokens.typography.styles.subtitle.subtitle1.fontWeight,
      );
      expect(
        done.style?.fontSize,
        tokens.typography.styles.subtitle.subtitle1.fontSize,
      );
      expect(
        step.style?.fontSize,
        tokens.typography.styles.body.bodyMedium.fontSize,
      );
    });

    testWidgets('names the remedy once a device is awaiting verification', (
      tester,
    ) async {
      await pumpConfigWidget(
        tester,
        const ProvisioningState.done(),
        extraOverrides: [
          matrixUnverifiedControllerProvider.overrideWith(
            () => FakeMatrixUnverifiedController([unverifiedPeer()]),
          ),
          // Otherwise the launcher opens the ceremony over the assertions.
          matrixVerificationModalLockProvider.overrideWith(
            _PreAcquiredLock.new,
          ),
        ],
      );

      expect(find.byKey(const Key('paired_verify_fallback')), findsOneWidget);
      expect(find.byKey(const Key('paired_verify_waiting')), findsNothing);
    });

    testWidgets('reports the ceremony as done once the peer is verified', (
      tester,
    ) async {
      // Absence from getUnverifiedDevices() means both "keys have not arrived"
      // and "the ceremony succeeded", so a two-branch version told a user who
      // had just matched the emoji that they were still waiting for it — on
      // the terminal screen of the whole flow.
      await pumpConfigWidget(
        tester,
        const ProvisioningState.done(),
        extraOverrides: [
          syncDevicesControllerProvider.overrideWith(
            () => FakeSyncDevicesController(const [
              SyncDeviceInfo(
                deviceId: 'THIS',
                isCurrentDevice: true,
                verified: true,
              ),
              SyncDeviceInfo(
                deviceId: 'PEER',
                isCurrentDevice: false,
                verified: true,
              ),
            ]),
          ),
        ],
      );
      await tester.pump();

      final context = tester.element(find.byType(ProvisionedConfigWidget));
      expect(find.byKey(const Key('paired_verify_done')), findsOneWidget);
      expect(find.byKey(const Key('paired_verify_waiting')), findsNothing);
      // Past tense in the step's own slot: appending a green row under a live
      // imperative left the screen asserting two opposite things about the
      // same fact, one line apart.
      expect(
        find.text(context.messages.syncPairedVerifyStepDone),
        findsOneWidget,
      );
      expect(find.text(context.messages.syncPairedVerifyStep), findsNothing);
      // The outstanding item leads and the finished one closes: a card that
      // opened with completed work spent the reader's first fixation on
      // nothing they could act on.
      expect(
        tester
            .getTopLeft(find.text(context.messages.syncPairedSettingsStep))
            .dy,
        lessThan(
          tester
              .getTopLeft(
                find.text(context.messages.syncPairedVerifyStepDone),
              )
              .dy,
        ),
      );

      // And the stall copy can no longer surface behind it.
      await tester.pump(kVerifyStallTimeout);
      await tester.pump();
      expect(find.byKey(const Key('paired_verify_fallback')), findsNothing);
    });

    testWidgets('an unverified peer still reads as outstanding, not done', (
      tester,
    ) async {
      await pumpConfigWidget(
        tester,
        const ProvisioningState.done(),
        extraOverrides: [
          syncDevicesControllerProvider.overrideWith(
            () => FakeSyncDevicesController(const [
              SyncDeviceInfo(
                deviceId: 'PEER',
                isCurrentDevice: false,
                verified: false,
              ),
            ]),
          ),
        ],
      );
      await tester.pump();

      expect(find.byKey(const Key('paired_verify_done')), findsNothing);
      expect(find.byKey(const Key('paired_verify_waiting')), findsOneWidget);
    });

    testWidgets('the stall remedy re-reads the trust state', (tester) async {
      // The ceremony completes out of band, so "nothing happened" and "it
      // worked and nobody told this screen" look identical until something
      // asks again.
      await pumpConfigWidget(tester, const ProvisioningState.done());
      await tester.pump(kVerifyStallTimeout);
      await tester.pump();

      await tester.ensureVisible(
        find.byKey(const Key('paired_verify_recheck')),
      );
      await tester.tap(find.byKey(const Key('paired_verify_recheck')));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('a dismissed prompt can be reopened, not merely re-queried', (
      tester,
    ) async {
      // The launcher fires once per device and its guard lives in its own
      // State, so the device staying unverified is exactly what keeps the
      // guard set — re-querying the providers can never bring the sheet back.
      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
            provisioningControllerProvider.overrideWith(
              () => _FakeProvisioningController(const ProvisioningState.done()),
            ),
            matrixUnverifiedControllerProvider.overrideWith(
              () => FakeMatrixUnverifiedController([unverifiedPeer()]),
            ),
            // Otherwise the launcher opens the ceremony over the button.
            matrixVerificationModalLockProvider.overrideWith(
              _PreAcquiredLock.new,
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: resolveTestTheme(),
            home: Consumer(
              builder: (ctx, ref, _) {
                container = ProviderScope.containerOf(ctx);
                return Scaffold(
                  body: ProvisionedConfigWidget(
                    pageIndexNotifier: pageIndexNotifier,
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final context = tester.element(find.byType(ProvisionedConfigWidget));
      final relaunch = find.byKey(const Key('paired_verify_recheck'));
      expect(
        tester.widget<DesignSystemButton>(relaunch).label,
        context.messages.syncPairShowEmojiAgain,
      );

      final before = container.read(matrixVerificationRelaunchProvider);
      await tester.ensureVisible(relaunch);
      await tester.tap(relaunch);
      await tester.pump();

      expect(
        container.read(matrixVerificationRelaunchProvider),
        greaterThan(before),
      );
    });

    testWidgets('a prompt that never arrives gets a remedy, not a spinner', (
      tester,
    ) async {
      // The one case where "keep waiting" is the wrong answer was also the
      // only case with nothing on screen but an indefinite spinner.
      await pumpConfigWidget(tester, const ProvisioningState.done());

      expect(find.byKey(const Key('paired_verify_waiting')), findsOneWidget);
      expect(find.byKey(const Key('paired_verify_fallback')), findsNothing);

      await tester.pump(kVerifyStallTimeout);
      await tester.pump();

      // The spinner stays — the ceremony may still arrive — but the way out
      // is now stated, and here re-querying *is* the right act: nothing was
      // dismissed, so there is nothing to reopen.
      final context = tester.element(find.byType(ProvisionedConfigWidget));
      expect(find.byKey(const Key('paired_verify_waiting')), findsOneWidget);
      expect(find.byKey(const Key('paired_verify_fallback')), findsOneWidget);
      expect(
        tester
            .widget<DesignSystemButton>(
              find.byKey(const Key('paired_verify_recheck')),
            )
            .label,
        context.messages.syncPairCheckAgain,
      );
    });
  });

  group('ConfigActionBar behavior', () {
    testWidgets(
      'next button is disabled when state is not complete',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            _ConfigActionBarTestWrapper(
              pageIndexNotifier: pageIndexNotifier,
            ),
            overrides: [
              matrixServiceProvider.overrideWithValue(mockMatrixService),
              provisioningControllerProvider.overrideWith(
                () => _FakeProvisioningController(
                  const ProvisioningState.loggingIn(),
                ),
              ),
            ],
          ),
        );
        await tester.pump();

        final context = tester.element(
          find.byType(_ConfigActionBarTestWrapper),
        );

        // Find the Next button (DesignSystemButton) - it should be disabled
        final nextButton = tester.widget<DesignSystemButton>(
          find.widgetWithText(
            DesignSystemButton,
            context.messages.syncPairGoToDevices,
          ),
        );
        expect(nextButton.onPressed, isNull);
      },
    );

    testWidgets(
      'next button is enabled when state is ready',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            _ConfigActionBarTestWrapper(
              pageIndexNotifier: pageIndexNotifier,
            ),
            overrides: [
              matrixServiceProvider.overrideWithValue(mockMatrixService),
              provisioningControllerProvider.overrideWith(
                () => _FakeProvisioningController(
                  const ProvisioningState.ready('handover-data'),
                ),
              ),
            ],
          ),
        );
        await tester.pump();

        final context = tester.element(
          find.byType(_ConfigActionBarTestWrapper),
        );

        final nextButton = tester.widget<DesignSystemButton>(
          find.widgetWithText(
            DesignSystemButton,
            context.messages.syncPairGoToDevices,
          ),
        );
        expect(nextButton.onPressed, isNotNull);
      },
    );

    testWidgets(
      'next button navigates to page 2 when tapped in ready state',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            _ConfigActionBarTestWrapper(
              pageIndexNotifier: pageIndexNotifier,
            ),
            overrides: [
              matrixServiceProvider.overrideWithValue(mockMatrixService),
              provisioningControllerProvider.overrideWith(
                () => _FakeProvisioningController(
                  const ProvisioningState.ready('handover-data'),
                ),
              ),
            ],
          ),
        );
        await tester.pump();

        final context = tester.element(
          find.byType(_ConfigActionBarTestWrapper),
        );
        await tester.tap(
          find.text(context.messages.syncPairGoToDevices),
        );
        await tester.pump();

        expect(pageIndexNotifier.value, 2);
      },
    );

    testWidgets(
      'next button is enabled when state is done',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            _ConfigActionBarTestWrapper(
              pageIndexNotifier: pageIndexNotifier,
            ),
            overrides: [
              matrixServiceProvider.overrideWithValue(mockMatrixService),
              provisioningControllerProvider.overrideWith(
                () => _FakeProvisioningController(
                  const ProvisioningState.done(),
                ),
              ),
            ],
          ),
        );
        await tester.pump();

        final context = tester.element(
          find.byType(_ConfigActionBarTestWrapper),
        );

        final nextButton = tester.widget<DesignSystemButton>(
          find.widgetWithText(
            DesignSystemButton,
            context.messages.syncPairGoToDevices,
          ),
        );
        expect(nextButton.onPressed, isNotNull);
      },
    );

    testWidgets(
      'previous button navigates to page 0',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            _ConfigActionBarTestWrapper(
              pageIndexNotifier: pageIndexNotifier,
            ),
            overrides: [
              matrixServiceProvider.overrideWithValue(mockMatrixService),
              provisioningControllerProvider.overrideWith(
                () => _FakeProvisioningController(
                  const ProvisioningState.loggingIn(),
                ),
              ),
            ],
          ),
        );
        await tester.pump();

        final context = tester.element(
          find.byType(_ConfigActionBarTestWrapper),
        );
        await tester.tap(
          find.text(context.messages.settingsMatrixPreviousPage),
        );
        await tester.pump();

        expect(pageIndexNotifier.value, 0);
      },
    );

    testWidgets(
      'error state promotes Retry into the accent slot',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            _ConfigActionBarTestWrapper(
              pageIndexNotifier: pageIndexNotifier,
            ),
            overrides: [
              matrixServiceProvider.overrideWithValue(mockMatrixService),
              provisioningControllerProvider.overrideWith(
                () => _FakeProvisioningController(
                  const ProvisioningState.error(
                    ProvisioningError.loginFailed,
                  ),
                ),
              ),
            ],
          ),
        );
        await tester.pump();

        final context = tester.element(
          find.byType(_ConfigActionBarTestWrapper),
        );

        // One accent slot, filled by whatever the user should press next:
        // in the error state that is Retry, not a disabled destination going
        // nowhere.
        expect(
          find.text(context.messages.syncPairGoToDevices),
          findsNothing,
        );
        final retry = tester.widget<DesignSystemButton>(
          find.byKey(const Key('provisioned_config_retry')),
        );
        expect(retry.onPressed, isNotNull);
      },
    );

    testWidgets(
      'next button is disabled in initial state',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            _ConfigActionBarTestWrapper(
              pageIndexNotifier: pageIndexNotifier,
            ),
            overrides: [
              matrixServiceProvider.overrideWithValue(mockMatrixService),
              provisioningControllerProvider.overrideWith(
                () => _FakeProvisioningController(
                  const ProvisioningState.initial(),
                ),
              ),
            ],
          ),
        );
        await tester.pump();

        final context = tester.element(
          find.byType(_ConfigActionBarTestWrapper),
        );

        final nextButton = tester.widget<DesignSystemButton>(
          find.widgetWithText(
            DesignSystemButton,
            context.messages.syncPairGoToDevices,
          ),
        );
        expect(nextButton.onPressed, isNull);
      },
    );
  });

  // Tests for the actual _ConfigActionBar widget rendered via provisionedConfigPage.
  // This covers lines 44-77 of the source (the private _ConfigActionBar.build method).
  group('provisionedConfigPage function — _ConfigActionBar', () {
    /// Pumps a full WoltModalSheet containing provisionedConfigPage.
    ///
    /// The modal is opened by tapping a trigger button.  After this helper
    /// returns the sheet is visible and fully settled.
    ///
    /// A fresh [ValueNotifier] starting at 0 is required so the single-page
    /// WoltModalSheet does not receive an out-of-range index from the shared
    /// [pageIndexNotifier] (which starts at 1 in setUp).
    Future<ValueNotifier<int>> pumpConfigPage(
      WidgetTester tester, {
      required ProvisioningState state,
      List<SyncDeviceInfo> devices = const [],
    }) async {
      final localNotifier = ValueNotifier<int>(0);
      addTearDown(localNotifier.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
            provisioningControllerProvider.overrideWith(
              () => _FakeProvisioningController(state),
            ),
            syncDevicesControllerProvider.overrideWith(
              () => FakeSyncDevicesController(devices),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: resolveTestTheme(),
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => ModalUtils.showMultiPageModal<void>(
                    context: ctx,
                    pageIndexNotifier: localNotifier,
                    pageListBuilder: (modalCtx) => [
                      provisionedConfigPage(
                        context: modalCtx,
                        pageIndexNotifier: localNotifier,
                      ),
                    ],
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      // Use pump+duration rather than pumpAndSettle to avoid timeout from
      // ongoing spinner animations.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      return localNotifier;
    }

    testWidgets(
      'previous returns to the scanner from a state where rescanning helps',
      (tester) async {
        final localNotifier = await pumpConfigPage(
          tester,
          state: const ProvisioningState.bundleDecoded(testBundle),
        );

        final prevFinder = find.byWidgetPredicate(
          (w) =>
              w is DesignSystemButton &&
              w.variant == DesignSystemButtonVariant.secondary,
        );
        expect(prevFinder, findsOneWidget);

        localNotifier.value = 1;

        // Invoke the callback directly to avoid WoltModalSheet trying to
        // render page 1 (which doesn't exist in our single-page test setup).
        final prevBtn = tester.widget<DesignSystemButton>(prevFinder);
        expect(prevBtn.onPressed, isNotNull);
        prevBtn.onPressed!();

        expect(localNotifier.value, 0);
      },
    );

    // Going back mid-flight drops the user onto a live scanner while
    // configureFromBundle is still running; going back from success and
    // pressing Connect again logs out the working session and retries with a
    // password that has already been rotated away.
    for (final (label, state) in [
      ('loggingIn', const ProvisioningState.loggingIn()),
      ('joiningRoom', const ProvisioningState.joiningRoom()),
      ('rotatingPassword', const ProvisioningState.rotatingPassword()),
      ('ready', const ProvisioningState.ready('handover')),
      ('done', const ProvisioningState.done()),
    ]) {
      testWidgets('previous is blocked in $label', (tester) async {
        await pumpConfigPage(tester, state: state);

        final prevBtn = tester.widget<DesignSystemButton>(
          find.byWidgetPredicate(
            (w) =>
                w is DesignSystemButton &&
                w.variant == DesignSystemButtonVariant.secondary,
          ),
        );
        expect(prevBtn.onPressed, isNull);
      });
    }

    // Individual tests for each incomplete state to keep isolation clear and
    // avoid modal-bleed between iterations in a single test body.
    for (final (label, state) in [
      ('initial', const ProvisioningState.initial()),
      ('loggingIn', const ProvisioningState.loggingIn()),
      ('joiningRoom', const ProvisioningState.joiningRoom()),
      ('rotatingPassword', const ProvisioningState.rotatingPassword()),
      ('bundleDecoded', const ProvisioningState.bundleDecoded(testBundle)),
    ]) {
      testWidgets(
        'next button is disabled in $label state',
        (tester) async {
          await pumpConfigPage(tester, state: state);

          final nextBtn = tester.widget<DesignSystemButton>(
            find.byWidgetPredicate(
              (w) =>
                  w is DesignSystemButton &&
                  w.variant == DesignSystemButtonVariant.primary,
            ),
          );
          expect(
            nextBtn.onPressed,
            isNull,
            reason: 'Expected null for state $label',
          );
        },
      );
    }

    testWidgets(
      'the error state fills the accent slot with a live Retry',
      (tester) async {
        // Not a disabled destination: the one accent slot carries whatever
        // the user should press next, and after a failure that is Retry.
        await pumpConfigPage(
          tester,
          state: const ProvisioningState.error(ProvisioningError.loginFailed),
        );

        final context = tester.element(find.byType(ProvisionedConfigWidget));
        expect(
          find.text(context.messages.syncPairGoToDevices),
          findsNothing,
        );
        final retry = tester.widget<DesignSystemButton>(
          find.byKey(const Key('provisioned_config_retry')),
        );
        expect(retry.onPressed, isNotNull);
        expect(retry.variant, DesignSystemButtonVariant.primary);
      },
    );

    testWidgets(
      'next button is enabled and navigates to page 2 when state is ready',
      (tester) async {
        final localNotifier = await pumpConfigPage(
          tester,
          state: const ProvisioningState.ready('handover'),
        );

        final nextFinder = find.byWidgetPredicate(
          (w) =>
              w is DesignSystemButton &&
              w.variant == DesignSystemButtonVariant.primary,
        );
        final nextBtn = tester.widget<DesignSystemButton>(nextFinder);
        expect(nextBtn.onPressed, isNotNull);

        // Invoke the callback directly to avoid the WoltModalSheet trying to
        // render page index 2 (which doesn't exist in our single-page modal).
        nextBtn.onPressed!();

        expect(localNotifier.value, 2);
      },
    );

    testWidgets(
      'done with an unverified peer keeps Go to Devices enabled but quiet',
      (tester) async {
        // The required action lives on the *other* device while the
        // checklist is open; the accent must not shine away from it.
        await pumpConfigPage(
          tester,
          state: const ProvisioningState.done(),
          devices: const [
            SyncDeviceInfo(
              deviceId: 'PEER',
              isCurrentDevice: false,
              verified: false,
            ),
          ],
        );

        final context = tester.element(find.byType(ProvisionedConfigWidget));
        final nextBtn = tester.widget<DesignSystemButton>(
          find.widgetWithText(
            DesignSystemButton,
            context.messages.syncPairGoToDevices,
          ),
        );
        expect(nextBtn.onPressed, isNotNull);
        expect(nextBtn.variant, DesignSystemButtonVariant.outlined);
      },
    );

    testWidgets(
      'done with a verified peer hands Go to Devices the accent',
      (tester) async {
        await pumpConfigPage(
          tester,
          state: const ProvisioningState.done(),
          devices: const [
            SyncDeviceInfo(
              deviceId: 'PEER',
              isCurrentDevice: false,
              verified: true,
            ),
          ],
        );

        final context = tester.element(find.byType(ProvisionedConfigWidget));
        final nextBtn = tester.widget<DesignSystemButton>(
          find.widgetWithText(
            DesignSystemButton,
            context.messages.syncPairGoToDevices,
          ),
        );
        expect(nextBtn.onPressed, isNotNull);
        expect(nextBtn.variant, DesignSystemButtonVariant.primary);
      },
    );

    testWidgets(
      'title and body from provisionedConfigPage are displayed in the modal',
      (tester) async {
        await pumpConfigPage(
          tester,
          state: const ProvisioningState.loggingIn(),
        );

        // The setup sheet carries its own title; "Devices" now names the
        // roster, which lives in the settings pane rather than this flow.
        expect(find.text('Sync Setup'), findsOneWidget);
        // The phase label must also be visible (proves the body rendered).
        final context = tester.element(find.byType(ProvisionedConfigWidget));
        expect(
          find.text(context.messages.provisionedSyncLoggingIn),
          findsOneWidget,
        );
      },
    );
  });
}

/// Test wrapper that replicates the _ConfigActionBar logic since it's private.
/// Uses the same provisioningControllerProvider to exercise the isComplete /
/// isError state.when() logic, including the error slot's accent Retry.
class _ConfigActionBarTestWrapper extends ConsumerWidget {
  const _ConfigActionBarTestWrapper({required this.pageIndexNotifier});

  final ValueNotifier<int> pageIndexNotifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(provisioningControllerProvider);
    final isComplete = state.when(
      initial: () => false,
      bundleDecoded: (_) => false,
      loggingIn: () => false,
      joiningRoom: () => false,
      rotatingPassword: () => false,
      ready: (_) => true,
      done: () => true,
      error: (_) => false,
    );
    final isError = state.when(
      initial: () => false,
      bundleDecoded: (_) => false,
      loggingIn: () => false,
      joiningRoom: () => false,
      rotatingPassword: () => false,
      ready: (_) => false,
      done: () => false,
      error: (_) => true,
    );

    return Column(
      children: [
        ProvisionedConfigWidget(pageIndexNotifier: pageIndexNotifier),
        Row(
          children: [
            OutlinedButton(
              onPressed: () => pageIndexNotifier.value = 0,
              child: Text(context.messages.settingsMatrixPreviousPage),
            ),
            const SizedBox(width: 8),
            if (isError)
              DesignSystemButton(
                key: const Key('provisioned_config_retry'),
                onPressed: () =>
                    ref.read(provisioningControllerProvider.notifier).retry(),
                label: context.messages.provisionedSyncRetry,
              )
            else
              DesignSystemButton(
                onPressed: isComplete
                    ? () => pageIndexNotifier.value = 2
                    : null,
                label: context.messages.syncPairGoToDevices,
              ),
          ],
        ),
      ],
    );
  }
}
