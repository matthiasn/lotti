import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/sync/models/pairing_check_code.dart';
import 'package:lotti/features/sync/models/sync_device_info.dart';
import 'package:lotti/features/sync/onboarding/onboarding_sync_service.dart';
import 'package:lotti/features/sync/state/provisioning_controller.dart';
import 'package:lotti/features/sync/state/sync_devices_provider.dart';
import 'package:lotti/features/sync/ui/provisioned/add_device_page.dart';
import 'package:lotti/features/sync/ui/re_sync_modal.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/sync_sticky_bar.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_utils/screenshot_harness.dart';
import '../../../../widget_test_utils.dart';

/// Call counters, held outside the notifiers on purpose: both providers are
/// autoDispose, so an override factory must mint a fresh instance every time
/// it is asked — reusing one throws "already associated with another
/// provider" the moment the provider is rebuilt.
class _Calls {
  int regenerate = 0;
  int refresh = 0;
}

/// Serves a fixed roster, so the "waiting for the new device" latch can be
/// driven deterministically instead of by a wall-clock poll. [refreshSucceeds]
/// stands in for a homeserver that cannot be reached.
class _FakeSyncDevicesController extends SyncDevicesController {
  _FakeSyncDevicesController(
    this.devices, {
    required this.calls,
    this.refreshSucceeds = true,
  });

  final List<SyncDeviceInfo> devices;
  final _Calls calls;
  final bool refreshSucceeds;

  @override
  Future<List<SyncDeviceInfo>> build() async => devices;

  @override
  Future<bool> refresh() async {
    calls.refresh++;
    return refreshSucceeds;
  }
}

/// Stands in for the real controller's `regenerateHandover()`, which reads the
/// persisted Matrix config. [handover] is what that call resolves to; a
/// [completer] holds the call open so the loading state can be observed.
class _FakeProvisioningController extends ProvisioningController {
  _FakeProvisioningController({
    required this.calls,
    this.handover,
    this.completer,
    this.throws = false,
  });

  final _Calls calls;
  final String? handover;
  final Completer<String?>? completer;

  /// Stands in for secure-storage or homeserver failures while minting.
  final bool throws;

  @override
  ProvisioningState build() => const ProvisioningState.initial();

  @override
  Future<String?> regenerateHandover() {
    calls.regenerate++;
    if (throws) return Future.error(Exception('secure storage unavailable'));
    return completer?.future ?? Future.value(handover);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const handover = 'dGVzdC1oYW5kb3Zlci1kYXRh';

  late MockMatrixService mockMatrixService;

  setUpAll(() {
    registerFallbackValue(
      const MatrixConfig(homeServer: '', user: '', password: ''),
    );
  });

  /// The account as it stands when the sheet opens: this device alone.
  final existing = <SyncDeviceInfo>[
    const SyncDeviceInfo(
      deviceId: 'THISDEVICE',
      displayName: 'Desktop',
      isCurrentDevice: true,
      verified: true,
    ),
  ];

  const newPhone = SyncDeviceInfo(
    deviceId: 'NEWPHONE',
    displayName: 'Phone',
    isCurrentDevice: false,
    verified: false,
  );

  const verifiedPhone = SyncDeviceInfo(
    deviceId: 'NEWPHONE',
    displayName: 'Phone',
    isCurrentDevice: false,
    verified: true,
  );

  setUp(() {
    // The generate path logs failures through DomainLogger.
    ensureDomainLoggerRegistered();
    mockMatrixService = MockMatrixService();
    when(() => mockMatrixService.loadConfig()).thenAnswer(
      (_) async => const MatrixConfig(
        homeServer: 'https://matrix.example.com',
        user: '@alice:example.com',
        password: 'rotated-pw',
      ),
    );
    when(
      () => mockMatrixService.syncRoomId,
    ).thenReturn('!room123:example.com');
    when(
      () => mockMatrixService.getSyncDevices(),
    ).thenAnswer((_) async => existing);
  });

  tearDown(tearDownTestGetIt);

  /// Sizes the surface for the sheet's tall single column; without it the
  /// lower controls sit outside the view and taps miss.
  void useTallSurface(WidgetTester tester) {
    tester.view
      ..physicalSize = const Size(900, 2400)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  List<Override> overrides({
    required _Calls calls,
    String? handoverData = handover,
    Completer<String?>? completer,
    List<SyncDeviceInfo>? devices,
    bool refreshSucceeds = true,
    bool generateThrows = false,
  }) => <Override>[
    matrixServiceProvider.overrideWithValue(mockMatrixService),
    provisioningControllerProvider.overrideWith(
      () => _FakeProvisioningController(
        calls: calls,
        handover: handoverData,
        completer: completer,
        throws: generateThrows,
      ),
    ),
    syncDevicesControllerProvider.overrideWith(
      () => _FakeSyncDevicesController(
        devices ?? existing,
        calls: calls,
        refreshSucceeds: refreshSucceeds,
      ),
    ),
  ];

  Future<_Calls> pumpAddDevice(
    WidgetTester tester, {
    String? handoverData = handover,
    Completer<String?>? completer,
    List<SyncDeviceInfo>? devices,
    bool refreshSucceeds = true,
    bool generateThrows = false,
    Duration pollInterval = const Duration(days: 1),
    AddDeviceJoinSignal? signal,
  }) async {
    useTallSurface(tester);

    final calls = _Calls();
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        // The shipped page is a scrollable modal sheet; without a scrollable
        // the tall column overflows the test surface.
        SingleChildScrollView(
          // Far beyond any test's pumped time by default: the roster is driven
          // directly through the provider, never by the real poll.
          child: AddDeviceView(pollInterval: pollInterval, signal: signal),
        ),
        overrides: overrides(
          calls: calls,
          handoverData: handoverData,
          completer: completer,
          devices: devices,
          refreshSucceeds: refreshSucceeds,
          generateThrows: generateThrows,
        ),
      ),
    );
    await tester.pump();
    return calls;
  }

  /// A signal wired up and disposed for one test.
  AddDeviceJoinSignal newSignal(WidgetTester tester) {
    final signal = AddDeviceJoinSignal();
    addTearDown(signal.dispose);
    return signal;
  }

  /// Scrolls [key] into view before tapping: the sheet is a tall column and
  /// the lower controls sit outside even the enlarged test surface.
  Future<void> tapVisible(WidgetTester tester, Key key) async {
    await tester.ensureVisible(find.byKey(key));
    await tester.pump();
    await tester.tap(find.byKey(key));
    await tester.pump();
  }

  group('AddDeviceView', () {
    testWidgets('shows a spinner until the handover code is minted', (
      tester,
    ) async {
      final completer = Completer<String?>();
      await pumpAddDevice(tester, completer: completer);

      expect(find.byType(DesignSystemSpinner), findsOneWidget);
      expect(find.byKey(const Key('addDeviceQrImage')), findsNothing);

      completer.complete(handover);
      await tester.pump();

      expect(find.byKey(const Key('addDeviceQrImage')), findsOneWidget);
    });

    testWidgets('renders the QR, the instructions and the security warning', (
      tester,
    ) async {
      await pumpAddDevice(tester);

      final context = tester.element(find.byType(AddDeviceView));

      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.byKey(const Key('addDeviceQrImage')), findsOneWidget);
      expect(find.text(context.messages.syncAddDeviceIntro), findsOneWidget);
      expect(
        find.byKey(const Key('add_device_security_note')),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.syncAddDeviceSecurityNote),
        findsOneWidget,
      );
    });

    testWidgets('masks the code until the user asks to see it', (tester) async {
      await pumpAddDevice(tester);

      // A live credential must not be readable just because the sheet is open.
      expect(find.text(handover), findsNothing);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

      await tapVisible(
        tester,
        const Key('addDeviceToggleHandoverVisibility'),
      );

      expect(find.text(handover), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });

    testWidgets('offers copying by name, not by a bare glyph', (tester) async {
      // The joining device's manual screen instructs "use Copy code", so the
      // control it names has to be findable under that name.
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

      await pumpAddDevice(tester);

      final context = tester.element(find.byType(AddDeviceView));
      final copy = tester.widget<DesignSystemButton>(
        find.byKey(const Key('addDeviceCopyHandoverData')),
      );
      expect(copy.label, context.messages.syncAddDeviceCopyCode);

      await tapVisible(tester, const Key('addDeviceCopyHandoverData'));

      expect(clipboardText, handover);
    });

    testWidgets('shows a check code the joining device can compare against', (
      tester,
    ) async {
      await pumpAddDevice(tester);

      final code = tester.widget<Text>(
        find.byKey(const Key('add_device_check_code')),
      );
      // Derived from account + room, so the other device renders the same
      // value from its decoded bundle.
      expect(
        code.data,
        pairingCheckCode(
          user: '@alice:example.com',
          roomId: '!room123:example.com',
          homeServer: 'https://matrix.example.com',
        ),
      );
    });

    testWidgets('says the code could not be made when minting throws', (
      tester,
    ) async {
      // Launched with `unawaited`, so an escaping exception both crashed the
      // zone and left the sheet claiming sync was not set up on a device that
      // is set up.
      await pumpAddDevice(tester, generateThrows: true);

      final context = tester.element(find.byType(AddDeviceView));
      expect(tester.takeException(), isNull);
      expect(
        find.text(context.messages.syncAddDeviceGenerateFailed),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.syncAddDeviceUnavailable),
        findsNothing,
      );
      expect(find.byKey(const Key('add_device_regenerate')), findsOneWidget);
    });

    testWidgets('offers a retry when no code can be minted', (tester) async {
      final calls = await pumpAddDevice(tester, handoverData: null);

      final context = tester.element(find.byType(AddDeviceView));
      expect(
        find.text(context.messages.syncAddDeviceUnavailable),
        findsOneWidget,
      );
      // No QR, and no masked-code row implying one exists.
      expect(find.byKey(const Key('addDeviceQrImage')), findsNothing);
      expect(
        find.byKey(const Key('addDeviceToggleHandoverVisibility')),
        findsNothing,
      );

      // A dead end with one sentence and no action is what this replaces.
      await tester.tap(find.byKey(const Key('add_device_regenerate')));
      await tester.pump();
      expect(calls.regenerate, 2);
    });

    testWidgets('mints the code once per open, not on every rebuild', (
      tester,
    ) async {
      final calls = await pumpAddDevice(tester);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(calls.regenerate, 1);
    });

    testWidgets('narrates the wait as a three-stop timeline', (tester) async {
      // Waiting, joined, verified: the body tells the whole story so the
      // pinned bar only has to explain its locked buttons.
      await pumpAddDevice(tester);

      final context = tester.element(find.byType(AddDeviceView));
      expect(find.byKey(const Key('add_device_timeline')), findsOneWidget);
      expect(
        find.text(context.messages.syncAddDeviceTimelineWaiting),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.syncAddDeviceTimelineJoined),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.syncAddDeviceTimelineVerified),
        findsOneWidget,
      );
    });
  });

  group('AddDeviceView join signal', () {
    testWidgets('waits while the account still holds only this device', (
      tester,
    ) async {
      final signal = newSignal(tester);
      await pumpAddDevice(tester, signal: signal);
      await tester.pump();

      expect(signal.value, AddDeviceJoinState.waiting);
    });

    testWidgets('follows the joined device through emoji verification', (
      tester,
    ) async {
      final signal = newSignal(tester);
      final container = ProviderContainer(
        overrides: overrides(calls: _Calls()),
      );
      addTearDown(container.dispose);

      useTallSurface(tester);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: makeTestableWidgetWithScaffold(
            SingleChildScrollView(
              child: AddDeviceView(
                pollInterval: const Duration(days: 1),
                signal: signal,
              ),
            ),
          ),
        ),
      );
      // Let the first roster resolve: the baseline is the set of sessions
      // present when the sheet opened, and it cannot latch before that.
      await tester.pump();
      await tester.pump();
      expect(signal.value, AddDeviceJoinState.waiting);
      expect(container.read(syncDevicesControllerProvider).value, isNotNull);

      // A session the sheet had not seen when it opened is the new device.
      container.read(syncDevicesControllerProvider.notifier).state =
          AsyncData<List<SyncDeviceInfo>>([...existing, newPhone]);
      await tester.pump();
      await tester.pump();

      expect(signal.value, AddDeviceJoinState.joined);

      // A success that blinks away is worse than none: a later roster that no
      // longer looks new must not undo it.
      container.read(syncDevicesControllerProvider.notifier).state =
          AsyncData<List<SyncDeviceInfo>>([...existing, newPhone]);
      await tester.pump();
      await tester.pump();
      expect(signal.value, AddDeviceJoinState.joined);

      // Joining is not sufficient: directlyVerifiedOnly key sharing withholds
      // the keys until the emoji ceremony completes. Follow the same target
      // identity until the roster reports it verified.
      container.read(syncDevicesControllerProvider.notifier).state =
          AsyncData<List<SyncDeviceInfo>>([...existing, verifiedPhone]);
      await tester.pump();
      await tester.pump();
      expect(signal.value, AddDeviceJoinState.ready);
      expect(signal.target?.deviceId, verifiedPhone.deviceId);
      expect(signal.target?.userId, '@alice:example.com');
    });

    testWidgets('logs once when a verified target has no resolvable user ID', (
      tester,
    ) async {
      when(() => mockMatrixService.loadConfig()).thenAnswer((_) async => null);
      final logger = MockDomainLogger();
      when(
        () => logger.error(
          LogDomain.sync,
          any<Object>(),
          subDomain: 'addDeviceTarget',
        ),
      ).thenReturn(null);
      await getIt.unregister<DomainLogger>();
      getIt.registerSingleton<DomainLogger>(logger);

      final signal = newSignal(tester);
      final container = ProviderContainer(
        overrides: overrides(calls: _Calls()),
      );
      addTearDown(container.dispose);
      useTallSurface(tester);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: makeTestableWidgetWithScaffold(
            SingleChildScrollView(
              child: AddDeviceView(
                pollInterval: const Duration(days: 1),
                signal: signal,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      container.read(syncDevicesControllerProvider.notifier).state =
          AsyncData<List<SyncDeviceInfo>>([...existing, newPhone]);
      await tester.pump();
      await tester.pump();
      container.read(syncDevicesControllerProvider.notifier).state =
          AsyncData<List<SyncDeviceInfo>>([...existing, verifiedPhone]);
      await tester.pump();
      await tester.pump();

      expect(signal.value, AddDeviceJoinState.joined);
      expect(signal.target, isNull);
      verify(
        () => logger.error(
          LogDomain.sync,
          any<Object>(),
          subDomain: 'addDeviceTarget',
        ),
      ).called(1);

      container.read(syncDevicesControllerProvider.notifier).state =
          AsyncData<List<SyncDeviceInfo>>([...existing, verifiedPhone]);
      await tester.pump();
      verifyNever(
        () => logger.error(
          LogDomain.sync,
          any<Object>(),
          subDomain: 'addDeviceTarget',
        ),
      );
    });

    testWidgets('stops claiming to wait once the roster keeps failing', (
      tester,
    ) async {
      // Three consecutive failures: one miss is a flaky request, but a dead
      // homeserver would otherwise spin "Waiting…" forever with no way out.
      final signal = newSignal(tester);
      await pumpAddDevice(
        tester,
        signal: signal,
        refreshSucceeds: false,
        pollInterval: const Duration(seconds: 5),
      );

      for (var i = 0; i < kAddDeviceMaxPollFailures; i++) {
        expect(signal.value, AddDeviceJoinState.waiting);
        await tester.pump(const Duration(seconds: 5));
        await tester.pump();
      }

      expect(signal.value, AddDeviceJoinState.rosterFailed);
    });

    testWidgets('stops polling once it has given up, and resumes on retry', (
      tester,
    ) async {
      // Continuing to hammer a homeserver that has failed three times running
      // changes nothing on screen and only adds load.
      final signal = newSignal(tester);
      final calls = await pumpAddDevice(
        tester,
        signal: signal,
        refreshSucceeds: false,
        pollInterval: const Duration(seconds: 5),
      );

      for (var i = 0; i < kAddDeviceMaxPollFailures; i++) {
        await tester.pump(const Duration(seconds: 5));
        await tester.pump();
      }
      expect(signal.value, AddDeviceJoinState.rosterFailed);

      final settled = calls.refresh;
      await tester.pump(const Duration(seconds: 30));
      await tester.pump();
      expect(calls.refresh, settled);

      signal.onRetry!();
      await tester.pump();
      await tester.pump();
      expect(calls.refresh, greaterThan(settled));

      // And the timer is running again.
      final afterRetry = calls.refresh;
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
      expect(calls.refresh, greaterThan(afterRetry));
    });

    testWidgets('treats a foreign device id as a different device', (
      tester,
    ) async {
      // Device ids are unique only within a Matrix user, and the roster spans
      // users so legacy one-account-per-device pairings still appear. Keyed on
      // the id alone, a new device colliding with a foreign one read as
      // already known and the sheet never latched.
      final signal = newSignal(tester);
      const foreign = SyncDeviceInfo(
        deviceId: 'SHARED',
        displayName: 'Legacy phone',
        isCurrentDevice: false,
        verified: false,
        userId: '@other:example.com',
      );
      final container = ProviderContainer(
        overrides: overrides(
          calls: _Calls(),
          devices: [...existing, foreign],
        ),
      );
      addTearDown(container.dispose);

      useTallSurface(tester);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: makeTestableWidgetWithScaffold(
            SingleChildScrollView(
              child: AddDeviceView(
                pollInterval: const Duration(days: 1),
                signal: signal,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(signal.value, AddDeviceJoinState.waiting);

      // Same device id, this account: a genuinely new session.
      container
          .read(syncDevicesControllerProvider.notifier)
          .state = AsyncData<List<SyncDeviceInfo>>([
        ...existing,
        foreign,
        const SyncDeviceInfo(
          deviceId: 'SHARED',
          displayName: 'New phone',
          isCurrentDevice: false,
          verified: false,
        ),
      ]);
      await tester.pump();
      await tester.pump();

      expect(signal.value, AddDeviceJoinState.joined);
    });

    testWidgets('a retry re-reads the roster and drops the error state', (
      tester,
    ) async {
      final signal = newSignal(tester);
      final calls = await pumpAddDevice(
        tester,
        signal: signal,
        refreshSucceeds: false,
        pollInterval: const Duration(seconds: 5),
      );

      for (var i = 0; i < kAddDeviceMaxPollFailures; i++) {
        await tester.pump(const Duration(seconds: 5));
        await tester.pump();
      }
      expect(signal.value, AddDeviceJoinState.rosterFailed);

      final before = calls.refresh;
      // The bar owns the control; the body owns the counter, so the retry has
      // to travel through the shared signal.
      signal.onRetry!();
      await tester.pump();
      await tester.pump();

      expect(calls.refresh, before + 1);
      // The counter resets, so a single further failure is not enough to
      // re-enter the error state.
      expect(signal.value, AddDeviceJoinState.waiting);
    });

    testWidgets('clears its retry hook when the sheet closes', (tester) async {
      final signal = newSignal(tester);
      await pumpAddDevice(tester, signal: signal);
      expect(signal.onRetry, isNotNull);

      await tester.pumpWidget(const SizedBox.shrink());
      expect(signal.onRetry, isNull);
    });
  });

  group('AddDeviceView layout', () {
    testWidgets('stacks the code above its details on a phone', (tester) async {
      // The wide branch splits them into two columns; a phone has to keep the
      // single column, and every other test here runs on a wide surface.
      tester.view
        ..physicalSize = const Size(390, 2400)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SingleChildScrollView(
            child: AddDeviceView(pollInterval: Duration(days: 1)),
          ),
          overrides: overrides(calls: _Calls()),
        ),
      );
      await tester.pump();

      final qr = tester.getRect(find.byKey(const Key('addDeviceQrImage')));
      final code = tester.getRect(
        find.byKey(const Key('add_device_check_code')),
      );
      // Stacked: the check code sits below the image, not beside it.
      expect(code.top, greaterThan(qr.bottom));
      // And the code sizes itself rather than taking a parent-set width.
      expect(qr.width, lessThanOrEqualTo(390));
      expect(qr.width, greaterThanOrEqualTo(200));
    });

    testWidgets('puts the code beside its details on a wide card', (
      tester,
    ) async {
      await pumpAddDevice(tester);

      final qr = tester.getRect(find.byKey(const Key('addDeviceQrImage')));
      final code = tester.getRect(
        find.byKey(const Key('add_device_check_code')),
      );
      expect(code.left, greaterThan(qr.right));
    });

    testWidgets('reduced motion parks the timeline dot', (tester) async {
      // The active stop's pulse must respect the OS animation veto — and
      // actually stop its controller, or the "waiting" screen ticks forever.
      useTallSurface(tester);
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SingleChildScrollView(
            child: AddDeviceView(pollInterval: Duration(days: 1)),
          ),
          overrides: overrides(calls: _Calls()),
          mediaQueryData: phoneMediaQueryData.copyWith(
            disableAnimations: true,
          ),
        ),
      );
      await tester.pump();

      // Settles only because the dot's controller is parked; a live
      // repeat(reverse: true) would make this time out.
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('add_device_timeline')), findsOneWidget);
    });
  });

  group('AddDeviceActionBar', () {
    Future<void> pumpBar(
      WidgetTester tester, {
      required List<SyncDeviceInfo> devices,
      Future<void> Function(BuildContext)? onSendMessages,
      Future<void> Function(BuildContext)? onSendSettings,
      AddDeviceJoinState state = AddDeviceJoinState.waiting,
    }) async {
      final signal = AddDeviceJoinSignal()..value = state;
      addTearDown(signal.dispose);
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          AddDeviceActionBar(
            signal: signal,
            onSendMessages: onSendMessages ?? (_) async {},
            onSendSettings: onSendSettings ?? (_) async {},
          ),
          overrides: overrides(calls: _Calls(), devices: devices),
        ),
      );
      await tester.pump();
    }

    testWidgets('withholds the hand-off while this is the only device', (
      tester,
    ) async {
      await pumpBar(tester, devices: existing);

      // Pressing it now would push config to nobody, and the bar says why.
      final button = tester.widget<DesignSystemButton>(
        find.byKey(const Key('add_device_send_settings')),
      );
      expect(button.onPressed, isNull);
      expect(
        tester
            .widget<DesignSystemButton>(
              find.byKey(const Key('add_device_send_messages')),
            )
            .onPressed,
        isNull,
      );
      expect(
        find.byKey(const Key('add_device_send_settings_pending')),
        findsOneWidget,
      );
    });

    testWidgets('carries the live status the body cannot show on a phone', (
      tester,
    ) async {
      // The body's own timeline can sit below the fold on a phone, so the
      // pinned bar is the only place the inviting user can see whether
      // anything is happening.
      await pumpBar(tester, devices: existing);
      expect(
        find.byKey(const Key('add_device_send_settings_pending')),
        findsOneWidget,
      );

      await pumpBar(
        tester,
        devices: [...existing, newPhone],
        state: AddDeviceJoinState.joined,
      );
      expect(find.byKey(const Key('add_device_joined')), findsOneWidget);
      expect(
        find.byKey(const Key('add_device_send_settings_pending')),
        findsNothing,
      );
    });

    testWidgets('offers a retry when the roster cannot be read', (
      tester,
    ) async {
      var retries = 0;
      final signal = AddDeviceJoinSignal()
        ..value = AddDeviceJoinState.rosterFailed
        ..onRetry = () => retries++;
      addTearDown(signal.dispose);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          AddDeviceActionBar(signal: signal, onSendSettings: (_) async {}),
          overrides: overrides(calls: _Calls()),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('add_device_poll_failed')), findsOneWidget);
      await tester.tap(find.byKey(const Key('add_device_poll_retry')));
      await tester.pump();
      expect(retries, 1);
    });

    testWidgets('the hand-off pair stacks below the wide-card width', (
      tester,
    ) async {
      // Two large labeled buttons in one phone-width row ellipsize both
      // labels; below the pairing card's breakpoint they stack, full width.
      final signal = AddDeviceJoinSignal()..value = AddDeviceJoinState.waiting;
      addTearDown(signal.dispose);
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          SizedBox(
            width: kAddDeviceWideCard - 40,
            child: AddDeviceActionBar(
              signal: signal,
              onSendMessages: (_) async {},
              onSendSettings: (_) async {},
            ),
          ),
          overrides: overrides(calls: _Calls(), devices: existing),
        ),
      );
      await tester.pump();

      final settings = tester.getRect(
        find.byKey(const Key('add_device_send_settings')),
      );
      final messages = tester.getRect(
        find.byKey(const Key('add_device_send_messages')),
      );
      expect(settings.bottom, lessThanOrEqualTo(messages.top));
      expect(
        settings.left,
        messages.left,
        reason: 'stacked and stretched, not side by side',
      );
      expect(settings.width, messages.width);
    });

    testWidgets('wears the lock while the hand-off is gated', (
      tester,
    ) async {
      // The lock glyph carries the "not yet" story on the buttons
      // themselves; the caption below says why in one line.
      await pumpBar(tester, devices: existing);

      expect(find.byIcon(Icons.lock_outline), findsNWidgets(2));
      expect(find.byIcon(Icons.sync_alt_rounded), findsNothing);
    });

    testWidgets('is quiet, and says so, while it cannot be pressed', (
      tester,
    ) async {
      // The caption and the buttons have to agree. Outlined rather than
      // secondary: the component paints an enabled secondary with the same
      // fill it paints a disabled filled button, so a live action would have
      // read as inert.
      await pumpBar(tester, devices: existing);

      final context = tester.element(find.byType(AddDeviceActionBar));
      expect(
        tester
            .widget<DesignSystemButton>(
              find.byKey(const Key('add_device_send_settings')),
            )
            .variant,
        DesignSystemButtonVariant.outlined,
      );
      expect(
        find.text(context.messages.syncAddDeviceUnlockHint),
        findsOneWidget,
      );
    });

    testWidgets('takes the accent as soon as it can be pressed', (
      tester,
    ) async {
      await pumpBar(
        tester,
        devices: [...existing, verifiedPhone],
        state: AddDeviceJoinState.ready,
      );

      final context = tester.element(find.byType(AddDeviceActionBar));
      expect(
        tester
            .widget<DesignSystemButton>(
              find.byKey(const Key('add_device_send_settings')),
            )
            .variant,
        DesignSystemButtonVariant.primary,
      );
      // Verification is complete, so the ready status agrees with the live
      // action.
      expect(find.byKey(const Key('add_device_ready')), findsOneWidget);
      // `context` keeps the localized lookup used by sibling assertions.
      expect(
        find.text(context.messages.syncAddDeviceSendSettingsReady),
        findsOneWidget,
      );
    });

    testWidgets('stays quiet after join until emoji verification', (
      tester,
    ) async {
      await pumpBar(
        tester,
        devices: [...existing, newPhone],
        state: AddDeviceJoinState.joined,
      );
      expect(
        tester
            .widget<DesignSystemButton>(
              find.byKey(const Key('add_device_send_settings')),
            )
            .variant,
        DesignSystemButtonVariant.outlined,
      );
      expect(find.byKey(const Key('add_device_joined')), findsOneWidget);
    });

    testWidgets('withholds transfers until the joined device is verified', (
      tester,
    ) async {
      await pumpBar(
        tester,
        devices: [...existing, newPhone],
        state: AddDeviceJoinState.joined,
      );

      expect(
        tester
            .widget<DesignSystemButton>(
              find.byKey(const Key('add_device_send_settings')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<DesignSystemButton>(
              find.byKey(const Key('add_device_send_messages')),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('does not let an older peer unlock a new target', (
      tester,
    ) async {
      // Existing peers say nothing about whether the device joining through
      // this sheet has completed emoji verification.
      await pumpBar(tester, devices: [...existing, newPhone]);

      final button = tester.widget<DesignSystemButton>(
        find.byKey(const Key('add_device_send_settings')),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('offers message history once the target is verified', (
      tester,
    ) async {
      await pumpBar(
        tester,
        devices: [...existing, verifiedPhone],
        state: AddDeviceJoinState.ready,
      );

      final sendMessages = tester.widget<DesignSystemButton>(
        find.byKey(const Key('add_device_send_messages')),
      );
      expect(sendMessages.onPressed, isNotNull);
    });

    testWidgets('opens onboarding history for the exact verified target', (
      tester,
    ) async {
      const target = OnboardingSyncTarget(
        userId: '@alice:example.com',
        deviceId: 'NEWPHONE',
      );
      final signal = AddDeviceJoinSignal()
        ..target = target
        ..value = AddDeviceJoinState.ready;
      addTearDown(signal.dispose);
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          AddDeviceActionBar(
            signal: signal,
            onSendSettings: (_) async {},
          ),
          overrides: overrides(
            calls: _Calls(),
            devices: [...existing, verifiedPhone],
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('add_device_send_messages')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final modal = tester.widget<ReSyncModalContent>(
        find.byType(ReSyncModalContent),
      );
      expect(modal.onboardingTarget?.userId, target.userId);
      expect(modal.onboardingTarget?.deviceId, target.deviceId);
    });

    testWidgets('runs the hand-off when pressed', (tester) async {
      var handOffs = 0;
      await pumpBar(
        tester,
        devices: [...existing, verifiedPhone],
        state: AddDeviceJoinState.ready,
        onSendSettings: (_) async => handOffs++,
      );

      await tester.tap(find.byKey(const Key('add_device_send_settings')));
      await tester.pump();

      expect(handOffs, 1);
    });

    testWidgets('opens message history when pressed', (tester) async {
      var messageHandOffs = 0;
      await pumpBar(
        tester,
        devices: [...existing, verifiedPhone],
        state: AddDeviceJoinState.ready,
        onSendMessages: (_) async => messageHandOffs++,
      );

      await tester.tap(find.byKey(const Key('add_device_send_messages')));
      await tester.pump();

      expect(messageHandOffs, 1);
    });
  });

  group('AddDeviceModal viewport fit', () {
    // Real fonts, not Ahem: the guarantee is geometric, and the test font's
    // fatter glyphs wrap prose onto extra lines that push the QR below where
    // production actually renders it.
    setUpAll(loadAppFonts);

    testWidgets('QR and check code clear the pinned bar at 1280x700', (
      tester,
    ) async {
      // The user-reported defect: at a short desktop window the sticky
      // hand-off bar sliced the QR mid-symbol — unscannable, and with no cue
      // that scrolling would reveal the rest. The QR is the one artifact
      // this sheet exists to show; it must render whole at rest.
      tester.view
        ..physicalSize = const Size(2560, 1400)
        ..devicePixelRatio = 2.0; // logical 1280×700
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final calls = _Calls();
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(
            builder: (context) => Center(
              child: DesignSystemButton(
                label: 'open',
                onPressed: () => AddDeviceModal.show(context),
              ),
            ),
          ),
          overrides: overrides(calls: calls),
          // Production geometry, or the guarantee is about the wrong world:
          // the default phone MediaQuery renders a bottom sheet instead of
          // the desktop dialog, and the bare test theme's larger type wraps
          // prose onto extra lines the shipped app never shows.
          theme: screenshotTheme(),
          mediaQueryData: const MediaQueryData(size: Size(1280, 700)),
        ),
      );
      await tester.tap(find.text('open'));
      // Bounded pumps, not pumpAndSettle: the bar's waiting spinner animates
      // indefinitely, so the tree never settles.
      for (var i = 0; i < 24; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      final qr = tester.getRect(find.byKey(const Key('addDeviceQrImage')));
      final bar = tester.getRect(find.byType(SyncStickyBar));
      expect(
        qr.bottom,
        lessThanOrEqualTo(bar.top),
        reason: 'the QR must render whole above the pinned bar at rest',
      );
      final check = tester.getRect(
        find.byKey(const Key('add_device_check_code')),
      );
      expect(
        check.bottom,
        lessThanOrEqualTo(bar.top),
        reason: 'the check code is part of the comparison the sheet asks for',
      );

      // Tear the sheet down so the roster poll timer cancels before the
      // test ends.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });
}
