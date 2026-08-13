import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/relationship_data.dart';

void main() {
  final testDate = DateTime(2026, 8, 13, 10, 30);

  group('RelationshipData', () {
    test('round-trip JSON serialization preserves all fields', () {
      final status = RelationshipStatus.active(
        id: 'status-1',
        createdAt: testDate,
        utcOffset: 60,
        timezone: 'Europe/Berlin',
      );

      final data = RelationshipData(
        title: 'Anna Example',
        status: status,
        nickname: 'Sis',
        important: true,
        statusHistory: [
          RelationshipStatus.dormant(
            id: 'status-0',
            createdAt: DateTime(2026, 8),
            utcOffset: 60,
          ),
          status,
        ],
        checkInCadenceDays: 14,
        birthday: DateTime(1990, 4, 21),
        profileId: 'profile-123',
        languageCode: 'de',
        coverArtId: 'image-abc',
        contactChannels: const [
          ContactChannel(
            type: ContactChannelType.mobile,
            value: '+49123456789',
            label: 'personal',
          ),
          ContactChannel(
            type: ContactChannelType.email,
            value: 'anna@example.com',
          ),
        ],
        contactRefs: const {'ios': 'contact-ref-1'},
      );

      final json = jsonDecode(jsonEncode(data)) as Map<String, dynamic>;
      final restored = RelationshipData.fromJson(json);

      expect(restored, data);
      expect(restored.status, isA<RelationshipActive>());
      expect(restored.statusHistory, hasLength(2));
      expect(restored.statusHistory.first, isA<RelationshipDormant>());
      expect(restored.contactChannels, hasLength(2));
      expect(restored.contactChannels.first.type, ContactChannelType.mobile);
      expect(restored.contactRefs, {'ios': 'contact-ref-1'});
      expect(restored.checkInCadenceDays, 14);
      expect(restored.birthday, DateTime(1990, 4, 21));
    });

    test('defaults are applied correctly', () {
      final data = RelationshipData(
        title: 'Minimal Person',
        status: RelationshipStatus.active(
          id: 'status-1',
          createdAt: testDate,
          utcOffset: 0,
        ),
      );

      expect(data.nickname, isNull);
      expect(data.important, isFalse);
      expect(data.statusHistory, isEmpty);
      expect(data.checkInCadenceDays, isNull);
      expect(data.birthday, isNull);
      expect(data.profileId, isNull);
      expect(data.languageCode, isNull);
      expect(data.coverArtId, isNull);
      expect(data.contactChannels, isEmpty);
      expect(data.contactRefs, isEmpty);
    });

    test('copyWith updates fields correctly', () {
      final data = RelationshipData(
        title: 'Original',
        status: RelationshipStatus.active(
          id: 'status-1',
          createdAt: testDate,
          utcOffset: 0,
        ),
      );

      final updated = data.copyWith(
        title: 'Renamed',
        important: true,
        checkInCadenceDays: 30,
      );

      expect(updated.title, 'Renamed');
      expect(updated.important, isTrue);
      expect(updated.checkInCadenceDays, 30);
      expect(updated.status, data.status);
    });
  });

  group('RelationshipStatus', () {
    test('all variants serialize and deserialize', () {
      final variants = <RelationshipStatus>[
        RelationshipStatus.active(
          id: 'rs-1',
          createdAt: testDate,
          utcOffset: 60,
        ),
        RelationshipStatus.dormant(
          id: 'rs-2',
          createdAt: testDate,
          utcOffset: 60,
          timezone: 'Europe/Berlin',
        ),
        RelationshipStatus.archived(
          id: 'rs-3',
          createdAt: testDate,
          utcOffset: -300,
        ),
      ];

      for (final variant in variants) {
        final json = jsonDecode(jsonEncode(variant)) as Map<String, dynamic>;
        final restored = RelationshipStatus.fromJson(json);
        expect(restored, variant);
      }
    });

    test('toDbString returns correct strings', () {
      expect(
        RelationshipStatus.active(
          id: 'rs-1',
          createdAt: testDate,
          utcOffset: 0,
        ).toDbString,
        'ACTIVE',
      );
      expect(
        RelationshipStatus.dormant(
          id: 'rs-2',
          createdAt: testDate,
          utcOffset: 0,
        ).toDbString,
        'DORMANT',
      );
      expect(
        RelationshipStatus.archived(
          id: 'rs-3',
          createdAt: testDate,
          utcOffset: 0,
        ).toDbString,
        'ARCHIVED',
      );
    });

    test('label returns human-readable labels', () {
      expect(
        RelationshipStatus.active(
          id: 'rs-1',
          createdAt: testDate,
          utcOffset: 0,
        ).label,
        'Active',
      );
      expect(
        RelationshipStatus.dormant(
          id: 'rs-2',
          createdAt: testDate,
          utcOffset: 0,
        ).label,
        'Dormant',
      );
      expect(
        RelationshipStatus.archived(
          id: 'rs-3',
          createdAt: testDate,
          utcOffset: 0,
        ).label,
        'Archived',
      );
    });
  });

  group('ContactChannel', () {
    test('all channel types round-trip through JSON', () {
      for (final type in ContactChannelType.values) {
        final channel = ContactChannel(
          type: type,
          value: 'value-for-${type.name}',
          label: type == ContactChannelType.phone ? 'work' : null,
        );
        final json = jsonDecode(jsonEncode(channel)) as Map<String, dynamic>;
        final restored = ContactChannel.fromJson(json);
        expect(restored, channel, reason: type.name);
      }
    });
  });
}
