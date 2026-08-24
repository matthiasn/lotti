import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/relationships/model/imported_contact.dart';

ContactChannel _channel(
  ContactChannelType type,
  String value, {
  String? label,
}) => ContactChannel(type: type, value: value, label: label);

RelationshipStatus _activeStatus() => RelationshipStatus.active(
  id: 'status-id',
  createdAt: clock.now(),
  utcOffset: 0,
);

ImportedContact _contact({
  String id = 'os-1',
  String displayName = 'Anna Schmidt',
  List<ContactChannel> channels = const [],
}) => (id: id, displayName: displayName, channels: channels);

void main() {
  group('contactChannelIdentity', () {
    test('ignores the punctuation people write numbers with', () {
      expect(
        contactChannelIdentity(
          _channel(ContactChannelType.mobile, '+1 (555) 010-9999'),
        ),
        contactChannelIdentity(
          _channel(ContactChannelType.mobile, '+15550109999'),
        ),
      );
    });

    test('ignores case, so a differently capitalised address is the same '
        'address', () {
      expect(
        contactChannelIdentity(
          _channel(ContactChannelType.email, 'Anna@Example.COM'),
        ),
        contactChannelIdentity(
          _channel(ContactChannelType.email, 'anna@example.com'),
        ),
      );
    });

    test('keeps the same value under different types apart', () {
      expect(
        contactChannelIdentity(_channel(ContactChannelType.phone, '5550109')),
        isNot(
          contactChannelIdentity(
            _channel(ContactChannelType.mobile, '5550109'),
          ),
        ),
      );
    });

    test('ignores the label, which is decoration rather than identity', () {
      expect(
        contactChannelIdentity(
          _channel(ContactChannelType.mobile, '5550109', label: 'home'),
        ),
        contactChannelIdentity(
          _channel(ContactChannelType.mobile, '5550109', label: 'work'),
        ),
      );
    });

    test('keeps genuinely different numbers apart', () {
      expect(
        contactChannelIdentity(
          _channel(ContactChannelType.mobile, '+15550109999'),
        ),
        isNot(
          contactChannelIdentity(
            _channel(ContactChannelType.mobile, '+15550109998'),
          ),
        ),
      );
    });
  });

  group('mergeContactChannels', () {
    test('appends a channel the person did not already have', () {
      final merged = mergeContactChannels(
        existing: [_channel(ContactChannelType.mobile, '+15550109999')],
        incoming: [_channel(ContactChannelType.email, 'anna@example.com')],
      );

      expect(merged, hasLength(2));
      expect(merged.last.value, 'anna@example.com');
    });

    test('never discards a manually entered channel', () {
      final typedByHand = _channel(
        ContactChannelType.messaging,
        '@anna',
        label: 'Signal',
      );

      final merged = mergeContactChannels(
        existing: [typedByHand],
        incoming: [_channel(ContactChannelType.mobile, '+15550109999')],
      );

      expect(
        merged.first,
        typedByHand,
        reason:
            'linking a contact must not overwrite what the user typed — '
            'the address book may not hold the handle at all',
      );
    });

    test('keeps the existing rendering when the incoming one is the same '
        'number formatted differently', () {
      final merged = mergeContactChannels(
        existing: [
          _channel(ContactChannelType.mobile, '+15550109999', label: 'Anna'),
        ],
        incoming: [
          _channel(
            ContactChannelType.mobile,
            '+1 (555) 010-9999',
            label: 'mobile',
          ),
        ],
      );

      expect(merged, hasLength(1));
      expect(merged.single.value, '+15550109999');
      expect(
        merged.single.label,
        'Anna',
        reason: "the user's own label survives a re-link",
      );
    });

    test('preserves the existing order and appends after it', () {
      final merged = mergeContactChannels(
        existing: [
          _channel(ContactChannelType.email, 'anna@example.com'),
          _channel(ContactChannelType.mobile, '+15550109999'),
        ],
        incoming: [_channel(ContactChannelType.phone, '+493090182')],
      );

      expect(
        merged.map((c) => c.value),
        ['anna@example.com', '+15550109999', '+493090182'],
      );
    });

    test('de-duplicates within the incoming list itself', () {
      final merged = mergeContactChannels(
        existing: const [],
        incoming: [
          _channel(ContactChannelType.mobile, '+15550109999'),
          _channel(ContactChannelType.mobile, '+1 555 010 9999'),
        ],
      );

      expect(merged, hasLength(1));
    });

    test('returns the existing list unchanged when nothing new arrives', () {
      final existing = [_channel(ContactChannelType.mobile, '+15550109999')];

      expect(
        mergeContactChannels(existing: existing, incoming: const []),
        existing,
      );
    });

    test('returns the incoming list when the person had no channels', () {
      final merged = mergeContactChannels(
        existing: const [],
        incoming: [_channel(ContactChannelType.email, 'anna@example.com')],
      );

      expect(merged.single.value, 'anna@example.com');
    });
  });

  group('relationshipDataFromContact', () {
    test('carries the name and channels onto the new person', () {
      final data = relationshipDataFromContact(
        _contact(
          channels: [_channel(ContactChannelType.mobile, '+15550109999')],
        ),
        refKey: 'ios:host-a',
        status: _activeStatus(),
      );

      expect(data.title, 'Anna Schmidt');
      expect(data.contactChannels.single.value, '+15550109999');
    });

    test('records the OS id under the device key that owns it', () {
      final data = relationshipDataFromContact(
        _contact(id: 'ABC-123'),
        refKey: 'android:host-a',
        status: _activeStatus(),
      );

      expect(
        data.contactRefs,
        {'android:host-a': 'ABC-123'},
        reason:
            'the same person has different ids in every address book, so '
            'a ref is only meaningful on the device that wrote it',
      );
    });

    test('stores no ref at all when the device key is unknown', () {
      final data = relationshipDataFromContact(
        _contact(id: 'ABC-123'),
        refKey: null,
        status: _activeStatus(),
      );

      expect(
        data.contactRefs,
        isEmpty,
        reason:
            'an id parked under a made-up key could collide with a key '
            'another device legitimately owns',
      );
    });

    test('imports nobody as important by default, so no agent is created '
        'without being asked for', () {
      final data = relationshipDataFromContact(
        _contact(),
        refKey: 'ios:host-a',
        status: _activeStatus(),
      );

      expect(data.important, isFalse);
      expect(data.checkInCadenceDays, isNull);
    });

    test('honors the importance and cadence chosen on the review screen', () {
      final data = relationshipDataFromContact(
        _contact(),
        refKey: 'ios:host-a',
        status: _activeStatus(),
        important: true,
        checkInCadenceDays: 14,
      );

      expect(data.important, isTrue);
      expect(data.checkInCadenceDays, 14);
    });

    test('starts a person with no channels rather than refusing them', () {
      final data = relationshipDataFromContact(
        _contact(),
        refKey: 'ios:host-a',
        status: _activeStatus(),
      );

      expect(data.contactChannels, isEmpty);
      expect(data.title, isNotEmpty);
    });
  });
}
