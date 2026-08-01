import 'dart:io';

import 'package:lotti/utils/platform.dart';

/// Path segments that precede the IANA name in `/etc/localtime`'s symlink
/// target. macOS and Linux ship the zoneinfo tree in different places.
const _zoneinfoPrefixes = <String>[
  '/usr/share/zoneinfo/',
  '/var/db/timezone/zoneinfo/',
  '/usr/lib/zoneinfo/',
];

/// Returns the local timezone as an **IANA location name** (`Europe/Berlin`),
/// falling back to the platform's zone abbreviation (`CEST`) only when no
/// location can be resolved.
///
/// The distinction matters: `DateTime.timeZoneName` yields an abbreviation,
/// and `getLocation` from the `timezone` package only accepts IANA names, so
/// feeding it the abbreviation throws `Location with the name "CEST" doesn't
/// exist`. Abbreviations are also ambiguous (`CST` is three different zones)
/// and change with DST, which makes them a poor thing to persist on an entry.
///
/// Resolution order:
///
/// 1. `/etc/timezone` — Linux ships the IANA name here as plain text.
/// 2. The `/etc/localtime` symlink target — works on macOS *and* Linux, where
///    it points into the zoneinfo tree, e.g.
///    `/var/db/timezone/zoneinfo/Europe/Berlin`.
/// 3. `DateTime.timeZoneName` — the abbreviation, as a last resort. Callers
///    that hand this to `getLocation` must tolerate failure.
///
/// [overrideIsTestEnv] is intended for tests only — it bypasses the
/// `isTestEnv` early-return so the platform-specific branches can be
/// exercised. [clock] is also test-only and lets callers inject a fixed
/// [DateTime] so the result is deterministic. [linuxTimezoneFilePath] and
/// [localtimeLinkPath] let tests point the two file lookups at fixtures.
Future<String> getLocalTimezone({
  String? linuxTimezoneFilePath,
  String? localtimeLinkPath,
  bool? overrideIsTestEnv,
  DateTime Function()? clock,
}) async {
  final now = (clock ?? DateTime.now)();
  final effectiveIsTestEnv = overrideIsTestEnv ?? isTestEnv;

  if (effectiveIsTestEnv) {
    return now.timeZoneName;
  }

  if (Platform.isLinux) {
    final fromFile = await _readTimezoneFile(
      linuxTimezoneFilePath ?? '/etc/timezone',
    );
    if (fromFile != null) return fromFile;
  }

  final fromLink = await _resolveLocaltimeLink(
    localtimeLinkPath ?? '/etc/localtime',
  );
  if (fromLink != null) return fromLink;

  return now.timeZoneName;
}

/// Reads an IANA name from a plain-text file such as `/etc/timezone`.
/// Returns null when the file is missing, unreadable or empty rather than
/// throwing — a missing file is a reason to try the next source, not to fail
/// the caller.
Future<String?> _readTimezoneFile(String path) async {
  try {
    final contents = (await File(path).readAsString()).trim();
    return contents.isEmpty ? null : contents;
  } on Object {
    return null;
  }
}

/// Extracts the IANA name from `/etc/localtime`'s symlink target.
///
/// Returns null when the path is not a symlink (some systems copy the zoneinfo
/// file instead of linking it) or when the target sits outside a recognised
/// zoneinfo tree, since a name cannot be derived in that case.
Future<String?> _resolveLocaltimeLink(String path) async {
  try {
    final link = Link(path);
    if (!link.existsSync()) return null;
    final target = await link.resolveSymbolicLinks();
    for (final prefix in _zoneinfoPrefixes) {
      // Searched rather than anchored at the start: sandboxed runtimes
      // (flatpak, snap) and test fixtures place the zoneinfo tree under a
      // different root, and the IANA name is still whatever follows it.
      final index = target.indexOf(prefix);
      if (index != -1) {
        final name = target.substring(index + prefix.length);
        return name.isEmpty ? null : name;
      }
    }
    return null;
  } on Object {
    return null;
  }
}
