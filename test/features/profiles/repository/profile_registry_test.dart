import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/profiles/model/profile.dart';
import 'package:lotti/features/profiles/profile_paths.dart';
import 'package:lotti/features/profiles/repository/profile_registry.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory realRoot;
  late ProfileRegistry registry;

  setUp(() {
    realRoot = Directory.systemTemp.createTempSync('lotti_profile_registry_');
    registry = ProfileRegistry(realRoot: realRoot);
  });

  tearDown(() async {
    if (realRoot.existsSync()) {
      await realRoot.delete(recursive: true);
    }
  });

  group('load', () {
    test('missing file yields default registry without writing it', () async {
      final state = await registry.load();

      expect(state.activeProfileId, Profile.realProfileId);
      expect(state.profiles.single.type, ProfileType.real);
      expect(registry.registryFile.existsSync(), isFalse);
    });

    test('corrupt file falls back to default registry', () async {
      registry.registryFile.writeAsStringSync('{"version": "not json-y}');

      final state = await registry.load();

      expect(state.activeProfileId, Profile.realProfileId);
      expect(state.profiles.single.type, ProfileType.real);
    });

    test('registry without a real profile falls back to default', () async {
      registry.registryFile.writeAsStringSync(
        jsonEncode({
          'version': 1,
          'activeProfileId': 'g1',
          'profiles': <Object>[],
        }),
      );

      final state = await registry.load();

      expect(state.activeProfileId, Profile.realProfileId);
    });
  });

  group('path traversal defense', () {
    test('rootFor refuses a dirName that escapes the real root', () {
      final doctored = Profile(
        id: 'evil',
        type: ProfileType.guest,
        name: 'evil',
        dirName: 'guest_profiles/../../elsewhere',
        createdAt: DateTime(2026),
      );

      expect(() => registry.rootFor(doctored), throwsArgumentError);
    });

    test('a doctored profiles.json entry is dropped at parse time', () async {
      final guest = await registry.createGuestProfile(name: 'Demo');
      final raw =
          jsonDecode(await registry.registryFile.readAsString())
              as Map<String, dynamic>;
      ((raw['profiles'] as List).last as Map<String, dynamic>)['dirName'] =
          '../../outside/${guest.id}';
      registry.registryFile.writeAsStringSync(jsonEncode(raw));

      final state = await registry.load();

      expect(state.profileById(guest.id), isNull);
    });
  });

  group('createGuestProfile', () {
    test('persists the entry and creates the directory skeleton', () async {
      final profile = await registry.createGuestProfile(name: 'Demo');

      expect(profile.isGuest, isTrue);
      expect(profile.dirName, 'guest_profiles/${profile.id}');
      expect(
        guestProfileRoot(realRoot, profile.id).existsSync(),
        isTrue,
      );

      final reloaded = await registry.load();
      expect(reloaded.profileById(profile.id)!.name, 'Demo');
      // Creation must not silently activate the new world.
      expect(reloaded.activeProfileId, Profile.realProfileId);
    });

    test('rootFor resolves the guest world under guest_profiles', () async {
      final profile = await registry.createGuestProfile(name: 'Demo');

      expect(
        registry.rootFor(profile).path,
        p.join(realRoot.path, guestProfilesDirName, profile.id),
      );
      expect(
        registry.rootFor(Profile.realDefault()).path,
        realRoot.path,
      );
    });
  });

  group('setActiveProfile', () {
    test('round-trips through the persisted marker', () async {
      final profile = await registry.createGuestProfile(name: 'Demo');

      await registry.setActiveProfile(profile.id);
      expect((await registry.load()).activeProfileId, profile.id);

      await registry.setActiveProfile(Profile.realProfileId);
      expect((await registry.load()).activeProfileId, Profile.realProfileId);
    });

    test('rejects unknown profiles', () async {
      await expectLater(
        registry.setActiveProfile('nope'),
        throwsArgumentError,
      );
    });
  });

  group('updateProfile', () {
    test('rejects unknown profiles', () async {
      await expectLater(
        registry.updateProfile(
          Profile(
            id: 'nope',
            type: ProfileType.guest,
            name: 'ghost',
            dirName: 'guest_profiles/nope',
            createdAt: DateTime(2026),
          ),
        ),
        throwsArgumentError,
      );
    });

    test('persists hostId written after first world boot', () async {
      final profile = await registry.createGuestProfile(name: 'Demo');

      await registry.updateProfile(profile.copyWith(hostId: 'host-1'));

      expect(
        (await registry.load()).profileById(profile.id)!.hostId,
        'host-1',
      );
    });
  });

  group('deleteGuestProfile', () {
    test('rejects unknown ids', () async {
      await expectLater(
        registry.deleteGuestProfile('nope'),
        throwsArgumentError,
      );
    });

    test('removes the entry and the directory tree', () async {
      final profile = await registry.createGuestProfile(name: 'Demo');
      final guestRoot = registry.rootFor(profile);
      File(p.join(guestRoot.path, 'db.sqlite')).writeAsStringSync('x');

      await registry.deleteGuestProfile(profile.id);

      expect(guestRoot.existsSync(), isFalse);
      expect((await registry.load()).profileById(profile.id), isNull);
      // The real root and registry survive.
      expect(realRoot.existsSync(), isTrue);
    });

    test('refuses to delete the real profile', () async {
      await expectLater(
        registry.deleteGuestProfile(Profile.realProfileId),
        throwsArgumentError,
      );
    });

    test('refuses to delete the active profile', () async {
      final profile = await registry.createGuestProfile(name: 'Demo');
      await registry.setActiveProfile(profile.id);

      await expectLater(
        registry.deleteGuestProfile(profile.id),
        throwsStateError,
      );
      expect(registry.rootFor(profile).existsSync(), isTrue);
    });
  });
}
