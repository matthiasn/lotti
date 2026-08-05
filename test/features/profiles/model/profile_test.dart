import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/profiles/model/profile.dart';

void main() {
  final createdAt = DateTime(2026, 8, 5, 12);

  Profile guest({String id = 'g1'}) => Profile(
    id: id,
    type: ProfileType.guest,
    name: 'Demo',
    dirName: 'guest_profiles/$id',
    createdAt: createdAt,
    hostId: 'host-abc',
  );

  group('Profile', () {
    test('JSON round-trip preserves every field', () {
      final parsed = Profile.tryFromJson(guest().toJson());

      expect(parsed, isNotNull);
      expect(parsed!.id, 'g1');
      expect(parsed.type, ProfileType.guest);
      expect(parsed.name, 'Demo');
      expect(parsed.dirName, 'guest_profiles/g1');
      expect(parsed.createdAt, createdAt);
      expect(parsed.hostId, 'host-abc');
    });

    test('hostId is optional and omitted from JSON when null', () {
      final profile = Profile.realDefault();
      final json = profile.toJson();

      expect(json.containsKey('hostId'), isFalse);
      expect(Profile.tryFromJson(json)!.hostId, isNull);
    });

    test('tryFromJson rejects malformed entries instead of throwing', () {
      expect(Profile.tryFromJson(null), isNull);
      expect(Profile.tryFromJson('not a map'), isNull);
      expect(Profile.tryFromJson(<String, dynamic>{}), isNull);
      expect(
        Profile.tryFromJson(guest().toJson()..['type'] = 'alien'),
        isNull,
      );
      expect(
        Profile.tryFromJson(guest().toJson()..['createdAt'] = 'yesterday-ish'),
        isNull,
      );
      expect(
        Profile.tryFromJson(guest().toJson()..['id'] = ''),
        isNull,
      );
      expect(
        Profile.tryFromJson(guest().toJson()..['hostId'] = 42),
        isNull,
      );
      for (final dirName in [
        '../evil',
        '/absolute',
        'guest_profiles/../escape',
        'guest_profiles/.',
        r'guest_profiles\evil',
        'C:/evil',
      ]) {
        expect(
          Profile.tryFromJson(guest().toJson()..['dirName'] = dirName),
          isNull,
          reason: 'dirName "$dirName" must be rejected',
        );
      }
    });

    test('realDefault is the fixed real profile at the root itself', () {
      final now = DateTime(2026, 8, 5, 9, 30);
      final profile = withClock(
        Clock.fixed(now),
        Profile.realDefault,
      );

      expect(profile.id, Profile.realProfileId);
      expect(profile.type, ProfileType.real);
      expect(profile.dirName, isEmpty);
      expect(profile.isGuest, isFalse);
      expect(profile.createdAt, now);
    });

    test('copyWith without arguments retains hostId and name', () {
      final same = guest().copyWith();

      expect(same.hostId, 'host-abc');
      expect(same.name, 'Demo');
    });

    test('copyWith updates hostId without touching identity', () {
      final updated = guest().copyWith(hostId: 'host-new', name: 'Demo 2');

      expect(updated.id, 'g1');
      expect(updated.dirName, 'guest_profiles/g1');
      expect(updated.hostId, 'host-new');
      expect(updated.name, 'Demo 2');
    });
  });

  group('ProfileRegistryState', () {
    test('initial state is the active real profile only', () {
      final state = ProfileRegistryState.initial();

      expect(state.version, ProfileRegistryState.schemaVersion);
      expect(state.activeProfileId, Profile.realProfileId);
      expect(state.profiles, hasLength(1));
      expect(state.activeProfile.type, ProfileType.real);
    });

    test('JSON round-trip preserves profiles and active marker', () {
      final state = ProfileRegistryState(
        version: 1,
        activeProfileId: 'g1',
        profiles: [Profile.realDefault(), guest()],
      );

      final parsed = ProfileRegistryState.tryFromJson(state.toJson());

      expect(parsed, isNotNull);
      expect(parsed!.activeProfileId, 'g1');
      expect(parsed.profiles.map((profile) => profile.id), ['real', 'g1']);
      expect(parsed.activeProfile.id, 'g1');
    });

    test('malformed profile entries are dropped, not fatal', () {
      final json = ProfileRegistryState(
        version: 1,
        activeProfileId: Profile.realProfileId,
        profiles: [Profile.realDefault(), guest()],
      ).toJson();
      (json['profiles'] as List).insert(1, {'garbage': true});

      final parsed = ProfileRegistryState.tryFromJson(json);

      expect(parsed, isNotNull);
      expect(parsed!.profiles.map((profile) => profile.id), ['real', 'g1']);
    });

    test('a registry without a real profile is unusable', () {
      final json = ProfileRegistryState(
        version: 1,
        activeProfileId: 'g1',
        profiles: [guest()],
      ).toJson();

      expect(ProfileRegistryState.tryFromJson(json), isNull);
    });

    test('a state with no real profile still yields a synthesized active '
        'profile', () {
      final state = ProfileRegistryState(
        version: 1,
        activeProfileId: 'gone',
        profiles: [guest()],
      );

      expect(state.activeProfile.id, Profile.realProfileId);
      expect(state.activeProfile.type, ProfileType.real);
    });

    test('dangling active marker falls back to the real profile', () {
      final state = ProfileRegistryState(
        version: 1,
        activeProfileId: 'deleted-guest',
        profiles: [Profile.realDefault()],
      );

      expect(state.activeProfile.id, Profile.realProfileId);
    });

    test('tryFromJson rejects structurally unusable documents', () {
      expect(ProfileRegistryState.tryFromJson(null), isNull);
      expect(ProfileRegistryState.tryFromJson([]), isNull);
      expect(
        ProfileRegistryState.tryFromJson({
          'version': 'one',
          'activeProfileId': 'real',
          'profiles': <Object>[],
        }),
        isNull,
      );
    });
  });
}
