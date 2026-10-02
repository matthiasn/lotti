import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/github/api/github_client.dart';
import 'package:lotti/features/github/state/github_providers.dart';
import 'package:lotti/features/github/ui/github_settings_page.dart';
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  late MockGitHubClient client;
  late MockGitHubTokenStorage tokens;

  setUp(() {
    client = MockGitHubClient();
    tokens = MockGitHubTokenStorage();
    when(tokens.readToken).thenAnswer((_) async => null);
    when(tokens.readLogin).thenAnswer((_) async => null);
  });

  Future<void> pump(WidgetTester tester, {Widget? child}) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        child ?? const GitHubSettingsBody(),
        overrides: [
          gitHubClientProvider.overrideWithValue(client),
          gitHubTokenStorageProvider.overrideWithValue(tokens),
        ],
      ),
    );
    await tester.pump();
  }

  DesignSystemButton connectButton(WidgetTester tester) => tester
      .widget<DesignSystemButton>(find.byKey(const Key('github_connect')));

  EditableText tokenField(WidgetTester tester) => tester.widget<EditableText>(
    find.descendant(
      of: find.byKey(const Key('github_token')),
      matching: find.byType(EditableText),
    ),
  );

  testWidgets(
    'connects with a token GitHub accepts, then shows whose it is and no '
    'longer the field',
    (tester) async {
      when(
        () => client.fetchViewerLogin('ghp_secret'),
      ).thenAnswer((_) async => 'pingu');
      when(
        () => tokens.save(token: 'ghp_secret', login: 'pingu'),
      ).thenAnswer((_) async {});
      await pump(tester);

      expect(connectButton(tester).onPressed, isNull);
      await tester.enterText(
        find.byKey(const Key('github_token')),
        'ghp_secret',
      );
      await tester.pump();
      expect(connectButton(tester).onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('github_connect')));
      await tester.pump();
      await tester.pump();

      verify(() => tokens.save(token: 'ghp_secret', login: 'pingu')).called(1);
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

    expect(
      find.text(
        'GitHub rejected the token. It may have expired or been revoked.',
      ),
      findsOneWidget,
    );
    expect(tokenField(tester).controller.text, 'ghp_old');
    verifyNever(
      () => tokens.save(
        token: any(named: 'token'),
        login: any(named: 'login'),
      ),
    );

    // Typing again clears the stale error.
    await tester.enterText(find.byKey(const Key('github_token')), 'ghp_new');
    await tester.pump();
    expect(
      find.text(
        'GitHub rejected the token. It may have expired or been revoked.',
      ),
      findsNothing,
    );
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

  testWidgets('disconnecting forgets the token and asks for one again', (
    tester,
  ) async {
    when(tokens.readToken).thenAnswer((_) async => 'ghp_secret');
    when(tokens.readLogin).thenAnswer((_) async => 'pingu');
    when(tokens.clear).thenAnswer((_) async {});
    await pump(tester);
    expect(find.text('Connected as @pingu'), findsOneWidget);

    await tester.tap(find.byKey(const Key('github_disconnect')));
    await tester.pump();

    verify(tokens.clear).called(1);
    expect(find.byKey(const Key('github_token')), findsOneWidget);
  });

  testWidgets('says where the token goes, connected or not', (tester) async {
    await pump(tester);
    expect(
      find.text(
        'The token stays on this device: it is never synced, and it is only '
        'ever sent to api.github.com.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('the mobile page titles itself GitHub around the same body', (
    tester,
  ) async {
    final activity = MockUserActivityService();
    when(activity.updateActivity).thenReturn(null);
    await setUpTestGetIt(
      additionalSetup: () =>
          getIt.registerSingleton<UserActivityService>(activity),
    );
    addTearDown(tearDownTestGetIt);
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
