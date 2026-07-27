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
import 'package:lotti/features/sync/state/provisioning_controller.dart';
import 'package:lotti/features/sync/state/sync_devices_provider.dart';
import 'package:lotti/features/sync/ui/provisioned/add_device_page.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../mocks/mocks.dart';
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
  });

  final _Calls calls;
  final String? handover;
  final Completer<String?>? completer;

  @override
  ProvisioningState build() => const ProvisioningState.initial();

  @override
  Future<String?> regenerateHandover() {
    calls.regenerate++;
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

  setUp(() {
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
  }) => <Override>[
    matrixServiceProvider.overrideWithValue(mockMatrixService),
    provisioningControllerProvider.overrideWith(
      () => _FakeProvisioningController(
        calls: calls,
        handover: handoverData,
        completer: completer,
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

    testWidgets('reports the join and latches it', (tester) async {
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

  group('AddDeviceActionBar', () {
    Future<void> pumpBar(
      WidgetTester tester, {
      required List<SyncDeviceInfo> devices,
      Future<void> Function(BuildContext)? onSendSettings,
      AddDeviceJoinState state = AddDeviceJoinState.waiting,
    }) async {
      final signal = AddDeviceJoinSignal()..value = state;
      addTearDown(signal.dispose);
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          AddDeviceActionBar(
            signal: signal,
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
        find.byKey(const Key('add_device_send_settings_pending')),
        findsOneWidget,
      );
    });

    testWidgets('carries the live status the body cannot show on a phone', (
      tester,
    ) async {
      // The body's own strip is below the fold on a phone, so the pinned bar
      // is the only place the inviting user can see whether anything is
      // happening.
      await pumpBar(tester, devices: existing);
      expect(find.byKey(const Key('add_device_waiting')), findsOneWidget);

      await pumpBar(
        tester,
        devices: [...existing, newPhone],
        state: AddDeviceJoinState.joined,
      );
      expect(find.byKey(const Key('add_device_joined')), findsOneWidget);
      expect(find.byKey(const Key('add_device_waiting')), findsNothing);
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

    testWidgets('leads in without claiming a second position', (tester) async {
      // The button needs a rung — its body heading is below the fold on every
      // viewport — but a second "Step N of 2" on the same screen stops either
      // fraction indicating anything.
      await pumpBar(tester, devices: existing);

      final context = tester.element(find.byType(AddDeviceActionBar));
      expect(
        find.text(context.messages.syncAddDeviceNextLeadIn),
        findsOneWidget,
      );
      // No second fraction: the body already carries "Now · Show the code".
      expect(
        find.text(context.messages.syncAddDeviceStepScan),
        findsNothing,
      );
    });

    testWidgets('is quiet, and says so, while it cannot be pressed', (
      tester,
    ) async {
      // Three lines about one control have to agree. Outlined rather than
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
        find.text(context.messages.syncAddDeviceNextLeadIn),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.syncAddDeviceSendSettingsPending),
        findsOneWidget,
      );
    });

    testWidgets('takes the accent as soon as it can be pressed', (
      tester,
    ) async {
      await pumpBar(tester, devices: [...existing, newPhone]);

      final context = tester.element(find.byType(AddDeviceActionBar));
      expect(
        tester
            .widget<DesignSystemButton>(
              find.byKey(const Key('add_device_send_settings')),
            )
            .variant,
        DesignSystemButtonVariant.primary,
      );
      // And the lead-in is gone rather than saying "after it joins" over a
      // status line saying "send now".
      expect(
        find.text(context.messages.syncAddDeviceNextLeadIn),
        findsNothing,
      );
    });

    testWidgets('takes the accent once the new device is here', (
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
        DesignSystemButtonVariant.primary,
      );
      // Nothing left to explain: the device it was waiting for has arrived.
      expect(
        find.byKey(const Key('add_device_send_settings_pending')),
        findsNothing,
      );
      expect(find.byKey(const Key('add_device_joined')), findsOneWidget);
    });

    testWidgets('offers the hand-off whenever the account has a peer', (
      tester,
    ) async {
      // Deliberately not "a device appeared while this sheet was open": the
      // joining device tells the user to come back here and press this, by
      // which point the sheet has been closed and reopened, so a delta-only
      // gate left the button dead forever.
      await pumpBar(tester, devices: [...existing, newPhone]);

      final button = tester.widget<DesignSystemButton>(
        find.byKey(const Key('add_device_send_settings')),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('runs the hand-off when pressed', (tester) async {
      var handOffs = 0;
      await pumpBar(
        tester,
        devices: [...existing, newPhone],
        onSendSettings: (_) async => handOffs++,
      );

      await tester.tap(find.byKey(const Key('add_device_send_settings')));
      await tester.pump();

      expect(handOffs, 1);
    });

    test('hasPeer ignores this device and an unresolved roster', () {
      expect(AddDeviceActionBar.hasPeer(null), isFalse);
      expect(AddDeviceActionBar.hasPeer(const []), isFalse);
      expect(AddDeviceActionBar.hasPeer(existing), isFalse);
      expect(AddDeviceActionBar.hasPeer([...existing, newPhone]), isTrue);
    });
  });
}
