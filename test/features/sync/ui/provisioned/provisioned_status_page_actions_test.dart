import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/state/matrix_unverified_provider.dart';
import 'package:lotti/features/sync/state/matrix_verification_modal_lock_provider.dart';
import 'package:lotti/features/sync/state/provisioning_controller.dart';
import 'package:lotti/features/sync/ui/provisioned/provisioned_status_page.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/diagnostic_info_button.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/verification_modal.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/utils/platform.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import 'provisioned_status_page_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMatrixService mockMatrixService;
  late MockMatrixClient mockClient;

  setUpAll(() {
    registerFallbackValue(FakeDeviceKeys());
  });

  setUp(() {
    mockMatrixService = MockMatrixService();
    mockClient = MockMatrixClient();

    when(() => mockMatrixService.client).thenReturn(mockClient);
    when(() => mockClient.userID).thenReturn('@alice:example.com');
    when(() => mockMatrixService.syncRoomId).thenReturn('!room123:example.com');
    when(() => mockMatrixService.deleteConfig()).thenAnswer((_) async {});
    when(() => mockMatrixService.getUnverifiedDevices()).thenReturn([]);
    when(() => mockMatrixService.getSyncDevices()).thenAnswer((_) async => []);
    when(
      () => mockMatrixService.keyVerificationStream,
    ).thenAnswer((_) => const Stream.empty());
    when(() => mockMatrixService.verifyDevice(any())).thenAnswer((_) async {});
    when(() => mockMatrixService.loadConfig()).thenAnswer(
      (_) async => const MatrixConfig(
        homeServer: 'https://matrix.example.com',
        user: '@alice:example.com',
        password: 'rotated-pw',
      ),
    );
  });

  testWidgets(
    'auto-verification launcher shows modal for unverified devices',
    (tester) async {
      final mockDevice = MockDeviceKeys();
      when(() => mockDevice.deviceDisplayName).thenReturn('Other Device');
      when(() => mockDevice.deviceId).thenReturn('OTHERDEVICE');
      when(() => mockDevice.userId).thenReturn('@alice:example.com');
      when(
        () => mockMatrixService.verifyDevice(mockDevice),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ProvisionedStatusWidget(),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
            matrixUnverifiedControllerProvider.overrideWith(
              () => FakeMatrixUnverifiedController([mockDevice]),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The auto-verification launcher should trigger a verification modal
      expect(find.text('Other Device'), findsWidgets);
    },
  );

  group('_StatusActionBar close button', () {
    // Covers lines 61, 63-64: the close button's onPressed resets the page
    // index notifier to 0 and pops the current route.
    testWidgets(
      'resets page index notifier to 0 and pops the route',
      (tester) async {
        final pageIndexNotifier = ValueNotifier<int>(3);
        addTearDown(pageIndexNotifier.dispose);

        // Build the real page via the public factory and extract the private
        // _StatusActionBar from its stickyActionBar so we can drive it inside a
        // navigator and observe the pop.
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            Builder(
              builder: (outerContext) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(outerContext).push(
                      MaterialPageRoute<void>(
                        builder: (routeContext) {
                          final page = provisionedStatusPage(
                            context: routeContext,
                            pageIndexNotifier: pageIndexNotifier,
                          );
                          return Scaffold(
                            body: page.stickyActionBar,
                          );
                        },
                      ),
                    );
                  },
                  child: const Text('Open Action Bar'),
                ),
              ),
            ),
            overrides: [
              matrixServiceProvider.overrideWithValue(mockMatrixService),
            ],
          ),
        );
        await tester.pump();

        await tester.tap(find.text('Open Action Bar'));
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(DesignSystemButton));
        final closeFinder = find.text(
          context.messages.tasksLabelsDialogClose,
        );
        expect(closeFinder, findsOneWidget);

        await tester.tap(closeFinder);
        await tester.pumpAndSettle();

        // Notifier was reset and the action-bar route was popped.
        expect(pageIndexNotifier.value, 0);
        expect(find.byType(DesignSystemButton), findsNothing);
        expect(find.text('Open Action Bar'), findsOneWidget);
      },
    );
  });

  group('action hierarchy', () {
    testWidgets('the page reads constructive-first, destructive-quietest', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ProvisionedStatusWidget(),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
            matrixUnverifiedControllerProvider.overrideWith(
              () => FakeMatrixUnverifiedController(const []),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      final context = tester.element(find.byType(ProvisionedStatusWidget));
      final messages = context.messages;

      // Two filled red pills and an accent-teal diagnostics link used to
      // outweigh the one action the page exists to offer.
      final disconnect = tester.widget<DesignSystemButton>(
        find.widgetWithText(
          DesignSystemButton,
          messages.provisionedSyncDisconnect,
        ),
      );
      expect(disconnect.variant, DesignSystemButtonVariant.dangerTertiary);

      final diagnostics = tester.widget<DesignSystemButton>(
        find.widgetWithText(
          DesignSystemButton,
          messages.settingsMatrixDiagnosticShowButton,
        ),
      );
      expect(diagnostics.variant, DesignSystemButtonVariant.outlined);
      // Neither support action borrows the "Add device" primary's shape, and
      // the diagnostics dump — the least likely reason anyone opens this
      // sheet — is the smaller of the two.
      expect(diagnostics.fullWidth, isFalse);
      expect(disconnect.fullWidth, isFalse);
      expect(diagnostics.size, DesignSystemButtonSize.small);
      // Both footer actions share one size; they were medium and small,
      // which is two pill geometries for a pair meant to read as one grammar.
      expect(disconnect.size, DesignSystemButtonSize.small);
      // Borderless, so its own padding has nothing to make it legible as
      // padding — without this the glyph reads as an arbitrary indent and the
      // footer shows three left edges.
      expect(disconnect.alignsLabelToLeadingEdge, isTrue);
      // And it comes last in the row.
      expect(
        tester.getTopLeft(find.byType(DiagnosticInfoButton)).dx,
        greaterThan(
          tester
              .getTopLeft(
                find.widgetWithText(
                  DesignSystemButton,
                  messages.provisionedSyncDisconnect,
                ),
              )
              .dx,
        ),
      );
    });
  });

  group('disconnect failure', () {
    testWidgets('a failed teardown says so and leaves the state alone', (
      tester,
    ) async {
      // Silently swallowing it left the pane showing a "configured" view of a
      // config that had not been torn down.
      ensureDomainLoggerRegistered();
      addTearDown(tearDownTestGetIt);
      when(
        () => mockMatrixService.deleteConfig(),
      ).thenThrow(Exception('homeserver unreachable'));

      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
            matrixUnverifiedControllerProvider.overrideWith(
              () => FakeMatrixUnverifiedController(const []),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: resolveTestTheme(),
            home: Consumer(
              builder: (ctx, ref, _) {
                container = ProviderScope.containerOf(ctx);
                return const Scaffold(body: ProvisionedStatusWidget());
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final context = tester.element(find.byType(ProvisionedStatusWidget));
      final messages = context.messages;

      await tester.tap(
        find.widgetWithText(
          DesignSystemButton,
          messages.provisionedSyncDisconnect,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(messages.syncDeleteConfigConfirm),
      );
      await tester.pumpAndSettle();

      verify(() => mockMatrixService.deleteConfig()).called(1);
      expect(find.text(messages.syncDisconnectFailed), findsOneWidget);
      // The provisioning state must not claim a teardown that did not happen.
      expect(
        container.read(provisioningControllerProvider),
        isA<ProvisioningState>().having(
          (s) => s,
          'stays initial',
          const ProvisioningState.initial(),
        ),
      );
    });
  });

  group('_AutoVerificationLauncher finally block', () {
    // Covers lines 174-175, 177-178: after the verification sheet closes, the
    // finally block invalidates the unverified provider and releases the lock.
    testWidgets(
      'releases lock and invalidates unverified provider after modal closes',
      (tester) async {
        final wasDesktop = isDesktop;
        isDesktop = false;
        addTearDown(() => isDesktop = wasDesktop);

        final mockDevice = MockDeviceKeys();
        when(() => mockDevice.deviceDisplayName).thenReturn('Other Device');
        when(() => mockDevice.deviceId).thenReturn('OTHERDEVICE');
        when(() => mockDevice.userId).thenReturn('@alice:example.com');
        when(
          () => mockMatrixService.verifyDevice(mockDevice),
        ).thenAnswer((_) async {});

        // build() is called once for the initial load; the finally block's
        // ref.invalidate triggers a second build.
        final buildCount = [0];

        late ProviderContainer container;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              matrixServiceProvider.overrideWithValue(mockMatrixService),
              matrixUnverifiedControllerProvider.overrideWith(
                () => CountingMatrixUnverifiedController(
                  [mockDevice],
                  buildCount,
                ),
              ),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: resolveTestTheme(),
              home: Consumer(
                builder: (ctx, ref, _) {
                  container = ProviderScope.containerOf(ctx);
                  return const Scaffold(body: ProvisionedStatusWidget());
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // The auto-launcher opened the verification modal and acquired the lock.
        expect(find.byType(VerificationModal), findsOneWidget);
        expect(container.read(matrixVerificationModalLockProvider), isTrue);
        final buildsBeforeClose = buildCount[0];

        // Close the modal via the top-bar close (X) button so the awaited
        // sheet future completes and the finally block runs.
        final closeButton = find.byIcon(LottiIcons.close);
        await tester.ensureVisible(closeButton);
        await tester.tap(closeButton);
        await tester.pumpAndSettle();

        // Modal gone, lock released, and the provider was invalidated/re-built.
        expect(find.byType(VerificationModal), findsNothing);
        expect(container.read(matrixVerificationModalLockProvider), isFalse);
        expect(buildCount[0], greaterThan(buildsBeforeClose));
      },
    );
  });
}
