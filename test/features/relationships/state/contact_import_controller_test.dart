import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/relationships/model/imported_contact.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/service/contacts_service.dart';
import 'package:lotti/features/relationships/state/contact_import_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

/// A contacts service whose access answer and contact list are scripted.
class _FakeContactsService implements ContactsService {
  bool supported = true;
  ContactsAccess access = ContactsAccess.granted;
  List<ImportedContact> contacts = const [];
  int readAllCount = 0;

  @override
  bool get isSupported => supported;

  @override
  Future<ContactsAccess> requestReadAccess() async => access;

  @override
  Future<List<ImportedContact>> readAll() async {
    readAllCount++;
    return contacts;
  }

  @override
  Future<ImportedContact?> pickSingle() async => null;

  @override
  Future<ImportedContact?> readById(String id) async => null;

  @override
  Future<void> openSystemSettings() async {}
}

void main() {
  final testDate = DateTime(2026, 8, 17, 12);

  late _FakeContactsService service;
  late MockRelationshipRepository repository;

  setUpAll(registerAllFallbackValues);

  ImportedContact contact(
    String id,
    String name, {
    List<ContactChannel> channels = const [],
  }) => (id: id, displayName: name, channels: channels);

  ContactChannel channel(ContactChannelType type, String value) =>
      ContactChannel(type: type, value: value);

  RelationshipEntry created(String id) => RelationshipEntry(
    meta: Metadata(
      id: id,
      createdAt: testDate,
      updatedAt: testDate,
      dateFrom: testDate,
      dateTo: testDate,
    ),
    data: RelationshipData(
      title: 'x',
      status: RelationshipStatus.active(
        id: 'status',
        createdAt: testDate,
        utcOffset: 0,
      ),
    ),
  );

  setUp(() {
    service = _FakeContactsService();
    repository = MockRelationshipRepository();
  });

  ({ProviderContainer container, ContactImportController controller}) build({
    String? refKey = 'android:host-a',
  }) {
    final container = ProviderContainer(
      overrides: [
        contactsServiceProvider.overrideWithValue(service),
        relationshipRepositoryProvider.overrideWithValue(repository),
        contactRefKeyProvider.overrideWith((ref) async => refKey),
      ],
    );
    addTearDown(container.dispose);
    // Reading the state first instantiates the notifier.
    container.read(contactImportControllerProvider);
    return (
      container: container,
      controller: container.read(contactImportControllerProvider.notifier),
    );
  }

  group('load — access outcomes', () {
    test('lists the address book when access is granted', () async {
      service.contacts = [contact('a', 'Anna'), contact('b', 'Bo')];
      final (:container, :controller) = build();

      await controller.load();

      expect(
        container.read(contactImportControllerProvider).status,
        ContactImportStatus.ready,
      );
      expect(
        container
            .read(contactImportControllerProvider)
            .contacts
            .map((c) => c.displayName),
        ['Anna', 'Bo'],
      );
    });

    test('treats iOS partial access as usable — a curated subset is the '
        'point of this feature', () async {
      service
        ..access = ContactsAccess.limited
        ..contacts = [contact('a', 'Anna')];
      final (:container, :controller) = build();

      await controller.load();

      expect(
        container.read(contactImportControllerProvider).status,
        ContactImportStatus.ready,
      );
    });

    test('reports a refusal the user can be asked about again', () async {
      service.access = ContactsAccess.denied;
      final (:container, :controller) = build();

      await controller.load();

      expect(
        container.read(contactImportControllerProvider).status,
        ContactImportStatus.denied,
      );
    });

    test('reports a permanent refusal separately, so the UI can offer '
        'settings instead of a useless retry', () async {
      service.access = ContactsAccess.permanentlyDenied;
      final (:container, :controller) = build();

      await controller.load();

      expect(
        container.read(contactImportControllerProvider).status,
        ContactImportStatus.permanentlyDenied,
      );
    });

    test('does not read the address book when access was refused', () async {
      service.access = ContactsAccess.denied;
      final controller = build().controller;

      await controller.load();

      expect(service.readAllCount, 0);
    });

    test(
      'reports desktop as unsupported without asking for permission',
      () async {
        service.supported = false;
        final (:container, :controller) = build();

        await controller.load();

        expect(
          container.read(contactImportControllerProvider).status,
          ContactImportStatus.unsupported,
        );
        expect(service.readAllCount, 0);
      },
    );

    test('distinguishes an empty address book from a refusal', () async {
      final (:container, :controller) = build();

      await controller.load();

      expect(
        container.read(contactImportControllerProvider).status,
        ContactImportStatus.empty,
      );
    });

    test('can be retried after the user grants access from settings', () async {
      service.access = ContactsAccess.permanentlyDenied;
      final (:container, :controller) = build();
      await controller.load();

      service
        ..access = ContactsAccess.granted
        ..contacts = [contact('a', 'Anna')];
      await controller.load();

      expect(
        container.read(contactImportControllerProvider).status,
        ContactImportStatus.ready,
      );
    });

    test('drops selections on reload, so no draft survives from a list that '
        'was replaced', () async {
      service.contacts = [contact('a', 'Anna')];
      final (:container, :controller) = build();
      await controller.load();
      controller.toggleSelection(contact('a', 'Anna'));

      await controller.load();

      expect(container.read(contactImportControllerProvider).drafts, isEmpty);
    });
  });

  group('search', () {
    setUp(() {
      service.contacts = [
        contact(
          'a',
          'Anna Schmidt',
          channels: [channel(ContactChannelType.mobile, '+15550109999')],
        ),
        contact('b', 'Bo Larsen'),
      ];
    });

    test('shows everything when the query is empty', () async {
      final controller = build().controller;
      await controller.load();

      expect(controller.visibleContacts, hasLength(2));
    });

    test('matches on name, case-insensitively', () async {
      final controller = build().controller;
      await controller.load();

      controller.setQuery('anna');

      expect(controller.visibleContacts.single.displayName, 'Anna Schmidt');
    });

    test(
      'matches on a channel value, so a number can be searched for',
      () async {
        final controller = build().controller;
        await controller.load();

        controller.setQuery('5550109');

        expect(controller.visibleContacts.single.id, 'a');
      },
    );

    test('ignores surrounding whitespace in the query', () async {
      final controller = build().controller;
      await controller.load();

      controller.setQuery('  bo  ');

      expect(controller.visibleContacts.single.displayName, 'Bo Larsen');
    });

    test('shows nothing when the query matches nobody', () async {
      final controller = build().controller;
      await controller.load();

      controller.setQuery('zzz');

      expect(controller.visibleContacts, isEmpty);
    });

    test('does not deselect a contact the query hides', () async {
      final (:container, :controller) = build();
      await controller.load();
      controller
        ..toggleSelection(contact('a', 'Anna Schmidt'))
        ..setQuery('bo');

      expect(
        container.read(contactImportControllerProvider).drafts.keys,
        ['a'],
        reason:
            'filtering the list must not silently undo a choice the user '
            'already made',
      );
    });
  });

  group('selection', () {
    test('selects a contact as unimportant, with no cadence', () async {
      final (:container, :controller) = build();

      controller.toggleSelection(contact('a', 'Anna'));

      final draft = container
          .read(contactImportControllerProvider)
          .drafts['a']!;
      expect(
        draft.important,
        isFalse,
        reason: 'importing someone is not consent to be nudged about them',
      );
      expect(draft.cadenceDays, isNull);
    });

    test('toggling twice deselects', () async {
      final (:container, :controller) = build();

      controller
        ..toggleSelection(contact('a', 'Anna'))
        ..toggleSelection(contact('a', 'Anna'));

      expect(container.read(contactImportControllerProvider).drafts, isEmpty);
    });

    test('keeps selections in the order they were made', () async {
      final (:container, :controller) = build();

      controller
        ..toggleSelection(contact('c', 'Cara'))
        ..toggleSelection(contact('a', 'Anna'));

      expect(
        container.read(contactImportControllerProvider).drafts.keys,
        ['c', 'a'],
      );
    });

    test('reports what is selected', () async {
      final controller = build().controller
        ..toggleSelection(contact('a', 'Anna'));

      expect(controller.isSelected('a'), isTrue);
      expect(controller.isSelected('b'), isFalse);
    });

    test('clearSelection drops every draft', () async {
      final (:container, :controller) = build();
      controller
        ..toggleSelection(contact('a', 'Anna'))
        ..toggleSelection(contact('b', 'Bo'))
        ..clearSelection();

      expect(container.read(contactImportControllerProvider).drafts, isEmpty);
    });
  });

  group('review decisions', () {
    test('marks a selected contact important', () async {
      final (:container, :controller) = build();
      controller
        ..toggleSelection(contact('a', 'Anna'))
        ..setImportant(contactId: 'a', important: true);

      expect(
        container.read(contactImportControllerProvider).drafts['a']!.important,
        isTrue,
      );
    });

    test('sets a cadence on an important contact', () async {
      final (:container, :controller) = build();
      controller
        ..toggleSelection(contact('a', 'Anna'))
        ..setImportant(contactId: 'a', important: true)
        ..setCadence(contactId: 'a', cadenceDays: 14);

      expect(
        container
            .read(contactImportControllerProvider)
            .drafts['a']!
            .cadenceDays,
        14,
      );
    });

    test('refuses a cadence on someone not marked important — it would never '
        'be evaluated', () async {
      final (:container, :controller) = build();
      controller
        ..toggleSelection(contact('a', 'Anna'))
        ..setCadence(contactId: 'a', cadenceDays: 14);

      expect(
        container
            .read(contactImportControllerProvider)
            .drafts['a']!
            .cadenceDays,
        isNull,
      );
    });

    test('clearing importance also clears the cadence, so it cannot '
        'reappear later', () async {
      final (:container, :controller) = build();
      controller
        ..toggleSelection(contact('a', 'Anna'))
        ..setImportant(contactId: 'a', important: true)
        ..setCadence(contactId: 'a', cadenceDays: 14)
        ..setImportant(contactId: 'a', important: false);

      final draft = container
          .read(contactImportControllerProvider)
          .drafts['a']!;
      expect(draft.important, isFalse);
      expect(draft.cadenceDays, isNull);
    });

    test('ignores decisions about a contact that is not selected', () async {
      final (:container, :controller) = build();

      controller
        ..setImportant(contactId: 'ghost', important: true)
        ..setCadence(contactId: 'ghost', cadenceDays: 7);

      expect(container.read(contactImportControllerProvider).drafts, isEmpty);
    });
  });

  group('importSelected', () {
    setUp(() {
      when(
        () => repository.createRelationship(
          data: any(named: 'data'),
          entryText: any(named: 'entryText'),
          categoryId: any(named: 'categoryId'),
        ),
      ).thenAnswer((_) async => created('new-id'));
    });

    test('creates one person per selected contact', () async {
      final controller = build().controller
        ..toggleSelection(contact('a', 'Anna'))
        ..toggleSelection(contact('b', 'Bo'));

      final ids = await controller.importSelected();

      expect(ids, hasLength(2));
      verify(
        () => repository.createRelationship(
          data: any(named: 'data'),
          entryText: any(named: 'entryText'),
          categoryId: any(named: 'categoryId'),
        ),
      ).called(2);
    });

    test(
      'carries the name, channels and review decisions onto the person',
      () async {
        final controller = build().controller
          ..toggleSelection(
            contact(
              'a',
              'Anna Schmidt',
              channels: [channel(ContactChannelType.mobile, '+15550109999')],
            ),
          )
          ..setImportant(contactId: 'a', important: true)
          ..setCadence(contactId: 'a', cadenceDays: 30);

        await controller.importSelected();

        final data =
            verify(
                  () => repository.createRelationship(
                    data: captureAny(named: 'data'),
                    entryText: any(named: 'entryText'),
                    categoryId: any(named: 'categoryId'),
                  ),
                ).captured.single
                as RelationshipData;

        expect(data.title, 'Anna Schmidt');
        expect(data.contactChannels.single.value, '+15550109999');
        expect(data.important, isTrue);
        expect(data.checkInCadenceDays, 30);
        expect(data.contactRefs.values.single, 'a');
      },
    );

    test(
      "records the OS id under this device's key so a ref written on one "
      'device is never trusted on another — not even a same-platform one',
      () async {
        final controller = build().controller
          ..toggleSelection(contact('os-99', 'Anna'));

        await controller.importSelected();

        final data =
            verify(
                  () => repository.createRelationship(
                    data: captureAny(named: 'data'),
                    entryText: any(named: 'entryText'),
                    categoryId: any(named: 'categoryId'),
                  ),
                ).captured.single
                as RelationshipData;

        expect(data.contactRefs, {'android:host-a': 'os-99'});
      },
    );

    test(
      'imports without a ref while the host id is unknown, rather than '
      'parking the id under a key another device could collide with',
      () async {
        final controller = build(refKey: null).controller
          ..toggleSelection(contact('os-99', 'Anna'));

        final ids = await controller.importSelected();

        final data =
            verify(
                  () => repository.createRelationship(
                    data: captureAny(named: 'data'),
                    entryText: any(named: 'entryText'),
                    categoryId: any(named: 'categoryId'),
                  ),
                ).captured.single
                as RelationshipData;

        expect(ids, isNotEmpty);
        expect(data.contactRefs, isEmpty);
      },
    );

    test('imports in the order the user selected', () async {
      final controller = build().controller
        ..toggleSelection(contact('c', 'Cara'))
        ..toggleSelection(contact('a', 'Anna'));

      await controller.importSelected();

      final titles = verify(
        () => repository.createRelationship(
          data: captureAny(named: 'data'),
          entryText: any(named: 'entryText'),
          categoryId: any(named: 'categoryId'),
        ),
      ).captured.cast<RelationshipData>().map((data) => data.title).toList();

      expect(titles, ['Cara', 'Anna']);
    });

    test('skips a rejected write instead of abandoning the batch', () async {
      when(
        () => repository.createRelationship(
          data: any(named: 'data'),
          entryText: any(named: 'entryText'),
          categoryId: any(named: 'categoryId'),
        ),
      ).thenAnswer((invocation) async {
        final data = invocation.namedArguments[#data]! as RelationshipData;
        return data.title == 'Bo' ? null : created('id-${data.title}');
      });

      final controller = build().controller
        ..toggleSelection(contact('a', 'Anna'))
        ..toggleSelection(contact('b', 'Bo'))
        ..toggleSelection(contact('c', 'Cara'));

      final ids = await controller.importSelected();

      expect(
        ids,
        ['id-Anna', 'id-Cara'],
        reason:
            'the people who did land are real; failing the whole batch '
            'would hide that',
      );
    });

    test('clears the selection after a successful import', () async {
      final (:container, :controller) = build();
      controller.toggleSelection(contact('a', 'Anna'));

      await controller.importSelected();

      expect(container.read(contactImportControllerProvider).drafts, isEmpty);
    });

    test('keeps the selection when nothing could be created, so the user can '
        'retry', () async {
      when(
        () => repository.createRelationship(
          data: any(named: 'data'),
          entryText: any(named: 'entryText'),
          categoryId: any(named: 'categoryId'),
        ),
      ).thenAnswer((_) async => null);

      final (:container, :controller) = build();
      controller.toggleSelection(contact('a', 'Anna'));

      final ids = await controller.importSelected();

      expect(ids, isEmpty);
      expect(
        container.read(contactImportControllerProvider).drafts.keys,
        ['a'],
      );
    });

    test('writes nothing when nobody is selected', () async {
      final controller = build().controller;

      expect(await controller.importSelected(), isEmpty);
      verifyNever(
        () => repository.createRelationship(
          data: any(named: 'data'),
          entryText: any(named: 'entryText'),
          categoryId: any(named: 'categoryId'),
        ),
      );
    });
  });

  group('contactRefKeyProvider', () {
    late MockVectorClockService vectorClockService;

    setUp(() {
      vectorClockService = MockVectorClockService();
      when(
        () => vectorClockService.initialized,
      ).thenAnswer((_) => Future.value());
      getIt.registerSingleton<VectorClockService>(vectorClockService);
    });

    tearDown(() => getIt.unregister<VectorClockService>());

    test('scopes the key to this device via the sync host id', () async {
      when(vectorClockService.getHost).thenAnswer((_) async => 'host-a');
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final key = await container.read(contactRefKeyProvider.future);

      expect(key, contactRefKeyForHost('host-a'));
      expect(
        key,
        endsWith(':host-a'),
        reason:
            'two devices on the same platform must land on different keys, '
            'so the host id has to be part of the key',
      );
    });

    test('yields no key while the host id is unprovisioned', () async {
      when(vectorClockService.getHost).thenAnswer((_) async => null);
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(await container.read(contactRefKeyProvider.future), isNull);
    });
  });
}
