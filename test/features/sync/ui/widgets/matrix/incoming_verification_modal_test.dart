import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/features/sync/state/matrix_service_provider.dart';
import 'package:lotti/features/sync/state/matrix_verification_handled_provider.dart';
import 'package:lotti/features/sync/state/matrix_verification_modal_lock_provider.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/incoming_verification_modal.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart' show EventTypes;
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../widget_test_utils.dart';
import '../../../sync_verification_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const requestId = 'incoming-1';

  late MockMatrixService mockMatrixService;
  late StreamController<SyncVerificationState> controller;

  /// The peer's request as the wrapper hands it to the sheet.
  SyncVerificationState requestFrom(
    String deviceId, {
    String id = requestId,
    KeyVerificationOutcome outcome = KeyVerificationOutcome.pending,
  }) => verificationState(
    id: id,
    direction: SyncVerificationDirection.incoming,
    peerDeviceId: deviceId,
    lastStep: EventTypes.KeyVerificationRequest,
    outcome: outcome,
  );

  final request = requestFrom('DEVICE1');

  /// The same ceremony, as the incoming stream reports it at [lastStep].
  SyncVerificationState incomingAt(
    String lastStep, {
    List<SyncVerificationEmoji>? emojis,
    KeyVerificationOutcome outcome = KeyVerificationOutcome.pending,
  }) => verificationState(
    id: requestId,
    direction: SyncVerificationDirection.incoming,
    lastStep: lastStep,
    emojis: emojis,
    outcome: outcome,
  );

  final incomingEmoji = emojiStep(
    id: requestId,
    direction: SyncVerificationDirection.incoming,
  );
  final incomingDone = doneStep(
    id: requestId,
    direction: SyncVerificationDirection.incoming,
  );
  final incomingCancelled = cancelledStep(
    id: requestId,
    direction: SyncVerificationDirection.incoming,
  );

  setUp(() {
    mockMatrixService = MockMatrixService();
    controller = StreamController<SyncVerificationState>.broadcast();

    when(
      () => mockMatrixService.incomingVerifications,
    ).thenAnswer((_) => controller.stream);
    when(() => mockMatrixService.getUnverifiedDevices()).thenReturn([]);
    when(
      () => mockMatrixService.acceptVerification(any()),
    ).thenAnswer((_) async {});
    when(
      () => mockMatrixService.acceptEmojiVerification(any()),
    ).thenAnswer((_) async {});
    when(
      () => mockMatrixService.cancelVerification(any()),
    ).thenAnswer((_) async {});
  });

  /// Pumps the modal inside the standard scaffold wrapper, emits [state] on
  /// the incoming stream, and settles one frame — the shared arrangement of
  /// nearly every test in this file.
  Future<void> pumpModalAt(
    WidgetTester tester,
    SyncVerificationState state,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        IncomingVerificationModal(request),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
        ],
      ),
    );

    controller.add(state);
    await tester.pump();
  }

  tearDown(() async {
    await controller.close();
  });

  testWidgets('answers the request and shows verify action before the emoji '
      'step', (tester) async {
    await pumpModalAt(tester, incomingAt(''));

    expect(find.text('Verify'), findsOneWidget);
    verify(() => mockMatrixService.acceptVerification(requestId)).called(1);
  });

  testWidgets('acts on the request itself until the stream reports the '
      'ceremony', (tester) async {
    // The runner stream replays only to its first subscriber, which may be
    // the add-device page. The sheet must not sit disabled waiting for a
    // replay it will never get.
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        IncomingVerificationModal(request),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
        ],
      ),
    );
    await tester.pump();

    expect(find.text('Verify'), findsOneWidget);
    verify(() => mockMatrixService.acceptVerification(requestId)).called(1);
  });

  testWidgets("starts from the service's live ceremony for the same request", (
    tester,
  ) async {
    when(
      () => mockMatrixService.incomingVerification,
    ).thenReturn(incomingEmoji);

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        IncomingVerificationModal(request),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
        ],
      ),
    );
    await tester.pump();

    // Already at the emoji step: nothing to auto-accept, emoji to compare.
    expect(find.text('They match'), findsOneWidget);
    verifyNever(() => mockMatrixService.acceptVerification(any()));
  });

  testWidgets("ignores another request's ceremony on the shared stream", (
    tester,
  ) async {
    // The service publishes every incoming ceremony on one stream and keeps
    // only the latest. A newer peer's emoji step must not appear in — or be
    // confirmed from — the sheet opened for this request.
    await pumpModalAt(
      tester,
      emojiStep(
        id: 'incoming-2',
        direction: SyncVerificationDirection.incoming,
        peerDeviceId: 'SOMEONE_ELSE',
      ),
    );

    expect(find.text('They match'), findsNothing);
    expect(find.text('Verify'), findsOneWidget);
    verify(() => mockMatrixService.acceptVerification(requestId)).called(1);

    controller.add(incomingEmoji);
    // Two pumps: the emission crosses the broadcast stream on a microtask.
    await tester.pump();
    await tester.pump();
    expect(find.text('They match'), findsOneWidget);
  });

  testWidgets('shows cancel label in emoji verification step', (tester) async {
    await pumpModalAt(tester, incomingEmoji);

    expect(find.text('They differ — cancel'), findsOneWidget);
    expect(find.text('They match'), findsOneWidget);
    expect(find.byKey(const Key('matrix_cancel_verification')), findsOneWidget);
  });

  testWidgets('shows success state when verification is done', (tester) async {
    await pumpModalAt(tester, incomingDone);

    expect(
      find.byKey(const Key('verification_success_stage')),
      findsOneWidget,
    );
    final context = tester.element(find.byType(IncomingVerificationModal));
    expect(
      find.text(context.messages.syncVerifiedCelebrationTitle),
      findsOneWidget,
    );
    expect(
      find.text(context.messages.settingsMatrixVerificationSuccessConfirm),
      findsOneWidget,
    );
  });

  testWidgets(
    'tapping Accept confirms the emoji by id and awaits the other device',
    (tester) async {
      await pumpModalAt(tester, incomingEmoji);

      await tester.ensureVisible(find.text('They match'));
      await tester.tap(find.text('They match'));
      await tester.pump();

      verify(
        () => mockMatrixService.acceptEmojiVerification(requestId),
      ).called(1);
      final context = tester.element(find.byType(IncomingVerificationModal));
      expect(
        find.text(context.messages.settingsMatrixContinueVerificationLabel),
        findsWidgets,
      );
    },
  );

  testWidgets('cancel button cancels the ceremony by id', (tester) async {
    await pumpModalAt(tester, incomingEmoji);

    expect(
      find.byKey(const Key('matrix_cancel_verification')),
      findsOneWidget,
    );
    await tester.ensureVisible(
      find.byKey(const Key('matrix_cancel_verification')),
    );
    await tester.tap(find.byKey(const Key('matrix_cancel_verification')));
    await tester.pump();

    verify(() => mockMatrixService.cancelVerification(requestId)).called(1);
  });

  testWidgets('displays device display name from unverified list', (
    tester,
  ) async {
    when(() => mockMatrixService.getUnverifiedDevices()).thenReturn([
      unverifiedPeerDevice(displayName: 'My Pixel'),
    ]);

    await pumpModalAt(tester, incomingAt(''));

    expect(find.text('My Pixel'), findsOneWidget);
    // The header names the account and session too, in one mono meta line.
    expect(find.textContaining('@alice:example.com'), findsOneWidget);
  });

  testWidgets('falls back to the device id when the roster does not know '
      'the device', (tester) async {
    await pumpModalAt(tester, incomingAt(''));

    // Named by its id in the title and again in the meta line.
    expect(find.text('DEVICE1'), findsNWidgets(2));
    expect(find.text('device name not found'), findsNothing);
  });

  testWidgets('auto-accept failure keeps verify button visible', (
    tester,
  ) async {
    when(
      () => mockMatrixService.acceptVerification(any()),
    ).thenThrow(Exception('network error'));

    await pumpModalAt(tester, incomingAt(''));

    // Verify button should still be visible as fallback
    expect(find.text('Verify'), findsOneWidget);
  });

  testWidgets('the verify button answers the request by id', (tester) async {
    // The auto-accept failed; the button is the manual fallback.
    var attempts = 0;
    when(() => mockMatrixService.acceptVerification(any())).thenAnswer((
      _,
    ) async {
      attempts++;
      if (attempts == 1) throw Exception('network error');
    });

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        IncomingVerificationModal(request),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
        ],
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Verify'));
    await tester.pump();

    verify(() => mockMatrixService.acceptVerification(requestId)).called(2);
  });

  testWidgets('Accept failure resets awaiting state and surfaces the error', (
    tester,
  ) async {
    // acceptEmojiVerification fails so the catch block runs: it resets
    // _awaitingOtherDevice to false and then rethrows.
    when(
      () => mockMatrixService.acceptEmojiVerification(any()),
    ).thenAnswer((_) async => throw Exception('boom'));

    await pumpModalAt(tester, incomingEmoji);

    final acceptFinder = find.text('They match');
    expect(acceptFinder, findsOneWidget);
    await tester.ensureVisible(acceptFinder);

    // The rethrow propagates out of the discarded onPressed future as an
    // unhandled async error; capture it via a guarded zone so it does not
    // fail the test. Only the tap + pumps that trigger the async failure run
    // inside the zone, so other assertions still fail the test normally.
    final asyncErrors = <Object>[];
    await runZonedGuarded(
      () async {
        await tester.tap(acceptFinder);
        // Flush the microtasks so the failed acceptEmojiVerification future
        // settles and the catch block runs setState.
        await tester.pump();
        await tester.pump();
      },
      (error, stack) => asyncErrors.add(error),
    );

    // The rethrow surfaced as an unhandled async error.
    expect(asyncErrors, isNotEmpty);

    // After the failure the catch block reset _awaitingOtherDevice to false,
    // so the button is interactive again and shows the "Accept" label rather
    // than the "continue verification" awaiting label.
    verify(
      () => mockMatrixService.acceptEmojiVerification(requestId),
    ).called(1);
    expect(find.text('They match'), findsOneWidget);
    final context = tester.element(find.byType(IncomingVerificationModal));
    expect(
      find.text(context.messages.settingsMatrixContinueVerificationLabel),
      findsNothing,
    );
  });

  testWidgets(
    'tapping Accept while not awaiting calls acceptEmojiVerification and '
    'sets awaiting state',
    (tester) async {
      // Use a completer that never completes so the awaiting state stays true.
      final completer = Completer<void>();
      addTearDown(completer.future.ignore);
      when(
        () => mockMatrixService.acceptEmojiVerification(any()),
      ).thenAnswer((_) => completer.future);

      await pumpModalAt(tester, incomingEmoji);

      // Tap Accept — sets _awaitingOtherDevice = true.
      final acceptFinder = find.text('They match');
      expect(acceptFinder, findsOneWidget);
      await tester.ensureVisible(acceptFinder);
      await tester.tap(acceptFinder);
      await tester.pump();

      // While in the awaiting state the button label changes, proving
      // _awaitingOtherDevice was set to true.
      final context = tester.element(find.byType(IncomingVerificationModal));
      expect(
        find.text(context.messages.settingsMatrixContinueVerificationLabel),
        findsWidgets,
      );
      verify(
        () => mockMatrixService.acceptEmojiVerification(requestId),
      ).called(1);
    },
  );

  testWidgets('success confirm button closes the modal', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => IncomingVerificationModal(request),
              ),
            ),
            child: const Text('open'),
          ),
        ),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
        ],
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    controller.add(incomingDone);
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const Key('verification_success_stage')),
      findsOneWidget,
    );

    final confirmFinder = find.text('Got it');
    expect(confirmFinder, findsOneWidget);
    await tester.ensureVisible(confirmFinder);
    await tester.tap(confirmFinder);
    await tester.pumpAndSettle();

    expect(find.byType(IncomingVerificationModal), findsNothing);
  });

  testWidgets(
    'refreshUnverifiedDevices loops through delay when devices initially '
    'non-empty',
    (tester) async {
      // build() calls getUnverifiedDevices() once per build before the loop
      // ever runs, so we keep returning a non-empty list for the first few
      // calls. That forces the loop's `isEmpty` check to fail and drive
      // execution into the delay + mounted re-check. After enough calls we
      // return empty so the loop breaks.
      var callCount = 0;
      when(() => mockMatrixService.getUnverifiedDevices()).thenAnswer((_) {
        callCount++;
        if (callCount <= 3) {
          return [
            unverifiedPeerDevice(
              deviceId: 'OTHER_DEVICE',
              displayName: 'Other Device',
            ),
          ];
        }
        return [];
      });

      await pumpModalAt(tester, incomingDone);

      // Advance time repeatedly so the 400ms delay inside the loop fires more
      // than once, proving the delay + mounted re-check ran.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // getUnverifiedDevices was polled more than the single build()-time call,
      // which can only happen if the loop traversed the delay path at least
      // once (the loop is the only other caller).
      expect(callCount, greaterThan(2));
    },
  );

  group('IncomingVerificationWrapper', () {
    late StreamController<SyncVerificationState> requests;
    late StreamController<SyncVerificationState> ownCeremonies;

    setUp(() {
      requests = StreamController<SyncVerificationState>.broadcast();
      ownCeremonies = StreamController<SyncVerificationState>.broadcast();
      when(
        () => mockMatrixService.incomingVerificationRequests,
      ).thenAnswer((_) => requests.stream);
      when(
        () => mockMatrixService.outgoingVerifications,
      ).thenAnswer((_) => ownCeremonies.stream);
      when(() => mockMatrixService.outgoingVerification).thenReturn(null);
      when(() => mockMatrixService.incomingVerification).thenReturn(null);
    });

    tearDown(() async {
      await requests.close();
      await ownCeremonies.close();
    });

    Future<void> pumpWrapper(
      WidgetTester tester, {
      List<Override> overrides = const [],
    }) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const IncomingVerificationWrapper(),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
            ...overrides,
          ],
        ),
      );
    }

    testWidgets('renders without error and listens to incoming requests', (
      tester,
    ) async {
      await pumpWrapper(tester);

      // The wrapper renders as SizedBox.shrink when idle.
      expect(find.byType(IncomingVerificationWrapper), findsOneWidget);
      // The request stream must have been subscribed once during initState.
      verify(() => mockMatrixService.incomingVerificationRequests).called(1);
    });

    testWidgets(
      'shows verification modal when a request arrives and lock is free',
      (tester) async {
        await pumpWrapper(tester);

        requests.add(request);
        await tester.pumpAndSettle();

        expect(find.byType(IncomingVerificationModal), findsOneWidget);
      },
    );

    testWidgets(
      'closing the modal releases the lock so a later request reopens it',
      (tester) async {
        await pumpWrapper(tester);

        // First request opens the modal (lock acquired).
        requests.add(request);
        await tester.pumpAndSettle();
        expect(find.byType(IncomingVerificationModal), findsOneWidget);

        // Dismiss the modal by popping the navigator. This completes the
        // showVerificationModalSheet future and runs the finally block.
        final modalContext = tester.element(
          find.byType(IncomingVerificationModal),
        );
        Navigator.of(modalContext).pop();
        await tester.pumpAndSettle();
        expect(find.byType(IncomingVerificationModal), findsNothing);

        // The lock was released, so a second incoming request must be able to
        // reopen the modal. If release() had not run, tryAcquire() would
        // return false and no modal would appear.
        requests.add(request);
        await tester.pumpAndSettle();
        expect(find.byType(IncomingVerificationModal), findsOneWidget);

        // Clean up the still-open second modal.
        Navigator.of(
          tester.element(find.byType(IncomingVerificationModal)),
        ).pop();
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'lock prevents a second modal from opening while first is open',
      (tester) async {
        // Override the lock provider with one that starts already acquired so
        // tryAcquire() returns false and the modal is never shown.
        await pumpWrapper(
          tester,
          overrides: [
            matrixVerificationModalLockProvider.overrideWith(
              _PreAcquiredLock.new,
            ),
          ],
        );

        requests.add(request);
        await tester.pump();

        // No modal should open because the lock is already held.
        expect(find.byType(IncomingVerificationModal), findsNothing);
      },
    );

    group('when its sheet closes', () {
      Future<void> showThenPop(WidgetTester tester) async {
        await pumpWrapper(tester);

        requests.add(request);
        await tester.pumpAndSettle();
        expect(find.byType(IncomingVerificationModal), findsOneWidget);

        Navigator.of(
          tester.element(find.byType(IncomingVerificationModal)),
        ).pop();
        await tester.pumpAndSettle();
      }

      testWidgets('cancels the ceremony the user walked away from', (
        tester,
      ) async {
        // A backdrop tap used to leave the ceremony live: the peer's sheet
        // kept waiting on a device that was gone, with nothing to free its
        // lock (TLC's `EventuallyOffered` with `CancelOnDismiss = FALSE`).
        // The service leaves a finished ceremony alone; the sheet asks by id.
        when(
          () => mockMatrixService.incomingVerification,
        ).thenReturn(incomingAt(EventTypes.KeyVerificationRequest));

        await showThenPop(tester);

        verify(() => mockMatrixService.cancelVerification(requestId)).called(1);
      });

      testWidgets("leaves a newer request's ceremony alone", (tester) async {
        // The service keeps the latest incoming ceremony; one for another
        // request is not this sheet's to cancel.
        when(
          () => mockMatrixService.incomingVerification,
        ).thenReturn(requestFrom('OTHER', id: 'incoming-2'));

        await showThenPop(tester);

        verifyNever(() => mockMatrixService.cancelVerification(any()));
      });

      testWidgets('cancels nothing when the service holds no ceremony', (
        tester,
      ) async {
        await showThenPop(tester);

        verifyNever(() => mockMatrixService.cancelVerification(any()));
      });
    });

    group('while another sheet holds the lock', () {
      late ProviderContainer container;
      late MatrixVerificationModalLock lock;

      Future<void> pumpWrapperBehindLock(WidgetTester tester) async {
        await pumpWrapper(tester);
        container = ProviderScope.containerOf(
          tester.element(find.byType(IncomingVerificationWrapper)),
        );
        lock = container.read(matrixVerificationModalLockProvider.notifier);
        expect(lock.tryAcquire(), isTrue);
      }

      testWidgets('holds the request and shows it once the lock frees', (
        tester,
      ) async {
        // Dropped, the request could never be shown again: the launcher
        // offers each device once and never asked (TLC's `AutoVerifies` with
        // `DeferIncoming = FALSE`).
        await pumpWrapperBehindLock(tester);

        requests.add(request);
        await tester.pump();
        expect(find.byType(IncomingVerificationModal), findsNothing);

        lock.release();
        await tester.pumpAndSettle();

        expect(find.byType(IncomingVerificationModal), findsOneWidget);
        expect(container.read(matrixVerificationModalLockProvider), isTrue);
      });

      testWidgets('drops a held request the peer has since cancelled', (
        tester,
      ) async {
        await pumpWrapperBehindLock(tester);

        requests.add(request);
        await tester.pump();
        // The service's live ceremony for the same request is cancelled now.
        when(
          () => mockMatrixService.incomingVerification,
        ).thenReturn(incomingCancelled);

        lock.release();
        await tester.pumpAndSettle();

        expect(find.byType(IncomingVerificationModal), findsNothing);
        expect(
          container.read(matrixVerificationModalLockProvider),
          isFalse,
          reason: 'nothing was shown, so nothing may hold the lock',
        );
      });

      group('with an unanswered ceremony of its own', () {
        /// This device's own request toward PEER, not yet answered.
        final outgoing = verificationState(
          id: 'outgoing',
          peerDeviceId: 'PEER',
          lastStep: EventTypes.KeyVerificationRequest,
        );
        const peerIdentity = '@alice:example.com/PEER';

        setUp(() {
          when(
            () => mockMatrixService.outgoingVerification,
          ).thenReturn(outgoing);
          when(
            () => mockMatrixService.handOffOutgoingVerificationTo(any()),
          ).thenAnswer((_) async {});
          when(
            () => mockMatrixService.ownUserId,
          ).thenReturn('@alice:example.com');
        });

        testWidgets('yields it to a smaller identity and records the peer '
            'it now shows as the one shown last', (tester) async {
          // Both devices started at each other. The larger identity withdraws
          // its own request, hands the open sheet to the peer's, and frees the
          // withdrawn target for the launcher: it was never really offered a
          // ceremony. The launcher's sheet shows the peer's ceremony after
          // the handoff, so "Show the emoji" must reopen that peer, not the
          // withdrawn one, and the launcher must not offer it again unasked
          // once the sheet closes (`RecordHandedOff`).
          when(() => mockMatrixService.ownDeviceId).thenReturn('ZZZ');
          await pumpWrapperBehindLock(tester);
          final handled = container.read(
            matrixVerificationHandledProvider.notifier,
          )..markShown(peerIdentity);

          requests.add(requestFrom('AAA'));
          await tester.pump();

          expect(find.byType(IncomingVerificationModal), findsNothing);
          verify(
            () => mockMatrixService.handOffOutgoingVerificationTo(requestId),
          ).called(1);
          expect(handled.lastShown, '@alice:example.com/AAA');
          expect(
            container.read(matrixVerificationHandledProvider),
            {'@alice:example.com/AAA'},
          );
        });

        testWidgets('a request that lands before its own ceremony is stored '
            'yields once the ceremony is', (tester) async {
          // verifyMatrixDevice stores the runner only after the send: a
          // request crossing it finds no own ceremony and is held. Offered
          // again when the ceremony appears, the larger identity yields; held
          // for good, neither device ever moved
          // (VerificationLaunch.tla, ReofferOnRegister).
          SyncVerificationState? stored;
          when(
            () => mockMatrixService.outgoingVerification,
          ).thenAnswer((_) => stored);
          when(() => mockMatrixService.ownDeviceId).thenReturn('ZZZ');
          await pumpWrapperBehindLock(tester);

          requests.add(requestFrom('AAA'));
          await tester.pump();
          verifyNever(
            () => mockMatrixService.handOffOutgoingVerificationTo(any()),
          );

          stored = outgoing;
          ownCeremonies.add(outgoing);
          await tester.pump();

          verify(
            () => mockMatrixService.handOffOutgoingVerificationTo(requestId),
          ).called(1);
        });

        testWidgets('keeps it against a larger identity and holds theirs', (
          tester,
        ) async {
          // Exactly one side yields; this one is the smaller, so the peer
          // will. Its request waits for the lock like any other.
          when(() => mockMatrixService.ownDeviceId).thenReturn('AAA');
          await pumpWrapperBehindLock(tester);

          requests.add(requestFrom('ZZZ'));
          await tester.pump();

          verifyNever(
            () => mockMatrixService.handOffOutgoingVerificationTo(any()),
          );
          expect(find.byType(IncomingVerificationModal), findsNothing);

          lock.release();
          await tester.pumpAndSettle();
          expect(find.byType(IncomingVerificationModal), findsOneWidget);
        });
      });
    });
  });

  testWidgets('a remote cancel shows the notice, not the success shield', (
    tester,
  ) async {
    // This modal has no cancellation branch of its own, so the SDK's isDone —
    // true for a cancel as well as a success — put the green shield and
    // "You've successfully verified" in front of a user whose ceremony had
    // just been refused. The state carries the outcome explicitly.
    await pumpModalAt(tester, incomingCancelled);

    final context = tester.element(find.byType(IncomingVerificationModal));
    expect(
      find.text(context.messages.settingsMatrixVerificationCancelledLabel),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('verification_success_stage')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('matrix_incoming_cancelled_confirm')),
      findsOneWidget,
    );
  });

  testWidgets('confirming a cancelled ceremony closes the sheet', (
    tester,
  ) async {
    // The confirm button is the only way out of the cancelled state.
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => IncomingVerificationModal(request),
              ),
            ),
            child: const Text('open'),
          ),
        ),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
        ],
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    controller.add(incomingCancelled);
    // Two pumps: the emission crosses the broadcast stream on a microtask, so
    // one frame is not enough once the modal sits on a pushed route.
    await tester.pump();
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('matrix_incoming_cancelled_confirm')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(IncomingVerificationModal), findsNothing);
  });

  testWidgets('does not auto-accept a ceremony that was already cancelled', (
    tester,
  ) async {
    // The auto-accept was gated on !isDone, which a cancelled ceremony
    // satisfies only by accident. Gating on pending states the intent. The
    // service already holds the cancelled ceremony, so the sheet starts
    // from it rather than from the request as it arrived.
    when(
      () => mockMatrixService.incomingVerification,
    ).thenReturn(incomingCancelled);
    await pumpModalAt(tester, incomingCancelled);

    verifyNever(() => mockMatrixService.acceptVerification(any()));
  });
}

/// A [MatrixVerificationModalLock] that starts already acquired so that
/// [tryAcquire] always returns `false` in tests.
class _PreAcquiredLock extends MatrixVerificationModalLock {
  @override
  bool build() => true; // starts locked
}
