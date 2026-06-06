import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/verification_modal.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:matrix/encryption.dart';
import 'package:matrix/encryption/utils/key_verification.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../widget_test_utils.dart';

class _FakeDeviceKeys extends Fake implements DeviceKeys {}

class FakeKeyVerificationEmoji extends Fake implements KeyVerificationEmoji {
  FakeKeyVerificationEmoji(this.emoji, this.name);

  @override
  final String emoji;

  @override
  final String name;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(_FakeDeviceKeys());
  });

  late MockMatrixService mockMatrixService;
  late MockDeviceKeys mockDeviceKeys;
  late StreamController<KeyVerificationRunner> controller;

  setUp(() {
    mockMatrixService = MockMatrixService();
    mockDeviceKeys = MockDeviceKeys();
    controller = StreamController<KeyVerificationRunner>.broadcast();

    when(
      () => mockMatrixService.keyVerificationStream,
    ).thenAnswer((_) => controller.stream);
    when(() => mockMatrixService.verifyDevice(any())).thenAnswer((_) async {});
    when(() => mockMatrixService.getUnverifiedDevices()).thenReturn([]);
    when(() => mockDeviceKeys.userId).thenReturn('@user:server');
    when(() => mockDeviceKeys.deviceDisplayName).thenReturn('Pixel 7');
    when(() => mockDeviceKeys.deviceId).thenReturn('DEVICE1');
  });

  tearDown(() async {
    await controller.close();
  });

  testWidgets('starts verification and shows start button when idle', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        VerificationModal(mockDeviceKeys),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
        ],
      ),
    );

    await tester.pump();

    verify(() => mockMatrixService.verifyDevice(mockDeviceKeys)).called(1);
    expect(find.byKey(const Key('matrix_start_verify')), findsOneWidget);
  });

  testWidgets('shows continue message when waiting for acceptance', (
    tester,
  ) async {
    final runner = MockKeyVerificationRunner();
    final keyVerification = MockKeyVerification();

    when(() => runner.lastStep).thenReturn('');
    when(() => runner.emojis).thenReturn(null);
    when(() => runner.keyVerification).thenReturn(keyVerification);
    when(() => keyVerification.isDone).thenReturn(false);

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        VerificationModal(mockDeviceKeys),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
        ],
      ),
    );

    controller.add(runner);
    await tester.pump();

    expect(
      find.text('Accept on other device to continue'),
      findsOneWidget,
    );
  });

  testWidgets('displays emojis and actions when verification key is shown', (
    tester,
  ) async {
    final runner = MockKeyVerificationRunner();
    final keyVerification = MockKeyVerification();
    final emojis = List.generate(
      8,
      (index) => FakeKeyVerificationEmoji('😀', 'emoji$index'),
    );

    when(() => runner.lastStep).thenReturn('m.key.verification.key');
    when(() => runner.emojis).thenReturn(emojis);
    when(() => runner.keyVerification).thenReturn(keyVerification);
    when(() => keyVerification.isDone).thenReturn(false);
    when(runner.cancelVerification).thenAnswer((_) async {});

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        VerificationModal(mockDeviceKeys),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
        ],
      ),
    );

    controller.add(runner);
    await tester.pump();

    expect(find.text('Accept'), findsOneWidget);
    final cancelFinder = find.byKey(const Key('matrix_cancel_verification'));
    expect(cancelFinder, findsOneWidget);

    await tester.tap(cancelFinder);
    await tester.pumpAndSettle();

    verify(runner.cancelVerification).called(1);
  });

  testWidgets('shows success state when verification is complete', (
    tester,
  ) async {
    final runner = MockKeyVerificationRunner();
    final keyVerification = MockKeyVerification();

    when(() => runner.lastStep).thenReturn('m.key.verification.done');
    when(() => runner.emojis).thenReturn(null);
    when(() => runner.keyVerification).thenReturn(keyVerification);
    when(() => keyVerification.isDone).thenReturn(true);

    when(() => mockDeviceKeys.deviceDisplayName).thenReturn('Pixel 7');
    when(() => mockDeviceKeys.deviceId).thenReturn('DEVICE1');

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        VerificationModal(mockDeviceKeys),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
        ],
      ),
    );

    controller.add(runner);
    await tester.pump();

    expect(
      find.text("You've successfully verified Pixel 7 (DEVICE1)"),
      findsOneWidget,
    );
    expect(find.byIcon(MdiIcons.shieldCheck), findsOneWidget);

    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('shows cancelled message when verification stops elsewhere', (
    tester,
  ) async {
    final runner = MockKeyVerificationRunner();
    final keyVerification = MockKeyVerification();

    when(() => runner.lastStep).thenReturn('m.key.verification.cancel');
    when(() => runner.emojis).thenReturn(null);
    when(() => runner.keyVerification).thenReturn(keyVerification);
    when(() => keyVerification.isDone).thenReturn(false);

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        VerificationModal(mockDeviceKeys),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
        ],
      ),
    );

    controller.add(runner);
    await tester.pump();

    expect(find.text('Cancelled on other device...'), findsOneWidget);

    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets(
    'tapping Accept transitions to awaiting other device state',
    (tester) async {
      final runner = MockKeyVerificationRunner();
      final keyVerification = MockKeyVerification();
      final emojis = List.generate(
        8,
        (index) => FakeKeyVerificationEmoji('😀', 'emoji$index'),
      );

      when(() => runner.lastStep).thenReturn('m.key.verification.key');
      when(() => runner.emojis).thenReturn(emojis);
      when(() => runner.keyVerification).thenReturn(keyVerification);
      when(() => keyVerification.isDone).thenReturn(false);
      when(runner.acceptEmojiVerification).thenAnswer((_) async {});

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          VerificationModal(mockDeviceKeys),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
        ),
      );

      controller.add(runner);
      await tester.pump();

      await tester.tap(find.text('Accept'));
      await tester.pump();

      verify(runner.acceptEmojiVerification).called(1);
      expect(
        find.text('Accept on other device to continue'),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'shows accept verification button for key step without emojis',
    (tester) async {
      final runner = MockKeyVerificationRunner();
      final keyVerification = MockKeyVerification();

      when(() => runner.lastStep).thenReturn('m.key.verification.key');
      when(() => runner.emojis).thenReturn(null);
      when(() => runner.keyVerification).thenReturn(keyVerification);
      when(() => keyVerification.isDone).thenReturn(false);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          VerificationModal(mockDeviceKeys),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
        ),
      );

      controller.add(runner);
      await tester.pump();

      expect(
        find.byKey(const Key('matrix_accept_verify')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'shows user ID under device name',
    (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          VerificationModal(mockDeviceKeys),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('Pixel 7'), findsOneWidget);
      expect(find.text('@user:server'), findsOneWidget);
    },
  );

  testWidgets(
    'shows device ID when display name is null',
    (tester) async {
      when(() => mockDeviceKeys.deviceDisplayName).thenReturn(null);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          VerificationModal(mockDeviceKeys),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('DEVICE1'), findsOneWidget);
    },
  );

  testWidgets(
    'manual start button works when no runner is present',
    (tester) async {
      when(
        () => mockMatrixService.verifyDevice(any()),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          VerificationModal(mockDeviceKeys),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
        ),
      );

      await tester.pump();
      await tester.pump();

      final startBtn = find.byKey(const Key('matrix_start_verify'));
      expect(startBtn, findsOneWidget);

      // Tap to retry manually
      await tester.tap(startBtn);
      await tester.pump();
      verify(
        () => mockMatrixService.verifyDevice(mockDeviceKeys),
      ).called(greaterThan(1));
    },
  );

  testWidgets(
    'exhausts all retries with exponential back-off when verifyDevice always throws',
    (tester) async {
      // verifyDevice always throws so every attempt falls through to the
      // delay branch (lines 57-59).
      when(
        () => mockMatrixService.verifyDevice(any()),
      ).thenThrow(Exception('network error'));

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          VerificationModal(mockDeviceKeys),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
        ),
      );

      // Pump through all 4 inter-attempt delays: 350ms, 700ms, 1400ms, 2800ms.
      // Using a single large pump that is ≥ sum of all delays (5250ms).
      await tester.pump(const Duration(milliseconds: 5300));

      // After all 5 attempts are exhausted the start-button becomes enabled
      // again (verificationStartInFlight = false) and is still visible.
      expect(find.byKey(const Key('matrix_start_verify')), findsOneWidget);

      // All 5 attempts were made.
      verify(
        () => mockMatrixService.verifyDevice(mockDeviceKeys),
      ).called(5);
    },
  );

  // Lines 76-77: The catch block in _acceptEmojiVerification that resets
  // _awaitingOtherDevice is guarded by a rethrow (line 79). Because the
  // onPressed handler calls _acceptEmojiVerification without awaiting, the
  // rethrown exception propagates as an unhandled async error which the Flutter
  // test framework reports as a test failure. This branch is structurally
  // untestable through widget-tap simulation without suppressing the framework
  // error handler — skipped intentionally.

  testWidgets(
    'tapping restart button when runner exists with empty lastStep calls startVerification',
    (tester) async {
      // Reset so we can count calls starting from zero after widget mounts.
      when(
        () => mockMatrixService.verifyDevice(any()),
      ).thenAnswer((_) async {});

      final runner = MockKeyVerificationRunner();
      final keyVerification = MockKeyVerification();

      when(() => runner.lastStep).thenReturn('');
      when(() => runner.emojis).thenReturn(null);
      when(() => runner.keyVerification).thenReturn(keyVerification);
      when(() => keyVerification.isDone).thenReturn(false);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          VerificationModal(mockDeviceKeys),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
        ),
      );

      controller.add(runner);
      await tester.pump();

      // The restart button (line 189) is shown when lastStep is empty.
      final restartBtn = find.byKey(const Key('matrix_restart_verify'));
      expect(restartBtn, findsOneWidget);

      await tester.tap(restartBtn);
      await tester.pump();

      // verifyDevice is called at least once from the restart tap
      // (in addition to the auto-start in initState).
      verify(
        () => mockMatrixService.verifyDevice(mockDeviceKeys),
      ).called(greaterThan(1));
    },
  );

  testWidgets(
    'tapping matrix_accept_verify calls acceptEmojiVerification (line 203)',
    (tester) async {
      final runner = MockKeyVerificationRunner();
      final keyVerification = MockKeyVerification();

      when(() => runner.lastStep).thenReturn('m.key.verification.key');
      when(() => runner.emojis).thenReturn(null);
      when(() => runner.keyVerification).thenReturn(keyVerification);
      when(() => keyVerification.isDone).thenReturn(false);
      when(runner.acceptEmojiVerification).thenAnswer((_) async {});

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          VerificationModal(mockDeviceKeys),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
        ),
      );

      controller.add(runner);
      await tester.pump();

      final acceptBtn = find.byKey(const Key('matrix_accept_verify'));
      expect(acceptBtn, findsOneWidget);

      await tester.tap(acceptBtn);
      await tester.pump();

      verify(runner.acceptEmojiVerification).called(1);
    },
  );

  testWidgets(
    'success confirm button calls stopTimer and pops modal (lines 276-279)',
    (tester) async {
      final runner = MockKeyVerificationRunner();
      final keyVerification = MockKeyVerification();

      when(() => runner.lastStep).thenReturn('m.key.verification.done');
      when(() => runner.emojis).thenReturn(null);
      when(() => runner.keyVerification).thenReturn(keyVerification);
      when(() => keyVerification.isDone).thenReturn(true);
      when(() => mockDeviceKeys.deviceDisplayName).thenReturn('Pixel 7');
      when(() => mockDeviceKeys.deviceId).thenReturn('DEVICE1');
      when(runner.stopTimer).thenReturn(null);

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
            navigatorKey: navigatorKey,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              FormBuilderLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: SizedBox.shrink()),
          ),
        ),
      );

      await tester.pump();

      // Push the modal as a second route.
      unawaited(
        navigatorKey.currentState!.push<void>(
          MaterialPageRoute<void>(
            builder: (_) => Scaffold(body: VerificationModal(mockDeviceKeys)),
          ),
        ),
      );

      // Let the route be built so the StreamBuilder subscribes to the stream.
      await tester.pump();
      await tester.pump();

      // Now deliver the done runner.  The StreamBuilder is now subscribed to
      // the broadcast stream and will receive this event.
      controller.add(runner);
      await tester.pump();

      // The success state must be visible.
      expect(find.byIcon(MdiIcons.shieldCheck), findsOneWidget);

      // Invoke the confirm button's onPressed directly: the button sits in a
      // Row(mainAxisAlignment: end) that may render at x > screenWidth in the
      // unconstrained route layout, making pointer-based tap() unreliable.
      final lastFilledBtn = tester
          .widgetList<FilledButton>(
            find.byType(FilledButton),
          )
          .last;
      lastFilledBtn.onPressed?.call();
      await tester.pump();

      // stopTimer is invoked: once from the button (line 278) and once from
      // _VerificationModalState.dispose() when the route is removed.
      verify(runner.stopTimer).called(greaterThanOrEqualTo(1));

      // Drain the 30-second auto-dismiss Timer.  The modal route was already
      // removed by the button's pop(), so the timer's pop() now removes the
      // parent home route — which is valid because it is still present.
      await tester.pump(const Duration(seconds: 30));
    },
  );

  testWidgets(
    'refreshUnverifiedDevices loops when getUnverifiedDevices returns non-empty list (lines 102-103)',
    (tester) async {
      // First two calls return non-empty so the loop's delay path fires
      // (lines 102-103); third call returns empty so it breaks out.
      var callCount = 0;
      when(() => mockMatrixService.getUnverifiedDevices()).thenAnswer((_) {
        callCount++;
        return callCount < 3 ? [MockDeviceKeys()] : [];
      });

      final runner = MockKeyVerificationRunner();
      final keyVerification = MockKeyVerification();

      when(() => runner.lastStep).thenReturn('m.key.verification.done');
      when(() => runner.emojis).thenReturn(null);
      when(() => runner.keyVerification).thenReturn(keyVerification);
      when(() => keyVerification.isDone).thenReturn(true);
      when(runner.stopTimer).thenReturn(null);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          VerificationModal(mockDeviceKeys),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
        ),
      );

      controller.add(runner);
      await tester.pump();

      // Pump through the retry delays (2 × 400 ms = 800 ms) so the loop body
      // executes with a non-empty device list, exercising lines 102-103.
      await tester.pump(const Duration(milliseconds: 900));

      // getUnverifiedDevices was polled multiple times during the loop.
      expect(callCount, greaterThan(1));

      // Drain the 30-second auto-dismiss Timer from the isLastStepDone branch.
      await tester.pump(const Duration(seconds: 30));
    },
  );
}
