import 'dart:io';

import 'package:lotti/utils/platform.dart';
import 'package:meta/meta.dart';
import 'package:timezone/timezone.dart';

/// The directory that separates a zoneinfo tree's root from the IANA name
/// inside it.
///
/// Matched as a whole path *segment* rather than as part of a fixed list of
/// absolute prefixes. The prefix list this replaced (`/usr/share/zoneinfo/`,
/// `/var/db/timezone/zoneinfo/`, `/usr/lib/zoneinfo/`) could only ever
/// enumerate layouts someone had already seen, and it missed the one macOS
/// actually ships — see [ianaNameFromZoneinfoPath].
const _zoneinfoDirectory = 'zoneinfo';

/// Parallel sub-trees that mirror the entire zone set under a different
/// leap-second convention. `/etc/localtime` may point into one, and the IANA
/// name is whatever follows.
const _zoneinfoFlavours = <String>['posix', 'right'];

/// Extracts the IANA location name from a path into a zoneinfo tree, or null
/// when [path] does not run through one.
///
/// The name is everything after the last `zoneinfo` segment, minus a leading
/// [_zoneinfoFlavours] directory:
///
/// ```text
/// /usr/share/zoneinfo/Europe/Berlin                     -> Europe/Berlin
/// /var/db/timezone/tz/2026c.1.0/zoneinfo/Europe/Berlin  -> Europe/Berlin
/// /usr/share/zoneinfo/right/Asia/Tokyo                  -> Asia/Tokyo
/// ```
///
/// **Why a segment scan rather than a prefix list.** macOS resolves
/// `/etc/localtime` to a *version-stamped* real path — on a machine carrying
/// tzdata 2026c that is
/// `/private/var/db/timezone/tz/2026c.1.0/zoneinfo/Europe/Berlin`, because
/// `/var/db/timezone/zoneinfo` is itself a symlink into `tz/<version>/`. No
/// fixed prefix survives a tzdata update, so matching one meant returning null
/// on every up-to-date Mac, falling through to `DateTime.timeZoneName`, and
/// handing `getLocation` the abbreviation `CEST` — which it rejects.
///
/// The scan takes the **last** occurrence so that a zoneinfo tree nested under
/// an unrelated root (flatpak and snap sandboxes, test fixtures) resolves to
/// the name inside it rather than to a path segment of the root.
@visibleForTesting
String? ianaNameFromZoneinfoPath(String path) {
  final segments = path.split('/');
  final zoneinfoIndex = segments.lastIndexOf(_zoneinfoDirectory);
  if (zoneinfoIndex == -1) return null;

  var nameSegments = segments.sublist(zoneinfoIndex + 1);
  if (nameSegments.isNotEmpty &&
      _zoneinfoFlavours.contains(nameSegments.first)) {
    nameSegments = nameSegments.sublist(1);
  }

  // A trailing separator ("…/zoneinfo/") splits into a final empty segment,
  // and an empty segment anywhere means the path was malformed rather than
  // that a zone is named "".
  if (nameSegments.isEmpty || nameSegments.any((segment) => segment.isEmpty)) {
    return null;
  }
  return nameSegments.join('/');
}

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
/// 2. The `/etc/localtime` symlink, read both one level deep and fully
///    resolved — see [_resolveLocaltimeLink] for why both are needed.
/// 3. `DateTime.timeZoneName` — the abbreviation, as a last resort. Callers
///    that hand this to `getLocation` must tolerate failure;
///    [configureLocalTimezone] does.
///
/// Every parameter is a test seam. [overrideIsTestEnv] bypasses the
/// `isTestEnv` early-return so the platform-specific branches can be reached
/// at all, and [overrideIsLinux] decides whether step 1 runs — without it the
/// `/etc/timezone` branch would be dead code on a macOS developer machine and
/// live only on CI, which is the worst of both worlds for a lookup this
/// fiddly. [clock] injects a fixed [DateTime] so the result is deterministic,
/// and [linuxTimezoneFilePath] and [localtimeLinkPath] point the two file
/// lookups at fixtures.
Future<String> getLocalTimezone({
  String? linuxTimezoneFilePath,
  String? localtimeLinkPath,
  bool? overrideIsTestEnv,
  bool? overrideIsLinux,
  DateTime Function()? clock,
}) async {
  final now = (clock ?? DateTime.now)();
  final effectiveIsTestEnv = overrideIsTestEnv ?? isTestEnv;

  if (effectiveIsTestEnv) {
    return now.timeZoneName;
  }

  if (overrideIsLinux ?? Platform.isLinux) {
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

/// Points the `timezone` package's [local] at the device's actual zone.
///
/// Without this the package's `local` is **UTC**: `initializeTimeZones()` only
/// loads the database, it does not choose a zone. Anything that builds
/// wall-clock components against `local` — `TZDateTime` in notification
/// scheduling — would then place a 09:00 reminder at 09:00 UTC, an hour or
/// more away from the 09:00 the user asked for.
///
/// Called once at start-up, and deliberately total: start-up must not fail
/// over a timezone.
///
/// **Two levels of degradation, because leaving [local] at UTC is not one.**
/// The previous implementation swallowed a resolution failure and returned,
/// which sounds harmless but silently kept the package's UTC default — the
/// exact "reminder lands hours off" outcome this function exists to prevent.
/// When [getLocalTimezone] can only produce an abbreviation, this now falls
/// back to [locationForDeviceZone], which is wrong about the user's *city*
/// but right about their *clock*.
///
/// [resolve] is a test seam — [getLocalTimezone] short-circuits to the
/// abbreviation under `isTestEnv`, so without it neither branch here could be
/// exercised. [deviceZone] is the seam for the offset fallback: a process
/// cannot change its own `TZ` mid-run, so the fallback's behaviour in a zone
/// other than the host's is only reachable by injection. [onError] surfaces
/// resolution failures without coupling this utility to the application's
/// logging service. It fires for the *named* lookup even when the offset
/// fallback then succeeds, because a device that cannot name its own zone is
/// worth knowing about either way — and again if the fallback itself throws,
/// which is reachable because [deviceZone] is caller-supplied.
Future<void> configureLocalTimezone({
  Future<String> Function()? resolve,
  void Function(Object error, StackTrace stackTrace)? onError,
  DeviceZone Function()? deviceZone,
}) async {
  // [onError] is caller-supplied, so reporting a failure is itself a call that
  // can fail. Left bare it would escape the catch block it sits in, and a
  // diagnostic that aborts start-up is worse than no diagnostic.
  void report(Object error, StackTrace stackTrace) {
    try {
      onError?.call(error, stackTrace);
    } on Object {
      // Nothing left to report it to.
    }
  }

  try {
    setLocalLocation(getLocation(await (resolve ?? getLocalTimezone)()));
    return;
  } on Object catch (error, stackTrace) {
    report(error, stackTrace);
  }

  try {
    final fallback = locationForDeviceZone((deviceZone ?? readDeviceZone)());
    if (fallback != null) {
      setLocalLocation(fallback);
    }
  } on Object catch (error, stackTrace) {
    // Guarded for the same reason the first attempt is: this runs
    // fire-and-forget during boot, and there is nothing left to degrade to.
    report(error, stackTrace);
  }
}

/// What `DateTime` can still say about the clock on a device that exposes no
/// IANA zone name.
///
/// `offsetAt` is the load-bearing member: `DateTime` knows the device's UTC
/// offset at *any* instant, not just now, which is what makes the device's
/// own daylight-saving rules observable without a zone name.
typedef DeviceZone = ({
  DateTime at,
  String abbreviation,
  Duration Function(DateTime instant) offsetAt,
});

/// Reads the [DeviceZone] from the platform clock.
///
/// [clock] is a test seam: it pins `at` so a test does not have to assert the
/// instant within a tolerance. `abbreviation` and `offsetAt` still come from
/// the platform either way — this fixes *when* the reading is taken, not what
/// the device says about that moment.
DeviceZone readDeviceZone({DateTime Function()? clock}) {
  final now = (clock ?? DateTime.now)();
  return (at: now, abbreviation: now.timeZoneName, offsetAt: _platformOffsetAt);
}

/// The device's UTC offset at [instant], as the platform's own timezone rules
/// see it.
Duration _platformOffsetAt(DateTime instant) =>
    DateTime.fromMillisecondsSinceEpoch(
      instant.millisecondsSinceEpoch,
    ).timeZoneOffset;

/// How far ahead a candidate zone is compared against the device's own rules,
/// and how finely.
///
/// Just over a year, so every seasonal transition the device observes falls
/// inside the window at least once. A fortnightly step is far shorter than any
/// daylight-saving period, so no transition can hide between two probes; it
/// costs ~29 offset comparisons per candidate, once, on a path that only runs
/// when the zone could not be named.
const _ruleProbeHorizon = Duration(days: 400);
const _ruleProbeStep = Duration(days: 14);

/// A [Location] that keeps [zone]'s wall clock, or null when the timezone
/// database holds none.
///
/// Picks a **rule set, not a city**. The name it lands on ("America/Menominee"
/// for a device in Chicago) is not a claim about where the user is — only that
/// the two keep the same clock.
///
/// Selection happens in two stages, and the second is not optional:
///
/// 1. **Instantaneous match.** Zones whose offset *and* abbreviation equal the
///    device's at `zone.at`. Where the device reports an abbreviation the
///    database does not use — Android is fond of `GMT-06:00` — offset alone
///    stands in, because a slightly wrong zone beats no fallback at all.
/// 2. **Agreement across upcoming transitions.** One instant is not a rule
///    set. A device in Chicago starting the app in January reports
///    `CST`/-06:00, which twenty-five zones also report — and the
///    alphabetically first of them, `America/Bahia_Banderas`, stays on CST all
///    year while Chicago springs forward in March. Choosing on the snapshot
///    alone therefore put every reminder an hour late from spring onwards.
///    Candidates are scored on how often their offset matches the device's own
///    across [_ruleProbeHorizon], which separates the two.
///
/// Scored rather than filtered, so a device whose tzdata is a different
/// vintage from the bundled database still gets its closest match instead of
/// nothing. Candidates are walked in sorted order and ties keep the first, so
/// the choice is stable across runs rather than dependent on map iteration
/// order.
@visibleForTesting
Location? locationForDeviceZone(DeviceZone zone) {
  final instant = zone.at.millisecondsSinceEpoch;
  final offset = zone.offsetAt(zone.at);

  final matchingAbbreviation = <String>[];
  final matchingOffset = <String>[];
  for (final entry in timeZoneDatabase.locations.entries) {
    final timeZone = entry.value.timeZone(instant);
    if (timeZone.offset != offset) continue;
    matchingOffset.add(entry.key);
    if (timeZone.abbreviation == zone.abbreviation) {
      matchingAbbreviation.add(entry.key);
    }
  }

  final candidates = matchingAbbreviation.isNotEmpty
      ? matchingAbbreviation
      : matchingOffset;
  if (candidates.isEmpty) return null;
  candidates.sort();

  var bestName = candidates.first;
  var bestScore = -1;
  for (final name in candidates) {
    final location = timeZoneDatabase.locations[name]!;
    var score = 0;
    for (
      var ahead = _ruleProbeStep;
      ahead <= _ruleProbeHorizon;
      ahead += _ruleProbeStep
    ) {
      final probe = zone.at.add(ahead);
      if (location.timeZone(probe.millisecondsSinceEpoch).offset ==
          zone.offsetAt(probe)) {
        score++;
      }
    }
    if (score > bestScore) {
      bestScore = score;
      bestName = name;
    }
  }
  return timeZoneDatabase.locations[bestName];
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

/// Extracts the IANA name from `/etc/localtime`, or null when none can be
/// derived.
///
/// Two readings of the link are tried in turn, and **neither alone is
/// sufficient**:
///
/// 1. `readlink` — the link's immediate target. macOS points `/etc/localtime`
///    straight at `/var/db/timezone/zoneinfo/Europe/Berlin`, naming the zone
///    without the tzdata version that fully resolving the path splices in. It
///    is also the only reading that survives a **dangling** link (minimal
///    containers ship one) or a sandbox that permits `readlink` on the link
///    while denying traversal of the tree it points into — Lotti's own macOS
///    build runs under `com.apple.security.app-sandbox`.
/// 2. `realpath` — the fully resolved path. Distributions that chain
///    `/etc/localtime` through an intermediate link, where the immediate
///    target names no zone at all, need this instead.
///
/// Each reading is attempted independently: one throwing must not cost the
/// other its turn, which is why this is a loop over thunks rather than a list
/// of already-awaited paths.
///
/// Returns null when the path is not a symlink (some systems copy the zoneinfo
/// file instead of linking it) or when neither reading runs through a zoneinfo
/// tree, since no name can be derived in that case.
Future<String?> _resolveLocaltimeLink(String path) async {
  final link = Link(path);
  try {
    if (!link.existsSync()) return null;
  } on Object {
    return null;
  }

  for (final read in <Future<String> Function()>[
    link.target,
    link.resolveSymbolicLinks,
  ]) {
    try {
      final name = ianaNameFromZoneinfoPath(await read());
      if (name != null) return name;
    } on Object {
      // This reading cannot see the path; the other one still may.
      continue;
    }
  }
  return null;
}
