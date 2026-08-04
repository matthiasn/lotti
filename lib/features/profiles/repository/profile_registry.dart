import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:lotti/features/profiles/model/profile.dart';
import 'package:lotti/features/profiles/profile_paths.dart';
import 'package:lotti/features/sync/matrix/utils/atomic_write.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

/// Owns `profiles.json` at the real root.
///
/// Deliberately NOT registered in getIt: getIt is reset on every profile
/// switch, while the registry describes all worlds and must survive
/// generations. It is constructed with the real root explicitly and never
/// resolves paths through the active profile.
class ProfileRegistry {
  ProfileRegistry({required this.realRoot, this.logging});

  final Directory realRoot;
  final DomainLogger? logging;

  static const Uuid _uuid = Uuid();

  File get registryFile =>
      File(p.join(realRoot.path, profilesRegistryFileName));

  /// Pure read. A missing or corrupt file yields the synthesized default
  /// (real profile, active) without persisting anything — the file is only
  /// ever written by mutations.
  Future<ProfileRegistryState> load() async {
    try {
      if (!registryFile.existsSync()) {
        return ProfileRegistryState.initial();
      }
      final raw = await registryFile.readAsString();
      final state = ProfileRegistryState.tryFromJson(jsonDecode(raw));
      if (state == null) {
        logging?.log(
          LogDomain.general,
          'profiles.json unusable, falling back to default registry',
          subDomain: 'profileRegistry',
        );
        return ProfileRegistryState.initial();
      }
      return state;
    } catch (e, st) {
      logging?.error(
        LogDomain.general,
        e,
        stackTrace: st,
        subDomain: 'profileRegistry.load',
      );
      return ProfileRegistryState.initial();
    }
  }

  /// Creates the registry entry and directory skeleton for a new guest
  /// world. The world's databases are created lazily by whoever opens it.
  Future<Profile> createGuestProfile({required String name}) async {
    final state = await load();
    final id = _uuid.v4();
    final profile = Profile(
      id: id,
      type: ProfileType.guest,
      name: name,
      dirName: '$guestProfilesDirName/$id',
      createdAt: clock.now(),
    );
    await guestProfileRoot(realRoot, id).create(recursive: true);
    await _save(
      state.copyWith(profiles: [...state.profiles, profile]),
    );
    return profile;
  }

  /// Persists the active-world marker. Written BEFORE a switch begins so a
  /// crash mid-switch reopens the intended world on next launch.
  Future<void> setActiveProfile(String id) async {
    final state = await load();
    if (state.profileById(id) == null) {
      throw ArgumentError.value(id, 'id', 'unknown profile');
    }
    await _save(state.copyWith(activeProfileId: id));
  }

  /// Updates mutable fields (name, informational hostId) of a profile.
  Future<void> updateProfile(Profile profile) async {
    final state = await load();
    if (state.profileById(profile.id) == null) {
      throw ArgumentError.value(profile.id, 'profile', 'unknown profile');
    }
    await _save(
      state.copyWith(
        profiles: [
          for (final existing in state.profiles)
            if (existing.id == profile.id) profile else existing,
        ],
      ),
    );
  }

  /// Removes a guest world: registry entry and its whole directory tree.
  /// Refuses to delete the real profile or the currently active profile.
  Future<void> deleteGuestProfile(String id) async {
    final state = await load();
    final profile = state.profileById(id);
    if (profile == null) {
      throw ArgumentError.value(id, 'id', 'unknown profile');
    }
    if (!profile.isGuest) {
      throw ArgumentError.value(id, 'id', 'only guest profiles can be deleted');
    }
    if (state.activeProfileId == id) {
      throw StateError('cannot delete the active profile');
    }
    final root = rootFor(profile);
    assertIsGuestRoot(root);
    if (root.existsSync()) {
      await root.delete(recursive: true);
    }
    await _save(
      state.copyWith(
        profiles: [
          for (final existing in state.profiles)
            if (existing.id != id) existing,
        ],
      ),
    );
  }

  /// Resolves a profile's root directory. The stored [Profile.dirName] uses
  /// `/` separators; joining per segment keeps this platform-independent.
  Directory rootFor(Profile profile) {
    if (profile.dirName.isEmpty) return realRoot;
    return Directory(
      p.joinAll([realRoot.path, ...profile.dirName.split('/')]),
    );
  }

  Future<void> _save(ProfileRegistryState state) async {
    await atomicWriteString(
      text: const JsonEncoder.withIndent('  ').convert(state.toJson()),
      filePath: registryFile.path,
      logging: logging,
      subDomain: 'profileRegistry',
    );
  }
}
