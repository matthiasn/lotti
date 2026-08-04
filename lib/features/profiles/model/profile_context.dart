import 'dart:io';

import 'package:lotti/features/profiles/model/profile.dart';

/// What a world is allowed to do. Guest worlds structurally exclude
/// capabilities rather than disabling them: excluded stacks are never
/// constructed, so they cannot touch device-global state (keychain sync
/// credentials, health stores).
class ProfileCapabilities {
  const ProfileCapabilities({
    required this.syncEnabled,
    required this.healthImportEnabled,
  });

  /// The real world: everything on.
  static const ProfileCapabilities real = ProfileCapabilities(
    syncEnabled: true,
    healthImportEnabled: true,
  );

  /// Guest worlds: no sync stack (own host ID, zero outbox traffic, never
  /// reads Matrix credentials), no health import (device health data must
  /// not bleed into a play world).
  static const ProfileCapabilities guest = ProfileCapabilities(
    syncEnabled: false,
    healthImportEnabled: false,
  );

  final bool syncEnabled;
  final bool healthImportEnabled;
}

/// Immutable description of the world the current service generation runs
/// in. Registered in getIt by the bootstrap before any other service, so
/// registration and runtime code can consult it.
class ProfileContext {
  const ProfileContext({
    required this.profile,
    required this.root,
    required this.capabilities,
  });

  /// Builds the context for [profile] rooted at [root], with capabilities
  /// derived from the profile type.
  factory ProfileContext.forProfile({
    required Profile profile,
    required Directory root,
  }) => ProfileContext(
    profile: profile,
    root: root,
    capabilities: profile.isGuest
        ? ProfileCapabilities.guest
        : ProfileCapabilities.real,
  );

  final Profile profile;

  /// The profile's root directory — the same instance the bootstrap
  /// registers as the getIt `Directory` singleton.
  final Directory root;

  final ProfileCapabilities capabilities;

  bool get isGuest => profile.isGuest;
}
