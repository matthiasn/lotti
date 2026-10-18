import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/subscription/sync_subscription_controller.dart';
import 'package:lotti/features/sync/ui/provisioned/sync_setup_entry.dart';
import 'package:lotti/features/sync/ui/subscription/subscribe_page.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';
import '../../subscription/fake_sync_subscription_controller.dart';

void main() {
  late ValueNotifier<int> pageIndex;

  setUp(() => pageIndex = ValueNotifier(SyncSetupPage.pairingCode));
  tearDown(() => pageIndex.dispose());

  Future<FakeSyncSubscriptionController> pump(
    WidgetTester tester,
    SyncSubscribeState state,
  ) async {
    final fake = FakeSyncSubscriptionController(state);
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        SubscribeBody(pageIndexNotifier: pageIndex),
        overrides: [
          syncSubscriptionControllerProvider.overrideWith(() => fake),
        ],
      ),
    );
    await tester.pump();
    return fake;
  }

  AppLocalizations messagesOf(WidgetTester tester) =>
      tester.element(find.byType(SubscribeBody)).messages;

  testWidgets('opening the page resumes an unfinished checkout', (
    tester,
  ) async {
    final fake = await pump(tester, const SyncSubscribeIdle());

    expect(fake.calls, ['resume']);
  });

  testWidgets('offers annual first and starts the chosen plan', (
    tester,
  ) async {
    final fake = await pump(tester, const SyncSubscribeIdle());
    final messages = messagesOf(tester);

    expect(find.text(messages.syncSubscribeIntro), findsOneWidget);
    expect(find.text(messages.syncSubscribeFootnote), findsOneWidget);
    final annual = tester.getTopLeft(
      find.byKey(const Key('sync_subscribe_annual')),
    );
    final monthly = tester.getTopLeft(
      find.byKey(const Key('sync_subscribe_monthly')),
    );
    expect(annual.dy, lessThan(monthly.dy));

    await tester.tap(find.byKey(const Key('sync_subscribe_monthly')));
    await tester.tap(find.byKey(const Key('sync_subscribe_annual')));

    expect(fake.calls, ['resume', 'subscribe:monthly', 'subscribe:annual']);
  });

  testWidgets('while paying it offers to reopen the checkout or cancel', (
    tester,
  ) async {
    final fake = await pump(
      tester,
      SyncSubscribeAwaitingPayment(Uri.parse('https://sync.example.com/c')),
    );

    expect(find.text(messagesOf(tester).syncSubscribeAwaiting), findsOneWidget);
    expect(find.byKey(const Key('sync_subscribe_annual')), findsNothing);

    await tester.tap(find.byKey(const Key('sync_subscribe_reopen')));
    await tester.tap(find.byKey(const Key('sync_subscribe_cancel')));

    expect(fake.calls, ['resume', 'reopen', 'cancel']);
  });

  testWidgets('a resumed wait has no checkout to reopen', (tester) async {
    await pump(tester, const SyncSubscribeAwaitingPayment(null));

    expect(find.byKey(const Key('sync_subscribe_reopen')), findsNothing);
    expect(find.byKey(const Key('sync_subscribe_cancel')), findsOneWidget);
  });

  testWidgets('shows progress while opening and after payment', (
    tester,
  ) async {
    final fake = await pump(tester, const SyncSubscribeOpening());
    final messages = messagesOf(tester);
    expect(find.text(messages.syncSubscribeOpening), findsOneWidget);

    fake.emit(const SyncSubscribeClaiming());
    await tester.pump();
    expect(find.text(messages.syncSubscribeClaiming), findsOneWidget);
  });

  testWidgets('hands over to the connect page once provisioning starts', (
    tester,
  ) async {
    final fake = await pump(tester, const SyncSubscribeClaiming());

    fake.emit(const SyncSubscribeConnecting());
    await tester.pump();

    expect(pageIndex.value, SyncSetupPage.connect);
  });

  testWidgets('an expired checkout says so above the plans', (tester) async {
    await pump(tester, const SyncSubscribeCheckoutExpired());

    expect(find.text(messagesOf(tester).syncSubscribeExpired), findsOneWidget);
    expect(find.byKey(const Key('sync_subscribe_annual')), findsOneWidget);
  });

  group('each failure names its own remedy', () {
    final expected = <SyncSubscribeFailure, String Function(AppLocalizations)>{
      SyncSubscribeFailure.offline: (m) => m.syncSubscribeErrorOffline,
      SyncSubscribeFailure.service: (m) => m.syncSubscribeErrorService,
      SyncSubscribeFailure.browserUnavailable: (m) =>
          m.syncSubscribeErrorBrowser,
      SyncSubscribeFailure.alreadySetUp: (m) =>
          m.syncSubscribeErrorAlreadySetUp,
      SyncSubscribeFailure.invalidBundle: (m) =>
          m.syncSubscribeErrorInvalidBundle,
    };
    for (final MapEntry(key: failure, value: message) in expected.entries) {
      testWidgets(failure.name, (tester) async {
        await pump(tester, SyncSubscribeFailed(failure));

        expect(
          tester
              .widget<Text>(find.byKey(const Key('sync_subscribe_notice')))
              .data,
          message(messagesOf(tester)),
        );
        // The plans stay available: every failure is retried from here.
        expect(find.byKey(const Key('sync_subscribe_annual')), findsOneWidget);
      });
    }
  });
}
