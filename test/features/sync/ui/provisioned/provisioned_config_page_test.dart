import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/progress_bars/design_system_progress_bar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/features/sync/models/sync_device_info.dart';
import 'package:lotti/features/sync/state/matrix_unverified_provider.dart';
import 'package:lotti/features/sync/state/matrix_verification_modal_lock_provider.dart';
import 'package:lotti/features/sync/state/matrix_verification_relaunch_provider.dart';
import 'package:lotti/features/sync/state/provisioning_controller.dart';
import 'package:lotti/features/sync/state/provisioning_error.dart';
import 'package:lotti/features/sync/state/sync_devices_provider.dart';
import 'package:lotti/features/sync/ui/provisioned/provisioned_config_page.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/verification_modal.dart';
import 'package:lotti/features/sync/ui/widgets/sync_device_pair_motif.dart';
import 'package:lotti/features/sync/ui/widgets/sync_wizard_progress_track.dart';
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
  _FakeProvisioningController(this.initialState);

  final ProvisioningState initialState;

  /// How often the bar's Retry invoked the controller.
  int retryCalls = 0;

  /// How often the bar's "Enter a new code" reset the controller.
  int resetCalls = 0;

  @override
  ProvisioningState build() => initialState;

  @override
  Future<void> retry() async {
    retryCalls++;
  }

  @override
  void reset() {
    resetCalls++;
    state = const ProvisioningState.initial();
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
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const ProvisionedConfigWidget(),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
          provisioningControllerProvider.overrideWith(
            () => _FakeProvisioningController(state),
          ),
          ...extraOverrides,
        ],
      ),
    );
    await tester.pump();
  }

  group('ProvisionedConfigWidget', () {
    testWidgets('shows the connecting motif in initial state', (tester) async {
      await pumpConfigWidget(
        tester,
        const ProvisioningState.initial(),
      );

      expect(find.byType(SyncDevicePairMotif), findsOneWidget);
    });

    testWidgets('shows the connecting motif in bundleDecoded state', (
      tester,
    ) async {
      await pumpConfigWidget(
        tester,
        const ProvisioningState.bundleDecoded(testBundle),
      );

      expect(find.byType(SyncDevicePairMotif), findsOneWidget);
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
      // The wait is narrated by the journey's own figure — dots streaming
      // toward the other machine — not a generic spinner-plus-bar pair that
      // gave two disagreeing measures of the same wait.
      final motif = tester.widget<SyncDevicePairMotif>(
        find.byType(SyncDevicePairMotif),
      );
      expect(motif.state, SyncDevicePairMotifState.connecting);
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
      expect(find.byType(SyncDevicePairMotif), findsOneWidget);
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
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      // Honest about the gate: the header names the two remaining steps.
      expect(
        find.text(context.messages.syncPairedStepsLeft),
        findsOneWidget,
      );
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
      // The remedies live in the sticky bar — the position the rest of the
      // wizard trained the user on — not as a grey pill inside the card.
      expect(
        find.text(context.messages.syncPairRetryThisCode),
        findsNothing,
      );
      expect(
        find.text(context.messages.syncPairEnterNewCode),
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
    });

    testWidgets('the done state renders next steps', (tester) async {
      await pumpConfigWidget(tester, const ProvisioningState.done());
      expectNextSteps(tester);
    });

    testWidgets('the track marks Connect while the journey runs', (
      tester,
    ) async {
      // In flight, the three-station track marks Connect as the live
      // station.
      await pumpConfigWidget(tester, const ProvisioningState.loggingIn());
      final track = tester.widget<SyncWizardProgressTrack>(
        find.byType(SyncWizardProgressTrack),
      );
      expect(track.active, SyncWizardStep.connect);
    });

    testWidgets('the endings drop the track', (tester) async {
      // The journey has ended one way or another; a progress track under an
      // ending would promise a next station that does not exist.
      await pumpConfigWidget(tester, const ProvisioningState.done());
      expect(
        find.byKey(const Key('sync_wizard_progress_track')),
        findsNothing,
      );
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

      // The lead carries the page's one title; the gate steps sit at body
      // rank so the reader's first fixation lands on the actionable
      // imperative.
      expect(
        done.style?.fontWeight,
        tokens.typography.styles.heading.heading3.fontWeight,
      );
      expect(
        done.style?.fontSize,
        tokens.typography.styles.heading.heading3.fontSize,
      );
      expect(
        step.style?.fontSize,
        tokens.typography.styles.body.bodySmall.fontSize,
      );
    });

    testWidgets('the settings step stays visibly locked behind the ceremony', (
      tester,
    ) async {
      // Verification gating is real: the interface must not promise the
      // settings hand-off before the ceremony completes.
      await pumpConfigWidget(tester, const ProvisioningState.done());

      final context = tester.element(find.byType(ProvisionedConfigWidget));
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
      // The Maintenance fallback route belongs to the unlocked step; while
      // the ceremony gates everything it would name an unreachable path.
      expect(
        find.text(context.messages.syncPairedSettingsStepFallback),
        findsNothing,
      );
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
      // The gate keeps its numbered order — a checked step 1 above a now
      // unlocked step 2 — and the settings step opens up, revealing its
      // Maintenance fallback route.
      expect(
        tester
            .getTopLeft(
              find.text(context.messages.syncPairedVerifyStepDone),
            )
            .dy,
        lessThan(
          tester
              .getTopLeft(find.text(context.messages.syncPairedSettingsStep))
              .dy,
        ),
      );
      expect(
        find.text(context.messages.syncPairedSettingsStepFallback),
        findsOneWidget,
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

    testWidgets('the stall fallback also covers a device awaiting the emoji', (
      tester,
    ) async {
      // The dismissed-prompt remedy lives in the bar's "Show the emoji"
      // accent; the in-card fallback re-reads the trust state either way.
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
      await tester.pump(kVerifyStallTimeout);
      await tester.pump();

      final context = tester.element(find.byType(ProvisionedConfigWidget));
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

  // Tests for the actual _ConfigActionBar widget rendered via
  // provisionedConfigPage.
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
      _FakeProvisioningController Function()? controller,
      List<Override> extraOverrides = const [],
    }) async {
      final localNotifier = ValueNotifier<int>(0);
      addTearDown(localNotifier.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
            provisioningControllerProvider.overrideWith(
              controller ?? () => _FakeProvisioningController(state),
            ),
            syncDevicesControllerProvider.overrideWith(
              () => FakeSyncDevicesController(devices),
            ),
            ...extraOverrides,
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
      // ongoing motif animations.
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

    testWidgets(
      'done with the ceremony outstanding points the quiet slot at Devices',
      (tester) async {
        // Back is unsafe from the done state; instead of a dead Back button
        // the quiet slot carries the roster destination while the accent
        // re-opens the ceremony.
        final localNotifier = await pumpConfigPage(
          tester,
          state: const ProvisioningState.done(),
        );

        final context = tester.element(find.byType(ProvisionedConfigWidget));
        final quiet = tester.widget<DesignSystemButton>(
          find.widgetWithText(
            DesignSystemButton,
            context.messages.syncPairGoToDevices,
          ),
        );
        expect(quiet.variant, DesignSystemButtonVariant.secondary);
        expect(quiet.onPressed, isNotNull);

        quiet.onPressed!();
        expect(localNotifier.value, 2);
      },
    );

    testWidgets(
      'the accent re-opens the ceremony while it gates everything',
      (tester) async {
        await pumpConfigPage(
          tester,
          state: const ProvisioningState.done(),
          extraOverrides: [
            // A peer must exist for the button to promise a ceremony.
            matrixUnverifiedControllerProvider.overrideWith(
              () => FakeMatrixUnverifiedController([unverifiedPeer()]),
            ),
            // Otherwise the launcher opens the ceremony over the bar.
            matrixVerificationModalLockProvider.overrideWith(
              _PreAcquiredLock.new,
            ),
          ],
        );

        final showEmoji = find.byKey(
          const Key('provisioned_config_show_emoji'),
        );
        final container = ProviderScope.containerOf(
          tester.element(find.byType(ProvisionedConfigWidget)),
        );
        final before = container.read(matrixVerificationRelaunchProvider);

        await tester.tap(showEmoji);
        await tester.pump();

        expect(
          container.read(matrixVerificationRelaunchProvider),
          greaterThan(before),
        );
      },
    );

    testWidgets(
      'the accent waits for a ceremony target before promising one',
      (tester) async {
        // Right after the handover the peer's device keys are often still in
        // flight: the unverified list is empty and a relaunch request would
        // vanish into a launcher with nothing to relaunch. An enabled button
        // here advertises an action that silently does nothing.
        await pumpConfigPage(tester, state: const ProvisioningState.done());

        final showEmoji = tester.widget<DesignSystemButton>(
          find.byKey(const Key('provisioned_config_show_emoji')),
        );
        expect(showEmoji.onPressed, isNull);
      },
    );

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
      'the error state promotes Enter a new code and demotes Retry',
      (tester) async {
        // A rejected login usually means the code predates a password
        // rotation or was mangled in transit — fixed by a fresh code, so
        // re-attempting the identical credential must not carry the accent.
        final controller = _FakeProvisioningController(
          const ProvisioningState.error(ProvisioningError.loginFailed),
        );
        final localNotifier = await pumpConfigPage(
          tester,
          state: controller.initialState,
          controller: () => controller,
        );

        final retry = tester.widget<DesignSystemButton>(
          find.byKey(const Key('provisioned_config_retry')),
        );
        expect(retry.variant, DesignSystemButtonVariant.secondary);
        expect(retry.onPressed, isNotNull);

        final newCode = tester.widget<DesignSystemButton>(
          find.byKey(const Key('provisioned_config_new_code')),
        );
        expect(newCode.variant, DesignSystemButtonVariant.primary);

        retry.onPressed!();
        expect(controller.retryCalls, 1);

        // Entering a new code resets the run and returns to Get code, so
        // the import page can clear the stale bundle.
        newCode.onPressed!();
        expect(controller.resetCalls, 1);
        expect(localNotifier.value, 0);
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
      'the error remedies stack on a phone so neither label truncates',
      (tester) async {
        // Side by side on a phone sheet, "Retry this code" and "Enter a new
        // code" ellipsize into indistinguishability — the exact distinction
        // this bar exists to communicate.
        tester.view
          ..physicalSize = const Size(390, 844)
          ..devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await pumpConfigPage(
          tester,
          state: const ProvisioningState.error(ProvisioningError.loginFailed),
        );

        final newCode = tester.getRect(
          find.byKey(const Key('provisioned_config_new_code')),
        );
        final retry = tester.getRect(
          find.byKey(const Key('provisioned_config_retry')),
        );
        // Stacked, accent first; both full labels on screen.
        expect(retry.top, greaterThanOrEqualTo(newCode.bottom));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'done with an unverified peer hands the accent to Show the emoji',
      (tester) async {
        // The ceremony is the one thing left, so the accent re-opens it;
        // the roster stays reachable through the quiet slot.
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
        final showEmoji = tester.widget<DesignSystemButton>(
          find.byKey(const Key('provisioned_config_show_emoji')),
        );
        expect(showEmoji.variant, DesignSystemButtonVariant.primary);
        final quiet = tester.widget<DesignSystemButton>(
          find.widgetWithText(
            DesignSystemButton,
            context.messages.syncPairGoToDevices,
          ),
        );
        expect(quiet.variant, DesignSystemButtonVariant.secondary);
        expect(quiet.onPressed, isNotNull);
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
        expect(
          find.byKey(const Key('provisioned_config_show_emoji')),
          findsNothing,
        );
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
        expect(find.text('Set up sync'), findsOneWidget);
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
