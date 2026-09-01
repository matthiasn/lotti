import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/inputs/design_system_text_input.dart';
import 'package:lotti/features/sync/state/provisioning_controller.dart';
import 'package:lotti/features/sync/ui/provisioned/manual_credentials_page.dart';
import 'package:lotti/features/sync/ui/provisioned/sync_setup_entry.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

/// Records what the form hands to the controller instead of signing in.
class _RecordingProvisioningController extends ProvisioningController {
  final configured = <MatrixConfig>[];

  @override
  ProvisioningState build() => const ProvisioningState.initial();

  @override
  Future<void> configureFromCredentials(MatrixConfig config) async {
    configured.add(config);
    state = const ProvisioningState.loggingIn();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMatrixService mockMatrixService;
  late ValueNotifier<int> pageIndexNotifier;
  late _RecordingProvisioningController controller;

  setUp(() {
    mockMatrixService = MockMatrixService();
    pageIndexNotifier = ValueNotifier(SyncSetupPage.credentials);
    controller = _RecordingProvisioningController();
    when(() => mockMatrixService.loadConfig()).thenAnswer((_) async => null);
  });

  tearDown(() => pageIndexNotifier.dispose());

  List<Override> overrides() => [
    matrixServiceProvider.overrideWithValue(mockMatrixService),
    provisioningControllerProvider.overrideWith(() => controller),
  ];

  Future<void> pumpForm(WidgetTester tester) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        ManualCredentialsWidget(pageIndexNotifier: pageIndexNotifier),
        overrides: overrides(),
      ),
    );
    await tester.pump();
  }

  Finder field(String key) => find.descendant(
    of: find.byKey(Key(key)),
    matching: find.byType(TextField),
  );

  DesignSystemButton submitButton(WidgetTester tester) =>
      tester.widget<DesignSystemButton>(
        find.byKey(const Key('sync_credentials_submit')),
      );

  Future<void> fill(
    WidgetTester tester, {
    String homeServer = 'matrix.example.com',
    String user = '@alice:example.com',
    String password = 'my-own-password',
  }) async {
    await tester.enterText(field('sync_credentials_homeserver'), homeServer);
    await tester.enterText(field('sync_credentials_user'), user);
    await tester.enterText(field('sync_credentials_password'), password);
    await tester.pump();
  }

  group('ManualCredentialsWidget', () {
    testWidgets('explains the step and asks for exactly three things', (
      tester,
    ) async {
      await pumpForm(tester);

      final context = tester.element(find.byType(ManualCredentialsWidget));
      expect(
        find.text(context.messages.syncCredentialsTitle),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.syncCredentialsIntro),
        findsOneWidget,
      );
      expect(find.byType(DesignSystemTextInput), findsNWidgets(3));
      // The password field starts hidden.
      final password = tester.widget<TextField>(
        field('sync_credentials_password'),
      );
      expect(password.obscureText, isTrue);
      // Where the password goes sits inside the frame that asks for it.
      expect(
        find.text(context.messages.syncCredentialsKeptOnDevice),
        findsOneWidget,
      );
    });

    testWidgets('the action stays disabled until every field has text', (
      tester,
    ) async {
      await pumpForm(tester);
      expect(submitButton(tester).onPressed, isNull);

      await tester.enterText(
        field('sync_credentials_homeserver'),
        'matrix.example.com',
      );
      await tester.enterText(
        field('sync_credentials_user'),
        '@alice:example.com',
      );
      await tester.pump();
      expect(submitButton(tester).onPressed, isNull);

      await tester.enterText(field('sync_credentials_password'), 'pw');
      await tester.pump();
      expect(submitButton(tester).onPressed, isNotNull);
    });

    testWidgets('a valid form signs in with the normalised config and moves '
        'to the connect step', (tester) async {
      await pumpForm(tester);
      await fill(tester);

      await tester.tap(find.byKey(const Key('sync_credentials_submit')));
      await tester.pump();

      expect(controller.configured, [
        const MatrixConfig(
          homeServer: 'https://matrix.example.com',
          user: '@alice:example.com',
          password: 'my-own-password',
        ),
      ]);
      expect(pageIndexNotifier.value, SyncSetupPage.connect);
    });

    testWidgets('Enter in the password field submits too', (tester) async {
      await pumpForm(tester);
      await fill(tester);

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(controller.configured, hasLength(1));
      expect(pageIndexNotifier.value, SyncSetupPage.connect);
    });

    testWidgets('a bad server address is reported on its own field and '
        'nothing is sent', (tester) async {
      await pumpForm(tester);
      await fill(tester, homeServer: 'http://insecure.example.com');

      await tester.tap(find.byKey(const Key('sync_credentials_submit')));
      await tester.pump();

      final context = tester.element(find.byType(ManualCredentialsWidget));
      final server = tester.widget<DesignSystemTextInput>(
        find.byKey(const Key('sync_credentials_homeserver')),
      );
      expect(server.errorText, context.messages.syncCredentialsErrorHomeserver);
      final user = tester.widget<DesignSystemTextInput>(
        find.byKey(const Key('sync_credentials_user')),
      );
      expect(user.errorText, isNull);
      expect(controller.configured, isEmpty);
      expect(pageIndexNotifier.value, SyncSetupPage.credentials);
    });

    testWidgets('a localpart instead of a Matrix ID is reported on the user '
        'field', (tester) async {
      await pumpForm(tester);
      await fill(tester, user: 'alice');

      await tester.tap(find.byKey(const Key('sync_credentials_submit')));
      await tester.pump();

      final context = tester.element(find.byType(ManualCredentialsWidget));
      final user = tester.widget<DesignSystemTextInput>(
        find.byKey(const Key('sync_credentials_user')),
      );
      expect(user.errorText, context.messages.syncCredentialsErrorUser);
      expect(controller.configured, isEmpty);
    });

    testWidgets('editing any field clears the error', (tester) async {
      await pumpForm(tester);
      await fill(tester, user: 'alice');
      await tester.tap(find.byKey(const Key('sync_credentials_submit')));
      await tester.pump();

      await tester.enterText(field('sync_credentials_user'), '@alice:x.org');
      await tester.pump();

      final user = tester.widget<DesignSystemTextInput>(
        find.byKey(const Key('sync_credentials_user')),
      );
      expect(user.errorText, isNull);
    });

    testWidgets('the eye toggles the password between hidden and shown', (
      tester,
    ) async {
      await pumpForm(tester);

      await tester.tap(
        find.byKey(const Key('sync_credentials_toggle_password')),
      );
      await tester.pump();
      expect(
        tester
            .widget<TextField>(field('sync_credentials_password'))
            .obscureText,
        isFalse,
      );

      await tester.tap(
        find.byKey(const Key('sync_credentials_toggle_password')),
      );
      await tester.pump();
      expect(
        tester
            .widget<TextField>(field('sync_credentials_password'))
            .obscureText,
        isTrue,
      );
    });

    testWidgets('prefills server and account from a persisted config, never '
        'the password', (tester) async {
      when(() => mockMatrixService.loadConfig()).thenAnswer(
        (_) async => const MatrixConfig(
          homeServer: 'https://old.example.com',
          user: '@old:example.com',
          password: 'stale-pw',
        ),
      );

      await pumpForm(tester);
      await tester.pump();

      expect(
        tester
            .widget<TextField>(field('sync_credentials_homeserver'))
            .controller!
            .text,
        'https://old.example.com',
      );
      expect(
        tester
            .widget<TextField>(field('sync_credentials_user'))
            .controller!
            .text,
        '@old:example.com',
      );
      expect(
        tester
            .widget<TextField>(field('sync_credentials_password'))
            .controller!
            .text,
        isEmpty,
      );
      // Two of three filled: the action still waits for the password.
      expect(submitButton(tester).onPressed, isNull);
    });

    testWidgets('the pairing-code link returns to the code page', (
      tester,
    ) async {
      await pumpForm(tester);

      await tester.tap(find.byKey(const Key('sync_credentials_use_code')));
      await tester.pump();

      expect(pageIndexNotifier.value, SyncSetupPage.pairingCode);
    });
  });

  group('manualCredentialsPage', () {
    testWidgets('titles the sheet like the pairing entry and hosts the form', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: resolveTestTheme(),
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => ModalUtils.showMultiPageModal<void>(
                    context: ctx,
                    pageIndexNotifier: ValueNotifier(0),
                    pageListBuilder: (modalCtx) => [
                      manualCredentialsPage(
                        context: modalCtx,
                        pageIndexNotifier: pageIndexNotifier,
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final context = tester.element(find.byType(ManualCredentialsWidget));
      // One sheet name across both entry pages.
      expect(
        find.text(context.messages.provisionedSyncImportTitle),
        findsOneWidget,
      );
      expect(find.byType(ManualCredentialsWidget), findsOneWidget);
    });
  });
}
