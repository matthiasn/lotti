/// Pure helpers for comparing semantic version strings.
library;

/// Whether [releaseVersion] is strictly newer than [installedVersion].
///
/// Compares dot-separated semantic version strings (e.g. `"0.9.804"` vs
/// `"0.9.802"`) component by component, from most to least significant. Each
/// component is parsed as an integer; unparseable components are treated as
/// `0`. If every shared component is equal, the version with more components is
/// considered newer (e.g. `"1.0.0.1"` is newer than `"1.0.0"`).
///
/// Returns `false` when the versions are equal or when [releaseVersion] is
/// older.
bool isNewerVersion(String releaseVersion, String installedVersion) {
  final releaseParts = releaseVersion.split('.').map(int.tryParse).toList();
  final installedParts = installedVersion.split('.').map(int.tryParse).toList();

  // Compare each shared part of the version, most significant first.
  for (var i = 0; i < releaseParts.length && i < installedParts.length; i++) {
    final release = releaseParts[i] ?? 0;
    final installed = installedParts[i] ?? 0;

    if (release > installed) return true;
    if (release < installed) return false;
  }

  // If all compared parts are equal, the version with more parts is newer.
  return releaseParts.length > installedParts.length;
}
