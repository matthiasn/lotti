import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/sync/sync_message.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/inputs/design_system_text_input.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/github/api/github_client.dart';
import 'package:lotti/features/github/domain/github_token_template.dart';
import 'package:lotti/features/github/repository/github_account_sync.dart';
import 'package:lotti/features/github/repository/github_token_storage.dart';
import 'package:lotti/features/github/state/github_providers.dart';
import 'package:lotti/features/github/ui/github_settings_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/widgets/pages/sliver_box_adapter_page.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../in_memory_keychain.dart';

void main() {
  late MockGitHubClient client;
  late GitHubTokenStorage storage;
  late List<SyncMessage> sent;
  late bool outboxRefuses;
  late Future<void> Function() onRescan;

  const rejected =
      'GitHub rejected the token. It may have expired or been revoked.';
  const otherDevices = Key('github_other_devices');

  setUp(() async {
    client = MockGitHubClient();
    storage = GitHubTokenStorage(inMemoryKeychain({}), namespace: 'real');
    sent = [];
    outboxRefuses = false;
    onRescan = () async {};
    final activity = MockUserActivityService();
    when(activity.updateActivity).thenReturn(null);
    await setUpTestGetIt(
      additionalSetup: () =>
          getIt.registerSingleton<UserActivityService>(activity),
    );
  });
  tearDown(tearDownTestGetIt);

  Future<void> pump(
    WidgetTester tester, {
    Widget? child,
    bool syncs = true,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        child ?? const GitHubSettingsBody(),
        overrides: [
          gitHubClientProvider.overrideWithValue(client),
          gitHubTokenStorageProvider.overrideWithValue(storage),
          gitHubAccountSyncProvider.overrideWithValue(
            GitHubAccountSync(
              storage: storage,
              enqueueOrThrow: (message) async {
                if (outboxRefuses) throw Exception('no outbox row');
                sent.add(message);
              },
              rescan: syncs ? () => onRescan() : null,
            ),
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  // A token another device sent, not checked here yet.
  Future<void> received(String token) => storage.applyIfNewer(
    GitHubAccountRecord(token: token, login: 'pingu', updatedAt: 1),
  );

  DesignSystemButton button(WidgetTester tester, Key key) =>
      tester.widget<DesignSystemButton>(find.byKey(key));

  /// The toast on screen, or null while none shows.
  DesignSystemToast? shownToast(WidgetTester tester) {
    final found = find.byType(DesignSystemToast);
    return found.evaluate().isEmpty
        ? null
        : tester.widget<DesignSystemToast>(found);
  }

  EditableText tokenField(WidgetTester tester) => tester.widget<EditableText>(
    find.descendant(
      of: find.byKey(const Key('github_token')),
      matching: find.byType(EditableText),
    ),
  );

  testWidgets(
    'connects with a token GitHub accepts, sends it to the other devices, '
    'then shows whose it is and no longer the field',
    (tester) async {
      when(
        () => client.fetchViewerLogin('ghp_secret'),
      ).thenAnswer((_) async => 'pingu');
      await pump(tester);

      expect(button(tester, const Key('github_connect')).onPressed, isNull);
      await tester.enterText(
        find.byKey(const Key('github_token')),
        'ghp_secret',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('github_connect')));
      await tester.pump();
      await tester.pump();

      expect(await storage.readToken(), 'ghp_secret');
      expect(sent, hasLength(1));
      expect(find.text('Connected as @pingu'), findsOneWidget);
      expect(find.byKey(const Key('github_token')), findsNothing);
    },
  );

  testWidgets('a refused token shows why, stays in the field, is not saved', (
    tester,
  ) async {
    when(() => client.fetchViewerLogin(any())).thenThrow(
      const GitHubException(GitHubFailureKind.unauthorized),
    );
    await pump(tester);

    await tester.enterText(find.byKey(const Key('github_token')), 'ghp_old');
    await tester.pump();
    await tester.tap(find.byKey(const Key('github_connect')));
    await tester.pump();
    await tester.pump();

    expect(find.text(rejected), findsOneWidget);
    expect(tokenField(tester).controller.text, 'ghp_old');
    expect(await storage.read(), isNull);
    expect(sent, isEmpty);

    // Typing again clears the stale error.
    await tester.enterText(find.byKey(const Key('github_token')), 'ghp_new');
    await tester.pump();
    expect(find.text(rejected), findsNothing);
  });

  testWidgets('the token is hidden until the user asks to see it', (
    tester,
  ) async {
    await pump(tester);
    expect(tokenField(tester).obscureText, isTrue);

    await tester.tap(find.byKey(const Key('github_token_toggle')));
    await tester.pump();

    expect(tokenField(tester).obscureText, isFalse);
  });

  testWidgets(
    'disconnecting forgets the token here and on the other devices, and '
    'asks for one again',
    (tester) async {
      await storage.save(token: 'ghp_secret', login: 'pingu');
      await pump(tester);
      expect(find.text('Connected as @pingu'), findsOneWidget);

      await tester.tap(find.byKey(const Key('github_disconnect')));
      await tester.pump();
      await tester.pump();

      expect(await storage.readToken(), isNull);
      expect((sent.single as SyncGitHubAccount).token, isNull);
      expect(find.byKey(const Key('github_token')), findsOneWidget);
    },
  );

  testWidgets('says where the token goes, connected or not', (tester) async {
    await pump(tester);
    expect(
      find.text(
        'The token syncs end-to-end encrypted to your other devices. Lotti '
        'uses it only for requests to api.github.com.',
      ),
      findsOneWidget,
    );
  });

  group('other devices', () {
    testWidgets(
      'without a token, checking them asks sync to catch up, and says so '
      'when none has arrived',
      (tester) async {
        var rescans = 0;
        onRescan = () async => rescans++;
        await pump(tester);
        expect(find.text('Check my other devices'), findsOneWidget);

        await tester.tap(find.byKey(otherDevices));
        await tester.pump();
        await tester.pump();

        expect(rescans, 1);
        expect(
          find.text(
            'No token has arrived from your other devices yet. On a device '
            'that has one, use “Send to my other devices”.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'a token that arrives while checking is checked with GitHub, then '
      'shown as connected',
      (tester) async {
        when(
          () => client.fetchViewerLogin('ghp_synced'),
        ).thenAnswer((_) async => 'pingu');
        onRescan = () => received('ghp_synced');
        await pump(tester);

        await tester.tap(find.byKey(otherDevices));
        await tester.pump();
        await tester.pump();
        await tester.pump();

        verify(() => client.fetchViewerLogin('ghp_synced')).called(1);
        expect(find.text('Connected as @pingu'), findsOneWidget);
        expect(find.byKey(const Key('github_sync_note')), findsNothing);
      },
    );

    testWidgets(
      'connected, sending to them sends the held token once, and says so',
      (tester) async {
        await storage.save(token: 'ghp_secret', login: 'pingu');
        await pump(tester);
        expect(find.text('Send to my other devices'), findsOneWidget);

        await tester.tap(find.byKey(otherDevices));
        await tester.pump();
        await tester.pump();

        expect(sent, hasLength(1));
        expect(
          find.text('Sent. Your other devices pick it up when they next sync.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'a token that arrives after the check found none clears the note',
      (tester) async {
        final updates = StreamController<Set<String>>.broadcast();
        addTearDown(updates.close);
        final notifications = MockUpdateNotifications();
        when(
          () => notifications.updateStream,
        ).thenAnswer((_) => updates.stream);
        getIt
          ..unregister<UpdateNotifications>()
          ..registerSingleton<UpdateNotifications>(notifications);
        when(
          () => client.fetchViewerLogin('ghp_synced'),
        ).thenAnswer((_) async => 'pingu');
        await pump(tester);
        await tester.tap(find.byKey(otherDevices));
        await tester.pump();
        await tester.pump();
        expect(find.byKey(const Key('github_sync_note')), findsOneWidget);

        // The catch-up queued it; the inbound worker applies it later.
        await received('ghp_synced');
        updates.add({gitHubAccountNotification});
        await tester.pump();
        await tester.pump();
        await tester.pump();

        expect(find.text('Connected as @pingu'), findsOneWidget);
        expect(find.byKey(const Key('github_sync_note')), findsNothing);
      },
    );

    testWidgets(
      'a connection the outbox refused says it is saved here and sent later',
      (tester) async {
        when(
          () => client.fetchViewerLogin('ghp_secret'),
        ).thenAnswer((_) async => 'pingu');
        outboxRefuses = true;
        await pump(tester);

        await tester.enterText(
          find.byKey(const Key('github_token')),
          'ghp_secret',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('github_connect')));
        await tester.pump();
        await tester.pump();
        await tester.pump();

        expect(find.text('Connected as @pingu'), findsOneWidget);
        expect(
          find.text(
            'Saved on this device. It could not be sent to your other '
            'devices yet; Lotti tries again when it next starts.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('a resend the outbox refused says to try again', (
      tester,
    ) async {
      await storage.save(token: 'ghp_secret', login: 'pingu');
      outboxRefuses = true;
      await pump(tester);

      await tester.tap(find.byKey(otherDevices));
      await tester.pump();
      await tester.pump();

      expect(
        find.text('Could not send it to your other devices. Try again.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'a token that arrives while checking but GitHub rejects shows the '
      'rejection, not a connection',
      (tester) async {
        when(() => client.fetchViewerLogin('ghp_revoked')).thenThrow(
          const GitHubException(GitHubFailureKind.unauthorized),
        );
        onRescan = () => received('ghp_revoked');
        await pump(tester);

        await tester.tap(find.byKey(otherDevices));
        await tester.pump();
        await tester.pump();
        await tester.pump();

        expect(find.text('Connected as @pingu'), findsNothing);
        expect(find.text(rejected), findsOneWidget);
      },
    );

    testWidgets(
      'a resend after the token went away behind the page says nothing',
      (tester) async {
        await storage.save(token: 'ghp_secret', login: 'pingu');
        await pump(tester);
        // Disconnected by another device; this page has not heard yet.
        await storage.applyIfNewer(
          GitHubAccountRecord(updatedAt: DateTime(2100).millisecondsSinceEpoch),
        );

        await tester.tap(find.byKey(otherDevices));
        await tester.pump();
        await tester.pump();

        expect(sent, isEmpty);
        expect(find.byKey(const Key('github_sync_note')), findsNothing);
      },
    );

    testWidgets(
      'an unexpected failure while checking leaves the action available',
      (tester) async {
        onRescan = () async => throw Exception('sync stack gone');
        await pump(tester);

        await tester.tap(find.byKey(otherDevices));
        await tester.pump();
        await tester.pump();

        expect(button(tester, otherDevices).onPressed, isNotNull);
      },
    );

    testWidgets('a world without sync offers neither', (tester) async {
      await pump(tester, syncs: false);
      expect(find.byKey(otherDevices), findsNothing);
    });
  });

  testWidgets(
    'a token from another device that GitHub rejects is not shown as '
    'connected: the field asks for one, with why',
    (tester) async {
      await received('ghp_revoked');
      when(() => client.fetchViewerLogin('ghp_revoked')).thenThrow(
        const GitHubException(GitHubFailureKind.unauthorized),
      );
      await pump(tester);

      expect(find.text('Connected as @pingu'), findsNothing);
      expect(find.byKey(const Key('github_token')), findsOneWidget);
      expect(find.text(rejected), findsOneWidget);
    },
  );

  testWidgets(
    'a token synced in while the page is open shows without leaving it',
    (tester) async {
      final updates = StreamController<Set<String>>.broadcast();
      addTearDown(updates.close);
      final notifications = MockUpdateNotifications();
      when(() => notifications.updateStream).thenAnswer((_) => updates.stream);
      getIt
        ..unregister<UpdateNotifications>()
        ..registerSingleton<UpdateNotifications>(notifications);
      when(
        () => client.fetchViewerLogin('ghp_synced'),
      ).thenAnswer((_) async => 'pingu');
      await pump(tester);
      expect(find.byKey(const Key('github_token')), findsOneWidget);

      await received('ghp_synced');
      updates.add({gitHubAccountNotification});
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.text('Connected as @pingu'), findsOneWidget);
    },
  );

  group('creating a token on GitHub', () {
    const createToken = Key('github_create_token');
    const caveat = Key('github_token_checks_caveat');
    const openFailedTitle = 'Your browser did not open';
    const openFailed =
        'Create the token on github.com under Settings → Developer settings '
        '→ Personal access tokens.';
    late MockUrlLauncher launcher;

    setUpAll(() => registerFallbackValue(FakeLaunchOptions()));

    setUp(() {
      final original = UrlLauncherPlatform.instance;
      launcher = MockUrlLauncher();
      UrlLauncherPlatform.instance = launcher;
      addTearDown(() => UrlLauncherPlatform.instance = original);
    });

    void browserAnswers(Future<bool> Function() answer) => when(
      () => launcher.launchUrl(any(), any()),
    ).thenAnswer((_) => answer());

    Future<void> tapCreate(WidgetTester tester) async {
      await tester.tap(find.byKey(createToken));
      await tester.pump();
      await tester.pump();
    }

    Future<void> connectedAs(String login) async {
      await received('ghp_ok');
      when(
        () => client.fetchViewerLogin('ghp_ok'),
      ).thenAnswer((_) async => login);
    }

    group('where the button shows', () {
      testWidgets('without a token: enabled, above the token field', (
        tester,
      ) async {
        await pump(tester);

        expect(button(tester, createToken).onPressed, isNotNull);
        expect(
          tester.getTopLeft(find.byKey(createToken)).dy,
          lessThan(tester.getTopLeft(find.byKey(const Key('github_token'))).dy),
        );
      });

      testWidgets('beside the reason a synced token was rejected', (
        tester,
      ) async {
        await received('ghp_expired');
        when(() => client.fetchViewerLogin('ghp_expired')).thenThrow(
          const GitHubException(GitHubFailureKind.unauthorized),
        );
        await pump(tester);

        expect(find.text(rejected), findsOneWidget);
        expect(find.byKey(createToken), findsOneWidget);
      });

      testWidgets('not while connected', (tester) async {
        await connectedAs('pingu');
        await pump(tester);

        expect(find.text('Connected as @pingu'), findsOneWidget);
        expect(find.byKey(createToken), findsNothing);
      });
    });

    group('opening the form', () {
      testWidgets("launches exactly GitHub's pre-filled token form", (
        tester,
      ) async {
        browserAnswers(() async => true);
        await pump(tester);

        await tapCreate(tester);

        final captured = verify(
          () => launcher.launchUrl(captureAny(), any()),
        ).captured;
        expect(captured.single, gitHubTokenTemplateUri().toString());
      });

      testWidgets('in the browser, outside the app', (tester) async {
        browserAnswers(() async => true);
        await pump(tester);

        await tapCreate(tester);

        final options =
            verify(
                  () => launcher.launchUrl(any(), captureAny()),
                ).captured.single
                as LaunchOptions;
        expect(options.mode, PreferredLaunchMode.externalApplication);
      });

      testWidgets('an opened browser leaves the page without an error', (
        tester,
      ) async {
        browserAnswers(() async => true);
        await pump(tester);

        await tapCreate(tester);

        expect(shownToast(tester), isNull);
      });
    });

    group('when the browser does not open', () {
      testWidgets(
        'a declined launch says, in an error toast, where to make the token '
        'by hand',
        (tester) async {
          browserAnswers(() async => false);
          await pump(tester);

          await tapCreate(tester);

          final toast = shownToast(tester);
          expect(toast?.tone, DesignSystemToastTone.error);
          expect(toast?.title, openFailedTitle);
          expect(toast?.description, openFailed);
        },
      );

      testWidgets('a launch that throws says the same, and throws nothing', (
        tester,
      ) async {
        when(
          () => launcher.launchUrl(any(), any()),
        ).thenThrow(Exception('no browser'));
        await pump(tester);

        await tapCreate(tester);

        expect(tester.takeException(), isNull);
        expect(shownToast(tester)?.title, openFailedTitle);
      });

      testWidgets('leaves the token field without an error', (tester) async {
        browserAnswers(() async => false);
        await pump(tester);

        await tapCreate(tester);

        final field = tester.widget<DesignSystemTextInput>(
          find.byKey(const Key('github_token')),
        );
        expect(field.errorText, isNull);
      });

      testWidgets('a page closed before the browser answers is left alone', (
        tester,
      ) async {
        final answer = Completer<bool>();
        browserAnswers(() => answer.future);
        await pump(tester);
        await tapCreate(tester);

        await tester.pumpWidget(const SizedBox());
        answer.complete(false);
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(shownToast(tester), isNull);
      });
    });

    group('what the page says', () {
      testWidgets('the intro points at the form, not at a classic token', (
        tester,
      ) async {
        await pump(tester);

        expect(
          find.text(
            'Lotti reads the pull requests you link to tasks with a '
            'read-only token from your GitHub account. Create one on GitHub '
            '— the permissions are filled in for you — choose your '
            'repositories, then paste the token here.',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('classic'), findsNothing);
      });

      testWidgets('without a token: what such a token cannot read', (
        tester,
      ) async {
        await pump(tester);

        expect(
          tester.widget<Text>(find.byKey(caveat)).data,
          'CI checks of private repositories may be incomplete: GitHub gives '
          'these tokens no access to check runs.',
        );
      });

      testWidgets('connected: no caveat about a token being made', (
        tester,
      ) async {
        await connectedAs('pingu');
        await pump(tester);

        expect(find.text('Connected as @pingu'), findsOneWidget);
        expect(find.byKey(caveat), findsNothing);
      });
    });
  });

  group('feedback', () {
    const connectedToast = 'Connected to GitHub as @pingu';
    const saveFailedTitle = 'Token not stored';
    const saveFailed =
        'GitHub accepted it, but this device could not keep it. Try again.';
    const disconnectedToast = 'Disconnected from GitHub';
    const disconnectFailedTitle = 'Token not removed';
    const disconnectFailed =
        'This device could not remove the token. Try again.';
    const connectKey = Key('github_connect');

    /// A keychain whose writes this test can make fail.
    late MockSecureStorage keychain;

    setUp(() {
      keychain = inMemoryKeychain({});
      storage = GitHubTokenStorage(keychain, namespace: 'real');
    });

    void writesFail() => when(
      () => keychain.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenThrow(Exception('-34018: a required entitlement is not present'));

    Future<void> typeAndConnect(WidgetTester tester, String token) async {
      await tester.enterText(find.byKey(const Key('github_token')), token);
      await tester.pump();
      await tester.tap(find.byKey(connectKey));
      await tester.pump();
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    Future<void> connectedAsPingu(WidgetTester tester) async {
      await received('ghp_ok');
      when(
        () => client.fetchViewerLogin('ghp_ok'),
      ).thenAnswer((_) async => 'pingu');
      await pump(tester);
      expect(find.text('Connected as @pingu'), findsOneWidget);
    }

    group('connecting', () {
      testWidgets('Connect spins while GitHub is asked, and stops after', (
        tester,
      ) async {
        final answer = Completer<String>();
        when(
          () => client.fetchViewerLogin('ghp_slow'),
        ).thenAnswer((_) => answer.future);
        await pump(tester);

        await typeAndConnect(tester, 'ghp_slow');
        expect(button(tester, connectKey).isLoading, isTrue);

        answer.completeError(
          const GitHubException(GitHubFailureKind.unauthorized),
        );
        await settle(tester);
        expect(button(tester, connectKey).isLoading, isFalse);
      });

      testWidgets('a token GitHub accepts is confirmed with a success toast', (
        tester,
      ) async {
        when(
          () => client.fetchViewerLogin('ghp_ok'),
        ).thenAnswer((_) async => 'pingu');
        await pump(tester);

        await typeAndConnect(tester, 'ghp_ok');
        await settle(tester);

        expect(find.text(connectedToast), findsOneWidget);
        expect(shownToast(tester)?.tone, DesignSystemToastTone.success);
      });

      testWidgets('a token GitHub refuses gets no toast, only the reason', (
        tester,
      ) async {
        when(() => client.fetchViewerLogin(any())).thenThrow(
          const GitHubException(GitHubFailureKind.unauthorized),
        );
        await pump(tester);

        await typeAndConnect(tester, 'ghp_old');
        await settle(tester);

        expect(find.text(rejected), findsOneWidget);
        expect(shownToast(tester), isNull);
      });

      testWidgets(
        'a keychain that refuses the write says so in an error toast, keeps '
        'the token typed, and lets Connect be pressed again',
        (tester) async {
          when(
            () => client.fetchViewerLogin('ghp_ok'),
          ).thenAnswer((_) async => 'pingu');
          await pump(tester);
          writesFail();

          await typeAndConnect(tester, 'ghp_ok');
          await settle(tester);

          final toast = shownToast(tester);
          expect(toast?.tone, DesignSystemToastTone.error);
          expect(toast?.title, saveFailedTitle);
          expect(toast?.description, saveFailed);
          expect(tokenField(tester).controller.text, 'ghp_ok');
          expect(button(tester, connectKey).isLoading, isFalse);
          expect(button(tester, connectKey).onPressed, isNotNull);
          expect(find.text('Connected as @pingu'), findsNothing);
        },
      );

      testWidgets(
        'a token stored whose change could not be announced still counts as '
        'connected',
        (tester) async {
          final notifications =
              getIt<UpdateNotifications>() as MockUpdateNotifications;
          when(
            () => notifications.notify(any(), fromSync: any(named: 'fromSync')),
          ).thenThrow(Exception('notification failed'));
          when(
            () => client.fetchViewerLogin('ghp_ok'),
          ).thenAnswer((_) async => 'pingu');
          await pump(tester);

          await typeAndConnect(tester, 'ghp_ok');
          await settle(tester);

          expect(await storage.readToken(), 'ghp_ok');
          expect(shownToast(tester)?.title, connectedToast);
          expect(shownToast(tester)?.tone, DesignSystemToastTone.success);
        },
      );

      testWidgets('a page closed while GitHub is asked is left alone', (
        tester,
      ) async {
        final answer = Completer<String>();
        when(
          () => client.fetchViewerLogin('ghp_slow'),
        ).thenAnswer((_) => answer.future);
        await pump(tester);
        await typeAndConnect(tester, 'ghp_slow');

        await tester.pumpWidget(const SizedBox());
        answer.complete('pingu');
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.byType(DesignSystemToast), findsNothing);
      });
    });

    group('disconnecting', () {
      testWidgets('is confirmed with a success toast', (tester) async {
        await connectedAsPingu(tester);

        await tester.tap(find.byKey(const Key('github_disconnect')));
        await settle(tester);

        expect(find.text(disconnectedToast), findsOneWidget);
        expect(shownToast(tester)?.tone, DesignSystemToastTone.success);
        expect(find.byKey(const Key('github_token')), findsOneWidget);
      });

      testWidgets(
        'a keychain that refuses says so in an error toast, and stays '
        'connected',
        (tester) async {
          await connectedAsPingu(tester);
          writesFail();

          await tester.tap(find.byKey(const Key('github_disconnect')));
          await settle(tester);

          final toast = shownToast(tester);
          expect(toast?.tone, DesignSystemToastTone.error);
          expect(toast?.title, disconnectFailedTitle);
          expect(toast?.description, disconnectFailed);
          expect(find.text('Connected as @pingu'), findsOneWidget);
        },
      );

      testWidgets(
        'a keychain that cannot be read afterwards still confirms, with no '
        'note about other devices',
        (tester) async {
          await connectedAsPingu(tester);
          // Reads fail from the moment the disconnection is written.
          var readsFail = false;
          final values = <String, String>{};
          when(
            () => keychain.write(
              key: any(named: 'key'),
              value: any(named: 'value'),
            ),
          ).thenAnswer((invocation) async {
            values[invocation.namedArguments[#key] as String] =
                invocation.namedArguments[#value] as String;
            readsFail = true;
          });
          when(() => keychain.read(key: any(named: 'key'))).thenAnswer((
            invocation,
          ) async {
            if (readsFail) throw Exception('keychain locked');
            return values[invocation.namedArguments[#key] as String];
          });

          await tester.tap(find.byKey(const Key('github_disconnect')));
          await settle(tester);

          expect(find.text(disconnectedToast), findsOneWidget);
          expect(find.byKey(const Key('github_sync_note')), findsNothing);
        },
      );
    });
  });

  testWidgets('the mobile page titles itself GitHub around the same body', (
    tester,
  ) async {
    await pump(tester, child: const GitHubSettingsPage());

    expect(
      tester
          .widget<SliverBoxAdapterPage>(find.byType(SliverBoxAdapterPage))
          .title,
      'GitHub',
    );
    expect(find.byType(GitHubSettingsBody), findsOneWidget);
    // Let the page's entrance animation finish on fake time.
    await tester.pump(const Duration(seconds: 1));
  });
}
