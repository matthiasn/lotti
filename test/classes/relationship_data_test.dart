import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
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
        avatarImageId: 'image-avatar',
        avatarCrop: const AvatarCrop(x: 0.32, y: 0.18, scale: 2.4),
        bannerImageId: 'image-banner',
        bannerCropX: 0.25,
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
      expect(restored.avatarImageId, 'image-avatar');
      expect(
        restored.avatarCrop,
        const AvatarCrop(x: 0.32, y: 0.18, scale: 2.4),
      );
      expect(restored.bannerImageId, 'image-banner');
      expect(restored.bannerCropX, 0.25);
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
      expect(data.avatarImageId, isNull);
      expect(
        data.avatarCrop,
        isNull,
        reason: 'null framing means "the default", not a stored centre',
      );
      expect(data.bannerImageId, isNull);
      expect(
        data.bannerCropX,
        0.5,
        reason: 'a banner with no chosen framing is centred',
      );
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

  group('avatarCrop in JSON', () {
    final base = RelationshipData(
      title: 'Anna',
      status: RelationshipStatus.active(
        id: 'status-1',
        createdAt: testDate,
        utcOffset: 0,
      ),
    );

    test(
      'a framing that is not a map at all reads as no framing rather than '
      'throwing — the container half of the guard each field carries',
      () {
        for (final raw in <Object>[
          'garbage',
          42,
          true,
          <double>[0.1, 0.2],
        ]) {
          final json = jsonDecode(jsonEncode(base)) as Map<String, dynamic>
            ..['avatarCrop'] = raw;
          expect(
            RelationshipData.fromJson(json).avatarCrop,
            isNull,
            reason: '$raw is not a framing',
          );
        }
      },
    );

    test('a map is parsed, its fields still guarded', () {
      final json = jsonDecode(jsonEncode(base)) as Map<String, dynamic>
        ..['avatarCrop'] = {'x': 0.1, 'y': 7, 'scale': 'wide'};
      expect(
        RelationshipData.fromJson(json).avatarCrop,
        // The default zoom is exactly what a non-number reads as; spelled
        // out so the guard is what this line asserts.
        // ignore: avoid_redundant_argument_values
        const AvatarCrop(x: 0.1, y: 1, scale: 1),
      );
    });

    test('absent stays null', () {
      final json = jsonDecode(jsonEncode(base)) as Map<String, dynamic>
        ..remove('avatarCrop');
      expect(RelationshipData.fromJson(json).avatarCrop, isNull);
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

  group('AvatarCrop', () {
    test('defaults frame the centre of the image at the widest zoom', () {
      const crop = AvatarCrop();
      expect(crop.x, 0.5);
      expect(crop.y, 0.5);
      expect(
        crop.scale,
        minAvatarCropScale,
        reason: 'the widest zoom is the one that exactly covers the circle',
      );
    });

    test('round-trips through JSON', () {
      const crop = AvatarCrop(x: 0.21, y: 0.87, scale: 3.5);
      expect(
        AvatarCrop.fromJson(
          jsonDecode(jsonEncode(crop)) as Map<String, dynamic>,
        ),
        crop,
      );
    });

    test('a crop that arrives out of range is read back inside it — a peer '
        'cannot make this device render an empty circle', () {
      final crop = AvatarCrop.fromJson(const {
        'x': -4.0,
        'y': 9.0,
        'scale': 250.0,
      });
      expect(crop.x, 0);
      expect(crop.y, 1);
      expect(crop.scale, maxAvatarCropScale);
    });

    test('NaN reads as the default framing rather than propagating', () {
      final crop = AvatarCrop.fromJson(const {
        'x': double.nan,
        'y': double.nan,
        'scale': double.nan,
      });
      expect(crop, const AvatarCrop());
    });

    test('a value that is not a number reads as the default rather than '
        'throwing — the guard the banner axis has, so a malformed framing '
        'cannot stop a person loading', () {
      final crop = AvatarCrop.fromJson(const {
        'x': 'left',
        'y': <String, Object?>{'fraction': 0.2},
        'scale': 'big',
      });
      expect(crop, const AvatarCrop());
    });

    test('a field that is missing reads as its default', () {
      expect(AvatarCrop.fromJson(const {'x': 0.1}), const AvatarCrop(x: 0.1));
    });

    glados.Glados3(
      glados.any.double,
      glados.any.double,
      glados.any.double,
      glados.ExploreConfig(numRuns: 300),
    ).test('clamped always lands inside the ranges the crop surface offers', (
      x,
      y,
      scale,
    ) {
      final clamped = AvatarCrop(x: x, y: y, scale: scale).clamped;
      expect(clamped.x, inInclusiveRange(0, 1));
      expect(clamped.y, inInclusiveRange(0, 1));
      expect(
        clamped.scale,
        inInclusiveRange(minAvatarCropScale, maxAvatarCropScale),
      );
    }, tags: 'glados');

    glados.Glados(
      glados.any.double,
      glados.ExploreConfig(numRuns: 300),
    ).test('clamped is idempotent: framing already in range is left alone', (
      value,
    ) {
      final once = AvatarCrop(x: value, y: value, scale: value).clamped;
      expect(once.clamped, once);
    }, tags: 'glados');
  });

  group('cropFractionFromJson', () {
    test('reads an int as well as a double — JSON does not distinguish', () {
      expect(cropFractionFromJson(1), 1.0);
      expect(cropFractionFromJson(0.25), 0.25);
    });

    test('anything that is not a number reads as centred, so a malformed '
        'framing cannot stop a person loading', () {
      expect(cropFractionFromJson(null), 0.5);
      expect(cropFractionFromJson('left'), 0.5);
      expect(cropFractionFromJson(const {'x': 1}), 0.5);
    });

    glados.Glados(
      glados.any.double,
      glados.ExploreConfig(numRuns: 300),
    ).test('always lands in 0…1', (value) {
      expect(cropFractionFromJson(value), inInclusiveRange(0, 1));
    }, tags: 'glados');
  });

  group('cropScaleFromJson', () {
    test('reads an int as well as a double, clamped to the range the crop '
        'surface offers', () {
      expect(cropScaleFromJson(2), 2.0);
      expect(cropScaleFromJson(1.5), 1.5);
      expect(cropScaleFromJson(0.1), minAvatarCropScale);
      expect(cropScaleFromJson(99), maxAvatarCropScale);
    });

    test('anything that is not a number reads as the smallest zoom', () {
      expect(cropScaleFromJson(null), minAvatarCropScale);
      expect(cropScaleFromJson('big'), minAvatarCropScale);
      expect(cropScaleFromJson(double.nan), minAvatarCropScale);
    });

    glados.Glados(
      glados.any.double,
      glados.ExploreConfig(numRuns: 300),
    ).test('always lands in the range the crop surface offers', (value) {
      expect(
        cropScaleFromJson(value),
        inInclusiveRange(minAvatarCropScale, maxAvatarCropScale),
      );
    }, tags: 'glados');
  });

  group('RelationshipImageFraming', () {
    RelationshipData dataWith({AvatarCrop? avatarCrop, double? bannerCropX}) =>
        RelationshipData(
          title: 'Anna',
          status: RelationshipStatus.active(
            id: 'status-1',
            createdAt: testDate,
            utcOffset: 0,
          ),
          avatarCrop: avatarCrop,
          bannerCropX: bannerCropX ?? 0.5,
        );

    test('clamps both framings on the way to storage', () {
      final clamped = dataWith(
        avatarCrop: const AvatarCrop(x: -1, y: 2, scale: 99),
        bannerCropX: 7,
      ).withClampedImageFraming;

      expect(clamped.avatarCrop, const AvatarCrop(x: 0, y: 1, scale: 4));
      expect(clamped.bannerCropX, 1);
    });

    test('leaves a person with no avatar crop without one', () {
      final clamped = dataWith().withClampedImageFraming;
      expect(
        clamped.avatarCrop,
        isNull,
        reason:
            'clamping must not invent a stored framing for a person who '
            'has never chosen one',
      );
    });

    test('changes nothing else about the person', () {
      final original = dataWith(
        avatarCrop: const AvatarCrop(x: 0.2, y: 0.3, scale: 2),
        bannerCropX: 0.4,
      ).copyWith(nickname: 'Sis', important: true, checkInCadenceDays: 7);
      expect(original.withClampedImageFraming, original);
    });
  });
}
