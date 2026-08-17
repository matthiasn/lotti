import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/relationships/service/contact_launcher.dart';
import 'package:lotti/features/relationships/service/pending_interaction_store.dart';
import 'package:lotti/features/relationships/ui/widgets/contact_quick_actions.dart';
import 'package:lotti/features/relationships/util/contact_channel_uri.dart';

import '../../../../widget_test_utils.dart';

/// A launcher whose answers are scripted per action and whose calls are
/// recorded, so the widget's two decisions — which buttons to show, and what
/// to do when one is pressed — are both observable.
class _FakeContactLauncher implements ContactLauncher {
  _FakeContactLauncher({
    this.launchable = const {
      ContactAction.call,
      ContactAction.message,
      ContactAction.email,
    },
    this.launchSucceeds = true,
  });

  final Set<ContactAction> launchable;
  final bool launchSucceeds;
  final List<(ContactChannel, ContactAction)> launched = [];

  @override
  Future<bool> canLaunch(ContactChannel channel, ContactAction action) async =>
      launchable.contains(action) && contactChannelUri(channel, action) != null;

  @override
  Future<bool> launch(ContactChannel channel, ContactAction action) async {
    launched.add((channel, action));
    return launchSucceeds;
  }
}

/// An in-memory stand-in for the settings-backed store.
class _FakePendingInteractionStore implements PendingInteractionStore {
  PendingInteraction? remembered;
  int clearCount = 0;

  @override
  Future<void> remember({
    required String relationshipId,
    required CheckInInteractionType interactionType,
  }) async {
    remembered = (
      relationshipId: relationshipId,
      interactionType: interactionType,
      startedAt: DateTime(2026, 8, 17),
    );
  }

  @override
  Future<PendingInteraction?> read() async => remembered;

  @override
  Future<void> clear() async {
    clearCount++;
    remembered = null;
  }
}

void main() {
  ContactChannel channel(ContactChannelType type, String value) =>
      ContactChannel(type: type, value: value);

  late _FakeContactLauncher launcher;
  late _FakePendingInteractionStore store;

  setUp(() {
    launcher = _FakeContactLauncher();
    store = _FakePendingInteractionStore();
  });

  Future<void> pump(
    WidgetTester tester,
    ContactChannel target, {
    String relationshipId = 'anna',
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        ContactQuickActions(relationshipId: relationshipId, channel: target),
        overrides: [
          contactLauncherProvider.overrideWithValue(launcher),
          pendingInteractionStoreProvider.overrideWithValue(store),
        ],
      ),
    );
    // The availability check is asynchronous; the first frame renders nothing.
    await tester.pumpAndSettle();
  }

  group('which buttons appear', () {
    testWidgets('a mobile number offers call and message', (tester) async {
      await pump(tester, channel(ContactChannelType.mobile, '+15550109999'));

      expect(find.byIcon(Icons.call_rounded), findsOneWidget);
      expect(find.byIcon(Icons.sms_rounded), findsOneWidget);
      expect(find.byIcon(Icons.mail_outline_rounded), findsNothing);
    });

    testWidgets('a landline offers call but never a message composer', (
      tester,
    ) async {
      await pump(tester, channel(ContactChannelType.phone, '+493090182'));

      expect(find.byIcon(Icons.call_rounded), findsOneWidget);
      expect(find.byIcon(Icons.sms_rounded), findsNothing);
    });

    testWidgets('an email address offers only mail', (tester) async {
      await pump(tester, channel(ContactChannelType.email, 'anna@example.com'));

      expect(find.byIcon(Icons.mail_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.call_rounded), findsNothing);
    });

    testWidgets('a messaging handle offers nothing rather than a guessed '
        'deep link', (tester) async {
      await pump(tester, channel(ContactChannelType.messaging, '@anna'));

      expect(find.byType(IconButton), findsNothing);
    });

    testWidgets('renders nothing when the platform has no handler', (
      tester,
    ) async {
      launcher = _FakeContactLauncher(launchable: const {});

      await pump(tester, channel(ContactChannelType.mobile, '+15550109999'));

      expect(
        find.byType(IconButton),
        findsNothing,
        reason: 'a tablet with no dialer must show no button, not a dead one',
      );
    });

    testWidgets('hides only the action the platform cannot service', (
      tester,
    ) async {
      launcher = _FakeContactLauncher(launchable: const {ContactAction.call});

      await pump(tester, channel(ContactChannelType.mobile, '+15550109999'));

      expect(find.byIcon(Icons.call_rounded), findsOneWidget);
      expect(find.byIcon(Icons.sms_rounded), findsNothing);
    });

    testWidgets('shows nothing for a number that maps to no URI', (
      tester,
    ) async {
      await pump(tester, channel(ContactChannelType.mobile, 'ask Bob'));

      expect(find.byType(IconButton), findsNothing);
    });

    testWidgets('orders call before message consistently', (tester) async {
      await pump(tester, channel(ContactChannelType.mobile, '+15550109999'));

      final icons = tester
          .widgetList<Icon>(
            find.descendant(
              of: find.byType(IconButton),
              matching: find.byType(Icon),
            ),
          )
          .map((icon) => icon.icon)
          .toList();

      expect(icons, [Icons.call_rounded, Icons.sms_rounded]);
    });
  });

  group('pressing a button', () {
    testWidgets('launches the channel it belongs to', (tester) async {
      final target = channel(ContactChannelType.mobile, '+15550109999');
      await pump(tester, target);

      await tester.tap(find.byIcon(Icons.call_rounded));
      await tester.pumpAndSettle();

      expect(launcher.launched, [(target, ContactAction.call)]);
    });

    testWidgets('remembers a placed call so the next resume can offer a '
        'check-in', (tester) async {
      await pump(
        tester,
        channel(ContactChannelType.mobile, '+15550109999'),
      );

      await tester.tap(find.byIcon(Icons.call_rounded));
      await tester.pumpAndSettle();

      expect(store.remembered!.relationshipId, 'anna');
      expect(store.remembered!.interactionType, CheckInInteractionType.call);
    });

    testWidgets('remembers a message as a message', (tester) async {
      await pump(tester, channel(ContactChannelType.mobile, '+15550109999'));

      await tester.tap(find.byIcon(Icons.sms_rounded));
      await tester.pumpAndSettle();

      expect(store.remembered!.interactionType, CheckInInteractionType.message);
    });

    testWidgets('remembers an email as a message, the nearest check-in kind', (
      tester,
    ) async {
      await pump(tester, channel(ContactChannelType.email, 'anna@example.com'));

      await tester.tap(find.byIcon(Icons.mail_outline_rounded));
      await tester.pumpAndSettle();

      expect(store.remembered!.interactionType, CheckInInteractionType.message);
    });

    testWidgets('remembers nothing when the platform refuses the launch — '
        'there was no conversation to log', (tester) async {
      launcher = _FakeContactLauncher(launchSucceeds: false);

      await pump(tester, channel(ContactChannelType.mobile, '+15550109999'));

      await tester.tap(find.byIcon(Icons.call_rounded));
      await tester.pumpAndSettle();

      expect(store.remembered, isNull);
    });

    testWidgets('tells the user when a launch is refused', (tester) async {
      launcher = _FakeContactLauncher(launchSucceeds: false);

      await pump(tester, channel(ContactChannelType.mobile, '+15550109999'));

      await tester.tap(find.byIcon(Icons.call_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Nothing on this device can open that'), findsOneWidget);
    });

    testWidgets('says nothing when the launch succeeds', (tester) async {
      await pump(tester, channel(ContactChannelType.mobile, '+15550109999'));

      await tester.tap(find.byIcon(Icons.call_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Nothing on this device can open that'), findsNothing);
    });
  });

  group('interactionTypeForAction', () {
    test('maps every action to a check-in kind', () {
      expect(
        interactionTypeForAction(ContactAction.call),
        CheckInInteractionType.call,
      );
      expect(
        interactionTypeForAction(ContactAction.message),
        CheckInInteractionType.message,
      );
      expect(
        interactionTypeForAction(ContactAction.email),
        CheckInInteractionType.message,
      );
    });
  });

  group('channel changes', () {
    testWidgets('re-checks availability when the channel is edited — a '
        'landline corrected to a mobile gains a message button', (
      tester,
    ) async {
      Widget build(ContactChannel target) => makeTestableWidgetWithScaffold(
        ContactQuickActions(relationshipId: 'anna', channel: target),
        overrides: [
          contactLauncherProvider.overrideWithValue(launcher),
          pendingInteractionStoreProvider.overrideWithValue(store),
        ],
      );

      await tester.pumpWidget(
        build(channel(ContactChannelType.phone, '+15550109999')),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.sms_rounded), findsNothing);

      await tester.pumpWidget(
        build(channel(ContactChannelType.mobile, '+15550109999')),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.sms_rounded), findsOneWidget);
    });
  });
}
