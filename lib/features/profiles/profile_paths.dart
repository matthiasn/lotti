import 'dart:io';

import 'package:path/path.dart' as p;

/// Directory under the real root that holds every guest world.
const String guestProfilesDirName = 'guest_profiles';

/// Registry file at the real root; global by definition (it lists worlds,
/// so it cannot live inside one).
const String profilesRegistryFileName = 'profiles.json';

/// Resolves the root directory of a guest profile.
Directory guestProfileRoot(Directory realRoot, String profileId) =>
    Directory(p.join(realRoot.path, guestProfilesDirName, profileId));

/// Guards recursive deletes: only paths inside a `guest_profiles/` segment
/// may ever be removed wholesale. Throws [ArgumentError] otherwise.
void assertIsGuestRoot(Directory dir) {
  final segments = p.split(p.normalize(dir.absolute.path));
  final index = segments.indexOf(guestProfilesDirName);
  if (index == -1 || index == segments.length - 1) {
    throw ArgumentError.value(
      dir.path,
      'dir',
      'not a guest profile root (must be a child of $guestProfilesDirName)',
    );
  }
}
