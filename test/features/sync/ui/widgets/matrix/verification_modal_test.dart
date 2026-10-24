import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/features/sync/models/sync_device_info.dart';
import 'package:lotti/features/sync/state/matrix_service_provider.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/verification_modal.dart';
import 'package:lotti/features/sync/ui/widgets/sync_device_pair_motif.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/themes/legacy_material_bridge.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../widget_test_utils.dart';
import '../../../sync_verification_fixtures.dart';

/// Counts pops so a test can tell one auto-dismiss from several.
class _PopCountingObserver extends NavigatorObserver {
  int pops = 0;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pops++;
    super.didPop(route, previousRoute);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMatrixService mockMatrixService;
  late StreamController<SyncVerificationState> controller;

  /// The device the sheet is opened for: the modal starts the ceremony toward
  /// its `(userId, deviceId)` and names it in the header.
  final device = unverifiedPeerDevice(userId: '@user:server');

  Future<void> verifyDeviceCall() => mockMatrixService.verifyDevice(
    userId: '@user:server',
    deviceId: 'DEVICE1',
  );

  setUp(() {
    mockMatrixService = MockMatrixService();
    controller = StreamController<SyncVerificationState>.broadcast();

    when(
      () => mockMatrixService.outgoingVerifications,
    ).thenAnswer((_) => controller.stream);
    when(
      () => mockMatrixService.verifyDevice(
        userId: any(named: 'userId'),
        deviceId: any(named: 'deviceId'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockMatrixService.acceptEmojiVerification(any()),
    ).thenAnswer((_) async {});
    when(
      () => mockMatrixService.cancelVerification(any()),
    ).thenAnswer((_) async {});
    when(() => mockMatrixService.getUnverifiedDevices()).thenReturn([]);
  });

  tearDown(() async {
    await controller.close();
  });

  Future<void> pumpModal(
    WidgetTester tester, {
    SyncDeviceInfo? forDevice,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        VerificationModal(forDevice ?? device),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
        ],
      ),
    );
    await tester.pump();
  }

  /// Pumps the modal and delivers [state] on the outgoing stream.
  Future<void> pumpModalAt(
    WidgetTester tester,
    SyncVerificationState state,
  ) async {
    await pumpModal(tester);
    controller.add(state);
    await tester.pump();
  }

  testWidgets('starts verification toward the device and shows the start '
      'button while no ceremony exists', (tester) async {
    await pumpModal(tester);

    verify(verifyDeviceCall).called(1);
    expect(find.byKey(const Key('matrix_start_verify')), findsOneWidget);
  });

  testWidgets('shows continue message when waiting for acceptance', (
    tester,
  ) async {
    await pumpModalAt(tester, verificationState());

    expect(
      find.text('Accept on other device to continue'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('matrix_start_verify')), findsNothing);
  });

  testWidgets('displays emojis and cancels the ceremony by id', (
    tester,
  ) async {
    await pumpModalAt(tester, emojiStep(id: 'sas-7'));

    expect(find.text('They match'), findsOneWidget);
    final cancelFinder = find.byKey(const Key('matrix_cancel_verification'));
    expect(cancelFinder, findsOneWidget);

    await tester.ensureVisible(cancelFinder);
    await tester.tap(cancelFinder);
    await tester.pumpAndSettle();

    verify(() => mockMatrixService.cancelVerification('sas-7')).called(1);
  });

  testWidgets('shows success state when verification is complete', (
    tester,
  ) async {
    await pumpModalAt(tester, doneStep());

    // The trust moment celebrates: the motif's gap closes into a solid
    // line and the copy states the property that was just established.
    expect(
      find.byKey(const Key('verification_success_stage')),
      findsOneWidget,
    );
    expect(find.text('Your devices trust each other'), findsOneWidget);
    final motif = tester.widget<SyncDevicePairMotif>(
      find.byType(SyncDevicePairMotif),
    );
    expect(motif.state, SyncDevicePairMotifState.linked);

    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('shows cancelled message when verification stops elsewhere', (
    tester,
  ) async {
    await pumpModalAt(tester, cancelledStep());

    expect(find.text('Cancelled on other device...'), findsOneWidget);

    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets(
    'tapping Accept confirms the emoji by id and awaits the other device',
    (tester) async {
      await pumpModalAt(tester, emojiStep(id: 'sas-7'));

      await tester.ensureVisible(find.text('They match'));
      await tester.tap(find.text('They match'));
      await tester.pump();

      verify(
        () => mockMatrixService.acceptEmojiVerification('sas-7'),
      ).called(1);
      expect(
        find.text('Accept on other device to continue'),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'shows accept verification button for key step without emojis',
    (tester) async {
      await pumpModalAt(
        tester,
        verificationState(lastStep: 'm.key.verification.key'),
      );

      expect(
        find.byKey(const Key('matrix_accept_verify')),
        findsOneWidget,
      );
    },
  );

  testWidgets('shows user ID under device name', (tester) async {
    await pumpModal(tester);

    expect(find.text('Pixel 7'), findsOneWidget);
    // Account and session id share one mono meta line.
    expect(find.text('@user:server · DEVICE1'), findsOneWidget);
  });

  testWidgets('shows device ID when display name is null', (tester) async {
    await pumpModal(
      tester,
      forDevice: unverifiedPeerDevice(
        userId: '@user:server',
        displayName: null,
      ),
    );

    expect(find.text('DEVICE1'), findsOneWidget);
  });

  testWidgets('manual start button works when no ceremony is present', (
    tester,
  ) async {
    await pumpModal(tester);
    await tester.pump();

    final startBtn = find.byKey(const Key('matrix_start_verify'));
    expect(startBtn, findsOneWidget);

    // Tap to retry manually
    await tester.tap(startBtn);
    await tester.pump();
    verify(verifyDeviceCall).called(greaterThan(1));
  });

  testWidgets(
    'exhausts all retries with exponential back-off when verifyDevice '
    'always throws',
    (tester) async {
      // verifyDevice always throws so every attempt falls through to the
      // delay branch.
      when(
        () => mockMatrixService.verifyDevice(
          userId: any(named: 'userId'),
          deviceId: any(named: 'deviceId'),
        ),
      ).thenThrow(Exception('network error'));

      await pumpModal(tester);

      // Pump through all 4 inter-attempt delays: 350ms, 700ms, 1400ms, 2800ms.
      // Using a single large pump that is ≥ sum of all delays (5250ms).
      await tester.pump(const Duration(milliseconds: 5300));

      // After all 5 attempts are exhausted the start-button becomes enabled
      // again (verificationStartInFlight = false) and is still visible.
      expect(find.byKey(const Key('matrix_start_verify')), findsOneWidget);

      // All 5 attempts were made.
      verify(verifyDeviceCall).called(5);
    },
  );

  testWidgets(
    'a failed accept re-enables the match buttons and surfaces the error',
    (tester) async {
      when(
        () => mockMatrixService.acceptEmojiVerification(any()),
      ).thenAnswer((_) async => throw StateError('homeserver unreachable'));

      await pumpModalAt(tester, emojiStep(emojis: sasEmojis('🐧')));

      await tester.ensureVisible(find.text('They match'));
      // The tap handler does not await the accept, so the rethrown failure
      // lands in the zone the tap ran in; catch it there.
      final zoneErrors = <Object>[];
      await runZonedGuarded(
        () => tester.tap(find.text('They match')),
        (error, _) => zoneErrors.add(error),
      );
      await tester.pump();

      verify(
        () => mockMatrixService.acceptEmojiVerification('ceremony-1'),
      ).called(1);
      // The failure is rethrown to the zone rather than swallowed …
      expect(zoneErrors, [
        isA<StateError>().having(
          (e) => e.message,
          'message',
          'homeserver unreachable',
        ),
      ]);
      // … and the modal leaves the waiting state so the user can retry.
      expect(find.text('Accept on other device to continue'), findsNothing);
      expect(find.text('They match'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping the restart button of a ceremony without a step starts again',
    (tester) async {
      await pumpModalAt(tester, verificationState());

      // The restart button is shown while the ceremony has no step yet.
      final restartBtn = find.byKey(const Key('matrix_restart_verify'));
      expect(restartBtn, findsOneWidget);

      await tester.tap(restartBtn);
      await tester.pump();

      // verifyDevice is called at least once from the restart tap
      // (in addition to the auto-start in initState).
      verify(verifyDeviceCall).called(greaterThan(1));
    },
  );

  testWidgets(
    'tapping matrix_accept_verify confirms the emoji by id',
    (tester) async {
      await pumpModalAt(
        tester,
        verificationState(id: 'sas-7', lastStep: 'm.key.verification.key'),
      );

      final acceptBtn = find.byKey(const Key('matrix_accept_verify'));
      expect(acceptBtn, findsOneWidget);

      await tester.tap(acceptBtn);
      await tester.pump();

      verify(
        () => mockMatrixService.acceptEmojiVerification('sas-7'),
      ).called(1);
    },
  );

  testWidgets(
    'success confirm button refreshes the device list and pops the modal',
    (tester) async {
      // Build a two-route navigator so that the button's pop() removes the
      // modal route and the 30-second auto-dismiss Timer's pop() removes the
      // parent route — both pops stay within valid Navigator state.
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
          child: MaterialApp(
            builder: LegacyMaterialBridge.builder,
            navigatorKey: navigatorKey,
            theme: resolveTestTheme(),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              FormBuilderLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: SizedBox.shrink()),
          ),
        ),
      );

      await tester.pump();

      // Push the modal as a second route.
      navigatorKey.currentState!.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(body: VerificationModal(device)),
        ),
      );

      // Let the route be built so the StreamBuilder subscribes to the stream.
      await tester.pump();
      await tester.pump();

      controller.add(doneStep());
      await tester.pump();

      expect(
        find.byKey(const Key('verification_success_stage')),
        findsOneWidget,
      );

      // Invoke the confirm button's onPressed directly: the button sits in a
      // Row(mainAxisAlignment: end) that may render at x > screenWidth in the
      // unconstrained route layout, making pointer-based tap() unreliable.
      final confirmBtn = tester
          .widgetList<DesignSystemButton>(
            find.byType(DesignSystemButton),
          )
          .last;
      confirmBtn.onPressed?.call();
      await tester.pumpAndSettle();

      expect(find.byType(VerificationModal), findsNothing);
      // The confirm refreshes the unverified list, on top of the refresh the
      // success state itself scheduled.
      verify(() => mockMatrixService.getUnverifiedDevices()).called(2);

      // Drain the 30-second auto-dismiss Timer.  The modal route was already
      // removed by the button's pop(), so the timer's pop() now removes the
      // parent home route — which is valid because it is still present.
      await tester.pump(const Duration(seconds: 30));
    },
  );

  testWidgets(
    'refreshUnverifiedDevices keeps polling while devices stay unverified',
    (tester) async {
      // First two calls return non-empty so the loop's delay path fires;
      // the third returns empty so it breaks out.
      var callCount = 0;
      when(() => mockMatrixService.getUnverifiedDevices()).thenAnswer((_) {
        callCount++;
        return callCount < 3 ? [unverifiedPeerDevice()] : [];
      });

      await pumpModalAt(tester, doneStep());

      // Pump through the retry delays (2 × 400 ms = 800 ms) so the loop body
      // executes with a non-empty device list.
      await tester.pump(const Duration(milliseconds: 900));

      // getUnverifiedDevices was polled multiple times during the loop.
      expect(callCount, greaterThan(1));

      // Drain the 30-second auto-dismiss Timer from the success branch.
      await tester.pump(const Duration(seconds: 30));
    },
  );

  testWidgets('a remote cancel shows the notice, not the success shield', (
    tester,
  ) async {
    // The SDK reports isDone == true for a cancel — `canceled || state in
    // {error, done}` — so the modal used to render the cancellation notice
    // and the green shield together. The outcome in the state is explicit.
    await pumpModalAt(tester, cancelledStep());

    expect(find.text('Cancelled on other device...'), findsOneWidget);
    expect(
      find.byKey(const Key('verification_success_stage')),
      findsNothing,
    );
    expect(find.text('Your devices trust each other'), findsNothing);

    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('does not refresh the device list for a cancelled ceremony', (
    tester,
  ) async {
    await pumpModalAt(tester, cancelledStep());

    // The refresh polls getUnverifiedDevices twelve times over ~5s; nothing
    // was verified, so it should never start.
    verifyNever(() => mockMatrixService.getUnverifiedDevices());

    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('arms one auto-dismiss however often the stream rebuilds', (
    tester,
  ) async {
    // The dismiss timers were created in build(), which a StreamBuilder re-runs
    // for every emission while the terminal state holds — so each rebuild armed
    // another 30-second pop, and the later ones fired at a route that may by
    // then belong to something else.
    final observer = _PopCountingObserver();
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => VerificationModal(device),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
        ],
        navigatorObservers: [observer],
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    for (var i = 0; i < 5; i++) {
      controller.add(cancelledStep());
      await tester.pump();
    }

    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();

    expect(observer.pops, 1);
  });

  testWidgets('confirming a cancelled ceremony closes the modal without '
      'waiting for the auto-dismiss', (tester) async {
    final observer = _PopCountingObserver();
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => VerificationModal(device),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
        ],
        navigatorObservers: [observer],
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    controller.add(cancelledStep());
    await tester.pump();
    await tester.pump();
    expect(find.text('Cancelled on other device...'), findsOneWidget);

    await tester.tap(find.byKey(const Key('matrix_cancelled_confirm')));
    await tester.pumpAndSettle();

    expect(observer.pops, 1);
    expect(find.byType(VerificationModal), findsNothing);

    // The armed auto-dismiss must not pop a second route once it fires.
    await tester.pump(const Duration(seconds: 31));
    expect(observer.pops, 1);
  });
}
