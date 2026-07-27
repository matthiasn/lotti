import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/models/sync_device_info.dart';
import 'package:lotti/features/sync/state/matrix_login_controller.dart';
import 'package:lotti/features/sync/ui/provisioned/provisioned_status_page.dart';
import 'package:lotti/features/sync/ui/provisioned/provisioned_sync_modal.dart';
import 'package:lotti/features/sync/ui/provisioned_sync_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/utils/consts.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_helper.dart';
import '../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestGetItMocks mocks;
  late MockMatrixService mockMatrixService;
  late MockMatrixClient mockClient;
  late MockUserActivityService mockUserActivityService;

  setUp(() async {
    mocks = await setUpTestGetIt();
    mockMatrixService = MockMatrixService();
    mockClient = MockMatrixClient();
    mockUserActivityService = MockUserActivityService();
    when(mockMatrixService.isLoggedIn).thenReturn(false);
    when(() => mockMatrixService.syncRoomId).thenReturn(null);
    when(() => mockMatrixService.client).thenReturn(mockClient);
    when(() => mockClient.userID).thenReturn(null);
    when(() => mockUserActivityService.updateActivity()).thenReturn(null);
    // SliverBoxAdapterPage wires a scroll listener to UserActivityService.
    getIt.registerSingleton<UserActivityService>(mockUserActivityService);
  });

  tearDown(tearDownTestGetIt);

  Future<void> pump(
    WidgetTester tester, {
    required bool enabled,
    bool configured = false,
  }) async {
    when(mockMatrixService.isLoggedIn).thenReturn(configured);
    when(
      () => mockMatrixService.syncRoomId,
    ).thenReturn(configured ? '!room:example.com' : null);
    when(
      () => mockMatrixService.getUnverifiedDevices(),
    ).thenReturn([]);
    when(
      () => mockMatrixService.getSyncDevices(),
    ).thenAnswer((_) async => const <SyncDeviceInfo>[]);
    when(
      () => mockMatrixService.keyVerificationStream,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => mocks.journalDb.watchConfigFlag(enableMatrixFlag),
    ).thenAnswer((_) => Stream<bool>.value(enabled));
    await tester.pumpWidget(
      RiverpodWidgetTestBench(
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
        ],
        child: const ProvisionedSyncPage(),
      ),
    );
    await tester.pump();
    // Drain the page chrome's back-button fade-in so no timer is left
    // pending at teardown.
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets(
    'renders the provisioned-sync card when matrix sync is enabled',
    (tester) async {
      await pump(tester, enabled: true);

      final context = tester.element(find.byType(ProvisionedSyncPage));
      expect(find.byType(SyncSetupEmptyState), findsOneWidget);
      // Both the page header and the card surface the same title.
      expect(find.text(context.messages.provisionedSyncTitle), findsWidgets);
    },
  );

  testWidgets(
    'feature gate hides the card when matrix sync is disabled',
    (tester) async {
      await pump(tester, enabled: false);

      expect(find.byType(SyncSetupEmptyState), findsNothing);
    },
  );

  testWidgets(
    'swaps to the roster when startup finishes, without leaving the page',
    (tester) async {
      // `matrixServiceProvider` hands back one stable object, so watching it
      // never notifies when login and room hydration complete. Init runs
      // unawaited at bootstrap, so a route opened mid-startup used to keep the
      // setup card until the user navigated away and back.
      // A finite stream rather than a controller closed at teardown: the page
      // stays subscribed through `loginStateStreamProvider`, and closing a
      // broadcast controller during async widget teardown can race the
      // listener under the bundled runner (see test/README.md).
      final loginGate = Completer<void>();
      Stream<LoginState> loginStates() async* {
        await loginGate.future;
        yield LoginState.loggedIn;
      }

      var configured = false;
      when(mockMatrixService.isLoggedIn).thenAnswer((_) => configured);
      when(
        () => mockMatrixService.syncRoomId,
      ).thenAnswer((_) => configured ? '!room:example.com' : null);
      when(() => mockMatrixService.getUnverifiedDevices()).thenReturn([]);
      when(
        () => mockMatrixService.getSyncDevices(),
      ).thenAnswer((_) async => const <SyncDeviceInfo>[]);
      when(
        () => mockMatrixService.keyVerificationStream,
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => mocks.journalDb.watchConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) => Stream<bool>.value(true));

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
            loginStateStreamProvider.overrideWith((_) => loginStates()),
          ],
          child: const ProvisionedSyncPage(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(SyncSetupEmptyState), findsOneWidget);

      // Startup completes: the login stream is the signal that gets the page
      // to re-evaluate.
      configured = true;
      loginGate.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ProvisionedStatusWidget), findsOneWidget);
      expect(find.byType(SyncSetupEmptyState), findsNothing);

      // Unmount inside the test body so the stream's subscription is torn
      // down here rather than racing teardown.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'shows the device roster inline once sync is configured, as desktop does',
    (tester) async {
      // Every instruction in the pairing flow says "open Settings → Sync
      // Settings → Devices, then choose Add device". While this page rendered
      // the setup card unconditionally, a mobile user following that sentence
      // landed on a screen with no Add device on it.
      await pump(tester, enabled: true, configured: true);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ProvisionedStatusWidget), findsOneWidget);
      expect(
        tester
            .widget<ProvisionedStatusWidget>(
              find.byType(ProvisionedStatusWidget),
            )
            .embedded,
        isTrue,
      );
      expect(find.byKey(const Key('sync_devices_add_device')), findsOneWidget);
      expect(find.byType(SyncSetupEmptyState), findsNothing);
    },
  );
}
