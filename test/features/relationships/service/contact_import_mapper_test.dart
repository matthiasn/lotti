import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/relationships/service/contact_import_mapper.dart';

/// The plugin's models are plain Dart classes, so they can be built directly
/// here — no platform channel, no mock. These tests therefore exercise the
/// real mapping code against the real shapes the plugin returns.
Contact _contact({
  String? id = 'os-1',
  String? displayName = 'Anna Schmidt',
  Name? name,
  List<Phone> phones = const [],
  List<Email> emails = const [],
}) => Contact(
  id: id,
  displayName: displayName,
  name: name,
  phones: phones,
  emails: emails,
);

Phone _phone(String number, {PhoneLabel? label, String? custom}) => Phone(
  number: number,
  label: Label(label ?? PhoneLabel.mobile, custom),
);

Email _email(String address, {EmailLabel? label, String? custom}) => Email(
  address: address,
  label: Label(label ?? EmailLabel.home, custom),
);

void main() {
  group('importedContactFrom — identity', () {
    test('takes the platform display name when it has one', () {
      final imported = importedContactFrom(_contact());

      expect(imported!.displayName, 'Anna Schmidt');
      expect(imported.id, 'os-1');
    });

    test('composes a name from the structured parts when the platform gives '
        'no display name — the Android sync case', () {
      final imported = importedContactFrom(
        _contact(
          displayName: null,
          name: const Name(first: 'Anna', middle: 'Marie', last: 'Schmidt'),
        ),
      );

      expect(imported!.displayName, 'Anna Marie Schmidt');
    });

    test('skips the absent parts when composing rather than doubling '
        'spaces', () {
      final imported = importedContactFrom(
        _contact(
          displayName: '  ',
          name: const Name(first: 'Anna', last: 'Schmidt'),
        ),
      );

      expect(imported!.displayName, 'Anna Schmidt');
    });

    test('trims a padded display name', () {
      final imported = importedContactFrom(
        _contact(displayName: '  Anna Schmidt  '),
      );

      expect(imported!.displayName, 'Anna Schmidt');
    });

    test('rejects a contact with no name at all — a relationship with no '
        'person is not a relationship', () {
      expect(importedContactFrom(_contact(displayName: null)), isNull);
    });

    test('rejects a contact whose name parts are all blank', () {
      expect(
        importedContactFrom(
          _contact(
            displayName: '',
            name: const Name(first: ' ', last: '  '),
          ),
        ),
        isNull,
      );
    });

    test('rejects a contact with no id — nothing could re-find it later', () {
      expect(importedContactFrom(_contact(id: null)), isNull);
    });

    test('rejects a contact whose id is blank', () {
      expect(importedContactFrom(_contact(id: '   ')), isNull);
    });
  });

  group('contactChannelsFrom — phone typing', () {
    test('treats a mobile number as messageable', () {
      final channels = contactChannelsFrom(
        _contact(phones: [_phone('+15550109999', label: PhoneLabel.mobile)]),
      );

      expect(channels.single.type, ContactChannelType.mobile);
    });

    test('treats an iPhone-labelled number as messageable', () {
      final channels = contactChannelsFrom(
        _contact(phones: [_phone('+15550109999', label: PhoneLabel.iPhone)]),
      );

      expect(channels.single.type, ContactChannelType.mobile);
    });

    test('treats a home number as a landline, so no message composer is '
        'offered for it', () {
      final channels = contactChannelsFrom(
        _contact(phones: [_phone('+493090182', label: PhoneLabel.home)]),
      );

      expect(channels.single.type, ContactChannelType.phone);
    });

    test('treats a fax number as a landline rather than something to text', () {
      final channels = contactChannelsFrom(
        _contact(phones: [_phone('+493090183', label: PhoneLabel.homeFax)]),
      );

      expect(channels.single.type, ContactChannelType.phone);
    });

    test('treats a work number as a landline', () {
      final channels = contactChannelsFrom(
        _contact(phones: [_phone('+493090184', label: PhoneLabel.work)]),
      );

      expect(channels.single.type, ContactChannelType.phone);
    });
  });

  group('contactChannelsFrom — labels', () {
    test('prefers a user-defined label over the enum', () {
      final channels = contactChannelsFrom(
        _contact(
          phones: [
            _phone(
              '+15550109999',
              label: PhoneLabel.custom,
              custom: 'Weekend phone',
            ),
          ],
        ),
      );

      expect(channels.single.label, 'Weekend phone');
    });

    test('falls back to the enum name for a standard label', () {
      final channels = contactChannelsFrom(
        _contact(phones: [_phone('+493090182', label: PhoneLabel.home)]),
      );

      expect(channels.single.label, 'home');
    });

    test('stores no label for a custom label with no text behind it', () {
      final channels = contactChannelsFrom(
        _contact(phones: [_phone('+15550109999', label: PhoneLabel.custom)]),
      );

      expect(channels.single.label, isNull);
    });

    test('stores no label for "other", which says nothing worth showing', () {
      final channels = contactChannelsFrom(
        _contact(emails: [_email('anna@example.com', label: EmailLabel.other)]),
      );

      expect(channels.single.label, isNull);
    });

    test('trims a padded custom label', () {
      final channels = contactChannelsFrom(
        _contact(
          emails: [
            _email(
              'anna@example.com',
              label: EmailLabel.custom,
              custom: '  Newsletter  ',
            ),
          ],
        ),
      );

      expect(channels.single.label, 'Newsletter');
    });
  });

  group('contactChannelsFrom — content and ordering', () {
    test('maps every email to an email channel', () {
      final channels = contactChannelsFrom(
        _contact(emails: [_email('anna@example.com', label: EmailLabel.work)]),
      );

      expect(channels.single.type, ContactChannelType.email);
      expect(channels.single.value, 'anna@example.com');
      expect(channels.single.label, 'work');
    });

    test('puts phones before emails so the call action leads', () {
      final channels = contactChannelsFrom(
        _contact(
          phones: [_phone('+15550109999')],
          emails: [_email('anna@example.com')],
        ),
      );

      expect(
        channels.map((c) => c.type),
        [ContactChannelType.mobile, ContactChannelType.email],
      );
    });

    test('drops a blank number instead of importing an unusable channel', () {
      final channels = contactChannelsFrom(
        _contact(phones: [_phone('   '), _phone('+15550109999')]),
      );

      expect(channels.single.value, '+15550109999');
    });

    test('drops a blank email address', () {
      final channels = contactChannelsFrom(
        _contact(emails: [_email(''), _email('anna@example.com')]),
      );

      expect(channels.single.value, 'anna@example.com');
    });

    test('trims the values it keeps', () {
      final channels = contactChannelsFrom(
        _contact(phones: [_phone('  +15550109999  ')]),
      );

      expect(channels.single.value, '+15550109999');
    });

    test('collapses the same number stored twice by SIM and account sync', () {
      final channels = contactChannelsFrom(
        _contact(
          phones: [
            _phone('+15550109999', label: PhoneLabel.mobile),
            _phone('+1 (555) 010-9999', label: PhoneLabel.iPhone),
          ],
        ),
      );

      expect(
        channels,
        hasLength(1),
        reason: 'two identical call buttons is the symptom users report',
      );
      expect(channels.single.label, 'mobile', reason: 'the first one wins');
    });

    test('keeps a number that appears as both mobile and landline, since '
        'they offer different actions', () {
      final channels = contactChannelsFrom(
        _contact(
          phones: [
            _phone('+15550109999', label: PhoneLabel.mobile),
            _phone('+15550109999', label: PhoneLabel.home),
          ],
        ),
      );

      expect(channels, hasLength(2));
    });

    test('returns nothing for a contact with no phones or emails', () {
      expect(contactChannelsFrom(_contact()), isEmpty);
    });
  });

  group('importedContactsFrom', () {
    test('maps a list and drops the entries that cannot become a person', () {
      final imported = importedContactsFrom([
        _contact(id: 'a', displayName: 'Anna'),
        _contact(id: null, displayName: 'No id'),
        _contact(id: 'c', displayName: null),
        _contact(id: 'd', displayName: 'Dan'),
      ]);

      expect(imported.map((c) => c.displayName), ['Anna', 'Dan']);
    });

    test('preserves the order the OS returned', () {
      final imported = importedContactsFrom([
        _contact(id: 'c', displayName: 'Cara'),
        _contact(id: 'a', displayName: 'Anna'),
      ]);

      expect(imported.map((c) => c.id), ['c', 'a']);
    });

    test('returns nothing for an empty address book', () {
      expect(importedContactsFrom(const []), isEmpty);
    });

    test('carries channels through the list mapping', () {
      final imported = importedContactsFrom([
        _contact(phones: [_phone('+15550109999')]),
      ]);

      expect(imported.single.channels.single.value, '+15550109999');
    });
  });
}
