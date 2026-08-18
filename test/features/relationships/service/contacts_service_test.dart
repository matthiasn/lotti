import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/relationships/service/contacts_service.dart';
import 'package:lotti/services/logging_domains.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

/// Drives the real [FlutterContactsService] against a faked
/// `flutter_contacts` platform channel, so the wrapper's own logic — the
/// permission mapping, the property set it asks for, the sort, and the
/// failure guard — is covered rather than mocked away.
///
/// `hasAddressBook` is injected because the test VM reports macOS, where the
/// real check is false and every method would return before reaching the
/// channel.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('flutter_contacts');
  final calls = <MethodCall>[];

  /// Installs a handler that answers [responses] per method name. A method
  /// with no entry throws, which is how the failure paths are exercised.
  void stub(Map<String, Object?> responses) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (!responses.containsKey(call.method)) {
            throw PlatformException(code: 'unavailable', message: call.method);
          }
          return responses[call.method];
        });
  }

  /// The shape `crud.getAll` / `native.showPicker` return over the channel.
  Map<String, Object?> contactJson({
    required String id,
    required String displayName,
    List<Map<String, Object?>> phones = const [],
    List<Map<String, Object?>> emails = const [],
  }) => {
    'id': id,
    'displayName': displayName,
    'phones': phones,
    'emails': emails,
  };

  Map<String, Object?> phoneJson(String number, {String label = 'mobile'}) => {
    'number': number,
    'label': {'label': label},
  };

  FlutterContactsService service({bool hasAddressBook = true}) =>
      FlutterContactsService(hasAddressBook: () => hasAddressBook);

  setUp(calls.clear);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('isSupported', () {
    test('is false where there is no address book to read', () {
      expect(service(hasAddressBook: false).isSupported, isFalse);
    });

    test('is true on a platform with an address book', () {
      expect(service().isSupported, isTrue);
    });

    test('defaults to the real platform check, which is false in the '
        'desktop test VM', () {
      expect(
        FlutterContactsService().isSupported,
        isFalse,
        reason:
            'the production default must consult dart:io, not assume '
            'mobile — this is the guard that keeps the picker off desktop',
      );
    });
  });

  group('failure reporting', () {
    test(
      'reports a platform failure instead of swallowing it silently',
      () async {
        stub(const {});
        final logger = MockDomainLogger();

        final reporting = FlutterContactsService(
          logger: logger,
          hasAddressBook: () => true,
        );
        await reporting.readAll();

        final captured = verify(
          () => logger.error(
            LogDomain.general,
            any<Object>(),
            message: captureAny(named: 'message'),
            stackTrace: any(named: 'stackTrace'),
            subDomain: captureAny(named: 'subDomain'),
          ),
        ).captured;

        expect(
          captured,
          ['contacts readAll failed', 'readAll'],
          reason:
              'a silently empty contact list is indistinguishable from an '
              'empty address book, so the failure must reach the log',
        );
      },
    );
  });

  group('contactsServiceProvider', () {
    test('provides the flutter_contacts-backed implementation', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(contactsServiceProvider),
        isA<FlutterContactsService>(),
      );
    });
  });

  group('requestReadAccess — permission mapping', () {
    test('reports full access as granted', () async {
      stub({'permissions.request': 'granted'});

      expect(await service().requestReadAccess(), ContactsAccess.granted);
    });

    test(
      'reports iOS 18 partial access as limited, not as a failure',
      () async {
        stub({'permissions.request': 'limited'});

        expect(
          await service().requestReadAccess(),
          ContactsAccess.limited,
          reason: 'a curated subset is exactly what this feature asks for',
        );
      },
    );

    test('reports a plain denial as askable again', () async {
      stub({'permissions.request': 'denied'});

      expect(await service().requestReadAccess(), ContactsAccess.denied);
    });

    test('reports "don\'t ask again" as permanently denied', () async {
      stub({'permissions.request': 'permanentlyDenied'});

      expect(
        await service().requestReadAccess(),
        ContactsAccess.permanentlyDenied,
      );
    });

    test('treats a policy restriction as permanent — a retry cannot lift '
        'parental controls or an MDM profile', () async {
      stub({'permissions.request': 'restricted'});

      expect(
        await service().requestReadAccess(),
        ContactsAccess.permanentlyDenied,
      );
    });

    test('treats a dismissed prompt as askable again', () async {
      stub({'permissions.request': 'notDetermined'});

      expect(await service().requestReadAccess(), ContactsAccess.denied);
    });

    test('asks only for read access, never write', () async {
      stub({'permissions.request': 'granted'});

      await service().requestReadAccess();

      expect(
        (calls.single.arguments as Map)['type'],
        'read',
        reason: 'ADR 0041: Lotti never writes to the address book',
      );
    });

    test(
      'reports unsupported on desktop without touching the channel',
      () async {
        stub({'permissions.request': 'granted'});

        expect(
          await service(hasAddressBook: false).requestReadAccess(),
          ContactsAccess.unsupported,
        );
        expect(calls, isEmpty);
      },
    );

    test('falls back to denied when the platform call fails', () async {
      stub(const {});

      expect(await service().requestReadAccess(), ContactsAccess.denied);
    });
  });

  // The plugin's own `NativeApi` carries a `Platform.isAndroid || isIOS`
  // check that throws before any channel call, and the test VM reports
  // macOS. So the picker's success path is genuinely unreachable here — no
  // stub can make `showPicker` return a contact.
  //
  // Rather than leave tests that pass for the wrong reason, this group covers
  // only what is real in the VM: that a platform refusal becomes a null
  // instead of an exception thrown at a user who just tapped "Link contact".
  // The mapping `pickSingle` performs on success is `importedContactFrom`,
  // covered directly in `contact_import_mapper_test.dart`, and the property
  // set it requests is pinned below on `readAll`, which reaches the channel.
  group('pickSingle', () {
    test(
      'converts a platform refusal into null rather than throwing',
      () async {
        stub(const {});

        expect(await service().pickSingle(), isNull);
      },
    );

    test('returns null on desktop without touching the channel', () async {
      stub({
        'native.showPicker': contactJson(id: 'os-1', displayName: 'Anna'),
      });

      expect(await service(hasAddressBook: false).pickSingle(), isNull);
      expect(calls, isEmpty);
    });
  });

  group('readAll', () {
    test('maps every readable contact', () async {
      stub({
        'crud.getAll': [
          contactJson(id: 'a', displayName: 'Anna'),
          contactJson(id: 'b', displayName: 'Bo'),
        ],
      });

      expect(
        (await service().readAll()).map((c) => c.displayName),
        ['Anna', 'Bo'],
      );
    });

    test(
      'sorts by name so the list reads the same on both platforms',
      () async {
        stub({
          'crud.getAll': [
            contactJson(id: 'c', displayName: 'Zoe'),
            contactJson(id: 'a', displayName: 'anna'),
            contactJson(id: 'b', displayName: 'Bo'),
          ],
        });

        expect(
          (await service().readAll()).map((c) => c.displayName),
          ['anna', 'Bo', 'Zoe'],
          reason: 'the sort is case-insensitive, or lowercase names sink',
        );
      },
    );

    test('carries the channels through, typed by label', () async {
      stub({
        'crud.getAll': [
          contactJson(
            id: 'a',
            displayName: 'Anna',
            phones: [
              phoneJson('+15550109999'),
              phoneJson('+493090182', label: 'home'),
            ],
          ),
        ],
      });

      final channels = (await service().readAll()).single.channels;

      expect(
        channels.map((c) => c.type),
        [ContactChannelType.mobile, ContactChannelType.phone],
        reason: 'the landline must not offer a message composer',
      );
    });

    test('drops contacts that cannot become a person', () async {
      stub({
        'crud.getAll': [
          contactJson(id: 'a', displayName: 'Anna'),
          contactJson(id: '', displayName: 'No id'),
        ],
      });

      expect((await service().readAll()).map((c) => c.id), ['a']);
    });

    test('returns nothing for an empty address book', () async {
      stub({'crud.getAll': <Object?>[]});

      expect(await service().readAll(), isEmpty);
    });

    test('asks only for name, phone and email', () async {
      stub({'crud.getAll': <Object?>[]});

      await service().readAll();

      final requested = ((calls.single.arguments as Map)['properties'] as List)
          .toSet();

      expect(
        requested,
        {'name', 'phone', 'email'},
        reason:
            'photos, addresses, notes and events are never read — not '
            'asking is cheaper than asking and discarding (ADR 0037)',
      );
    });

    test('returns nothing on desktop without touching the channel', () async {
      stub({'crud.getAll': <Object?>[]});

      expect(await service(hasAddressBook: false).readAll(), isEmpty);
      expect(calls, isEmpty);
    });

    test(
      'returns nothing rather than throwing when the read is refused',
      () async {
        stub(const {});

        expect(await service().readAll(), isEmpty);
      },
    );
  });

  group('readById', () {
    test('maps the contact behind a stored ref', () async {
      stub({
        'crud.get': contactJson(
          id: 'os-1',
          displayName: 'Anna Schmidt',
          emails: [
            {
              'address': 'anna@example.com',
              'label': {'label': 'work'},
            },
          ],
        ),
      });

      final contact = await service().readById('os-1');

      expect(contact!.channels.single.value, 'anna@example.com');
    });

    test('passes the id through to the platform', () async {
      stub({'crud.get': contactJson(id: 'os-1', displayName: 'Anna')});

      await service().readById('os-1');

      expect((calls.single.arguments as Map)['id'], 'os-1');
    });

    test('returns null when the contact was deleted from the device', () async {
      stub({'crud.get': null});

      expect(await service().readById('gone'), isNull);
    });

    test('returns null on desktop without touching the channel', () async {
      stub({'crud.get': contactJson(id: 'os-1', displayName: 'Anna')});

      expect(await service(hasAddressBook: false).readById('os-1'), isNull);
      expect(calls, isEmpty);
    });

    test('returns null rather than throwing when the read fails', () async {
      stub(const {});

      expect(await service().readById('os-1'), isNull);
    });
  });

  group('openSystemSettings', () {
    test('asks the platform to open settings', () async {
      stub({'permissions.openSettings': null});

      await service().openSystemSettings();

      expect(calls.single.method, 'permissions.openSettings');
    });

    test('does nothing on desktop', () async {
      stub({'permissions.openSettings': null});

      await service(hasAddressBook: false).openSystemSettings();

      expect(calls, isEmpty);
    });

    test(
      'swallows a platform failure rather than throwing at the user',
      () async {
        stub(const {});

        await expectLater(service().openSystemSettings(), completes);
      },
    );
  });
}
