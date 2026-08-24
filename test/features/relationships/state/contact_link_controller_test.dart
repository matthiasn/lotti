import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/relationships/model/imported_contact.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/service/contacts_service.dart';
import 'package:lotti/features/relationships/state/contact_import_controller.dart';
import 'package:lotti/features/relationships/state/contact_link_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

class _FakeContactsService implements ContactsService {
  bool supported = true;
  ImportedContact? picked;
  ImportedContact? byId;
  String? readByIdArg;

  @override
  bool get isSupported => supported;

  @override
  Future<ImportedContact?> pickSingle() async => picked;

  @override
  Future<ImportedContact?> readById(String id) async {
    readByIdArg = id;
    return byId;
  }

  @override
  Future<ContactsAccess> requestReadAccess() async => ContactsAccess.granted;

  @override
  Future<List<ImportedContact>> readAll() async => const [];

  @override
  Future<void> openSystemSettings() async {}
}

void main() {
  final testDate = DateTime(2026, 8, 17, 12);
  // Refs are per-device: the key carries this device's sync host id, and a
  // same-platform key with a different host belongs to another device.
  const deviceKey = 'android:host-a';
  const otherDeviceKey = 'android:host-b';

  late _FakeContactsService service;
  late MockRelationshipRepository repository;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    service = _FakeContactsService();
    repository = MockRelationshipRepository();
    when(
      () => repository.updateRelationship(any()),
    ).thenAnswer((_) async => true);
  });

  ContactChannel channel(
    ContactChannelType type,
    String value, {
    String? label,
  }) => ContactChannel(type: type, value: value, label: label);

  ImportedContact contact({
    String id = 'os-1',
    String name = 'Anna Schmidt',
    List<ContactChannel> channels = const [],
  }) => (id: id, displayName: name, channels: channels);

  RelationshipEntry person({
    String title = 'Mum',
    List<ContactChannel> channels = const [],
    Map<String, String> refs = const {},
  }) => RelationshipEntry(
    meta: Metadata(
      id: 'rel-1',
      createdAt: testDate,
      updatedAt: testDate,
      dateFrom: testDate,
      dateTo: testDate,
    ),
    data: RelationshipData(
      title: title,
      status: RelationshipStatus.active(
        id: 'status-1',
        createdAt: testDate,
        utcOffset: 0,
      ),
      contactChannels: channels,
      contactRefs: refs,
    ),
  );

  ContactLinkController build({String? refKey = deviceKey}) {
    final container = ProviderContainer(
      overrides: [
        contactsServiceProvider.overrideWithValue(service),
        relationshipRepositoryProvider.overrideWithValue(repository),
        contactRefKeyProvider.overrideWith((ref) async => refKey),
      ],
    );
    addTearDown(container.dispose);
    return container.read(contactLinkControllerProvider);
  }

  RelationshipData savedData() =>
      (verify(
                () => repository.updateRelationship(captureAny()),
              ).captured.single
              as RelationshipEntry)
          .data;

  group('linkContact', () {
    test('copies the chosen channels onto the person', () async {
      service.picked = contact(
        channels: [channel(ContactChannelType.mobile, '+15550109999')],
      );

      final outcome = await build().linkContact(person());

      expect(outcome, ContactLinkOutcome.linked);
      expect(savedData().contactChannels.single.value, '+15550109999');
    });

    test(
      'records the OS id so a later refresh can find the contact again',
      () async {
        service.picked = contact(
          id: 'os-42',
          channels: [channel(ContactChannelType.mobile, '+15550109999')],
        );

        await build().linkContact(person());

        expect(savedData().contactRefs, {deviceKey: 'os-42'});
      },
    );

    test('keeps the name the user gave the person', () async {
      service.picked = contact(
        name: 'Margaret Schmidt',
        channels: [channel(ContactChannelType.mobile, '+15550109999')],
      );

      await build().linkContact(person());

      expect(
        savedData().title,
        'Mum',
        reason:
            'someone renamed to "Mum" on purpose must not be silently '
            'renamed back by a contact refresh',
      );
    });

    test(
      'adds to the channels already there rather than replacing them',
      () async {
        service.picked = contact(
          channels: [channel(ContactChannelType.email, 'anna@example.com')],
        );

        await build().linkContact(
          person(
            channels: [
              channel(ContactChannelType.messaging, '@anna', label: 'Signal'),
            ],
          ),
        );

        final saved = savedData().contactChannels;
        expect(saved, hasLength(2));
        expect(
          saved.first.value,
          '@anna',
          reason:
              'a handwritten handle the address book does not hold must '
              'survive linking',
        );
      },
    );

    test('reports no changes when the contact holds nothing new', () async {
      service.picked = contact(
        channels: [channel(ContactChannelType.mobile, '+1 (555) 010-9999')],
      );

      final outcome = await build().linkContact(
        person(
          channels: [channel(ContactChannelType.mobile, '+15550109999')],
          refs: {deviceKey: 'os-1'},
        ),
      );

      expect(outcome, ContactLinkOutcome.noChanges);
      verifyNever(() => repository.updateRelationship(any()));
    });

    test('still saves when only the ref changed, so re-linking to a '
        'different contact takes effect', () async {
      service.picked = contact(
        id: 'os-99',
        channels: [channel(ContactChannelType.mobile, '+15550109999')],
      );

      final outcome = await build().linkContact(
        person(
          channels: [channel(ContactChannelType.mobile, '+15550109999')],
          refs: {deviceKey: 'os-1'},
        ),
      );

      expect(outcome, ContactLinkOutcome.linked);
      expect(savedData().contactRefs[deviceKey], 'os-99');
    });

    test('reports a cancelled picker without writing anything', () async {
      final outcome = await build().linkContact(person());

      expect(outcome, ContactLinkOutcome.cancelled);
      verifyNever(() => repository.updateRelationship(any()));
    });

    test('reports unsupported on desktop without opening a picker', () async {
      service
        ..supported = false
        ..picked = contact();

      final outcome = await build().linkContact(person());

      expect(outcome, ContactLinkOutcome.unsupported);
      verifyNever(() => repository.updateRelationship(any()));
    });

    test('reports a rejected write rather than claiming success', () async {
      when(
        () => repository.updateRelationship(any()),
      ).thenAnswer((_) async => false);
      service.picked = contact(
        channels: [channel(ContactChannelType.mobile, '+15550109999')],
      );

      expect(
        await build().linkContact(person()),
        ContactLinkOutcome.saveFailed,
      );
    });

    test('links a contact that carries no channels at all', () async {
      service.picked = contact(id: 'os-7');

      final outcome = await build().linkContact(person());

      expect(outcome, ContactLinkOutcome.linked);
      expect(savedData().contactRefs, {deviceKey: 'os-7'});
    });

    test(
      "writes only into this device's slot, leaving a ref another device "
      'wrote untouched',
      () async {
        service.picked = contact(
          id: 'os-42',
          channels: [channel(ContactChannelType.mobile, '+15550109999')],
        );

        await build().linkContact(
          person(refs: {otherDeviceKey: 'their-os-id'}),
        );

        expect(savedData().contactRefs, {
          otherDeviceKey: 'their-os-id',
          deviceKey: 'os-42',
        });
      },
    );

    test(
      'copies channels without storing a ref while the host id is unknown, '
      'rather than parking the id under a key another device could collide '
      'with',
      () async {
        service.picked = contact(
          id: 'os-42',
          channels: [channel(ContactChannelType.mobile, '+15550109999')],
        );

        final outcome = await build(refKey: null).linkContact(person());

        expect(outcome, ContactLinkOutcome.linked);
        expect(savedData().contactRefs, isEmpty);
      },
    );
  });

  group('refreshFromContact', () {
    test('re-reads the linked contact and copies anything new', () async {
      service.byId = contact(
        channels: [
          channel(ContactChannelType.mobile, '+15550109999'),
          channel(ContactChannelType.email, 'anna@example.com'),
        ],
      );

      final outcome = await build().refreshFromContact(
        person(
          channels: [channel(ContactChannelType.mobile, '+15550109999')],
          refs: {deviceKey: 'os-1'},
        ),
      );

      expect(outcome, ContactLinkOutcome.linked);
      expect(savedData().contactChannels, hasLength(2));
    });

    test('reads the contact the stored ref names', () async {
      service.byId = contact(id: 'os-5');

      await build().refreshFromContact(person(refs: {deviceKey: 'os-5'}));

      expect(service.readByIdArg, 'os-5');
    });

    test(
      'reports the contact missing when this device has no ref — refs are '
      'per-device, so a person linked on a phone is unlinked on a tablet',
      () async {
        final outcome = await build().refreshFromContact(person());

        expect(outcome, ContactLinkOutcome.contactMissing);
        expect(service.readByIdArg, isNull);
      },
    );

    test('treats an empty ref as no ref', () async {
      final outcome = await build().refreshFromContact(
        person(refs: {deviceKey: ''}),
      );

      expect(outcome, ContactLinkOutcome.contactMissing);
    });

    test(
      "never resolves a ref another device wrote — a same-platform peer's "
      'contact id would name an unrelated person in this address book',
      () async {
        service.byId = contact(
          name: 'Wrong Person',
          channels: [channel(ContactChannelType.mobile, '+15550100000')],
        );

        final outcome = await build().refreshFromContact(
          person(refs: {otherDeviceKey: 'os-1'}),
        );

        expect(outcome, ContactLinkOutcome.contactMissing);
        expect(
          service.readByIdArg,
          isNull,
          reason:
              "the other device's id must not even be looked up — ids are "
              'only meaningful in the address book that assigned them',
        );
        verifyNever(() => repository.updateRelationship(any()));
      },
    );

    test('reports the contact missing while the host id is unknown', () async {
      final outcome = await build(refKey: null).refreshFromContact(
        person(refs: {deviceKey: 'os-1'}),
      );

      expect(outcome, ContactLinkOutcome.contactMissing);
      expect(service.readByIdArg, isNull);
    });

    test(
      'reports the contact missing when it was deleted from the device',
      () async {
        final outcome = await build().refreshFromContact(
          person(refs: {deviceKey: 'os-gone'}),
        );

        expect(outcome, ContactLinkOutcome.contactMissing);
        verifyNever(() => repository.updateRelationship(any()));
      },
    );

    test('reports no changes when the contact has not moved on', () async {
      service.byId = contact(
        channels: [channel(ContactChannelType.mobile, '+15550109999')],
      );

      final outcome = await build().refreshFromContact(
        person(
          channels: [channel(ContactChannelType.mobile, '+15550109999')],
          refs: {deviceKey: 'os-1'},
        ),
      );

      expect(outcome, ContactLinkOutcome.noChanges);
    });

    test('reports unsupported on desktop', () async {
      service.supported = false;

      expect(
        await build().refreshFromContact(person(refs: {deviceKey: 'os-1'})),
        ContactLinkOutcome.unsupported,
      );
    });

    test('reports a rejected write', () async {
      when(
        () => repository.updateRelationship(any()),
      ).thenAnswer((_) async => false);
      service.byId = contact(
        channels: [channel(ContactChannelType.mobile, '+15550109999')],
      );

      expect(
        await build().refreshFromContact(person(refs: {deviceKey: 'os-1'})),
        ContactLinkOutcome.saveFailed,
      );
    });
  });
}
