import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/relationships/util/contact_channel_uri.dart';

ContactChannel _channel(ContactChannelType type, String value) =>
    ContactChannel(type: type, value: value);

void main() {
  group('schemeForContactAction', () {
    test('maps each action to the scheme its platform declaration covers', () {
      expect(schemeForContactAction(ContactAction.call), 'tel');
      expect(schemeForContactAction(ContactAction.message), 'sms');
      expect(schemeForContactAction(ContactAction.email), 'mailto');
    });

    test('assigns a distinct scheme to every action', () {
      final schemes = ContactAction.values.map(schemeForContactAction).toSet();

      expect(
        schemes,
        hasLength(ContactAction.values.length),
        reason:
            'two actions sharing a scheme would make the manifest '
            'cross-check pass while one action stayed undeclared',
      );
    });
  });

  group('contactActionsFor', () {
    test('offers a landline the dialer but not a message composer', () {
      expect(
        contactActionsFor(ContactChannelType.phone),
        {ContactAction.call},
      );
    });

    test('offers a mobile number both call and message', () {
      expect(
        contactActionsFor(ContactChannelType.mobile),
        {ContactAction.call, ContactAction.message},
      );
    });

    test('offers an email address only the mail composer', () {
      expect(
        contactActionsFor(ContactChannelType.email),
        {ContactAction.email},
      );
    });

    test('offers a messaging handle nothing — no scheme can address it', () {
      expect(contactActionsFor(ContactChannelType.messaging), isEmpty);
    });

    test('answers for every channel type, so a new type cannot fall '
        'through untriaged', () {
      for (final type in ContactChannelType.values) {
        expect(
          () => contactActionsFor(type),
          returnsNormally,
          reason: 'no mapping for $type',
        );
      }
    });
  });

  group('contactChannelUri — action/type mismatches yield no URI', () {
    test('refuses to email a phone number', () {
      expect(
        contactChannelUri(
          _channel(ContactChannelType.mobile, '+15550109999'),
          ContactAction.email,
        ),
        isNull,
      );
    });

    test('refuses to message a landline', () {
      expect(
        contactChannelUri(
          _channel(ContactChannelType.phone, '+15550109999'),
          ContactAction.message,
        ),
        isNull,
      );
    });

    test('refuses to call an email address', () {
      expect(
        contactChannelUri(
          _channel(ContactChannelType.email, 'anna@example.com'),
          ContactAction.call,
        ),
        isNull,
      );
    });

    test('yields nothing for a messaging handle under any action', () {
      final handle = _channel(ContactChannelType.messaging, '@anna');

      for (final action in ContactAction.values) {
        expect(
          contactChannelUri(handle, action),
          isNull,
          reason: 'messaging handle produced a URI for $action',
        );
      }
    });
  });

  group('contactChannelUri — unusable values yield no URI', () {
    test('rejects an empty value', () {
      expect(
        contactChannelUri(
          _channel(ContactChannelType.mobile, ''),
          ContactAction.call,
        ),
        isNull,
      );
    });

    test('rejects a whitespace-only value rather than dialing nothing', () {
      expect(
        contactChannelUri(
          _channel(ContactChannelType.mobile, '   \t '),
          ContactAction.call,
        ),
        isNull,
      );
    });

    test('rejects a phone value holding no digits at all', () {
      expect(
        contactChannelUri(
          _channel(ContactChannelType.phone, 'ask Bob'),
          ContactAction.call,
        ),
        isNull,
        reason: 'a note typed into the number field must not become tel:',
      );
    });

    test('rejects punctuation that strips down to an empty number', () {
      expect(
        contactChannelUri(
          _channel(ContactChannelType.mobile, '+ () - .'),
          ContactAction.call,
        ),
        isNull,
      );
    });
  });

  group('contactChannelUri — telephony formatting', () {
    test('strips the punctuation people write numbers with', () {
      final uri = contactChannelUri(
        _channel(ContactChannelType.mobile, '+1 (555) 010-9999'),
        ContactAction.call,
      );

      expect(uri.toString(), 'tel:+15550109999');
    });

    test('preserves a leading + as the country prefix', () {
      final uri = contactChannelUri(
        _channel(ContactChannelType.phone, '+49 30 901820'),
        ContactAction.call,
      );

      expect(uri.toString(), 'tel:+4930901820');
    });

    test('emits a national number without inventing a prefix', () {
      final uri = contactChannelUri(
        _channel(ContactChannelType.phone, '030 901820'),
        ContactAction.call,
      );

      expect(uri.toString(), 'tel:030901820');
    });

    test('drops a + that is not the country prefix instead of dialing it', () {
      final uri = contactChannelUri(
        _channel(ContactChannelType.mobile, '555+010+9999'),
        ContactAction.call,
      );

      expect(uri.toString(), 'tel:5550109999');
    });

    test('keeps only the first + when the value is doubly prefixed', () {
      final uri = contactChannelUri(
        _channel(ContactChannelType.mobile, '++15550109999'),
        ContactAction.call,
      );

      expect(uri.toString(), 'tel:+15550109999');
    });

    test('trims surrounding whitespace before dialing', () {
      final uri = contactChannelUri(
        _channel(ContactChannelType.mobile, '  +15550109999  '),
        ContactAction.call,
      );

      expect(uri.toString(), 'tel:+15550109999');
    });

    test('messaging a mobile uses the sms scheme with the same number', () {
      final uri = contactChannelUri(
        _channel(ContactChannelType.mobile, '+1 (555) 010-9999'),
        ContactAction.message,
      );

      expect(uri.toString(), 'sms:+15550109999');
    });
  });

  group('contactChannelUri — email addressing', () {
    test('emits a mailto URI with the address unescaped', () {
      final uri = contactChannelUri(
        _channel(ContactChannelType.email, 'anna@example.com'),
        ContactAction.email,
      );

      expect(uri.toString(), 'mailto:anna@example.com');
      expect(
        uri.toString(),
        isNot(contains('%40')),
        reason:
            'an escaped @ reaches some mail clients as a malformed '
            'recipient',
      );
    });

    test('accepts the plus-addressing and dots real addresses carry', () {
      final uri = contactChannelUri(
        _channel(ContactChannelType.email, 'anna.k+lotti@mail.example.co.uk'),
        ContactAction.email,
      );

      expect(uri.toString(), 'mailto:anna.k+lotti@mail.example.co.uk');
    });

    test('trims whitespace pasted in with the address', () {
      final uri = contactChannelUri(
        _channel(ContactChannelType.email, '  anna@example.com '),
        ContactAction.email,
      );

      expect(uri.toString(), 'mailto:anna@example.com');
    });

    test('percent-encodes a non-ASCII address rather than emitting raw '
        'bytes', () {
      final uri = contactChannelUri(
        _channel(ContactChannelType.email, 'anna@münchen.example'),
        ContactAction.email,
      );

      expect(uri.toString(), 'mailto:anna@m%C3%BCnchen.example');
    });

    test('rejects an address with no @ so no empty composer opens', () {
      expect(
        contactChannelUri(
          _channel(ContactChannelType.email, 'anna.example.com'),
          ContactAction.email,
        ),
        isNull,
      );
    });

    test('rejects an address with no domain dot', () {
      expect(
        contactChannelUri(
          _channel(ContactChannelType.email, 'anna@localhost'),
          ContactAction.email,
        ),
        isNull,
      );
    });

    test('rejects an address missing its local part', () {
      expect(
        contactChannelUri(
          _channel(ContactChannelType.email, '@example.com'),
          ContactAction.email,
        ),
        isNull,
      );
    });

    test('rejects an address carrying interior whitespace', () {
      expect(
        contactChannelUri(
          _channel(ContactChannelType.email, 'anna k@example.com'),
          ContactAction.email,
        ),
        isNull,
      );
    });

    test('rejects a doubled @ that would address the wrong host', () {
      expect(
        contactChannelUri(
          _channel(ContactChannelType.email, 'anna@@example.com'),
          ContactAction.email,
        ),
        isNull,
      );
    });
  });

  group('contactChannelUri — every offered action produces a launchable '
      'URI', () {
    /// A representative, valid value per channel type. The invariant under
    /// test is the one the UI relies on: if [contactActionsFor] offers a
    /// button, pressing it must have somewhere to go.
    const values = {
      ContactChannelType.phone: '+15550109999',
      ContactChannelType.mobile: '+15550109999',
      ContactChannelType.email: 'anna@example.com',
      ContactChannelType.messaging: '@anna',
    };

    for (final type in ContactChannelType.values) {
      test('$type', () {
        final channel = _channel(type, values[type]!);

        for (final action in ContactAction.values) {
          final uri = contactChannelUri(channel, action);

          if (contactActionsFor(type).contains(action)) {
            expect(
              uri,
              isNotNull,
              reason: '$type offers $action but produced no URI',
            );
            expect(uri!.scheme, schemeForContactAction(action));
          } else {
            expect(
              uri,
              isNull,
              reason: '$type does not offer $action but produced $uri',
            );
          }
        }
      });
    }
  });
}
