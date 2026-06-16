import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/features/sync/state/matrix_verification_modal_lock_provider.dart';
import 'package:lotti/features/sync/state/provisioning_controller.dart';
import 'package:lotti/features/sync/state/provisioning_error.dart';
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

/// A fake provisioning controller that provides a fixed state.
class _FakeProvisioningController extends ProvisioningController {
  _FakeProvisioningController(this.initialState);

  final ProvisioningState initialState;

  @override
  ProvisioningState build() => initialState;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMatrixService mockMatrixService;
  late ValueNotifier<int> pageIndexNotifier;

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
        ProvisionedConfigWidget(pageIndexNotifier: pageIndexNotifier),
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
    testWidgets('shows spinner when in initial state', (tester) async {
      await pumpConfigWidget(
        tester,
        const ProvisioningState.initial(),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('shows spinner when in bundleDecoded state', (tester) async {
      await pumpConfigWidget(
        tester,
        const ProvisioningState.bundleDecoded(testBundle),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
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
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
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
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('3 / 3'), findsOneWidget);
    });

    testWidgets('shows QR code when in ready state', (tester) async {
      await pumpConfigWidget(
        tester,
        const ProvisioningState.ready('dGVzdC1oYW5kb3Zlci1kYXRh'),
      );

      final context = tester.element(find.byType(ProvisionedConfigWidget));
      expect(
        find.text(context.messages.provisionedSyncReady),
        findsOneWidget,
      );
      expect(find.byKey(const Key('provisionedQrImage')), findsOneWidget);
      // The handover data should be masked by default
      expect(find.text('\u2022' * 24), findsOneWidget);
      expect(find.byIcon(Icons.copy), findsOneWidget);
    });

    testWidgets(
      'auto-advances via incoming verification stream',
      (tester) async {
        final keyVerification = MockKeyVerification();
        final runner = MockKeyVerificationRunner();
        final device = MockDeviceKeys();
        final incomingController =
            StreamController<KeyVerificationRunner>.broadcast();
        addTearDown(incomingController.close);

        var checks = 0;
        when(() => keyVerification.isDone).thenReturn(true);
        when(() => runner.lastStep).thenReturn('m.key.verification.done');
        when(() => runner.keyVerification).thenReturn(keyVerification);
        when(
          () => mockMatrixService.incomingKeyVerificationRunnerStream,
        ).thenAnswer((_) => incomingController.stream);
        when(() => mockMatrixService.getUnverifiedDevices()).thenAnswer((_) {
          checks += 1;
          return checks < 3 ? [device] : [];
        });

        await pumpConfigWidget(
          tester,
          const ProvisioningState.ready('dGVzdC1oYW5kb3Zlci1kYXRh'),
        );

        incomingController.add(runner);
        await tester.pump(const Duration(seconds: 2));

        expect(pageIndexNotifier.value, 2);
      },
    );

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

    testWidgets(
      'auto-advances to status page when verification completes and trust updates',
      (tester) async {
        final keyVerification = MockKeyVerification();
        final runner = MockKeyVerificationRunner();
        final device = MockDeviceKeys();
        final outgoingController =
            StreamController<KeyVerificationRunner>.broadcast();
        addTearDown(outgoingController.close);

        var checks = 0;
        when(() => keyVerification.isDone).thenReturn(true);
        when(() => runner.lastStep).thenReturn('m.key.verification.done');
        when(() => runner.keyVerification).thenReturn(keyVerification);
        when(
          () => mockMatrixService.keyVerificationStream,
        ).thenAnswer((_) => outgoingController.stream);
        when(() => mockMatrixService.getUnverifiedDevices()).thenAnswer((_) {
          checks += 1;
          return checks < 3 ? [device] : [];
        });

        await pumpConfigWidget(
          tester,
          const ProvisioningState.ready('dGVzdC1oYW5kb3Zlci1kYXRh'),
        );

        outgoingController.add(runner);
        await tester.pump(const Duration(seconds: 2));

        expect(pageIndexNotifier.value, 2);
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
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
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

    testWidgets('shows error and retry button in error state', (tester) async {
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
      expect(
        find.text(context.messages.provisionedSyncRetry),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
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

    testWidgets('shows masked handover data by default', (tester) async {
      await pumpConfigWidget(
        tester,
        const ProvisioningState.ready('dGVzdC1oYW5kb3Zlci1kYXRh'),
      );

      // Handover text should be masked by default
      expect(find.text('dGVzdC1oYW5kb3Zlci1kYXRh'), findsNothing);
      expect(find.text('\u2022' * 24), findsOneWidget);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });

    testWidgets('reveals handover data when visibility toggled', (
      tester,
    ) async {
      await pumpConfigWidget(
        tester,
        const ProvisioningState.ready('dGVzdC1oYW5kb3Zlci1kYXRh'),
      );

      // Tap the visibility toggle
      await tester.tap(find.byKey(const Key('toggleHandoverVisibility')));
      await tester.pump();

      // Now the handover text should be visible
      expect(find.text('dGVzdC1oYW5kb3Zlci1kYXRh'), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });

    testWidgets('copy button copies handover data to clipboard', (
      tester,
    ) async {
      // Set up a mock clipboard channel
      String? clipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            final args = call.arguments as Map<dynamic, dynamic>;
            clipboardText = args['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      await pumpConfigWidget(
        tester,
        const ProvisioningState.ready('dGVzdC1oYW5kb3Zlci1kYXRh'),
      );

      final copyFinder = find.byKey(const Key('copyHandoverData'));
      await tester.ensureVisible(copyFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(copyFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(clipboardText, 'dGVzdC1oYW5kb3Zlci1kYXRh');

      final context = tester.element(find.byType(ProvisionedConfigWidget));
      expect(
        find.text(context.messages.provisionedSyncCopiedToClipboard),
        findsOneWidget,
      );
    });

    testWidgets('retry button invokes controller retry in error state', (
      tester,
    ) async {
      await pumpConfigWidget(
        tester,
        const ProvisioningState.error(ProvisioningError.loginFailed),
      );

      final context = tester.element(find.byType(ProvisionedConfigWidget));
      final retryFinder = find.text(context.messages.provisionedSyncRetry);
      expect(retryFinder, findsOneWidget);

      // Tap retry — should not throw
      await tester.tap(retryFinder);
      await tester.pump();
    });

    testWidgets('shows 2-step progress on mobile for loggingIn state', (
      tester,
    ) async {
      final wasDesktop = isDesktop;
      isDesktop = false;
      addTearDown(() => isDesktop = wasDesktop);

      await pumpConfigWidget(
        tester,
        const ProvisioningState.loggingIn(),
      );

      expect(find.text('1 / 2'), findsOneWidget);
    });

    testWidgets('shows 2-step progress on mobile for joiningRoom state', (
      tester,
    ) async {
      final wasDesktop = isDesktop;
      isDesktop = false;
      addTearDown(() => isDesktop = wasDesktop);

      await pumpConfigWidget(
        tester,
        const ProvisioningState.joiningRoom(),
      );

      expect(find.text('2 / 2'), findsOneWidget);
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
            context.messages.settingsMatrixNextPage,
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
            context.messages.settingsMatrixNextPage,
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
          find.text(context.messages.settingsMatrixNextPage),
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
            context.messages.settingsMatrixNextPage,
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
      'next button is disabled in error state',
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

        final nextButton = tester.widget<DesignSystemButton>(
          find.widgetWithText(
            DesignSystemButton,
            context.messages.settingsMatrixNextPage,
          ),
        );
        expect(nextButton.onPressed, isNull);
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
            context.messages.settingsMatrixNextPage,
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
      // ongoing CircularProgressIndicator animations.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      return localNotifier;
    }

    testWidgets(
      'previous button (secondary) is present and navigates to page 0',
      (tester) async {
        final localNotifier = await pumpConfigPage(
          tester,
          state: const ProvisioningState.loggingIn(),
        );

        // The previous button (secondary) must be in the action bar.
        final prevFinder = find.byWidgetPredicate(
          (w) =>
              w is DesignSystemButton &&
              w.variant == DesignSystemButtonVariant.secondary,
        );
        expect(prevFinder, findsOneWidget);

        // Set to a non-zero value so the navigation back to 0 is observable.
        localNotifier.value = 1;

        // Invoke the callback directly to avoid WoltModalSheet trying to
        // render page 1 (which doesn't exist in our single-page test setup).
        final prevBtn = tester.widget<DesignSystemButton>(prevFinder);
        prevBtn.onPressed!();

        expect(localNotifier.value, 0);
      },
    );

    // Individual tests for each incomplete state to keep isolation clear and
    // avoid modal-bleed between iterations in a single test body.
    for (final (label, state) in [
      ('initial', const ProvisioningState.initial()),
      ('loggingIn', const ProvisioningState.loggingIn()),
      ('joiningRoom', const ProvisioningState.joiningRoom()),
      ('rotatingPassword', const ProvisioningState.rotatingPassword()),
      ('error', const ProvisioningState.error(ProvisioningError.loginFailed)),
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
      'next button is enabled when state is done',
      (tester) async {
        await pumpConfigPage(
          tester,
          state: const ProvisioningState.done(),
        );

        final nextBtn = tester.widget<DesignSystemButton>(
          find.byWidgetPredicate(
            (w) =>
                w is DesignSystemButton &&
                w.variant == DesignSystemButtonVariant.primary,
          ),
        );
        expect(nextBtn.onPressed, isNotNull);
      },
    );

    testWidgets(
      'title and body from provisionedConfigPage are displayed in the modal',
      (tester) async {
        await pumpConfigPage(
          tester,
          state: const ProvisioningState.loggingIn(),
        );

        // The title "Provisioned Sync" should appear in the modal's top bar.
        expect(find.text('Provisioned Sync'), findsOneWidget);
        // The progress bar must also be visible (proves the body rendered).
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
      },
    );
  });

  group('_ReadyViewState — maybeAdvance via keyVerification.isDone', () {
    // Covers line 231: the OR branch where lastStep is not the done string
    // but runner.keyVerification.isDone is true.
    testWidgets(
      'auto-advances when keyVerification.isDone is true and lastStep differs',
      (tester) async {
        final keyVerification = MockKeyVerification();
        final runner = MockKeyVerificationRunner();
        final device = MockDeviceKeys();
        final outgoingController =
            StreamController<KeyVerificationRunner>.broadcast();
        addTearDown(outgoingController.close);

        var checks = 0;
        // lastStep is NOT the done string — the second OR operand drives isDone.
        when(() => runner.lastStep).thenReturn('m.key.verification.mac');
        when(() => keyVerification.isDone).thenReturn(true);
        when(() => runner.keyVerification).thenReturn(keyVerification);
        when(
          () => mockMatrixService.keyVerificationStream,
        ).thenAnswer((_) => outgoingController.stream);
        when(() => mockMatrixService.getUnverifiedDevices()).thenAnswer((_) {
          checks += 1;
          return checks < 3 ? [device] : [];
        });

        await pumpConfigWidget(
          tester,
          const ProvisioningState.ready('dGVzdC1oYW5kb3Zlci1kYXRh'),
        );

        outgoingController.add(runner);
        // Drive the delayed polling (20 × 350 ms max; we get early-exit at
        // checks == 3, so 2 × 350 ms = 700 ms is enough).
        await tester.pump(const Duration(milliseconds: 800));

        expect(pageIndexNotifier.value, 2);
      },
    );
  });

  group(
    '_ReadyViewState — waitUntilNoUnverifiedDevices post-loop fallback',
    () {
      // Covers lines 223-225: the code after the for-loop that runs when all
      // 20 polling attempts still see unverified devices.
      testWidgets(
        'returns false and does not advance when devices remain unverified '
        'after all polling attempts',
        (tester) async {
          final keyVerification = MockKeyVerification();
          final runner = MockKeyVerificationRunner();
          final device = MockDeviceKeys();
          final outgoingController =
              StreamController<KeyVerificationRunner>.broadcast();
          addTearDown(outgoingController.close);

          when(() => runner.lastStep).thenReturn('m.key.verification.done');
          when(() => keyVerification.isDone).thenReturn(true);
          when(() => runner.keyVerification).thenReturn(keyVerification);
          when(
            () => mockMatrixService.keyVerificationStream,
          ).thenAnswer((_) => outgoingController.stream);
          // Always return a non-empty list so the loop exhausts all 20 attempts
          // and falls through to the post-loop check which also returns non-empty.
          when(
            () => mockMatrixService.getUnverifiedDevices(),
          ).thenReturn([device]);

          await pumpConfigWidget(
            tester,
            const ProvisioningState.ready('dGVzdC1oYW5kb3Zlci1kYXRh'),
          );

          outgoingController.add(runner);
          // Drive past 20 × 350 ms = 7 000 ms of polling time; use 8 s to
          // cover the final post-loop check as well.
          await tester.pump(const Duration(seconds: 8));

          // Since devices never became verified, the page index must NOT change.
          expect(pageIndexNotifier.value, 1);
        },
      );
    },
  );

  group(
    '_DoneViewState._triggerVerification finally block',
    () {
      // Covers lines 375-376, 378: the finally block that invalidates the
      // unverified provider and releases the modal lock after the sheet closes.
      testWidgets(
        'releases lock and invalidates unverified provider after modal closes',
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

          late ProviderContainer container;
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                matrixServiceProvider.overrideWithValue(mockMatrixService),
                provisioningControllerProvider.overrideWith(
                  () => _FakeProvisioningController(
                    const ProvisioningState.done(),
                  ),
                ),
              ],
              child: MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                theme: resolveTestTheme(),
                home: Consumer(
                  builder: (ctx, ref, _) {
                    // Capture the container so we can read the lock state.
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

          // Advance past the 3 s delay to trigger the verification flow.
          await tester.pump(const Duration(seconds: 3));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          // The verification modal must be open.
          expect(find.byType(VerificationModal), findsOneWidget);

          // The lock should be acquired (true).
          expect(container.read(matrixVerificationModalLockProvider), isTrue);

          // Close the modal by tapping the close (X) button in the top bar.
          final closeButton = find.byIcon(Icons.close_rounded);
          await tester.ensureVisible(closeButton);
          await tester.tap(closeButton);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          // Modal is gone and the lock has been released (false).
          expect(find.byType(VerificationModal), findsNothing);
          expect(container.read(matrixVerificationModalLockProvider), isFalse);
        },
      );
    },
  );
}

/// Test wrapper that replicates the _ConfigActionBar logic since it's private.
/// Uses the same provisioningControllerProvider to exercise the isComplete
/// state.when() logic.
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
            DesignSystemButton(
              onPressed: isComplete ? () => pageIndexNotifier.value = 2 : null,
              label: context.messages.settingsMatrixNextPage,
            ),
          ],
        ),
      ],
    );
  }
}
