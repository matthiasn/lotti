import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/relationships/service/contact_launcher.dart';
import 'package:lotti/features/relationships/service/pending_interaction_store.dart';
import 'package:lotti/features/relationships/ui/widgets/person_contact_row.dart';
import 'package:lotti/features/relationships/util/contact_channel_uri.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';
import '../../helpers/fake_contact_launcher.dart';
import '../../helpers/fake_pending_interaction_store.dart';

void main() {
  final at = DateTime(2026, 8, 13, 10);
  const mobile = ContactChannel(
    type: ContactChannelType.mobile,
    value: '+15550100123',
    label: 'Mobile',
  );
  const work = ContactChannel(
    type: ContactChannelType.mobile,
    value: '+15550100456',
    label: 'Work',
  );
  const landline = ContactChannel(
    type: ContactChannelType.phone,
    value: '+493090182',
  );
  const email = ContactChannel(
    type: ContactChannelType.email,
    value: 'pip@frostbeak.example',
  );

  RelationshipEntry person(List<ContactChannel> channels) => RelationshipEntry(
    meta: Metadata(
      id: 'pip',
      createdAt: at,
      updatedAt: at,
      dateFrom: at,
      dateTo: at,
    ),
    data: RelationshipData(
      title: 'Commander Pip Frostbeak',
      nickname: 'Pip',
      contactChannels: channels,
      status: RelationshipStatus.active(id: 's', createdAt: at, utcOffset: 0),
    ),
  );

  late FakeContactLauncher launcher;
  late FakePendingInteractionStore store;

  setUp(() {
    launcher = FakeContactLauncher();
    store = FakePendingInteractionStore();
  });

  Widget build(List<ContactChannel> channels) => makeTestableWidgetWithScaffold(
    PersonContactRow(relationship: person(channels)),
    overrides: [
      contactLauncherProvider.overrideWithValue(launcher),
      pendingInteractionStoreProvider.overrideWithValue(store),
    ],
  );

  Future<void> pump(WidgetTester tester, List<ContactChannel> channels) async {
    await tester.pumpWidget(build(channels));
    // Availability is asked asynchronously; the first frame renders nothing.
    await tester.pumpAndSettle();
  }

  Finder action(ContactAction a) =>
      find.byKey(ValueKey('person-contact-${a.name}'));

  group('which actions appear', () {
    testWidgets('one labelled button per action the device can service, '
        'call, message, email in that order', (tester) async {
      await pump(tester, const [email, mobile]);

      expect(find.text('Call'), findsOneWidget);
      expect(find.text('Message'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      final xs = [
        for (final a in ContactAction.values) tester.getTopLeft(action(a)).dx,
      ];
      expect(xs, orderedEquals([...xs]..sort()));
    });

    testWidgets('a landline offers no message composer', (tester) async {
      await pump(tester, const [landline]);

      expect(action(ContactAction.call), findsOneWidget);
      expect(action(ContactAction.message), findsNothing);
    });

    testWidgets('renders nothing when the device can service nothing — no '
        'dead buttons', (tester) async {
      launcher = FakeContactLauncher(launchable: const {});

      await pump(tester, const [mobile, email]);

      expect(find.byKey(const ValueKey('person-contact-row')), findsNothing);
    });

    testWidgets('renders nothing for a person without channels', (
      tester,
    ) async {
      await pump(tester, const []);

      expect(find.byKey(const ValueKey('person-contact-row')), findsNothing);
    });

    testWidgets('asks again when the channels change — a landline corrected '
        'to a mobile gains Message', (tester) async {
      await pump(tester, const [landline]);
      expect(action(ContactAction.message), findsNothing);

      await tester.pumpWidget(build(const [mobile]));
      await tester.pumpAndSettle();

      expect(action(ContactAction.message), findsOneWidget);
    });

    testWidgets('an answer about the old channels that lands late is '
        'discarded: the row never offers a number the person no longer has', (
      tester,
    ) async {
      // The first probe — about the mobile — hangs until released.
      final slow = _GatedLauncher(gated: mobile.value);
      launcher = slow;
      await tester.pumpWidget(build(const [mobile]));
      await tester.pump();

      // The number is corrected to the work line while that probe waits.
      await tester.pumpWidget(build(const [work]));
      await tester.pumpAndSettle();
      expect(action(ContactAction.call), findsOneWidget);

      // Now the stale answer arrives; the row stays on the work line.
      slow.release();
      await tester.pumpAndSettle();
      await tester.tap(action(ContactAction.call));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('person-contact-choice-+15550100456')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('person-contact-choice-+15550100123')),
        findsNothing,
      );
    });
  });

  group('calling', () {
    testWidgets('a call is never placed by one tap: the sheet names the '
        'person and the number, and choosing it calls', (tester) async {
      await pump(tester, const [mobile]);

      await tester.tap(action(ContactAction.call));
      await tester.pumpAndSettle();

      expect(launcher.launched, isEmpty);
      expect(find.text('Call Pip?'), findsOneWidget);
      expect(find.text('+15550100123'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('person-contact-choice-+15550100123')),
      );
      await tester.pumpAndSettle();

      expect(launcher.launched, [(mobile, ContactAction.call)]);
      expect(store.pending!.relationshipId, 'pip');
    });

    testWidgets('with several numbers the sheet asks which', (tester) async {
      await pump(tester, const [mobile, work]);

      await tester.tap(action(ContactAction.call));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('person-contact-choice-+15550100456')),
      );
      await tester.pumpAndSettle();

      expect(launcher.launched, [(work, ContactAction.call)]);
    });

    testWidgets('closing the sheet calls no one', (tester) async {
      await pump(tester, const [mobile]);

      await tester.tap(action(ContactAction.call));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(launcher.launched, isEmpty);
      expect(store.pending, isNull);
    });
  });

  testWidgets('a message to the one number that takes it opens at once', (
    tester,
  ) async {
    await pump(tester, const [mobile, landline]);

    await tester.tap(action(ContactAction.message));
    await tester.pumpAndSettle();

    expect(launcher.launched, [(mobile, ContactAction.message)]);
    expect(find.text('Message'), findsOneWidget, reason: 'no sheet opened');
  });
}

/// A launcher that answers at once for every channel but [gated], whose
/// answers wait until [release].
class _GatedLauncher extends FakeContactLauncher {
  _GatedLauncher({required this.gated});

  final String gated;
  final Completer<void> _gate = Completer<void>();

  void release() => _gate.complete();

  @override
  Future<bool> canLaunch(ContactChannel channel, ContactAction action) async {
    if (channel.value == gated) await _gate.future;
    return super.canLaunch(channel, action);
  }
}
