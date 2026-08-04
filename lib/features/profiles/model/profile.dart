import 'package:clock/clock.dart';

/// The kind of world a profile describes.
enum ProfileType {
  /// The user's real data at the pre-existing documents root.
  real,

  /// An isolated guest/demo world under `guest_profiles/<id>/`.
  guest,
}

/// One entry in the profile registry (`profiles.json`).
///
/// Deliberately hand-rolled (no freezed): registry parsing must degrade
/// gracefully on malformed input — [tryFromJson] returns null instead of
/// throwing, so a corrupt file collapses to the synthesized default registry
/// rather than blocking boot.
class Profile {
  const Profile({
    required this.id,
    required this.type,
    required this.name,
    required this.dirName,
    required this.createdAt,
    this.hostId,
  });

  /// Synthesized registry entry for the pre-existing real world. Used when
  /// no `profiles.json` exists yet (every install predating profiles).
  factory Profile.realDefault() => Profile(
    id: realProfileId,
    type: ProfileType.real,
    name: 'Default',
    dirName: '',
    createdAt: clock.now(),
  );

  /// The fixed id of the real profile; its data lives at the real root
  /// itself ([dirName] is empty) and is never moved.
  static const String realProfileId = 'real';

  final String id;
  final ProfileType type;

  /// Display name, e.g. 'Demo'.
  final String name;

  /// Root directory relative to the real root, using `/` separators
  /// (platform-independent registry format). Empty for the real profile.
  final String dirName;

  final DateTime createdAt;

  /// Informational copy of the world's sync host ID, written after the
  /// world's first boot. The authoritative value lives in the world's own
  /// settings database.
  final String? hostId;

  bool get isGuest => type == ProfileType.guest;

  Profile copyWith({String? name, String? hostId}) => Profile(
    id: id,
    type: type,
    name: name ?? this.name,
    dirName: dirName,
    createdAt: createdAt,
    hostId: hostId ?? this.hostId,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'type': type.name,
    'name': name,
    'dirName': dirName,
    'createdAt': createdAt.toIso8601String(),
    if (hostId != null) 'hostId': hostId,
  };

  /// Lenient parse: returns null on any malformed field.
  static Profile? tryFromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final id = json['id'];
    final typeName = json['type'];
    final name = json['name'];
    final dirName = json['dirName'];
    final createdAtRaw = json['createdAt'];
    final hostId = json['hostId'];
    if (id is! String || id.isEmpty) return null;
    if (name is! String) return null;
    if (dirName is! String) return null;
    final type = ProfileType.values.asNameMap()[typeName];
    if (type == null) return null;
    final createdAt = createdAtRaw is String
        ? DateTime.tryParse(createdAtRaw)
        : null;
    if (createdAt == null) return null;
    if (hostId is! String?) return null;
    return Profile(
      id: id,
      type: type,
      name: name,
      dirName: dirName,
      createdAt: createdAt,
      hostId: hostId,
    );
  }
}

/// The persisted content of `profiles.json`.
class ProfileRegistryState {
  const ProfileRegistryState({
    required this.version,
    required this.activeProfileId,
    required this.profiles,
  });

  /// Default state for installs without a registry file: the real world,
  /// active, untouched.
  factory ProfileRegistryState.initial() => ProfileRegistryState(
    version: schemaVersion,
    activeProfileId: Profile.realProfileId,
    profiles: [Profile.realDefault()],
  );

  static const int schemaVersion = 1;

  final int version;
  final String activeProfileId;
  final List<Profile> profiles;

  Profile? profileById(String id) {
    for (final profile in profiles) {
      if (profile.id == id) return profile;
    }
    return null;
  }

  /// The active profile, falling back to the real profile if the marker is
  /// dangling (e.g. the guest dir was deleted externally).
  Profile get activeProfile =>
      profileById(activeProfileId) ??
      profileById(Profile.realProfileId) ??
      Profile.realDefault();

  ProfileRegistryState copyWith({
    String? activeProfileId,
    List<Profile>? profiles,
  }) => ProfileRegistryState(
    version: version,
    activeProfileId: activeProfileId ?? this.activeProfileId,
    profiles: profiles ?? this.profiles,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'version': version,
    'activeProfileId': activeProfileId,
    'profiles': [for (final profile in profiles) profile.toJson()],
  };

  /// Lenient parse: returns null when the document as a whole is unusable.
  /// Individual malformed profile entries are dropped; a state without a
  /// real profile is considered unusable.
  static ProfileRegistryState? tryFromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final version = json['version'];
    final activeProfileId = json['activeProfileId'];
    final profilesRaw = json['profiles'];
    if (version is! int || version < 1) return null;
    if (activeProfileId is! String || activeProfileId.isEmpty) return null;
    if (profilesRaw is! List) return null;
    final profiles = [
      for (final entry in profilesRaw)
        if (Profile.tryFromJson(entry) case final Profile profile) profile,
    ];
    final state = ProfileRegistryState(
      version: version,
      activeProfileId: activeProfileId,
      profiles: profiles,
    );
    if (state.profileById(Profile.realProfileId) == null) return null;
    return state;
  }
}
