import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/state/provisioning_controller.dart';
import 'package:lotti/features/sync/state/provisioning_error.dart';
import 'package:lotti/features/sync/ui/provisioned/provisioned_config_page.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/verification_modal.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../widget_test_utils.dart';

class MockMatrixService extends Mock implements MatrixService {}

class MockDeviceKeys extends Mock implements DeviceKeys {}

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
    v: 1,
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
    when(() => mockMatrixService.login()).thenAnswer((_) async => true);
    when(() => mockMatrixService.joinRoom(any()))
        .thenAnswer((_) async => '!room:example.com');
    when(() => mockMatrixService.saveRoom(any())).thenAnswer((_) async {});
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
  });

  tearDown(() {
    pageIndexNotifier.dispose();
  });

  group('ProvisionedConfigWidget', () {
    testWidgets('shows spinner when in initial state', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ProvisionedConfigWidget(pageIndexNotifier: pageIndexNotifier),
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

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('shows spinner when in bundleDecoded state', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ProvisionedConfigWidget(pageIndexNotifier: pageIndexNotifier),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
            provisioningControllerProvider.overrideWith(
              () => _FakeProvisioningController(
                const ProvisioningState.bundleDecoded(testBundle),
              ),
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('shows progress when in loggingIn state', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ProvisionedConfigWidget(pageIndexNotifier: pageIndexNotifier),
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

      final context = tester.element(find.byType(ProvisionedConfigWidget));
      expect(
        find.text(context.messages.provisionedSyncLoggingIn),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('shows progress when in joiningRoom state', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ProvisionedConfigWidget(pageIndexNotifier: pageIndexNotifier),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
            provisioningControllerProvider.overrideWith(
              () => _FakeProvisioningController(
                const ProvisioningState.joiningRoom(),
              ),
            ),
          ],
        ),
      );
      await tester.pump();

      final context = tester.element(find.byType(ProvisionedConfigWidget));
      expect(
        find.text(context.messages.provisionedSyncJoiningRoom),
        findsOneWidget,
      );
    });

    testWidgets('shows progress when in rotatingPassword state',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ProvisionedConfigWidget(pageIndexNotifier: pageIndexNotifier),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
            provisioningControllerProvider.overrideWith(
              () => _FakeProvisioningController(
                const ProvisioningState.rotatingPassword(),
              ),
            ),
          ],
        ),
      );
      await tester.pump();

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
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ProvisionedConfigWidget(pageIndexNotifier: pageIndexNotifier),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
            provisioningControllerProvider.overrideWith(
              () => _FakeProvisioningController(
                const ProvisioningState.ready('dGVzdC1oYW5kb3Zlci1kYXRh'),
              ),
            ),
          ],
        ),
      );
      await tester.pump();

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

    testWidgets('shows success when in done state', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ProvisionedConfigWidget(pageIndexNotifier: pageIndexNotifier),
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

      final context = tester.element(find.byType(ProvisionedConfigWidget));
      expect(
        find.text(context.messages.provisionedSyncDone),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('shows error and retry button in error state', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ProvisionedConfigWidget(pageIndexNotifier: pageIndexNotifier),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
            provisioningControllerProvider.overrideWith(
              () => _FakeProvisioningController(
                const ProvisioningState.error(ProvisioningError.loginFailed),
              ),
            ),
          ],
        ),
      );
      await tester.pump();

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
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProvisionedConfigWidget(pageIndexNotifier: pageIndexNotifier),
            overrides: [
              matrixServiceProvider.overrideWithValue(mockMatrixService),
              provisioningControllerProvider.overrideWith(
                () => _FakeProvisioningController(
                  const ProvisioningState.error(
                    ProvisioningError.configurationError,
                  ),
                ),
              ),
            ],
          ),
        );
        await tester.pump();

        final context = tester.element(find.byType(ProvisionedConfigWidget));
        expect(
          find.text(context.messages.provisionedSyncErrorConfigurationFailed),
          findsOneWidget,
        );
      },
    );

    testWidgets('shows masked handover data by default', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ProvisionedConfigWidget(pageIndexNotifier: pageIndexNotifier),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
            provisioningControllerProvider.overrideWith(
              () => _FakeProvisioningController(
                const ProvisioningState.ready('dGVzdC1oYW5kb3Zlci1kYXRh'),
              ),
            ),
          ],
        ),
      );
      await tester.pump();

      // Handover text should be masked by default
      expect(find.text('dGVzdC1oYW5kb3Zlci1kYXRh'), findsNothing);
      expect(find.text('\u2022' * 24), findsOneWidget);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });

    testWidgets('reveals handover data when visibility toggled',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ProvisionedConfigWidget(pageIndexNotifier: pageIndexNotifier),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
            provisioningControllerProvider.overrideWith(
              () => _FakeProvisioningController(
                const ProvisioningState.ready('dGVzdC1oYW5kb3Zlci1kYXRh'),
              ),
            ),
          ],
        ),
      );
      await tester.pump();

      // Tap the visibility toggle
      await tester.tap(find.byKey(const Key('toggleHandoverVisibility')));
      await tester.pump();

      // Now the handover text should be visible
      expect(find.text('dGVzdC1oYW5kb3Zlci1kYXRh'), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
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

        final context =
            tester.element(find.byType(_ConfigActionBarTestWrapper));

        // Find the Next button (LottiPrimaryButton) - it should be disabled
        final nextButton = tester.widget<LottiPrimaryButton>(
          find.widgetWithText(
            LottiPrimaryButton,
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

        final context =
            tester.element(find.byType(_ConfigActionBarTestWrapper));

        final nextButton = tester.widget<LottiPrimaryButton>(
          find.widgetWithText(
            LottiPrimaryButton,
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

        final context =
            tester.element(find.byType(_ConfigActionBarTestWrapper));
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

        final context =
            tester.element(find.byType(_ConfigActionBarTestWrapper));

        final nextButton = tester.widget<LottiPrimaryButton>(
          find.widgetWithText(
            LottiPrimaryButton,
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

        final context =
            tester.element(find.byType(_ConfigActionBarTestWrapper));
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

        final context =
            tester.element(find.byType(_ConfigActionBarTestWrapper));

        final nextButton = tester.widget<LottiPrimaryButton>(
          find.widgetWithText(
            LottiPrimaryButton,
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

        final context =
            tester.element(find.byType(_ConfigActionBarTestWrapper));

        final nextButton = tester.widget<LottiPrimaryButton>(
          find.widgetWithText(
            LottiPrimaryButton,
            context.messages.settingsMatrixNextPage,
          ),
        );
        expect(nextButton.onPressed, isNull);
      },
    );
  });
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
            LottiPrimaryButton(
              onPressed: isComplete ? () => pageIndexNotifier.value = 2 : null,
              label: context.messages.settingsMatrixNextPage,
            ),
          ],
        ),
      ],
    );
  }
}
