import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/relationships/state/contact_link_controller.dart';
import 'package:lotti/features/relationships/ui/widgets/contact_link_action.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

/// Records which controller method was invoked, and answers with a scripted
/// outcome so every toast branch is reachable.
class _FakeContactLinkController implements ContactLinkController {
  _FakeContactLinkController(this.outcome);

  final ContactLinkOutcome outcome;
  final List<String> calls = [];

  @override
  Future<ContactLinkOutcome> linkContact(RelationshipEntry relationship) async {
    calls.add('link');
    return outcome;
  }

  @override
  Future<ContactLinkOutcome> refreshFromContact(
    RelationshipEntry relationship,
  ) async {
    calls.add('refresh');
    return outcome;
  }
}

void main() {
  final testDate = DateTime(2026, 8, 17, 12);
  // Refs are per-device: the key carries this device's sync host id.
  const deviceKey = 'android:host-a';

  RelationshipEntry person({Map<String, String> refs = const {}}) =>
      RelationshipEntry(
        meta: Metadata(
          id: 'rel-1',
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate,
        ),
        data: RelationshipData(
          title: 'Anna',
          status: RelationshipStatus.active(
            id: 'status-1',
            createdAt: testDate,
            utcOffset: 0,
          ),
          contactRefs: refs,
        ),
      );

  group('contactIsLinkedOnThisDevice', () {
    test("a ref under this device's key counts as linked", () {
      expect(
        contactIsLinkedOnThisDevice(
          person(refs: {deviceKey: 'os-1'}),
          deviceKey,
        ),
        isTrue,
      );
    });

    test('no ref at all is unlinked', () {
      expect(contactIsLinkedOnThisDevice(person(), deviceKey), isFalse);
    });

    test('an empty ref counts as unlinked', () {
      expect(
        contactIsLinkedOnThisDevice(person(refs: {deviceKey: ''}), deviceKey),
        isFalse,
      );
    });

    test('a ref another device wrote counts as unlinked — even one from a '
        'device on the same platform', () {
      expect(
        contactIsLinkedOnThisDevice(
          person(refs: {'android:host-b': 'os-1', 'ios:host-c': 'os-2'}),
          deviceKey,
        ),
        isFalse,
        reason:
            'offering "update from contact" here would resolve another '
            "device's contact id against this device's address book",
      );
    });

    test('no key yet (host id unknown) is unlinked whatever the refs say', () {
      expect(
        contactIsLinkedOnThisDevice(person(refs: {deviceKey: 'os-1'}), null),
        isFalse,
      );
    });
  });

  group('runContactLinkAction', () {
    /// A button that runs the link intent through the shared helper, so the
    /// toast the user sees is the helper's — not a page's.
    Future<_FakeContactLinkController> pump(
      WidgetTester tester, {
      required ContactLinkOutcome outcome,
    }) async {
      final controller = _FakeContactLinkController(outcome);
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => runContactLinkAction(
                context,
                ref,
                (c) => c.linkContact(person()),
              ),
              child: const Text('Link'),
            ),
          ),
          overrides: [
            contactLinkControllerProvider.overrideWithValue(controller),
          ],
        ),
      );
      await tester.tap(find.text('Link'));
      await tester.pumpAndSettle();
      return controller;
    }

    testWidgets('runs the intent it was handed', (tester) async {
      final controller = await pump(
        tester,
        outcome: ContactLinkOutcome.linked,
      );

      expect(controller.calls, ['link']);
    });

    testWidgets('confirms when details were copied', (tester) async {
      await pump(tester, outcome: ContactLinkOutcome.linked);

      expect(find.text('Contact details copied'), findsOneWidget);
    });

    testWidgets('says so when the contact held nothing new', (tester) async {
      await pump(tester, outcome: ContactLinkOutcome.noChanges);

      expect(find.text('Nothing new to copy'), findsOneWidget);
    });

    testWidgets('says so when the contact is not on this device', (
      tester,
    ) async {
      await pump(tester, outcome: ContactLinkOutcome.contactMissing);

      expect(find.text("That contact isn't on this device"), findsOneWidget);
    });

    testWidgets('reports a rejected save', (tester) async {
      await pump(tester, outcome: ContactLinkOutcome.saveFailed);

      expect(find.text('Could not save the contact details'), findsOneWidget);
    });

    testWidgets('says nothing when the user backs out of the picker — '
        'cancelling is an answer, not a failure', (tester) async {
      await pump(tester, outcome: ContactLinkOutcome.cancelled);

      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('Contact details copied'), findsNothing);
      expect(find.text('Could not save the contact details'), findsNothing);
    });

    testWidgets('says nothing for the unsupported outcome either', (
      tester,
    ) async {
      await pump(tester, outcome: ContactLinkOutcome.unsupported);

      expect(find.byType(SnackBar), findsNothing);
    });
  });
}
