import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/github/api/github_client.dart';
import 'package:lotti/features/github/repository/github_account_sync.dart';
import 'package:lotti/features/github/repository/github_token_storage.dart';
import 'package:lotti/features/github/state/github_providers.dart';
import 'package:lotti/features/github/ui/github_settings_page.dart';
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../in_memory_keychain.dart';

void main() {
  late MockGitHubClient client;
  late GitHubTokenStorage storage;
  late List<SyncMessage> sent;
  late Future<void> Function() onRescan;

  const rejected =
      'GitHub rejected the token. It may have expired or been revoked.';
  const otherDevices = Key('github_other_devices');

  setUp(() async {
    client = MockGitHubClient();
    storage = GitHubTokenStorage(inMemoryKeychain({}), namespace: 'real');
    sent = [];
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
              enqueue: (message) async => sent.add(message),
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
        'The token syncs end-to-end encrypted to your other devices, and is '
        'only ever sent to api.github.com.',
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
