import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/model/imported_contact.dart';
import 'package:lotti/features/relationships/service/contacts_service.dart';
import 'package:lotti/features/relationships/state/contact_import_controller.dart';
import 'package:lotti/features/relationships/state/contact_link_controller.dart';
import 'package:lotti/features/relationships/ui/widgets/contact_link_action.dart';

import '../../../../widget_test_utils.dart';

/// Only [isSupported] matters to the widget; the rest of the interface is
/// satisfied so the real provider type can be overridden.
class _FakeContactsService implements ContactsService {
  _FakeContactsService({this.supported = true});

  final bool supported;

  @override
  bool get isSupported => supported;

  @override
  Future<ContactsAccess> requestReadAccess() async => ContactsAccess.granted;

  @override
  Future<ImportedContact?> pickSingle() async => null;

  @override
  Future<List<ImportedContact>> readAll() async => const [];

  @override
  Future<ImportedContact?> readById(String id) async => null;

  @override
  Future<void> openSystemSettings() async {}
}

/// Records which controller method the widget invoked, and answers with a
/// scripted outcome so every toast branch is reachable.
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
  final platformKey = contactRefPlatformKey();

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

  Future<_FakeContactLinkController> pump(
    WidgetTester tester, {
    required RelationshipEntry relationship,
    bool supported = true,
    ContactLinkOutcome outcome = ContactLinkOutcome.linked,
  }) async {
    final controller = _FakeContactLinkController(outcome);
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        ContactLinkAction(relationship: relationship),
        overrides: [
          contactsServiceProvider.overrideWithValue(
            _FakeContactsService(supported: supported),
          ),
          contactLinkControllerProvider.overrideWithValue(controller),
        ],
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  group('what is offered', () {
    testWidgets('an unlinked person gets a single link button', (tester) async {
      await pump(tester, relationship: person());

      expect(find.byIcon(LottiIcons.findPerson), findsOneWidget);
      expect(find.byIcon(LottiIcons.contactCard), findsNothing);
    });

    testWidgets('a linked person gets the menu instead', (tester) async {
      await pump(tester, relationship: person(refs: {platformKey: 'os-1'}));

      expect(find.byIcon(LottiIcons.contactCard), findsOneWidget);
      expect(find.byIcon(LottiIcons.findPerson), findsNothing);
    });

    testWidgets('an empty ref counts as unlinked', (tester) async {
      await pump(tester, relationship: person(refs: {platformKey: ''}));

      expect(find.byIcon(LottiIcons.findPerson), findsOneWidget);
    });

    testWidgets('a ref belonging to another platform counts as unlinked — '
        'refs do not travel between devices', (tester) async {
      final otherPlatform = platformKey == 'ios' ? 'android' : 'ios';

      await pump(tester, relationship: person(refs: {otherPlatform: 'os-1'}));

      expect(find.byIcon(LottiIcons.findPerson), findsOneWidget);
    });

    testWidgets('renders nothing where there is no address book', (
      tester,
    ) async {
      await pump(tester, relationship: person(), supported: false);

      expect(find.byType(IconButton), findsNothing);
      expect(find.byType(PopupMenuButton<dynamic>), findsNothing);
    });
  });

  group('the menu on a linked person', () {
    testWidgets('offers refreshing and re-linking as separate intents', (
      tester,
    ) async {
      await pump(tester, relationship: person(refs: {platformKey: 'os-1'}));

      await tester.tap(find.byIcon(LottiIcons.contactCard));
      await tester.pumpAndSettle();

      expect(find.text('Update from contact'), findsOneWidget);
      expect(find.text('Link a different contact'), findsOneWidget);
    });

    testWidgets('refreshing re-reads the linked contact', (tester) async {
      final controller = await pump(
        tester,
        relationship: person(refs: {platformKey: 'os-1'}),
      );

      await tester.tap(find.byIcon(LottiIcons.contactCard));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Update from contact'));
      await tester.pumpAndSettle();

      expect(controller.calls, ['refresh']);
    });

    testWidgets('re-linking opens the picker instead', (tester) async {
      final controller = await pump(
        tester,
        relationship: person(refs: {platformKey: 'os-1'}),
      );

      await tester.tap(find.byIcon(LottiIcons.contactCard));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Link a different contact'));
      await tester.pumpAndSettle();

      expect(controller.calls, ['link']);
    });
  });

  group('what the user is told', () {
    Future<void> tapLink(WidgetTester tester) async {
      await tester.tap(find.byIcon(LottiIcons.findPerson));
      await tester.pumpAndSettle();
    }

    testWidgets('confirms when details were copied', (tester) async {
      await pump(tester, relationship: person());
      await tapLink(tester);

      expect(find.text('Contact details copied'), findsOneWidget);
    });

    testWidgets('says so when the contact held nothing new', (tester) async {
      await pump(
        tester,
        relationship: person(),
        outcome: ContactLinkOutcome.noChanges,
      );
      await tapLink(tester);

      expect(find.text('Nothing new to copy'), findsOneWidget);
    });

    testWidgets('says so when the contact is not on this device', (
      tester,
    ) async {
      await pump(
        tester,
        relationship: person(),
        outcome: ContactLinkOutcome.contactMissing,
      );
      await tapLink(tester);

      expect(find.text("That contact isn't on this device"), findsOneWidget);
    });

    testWidgets('reports a rejected save', (tester) async {
      await pump(
        tester,
        relationship: person(),
        outcome: ContactLinkOutcome.saveFailed,
      );
      await tapLink(tester);

      expect(find.text('Could not save the contact details'), findsOneWidget);
    });

    testWidgets('says nothing when the user backs out of the picker — '
        'cancelling is an answer, not a failure', (tester) async {
      await pump(
        tester,
        relationship: person(),
        outcome: ContactLinkOutcome.cancelled,
      );
      await tapLink(tester);

      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('Contact details copied'), findsNothing);
      expect(find.text('Could not save the contact details'), findsNothing);
    });
  });
}
