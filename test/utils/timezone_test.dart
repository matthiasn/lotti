import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/utils/timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  // Fixed reference moment used to assert the function returns the same
  // timezone name the underlying [DateTime] would expose for the injected
  // clock — without depending on real wall-clock time.
  final fixedNow = DateTime(2024, 3, 15, 12);
  DateTime clock() => fixedNow;

  // ---------------------------------------------------------------------------
  // ianaNameFromZoneinfoPath
  //
  // The pure half of the resolution, tested without touching the filesystem.
  // This is where the "CEST" bug lived: the parser matched a fixed list of
  // absolute zoneinfo prefixes, and macOS's real path carries a tzdata version
  // directory that no fixed prefix can contain.
  // ---------------------------------------------------------------------------
  group('ianaNameFromZoneinfoPath — layouts that must resolve', () {
    test(
      'the version-stamped path macOS actually resolves /etc/localtime to',
      () {
        // The regression. /var/db/timezone/zoneinfo is itself a symlink into
        // tz/<tzdata-version>/, so realpath() returns this — and the prefix
        // list this replaced contained '/var/db/timezone/zoneinfo/', which
        // does not appear in it. Every up-to-date Mac therefore fell through
        // to DateTime.timeZoneName and handed getLocation the abbreviation.
        expect(
          ianaNameFromZoneinfoPath(
            '/private/var/db/timezone/tz/2026c.1.0/zoneinfo/Europe/Berlin',
          ),
          'Europe/Berlin',
          reason:
              'the tzdata version between the tree root and "zoneinfo" must '
              'not defeat the match, or it breaks again on the next update',
        );
      },
    );

    test('the same path with a different tzdata version', () {
      // Pins that the match is version-agnostic rather than accidentally
      // tolerant of one particular string.
      expect(
        ianaNameFromZoneinfoPath(
          '/private/var/db/timezone/tz/2031a.7.2/zoneinfo/Asia/Tokyo',
        ),
        'Asia/Tokyo',
      );
    });

    test("macOS's unresolved link target", () {
      expect(
        ianaNameFromZoneinfoPath('/var/db/timezone/zoneinfo/Europe/Berlin'),
        'Europe/Berlin',
      );
    });

    test('the Linux system tree', () {
      expect(
        ianaNameFromZoneinfoPath('/usr/share/zoneinfo/America/New_York'),
        'America/New_York',
      );
    });

    test('the alternate Linux tree', () {
      expect(
        ianaNameFromZoneinfoPath('/usr/lib/zoneinfo/Asia/Tokyo'),
        'Asia/Tokyo',
      );
    });

    test('a relative link target', () {
      // readlink() reports whatever the link literally holds, which need not
      // be absolute.
      expect(
        ianaNameFromZoneinfoPath('../usr/share/zoneinfo/Europe/Paris'),
        'Europe/Paris',
      );
    });

    test('a tree nested under a sandbox root', () {
      // flatpak and snap mount the host tree under a prefix of their own.
      expect(
        ianaNameFromZoneinfoPath(
          '/run/host/usr/share/zoneinfo/America/Sao_Paulo',
        ),
        'America/Sao_Paulo',
      );
    });

    test('a three-segment zone name stays intact', () {
      expect(
        ianaNameFromZoneinfoPath(
          '/usr/share/zoneinfo/America/Argentina/Buenos_Aires',
        ),
        'America/Argentina/Buenos_Aires',
      );
    });

    test('a single-segment zone name', () {
      expect(ianaNameFromZoneinfoPath('/usr/share/zoneinfo/UTC'), 'UTC');
    });

    test('the last zoneinfo segment wins', () {
      // A backup or staging copy of the tree placed inside another one would
      // otherwise resolve to "usr/share/zoneinfo/Asia/Tokyo".
      expect(
        ianaNameFromZoneinfoPath(
          '/opt/zoneinfo/usr/share/zoneinfo/Asia/Tokyo',
        ),
        'Asia/Tokyo',
      );
    });

    for (final flavour in ['posix', 'right']) {
      test('the $flavour/ leap-second subtree is stripped', () {
        expect(
          ianaNameFromZoneinfoPath(
            '/usr/share/zoneinfo/$flavour/Australia/Sydney',
          ),
          'Australia/Sydney',
        );
      });
    }

    test('only the first flavour segment is stripped', () {
      // "posix" is stripped as the subtree it names, not as a banned word, so
      // a deeper occurrence is left alone.
      expect(
        ianaNameFromZoneinfoPath('/usr/share/zoneinfo/posix/posix/UTC'),
        'posix/UTC',
      );
    });
  });

  group('ianaNameFromZoneinfoPath — paths that name no zone', () {
    test('a path with no zoneinfo segment at all', () {
      expect(ianaNameFromZoneinfoPath('/etc/localtime.backup'), isNull);
    });

    test('a segment that merely contains "zoneinfo"', () {
      // Matching a substring rather than a whole segment would derive
      // "Europe/Berlin" from a directory that is not a zoneinfo tree.
      expect(
        ianaNameFromZoneinfoPath('/home/u/zoneinfo-backup/Europe/Berlin'),
        isNull,
      );
      expect(
        ianaNameFromZoneinfoPath('/home/u/myzoneinfo/Europe/Berlin'),
        isNull,
      );
    });

    test('the tree root with nothing after it', () {
      expect(ianaNameFromZoneinfoPath('/usr/share/zoneinfo'), isNull);
    });

    test('the tree root with a trailing separator', () {
      expect(ianaNameFromZoneinfoPath('/usr/share/zoneinfo/'), isNull);
    });

    test('a flavour subtree with no zone inside it', () {
      expect(ianaNameFromZoneinfoPath('/usr/share/zoneinfo/right'), isNull);
    });

    test('a doubled separator inside the name', () {
      // An empty segment means a malformed path, not a zone named "".
      expect(
        ianaNameFromZoneinfoPath('/usr/share/zoneinfo//Europe/Berlin'),
        isNull,
      );
    });

    test('an empty path', () {
      expect(ianaNameFromZoneinfoPath(''), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // getLocalTimezone
  // ---------------------------------------------------------------------------
  group('getLocalTimezone — test-environment short circuit', () {
    test('returns system timezone name in test environment', () async {
      final tz = await getLocalTimezone(clock: clock);
      expect(tz, fixedNow.timeZoneName);
    });

    test(
      'returns system timezone name when isTestEnv is true explicitly',
      () async {
        final tz = await getLocalTimezone(
          overrideIsTestEnv: true,
          clock: clock,
        );
        expect(tz, fixedNow.timeZoneName);
      },
    );
  });

  group('getLocalTimezone — fallback', () {
    test(
      'falls back to the platform abbreviation when nothing resolves',
      () async {
        // Previously this asserted the abbreviation on any non-Linux host with
        // no fixtures at all, which read the machine's real /etc/localtime. On
        // a macOS runner in a named zone that now resolves to Europe/Berlin,
        // so the assertion described the bug rather than the contract — and
        // Buildkite runs `make junit_test` on macOS, where it would fail.
        //
        // Both lookups are pointed at paths that do not exist, which is the
        // condition the fallback actually documents, and is the same on every
        // platform.
        final tempDir = await Directory.systemTemp.createTemp('tz_fallback');

        try {
          final tz = await getLocalTimezone(
            linuxTimezoneFilePath: '${tempDir.path}/absent',
            localtimeLinkPath: '${tempDir.path}/absent-link',
            overrideIsTestEnv: false,
            clock: clock,
          );
          expect(tz, fixedNow.timeZoneName);
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );
  });

  group('getLocalTimezone — /etc/timezone', () {
    // Linux is the only platform that ships this file, but the branch is
    // driven through `overrideIsLinux` rather than skipped off-Linux: a test
    // that early-returns on the developer's machine and only really runs on CI
    // is a test nobody is watching.
    late Directory tempDir;
    late File tzFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('tz_test');
      tzFile = File('${tempDir.path}/timezone');
    });

    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    test('reads the IANA name straight out of the file', () async {
      await tzFile.writeAsString('Europe/Berlin\n');

      expect(
        await getLocalTimezone(
          linuxTimezoneFilePath: tzFile.path,
          localtimeLinkPath: '${tempDir.path}/absent-link',
          overrideIsTestEnv: false,
          overrideIsLinux: true,
        ),
        'Europe/Berlin',
      );
    });

    test('trims surrounding whitespace', () async {
      await tzFile.writeAsString('  America/New_York  \n\n');

      expect(
        await getLocalTimezone(
          linuxTimezoneFilePath: tzFile.path,
          localtimeLinkPath: '${tempDir.path}/absent-link',
          overrideIsTestEnv: false,
          overrideIsLinux: true,
        ),
        'America/New_York',
      );
    });

    test('a missing file falls through instead of throwing', () async {
      expect(
        await getLocalTimezone(
          linuxTimezoneFilePath: '${tempDir.path}/absent',
          localtimeLinkPath: '${tempDir.path}/absent-link',
          overrideIsTestEnv: false,
          overrideIsLinux: true,
          clock: clock,
        ),
        fixedNow.timeZoneName,
      );
    });

    test('an unreadable path falls through instead of throwing', () async {
      // A directory where a file is expected: readAsString throws, and the
      // caller must see the next source rather than the exception.
      await Directory('${tempDir.path}/not-a-file').create();

      expect(
        await getLocalTimezone(
          linuxTimezoneFilePath: '${tempDir.path}/not-a-file',
          localtimeLinkPath: '${tempDir.path}/absent-link',
          overrideIsTestEnv: false,
          overrideIsLinux: true,
          clock: clock,
        ),
        fixedNow.timeZoneName,
      );
    });

    test('is not consulted off Linux, even when the file exists', () async {
      // macOS has no /etc/timezone; reading whatever sits at that path anyway
      // would be a guess, so the branch must stay shut.
      await tzFile.writeAsString('Europe/Berlin\n');

      expect(
        await getLocalTimezone(
          linuxTimezoneFilePath: tzFile.path,
          localtimeLinkPath: '${tempDir.path}/absent-link',
          overrideIsTestEnv: false,
          overrideIsLinux: false,
          clock: clock,
        ),
        fixedNow.timeZoneName,
      );
    });
  });

  group(
    'getLocalTimezone — IANA resolution via /etc/localtime',
    () {
      // The bug this covers: `DateTime.timeZoneName` returns an ABBREVIATION
      // ("CEST"), and `getLocation` from the timezone package only accepts IANA
      // names, so it throws `Location with the name "CEST" doesn't exist`. On
      // macOS there is no /etc/timezone, so the abbreviation used to be the only
      // thing this returned. The /etc/localtime symlink carries the IANA name on
      // both macOS and Linux.

      late Directory tempDir;

      setUp(() async {
        tempDir = await Directory.systemTemp.createTemp('tz_link_test');
      });

      tearDown(() async {
        if (tempDir.existsSync()) await tempDir.delete(recursive: true);
      });

      /// Builds a zoneinfo tree under [tempDir] and links [linkName] at it, the
      /// way the OS lays it out.
      Future<String> makeLocaltimeLink({
        required String zoneinfoPrefix,
        required String ianaName,
        String linkName = 'localtime',
      }) async {
        final target = Directory('${tempDir.path}$zoneinfoPrefix$ianaName');
        await target.parent.create(recursive: true);
        await File(target.path).writeAsString('TZif');
        final link = Link('${tempDir.path}/$linkName');
        await link.create(target.path);
        return link.path;
      }

      test('reads the IANA name from a macOS-style zoneinfo link', () async {
        // macOS: /etc/localtime -> /var/db/timezone/zoneinfo/Europe/Berlin
        final linkPath = await makeLocaltimeLink(
          zoneinfoPrefix: '/var/db/timezone/zoneinfo/',
          ianaName: 'Europe/Berlin',
        );

        final tz = await getLocalTimezone(
          // No /etc/timezone on macOS — point the file lookup at nothing so the
          // link is what answers.
          linuxTimezoneFilePath: '${tempDir.path}/absent',
          localtimeLinkPath: linkPath,
          overrideIsTestEnv: false,
        );

        expect(
          tz,
          'Europe/Berlin',
          reason: 'must be an IANA name, not the CEST abbreviation',
        );
      });

      test(
        'resolves the real macOS layout, where zoneinfo is a versioned link',
        () async {
          // The shape that produced the reported crash, end to end. macOS lays
          // the tree out as
          //   /var/db/timezone/zoneinfo -> /var/db/timezone/tz/<version>/zoneinfo
          // so resolveSymbolicLinks() on /etc/localtime returns a path with the
          // tzdata version spliced into the middle. Reproduced here with a real
          // directory symlink rather than a hand-written string, so the test
          // exercises the same filesystem behaviour the app hits.
          final versioned = Directory(
            '${tempDir.path}/var/db/timezone/tz/2026c.1.0/zoneinfo/Europe',
          );
          await versioned.create(recursive: true);
          await File('${versioned.path}/Berlin').writeAsString('TZif');

          await Link('${tempDir.path}/var/db/timezone/zoneinfo').create(
            '${tempDir.path}/var/db/timezone/tz/2026c.1.0/zoneinfo',
          );
          final localtime = Link('${tempDir.path}/localtime');
          await localtime.create(
            '${tempDir.path}/var/db/timezone/zoneinfo/Europe/Berlin',
          );

          final tz = await getLocalTimezone(
            linuxTimezoneFilePath: '${tempDir.path}/absent',
            localtimeLinkPath: localtime.path,
            overrideIsTestEnv: false,
            clock: clock,
          );

          expect(
            tz,
            'Europe/Berlin',
            reason:
                'the tzdata version directory in the fully resolved path is '
                'what made this return the "CEST" abbreviation instead',
          );
          expect(
            tz,
            isNot(fixedNow.timeZoneName),
            reason: 'guards against the fallback quietly answering instead',
          );
        },
      );

      test(
        'resolves the real macOS layout, where /etc is itself a symlink',
        () async {
          // On macOS /etc -> /private/etc, so resolveSymbolicLinks() returns
          // /private/var/db/timezone/zoneinfo/Europe/Berlin — the zoneinfo
          // segment is not at the start of the path. This is the actual shape on
          // the machine that produced the "CEST" crash, so it is the case worth
          // pinning rather than assuming.
          final zoneFile = File(
            '${tempDir.path}/private/var/db/timezone/zoneinfo/Europe/Berlin',
          );
          await zoneFile.parent.create(recursive: true);
          await zoneFile.writeAsString('TZif');

          // /etc -> /private/etc, then /etc/localtime -> the zoneinfo file.
          final privateEtc = Directory('${tempDir.path}/private/etc');
          await privateEtc.create(recursive: true);
          await Link('${tempDir.path}/etc').create(privateEtc.path);
          final localtime = Link('${tempDir.path}/etc/localtime');
          await localtime.create(zoneFile.path);

          final tz = await getLocalTimezone(
            linuxTimezoneFilePath: '${tempDir.path}/absent',
            localtimeLinkPath: localtime.path,
            overrideIsTestEnv: false,
          );

          expect(
            tz,
            'Europe/Berlin',
            reason:
                'the zoneinfo segment is mid-path once /etc is resolved, so '
                'anchoring the match at the start would miss it',
          );
        },
      );

      test('reads a dangling link, which realpath cannot follow', () async {
        // A link into a tree that is not there — minimal containers ship one,
        // and a sandbox that allows readlink() while denying traversal of the
        // target tree looks the same from here. resolveSymbolicLinks() throws,
        // so the name is only reachable from the link's immediate target.
        final localtime = Link('${tempDir.path}/localtime');
        // Deliberately inside the fixture directory: pointing at a real system
        // path such as /usr/share/zoneinfo/... would not dangle on a host that
        // ships one, and the test would prove nothing.
        await localtime.create(
          '${tempDir.path}/absent-tree/usr/share/zoneinfo/Pacific/Auckland',
        );

        expect(
          localtime.existsSync(),
          isTrue,
          reason: 'the link itself is present; only its target is missing',
        );
        await expectLater(localtime.resolveSymbolicLinks(), throwsA(anything));

        final tz = await getLocalTimezone(
          linuxTimezoneFilePath: '${tempDir.path}/absent',
          localtimeLinkPath: localtime.path,
          overrideIsTestEnv: false,
          clock: clock,
        );

        expect(
          tz,
          'Pacific/Auckland',
          reason:
              'one reading of the link throwing must not cost the other its '
              'turn',
        );
      });

      test('follows a chain whose immediate target names no zone', () async {
        // The mirror case: readlink() answers with an intermediate path that
        // carries no zoneinfo segment, and only the fully resolved path does.
        final zoneFile = File(
          '${tempDir.path}/usr/share/zoneinfo/America/Chicago',
        );
        await zoneFile.parent.create(recursive: true);
        await zoneFile.writeAsString('TZif');

        await Link('${tempDir.path}/current-zone').create(zoneFile.path);
        final localtime = Link('${tempDir.path}/localtime');
        await localtime.create('${tempDir.path}/current-zone');

        final tz = await getLocalTimezone(
          linuxTimezoneFilePath: '${tempDir.path}/absent',
          localtimeLinkPath: localtime.path,
          overrideIsTestEnv: false,
          clock: clock,
        );

        expect(tz, 'America/Chicago');
      });

      test('reads the IANA name from a Linux-style zoneinfo link', () async {
        final linkPath = await makeLocaltimeLink(
          zoneinfoPrefix: '/usr/share/zoneinfo/',
          ianaName: 'America/New_York',
        );

        final tz = await getLocalTimezone(
          linuxTimezoneFilePath: '${tempDir.path}/absent',
          localtimeLinkPath: linkPath,
          overrideIsTestEnv: false,
        );

        expect(tz, 'America/New_York');
      });

      test('keeps multi-segment zone names intact', () async {
        final linkPath = await makeLocaltimeLink(
          zoneinfoPrefix: '/usr/share/zoneinfo/',
          ianaName: 'America/Argentina/Buenos_Aires',
        );

        final tz = await getLocalTimezone(
          linuxTimezoneFilePath: '${tempDir.path}/absent',
          localtimeLinkPath: linkPath,
          overrideIsTestEnv: false,
        );

        expect(tz, 'America/Argentina/Buenos_Aires');
      });

      for (final variant in const ['posix/', 'right/']) {
        test('strips the $variant zoneinfo subtree', () async {
          final linkPath = await makeLocaltimeLink(
            zoneinfoPrefix: '/usr/share/zoneinfo/$variant',
            ianaName: 'Europe/Berlin',
          );

          final tz = await getLocalTimezone(
            linuxTimezoneFilePath: '${tempDir.path}/absent',
            localtimeLinkPath: linkPath,
            overrideIsTestEnv: false,
          );

          expect(tz, 'Europe/Berlin');
        });
      }

      test('falls back to the abbreviation when the link is missing', () async {
        final tz = await getLocalTimezone(
          linuxTimezoneFilePath: '${tempDir.path}/absent',
          localtimeLinkPath: '${tempDir.path}/no-such-link',
          overrideIsTestEnv: false,
          clock: clock,
        );

        expect(
          tz,
          fixedNow.timeZoneName,
          reason: 'unresolvable is not a crash — callers must tolerate this',
        );
      });

      test('falls back when /etc/localtime is a copy, not a link', () async {
        // Some systems copy the zoneinfo file into place. There is no link to
        // read, so no name can be derived.
        final copied = File('${tempDir.path}/localtime');
        await copied.writeAsString('TZif');

        final tz = await getLocalTimezone(
          linuxTimezoneFilePath: '${tempDir.path}/absent',
          localtimeLinkPath: copied.path,
          overrideIsTestEnv: false,
          clock: clock,
        );

        expect(tz, fixedNow.timeZoneName);
      });

      test('falls back when the link points outside a zoneinfo tree', () async {
        // A link into an unrecognised location yields no derivable name.
        final stray = File('${tempDir.path}/stray-tzfile');
        await stray.writeAsString('TZif');
        final link = Link('${tempDir.path}/localtime');
        await link.create(stray.path);

        final tz = await getLocalTimezone(
          linuxTimezoneFilePath: '${tempDir.path}/absent',
          localtimeLinkPath: link.path,
          overrideIsTestEnv: false,
          clock: clock,
        );

        expect(tz, fixedNow.timeZoneName);
      });

      test('an empty /etc/timezone falls through to the link', () async {
        // A present-but-empty file used to be returned as an empty string.
        final tzFile = File('${tempDir.path}/timezone');
        await tzFile.writeAsString('   \n');
        final linkPath = await makeLocaltimeLink(
          zoneinfoPrefix: '/usr/share/zoneinfo/',
          ianaName: 'Asia/Tokyo',
        );

        final tz = await getLocalTimezone(
          linuxTimezoneFilePath: tzFile.path,
          localtimeLinkPath: linkPath,
          overrideIsTestEnv: false,
          overrideIsLinux: true,
        );

        expect(tz, 'Asia/Tokyo');
      });
    },
    skip: Platform.isWindows ? 'requires POSIX symbolic links' : false,
  );

  // ---------------------------------------------------------------------------
  // Glados property tests for the Linux whitespace-trim path
  //
  // The review identified that only two concrete whitespace examples are tested.
  // This property proves that `.trim()` is correct for any combination of
  // leading/trailing whitespace from the representative set.
  // ---------------------------------------------------------------------------
  group('getLocalTimezone — /etc/timezone properties', () {
    // Known valid timezone strings drawn from common real values.
    const knownTimezones = [
      'UTC',
      'Europe/Berlin',
      'America/New_York',
      'Asia/Tokyo',
      'Australia/Sydney',
      'America/Los_Angeles',
      'Europe/London',
      'America/Chicago',
    ];

    // Whitespace chars that can pad the file content.
    const whitespaceOptions = ['', ' ', '  ', '\t', '\n', ' \t', '\n '];

    late Directory tempDir0;
    late File tzFile0;

    setUpAll(() async {
      tempDir0 = await Directory.systemTemp.createTemp('tz_glados');
      tzFile0 = File('${tempDir0.path}/timezone');
    });

    tearDownAll(() async {
      await tempDir0.delete(recursive: true);
    });

    glados.Glados3(
      glados.AnyUtils(glados.any).choose(knownTimezones),
      glados.AnyUtils(glados.any).choose(whitespaceOptions),
      glados.AnyUtils(glados.any).choose(whitespaceOptions),
      glados.ExploreConfig(numRuns: 60),
    ).test(
      'trims any leading/trailing whitespace from the timezone file',
      (timezone, leadingWs, trailingWs) async {
        await tzFile0.writeAsString('$leadingWs$timezone$trailingWs');
        final result = await getLocalTimezone(
          linuxTimezoneFilePath: tzFile0.path,
          localtimeLinkPath: '${tempDir0.path}/absent-link',
          overrideIsTestEnv: false,
          overrideIsLinux: true,
        );
        expect(
          result,
          timezone,
          reason:
              'leading="$leadingWs", trailing="$trailingWs", raw content '
              '"$leadingWs$timezone$trailingWs"',
        );
      },
      tags: 'glados',
    );
  });

  // ---------------------------------------------------------------------------
  // The offset fallback
  // ---------------------------------------------------------------------------
  group('readDeviceZone', () {
    test('reports what DateTime knows about the process clock', () {
      // The instant is pinned rather than asserted within a tolerance, so the
      // test cannot depend on how long the two readings are apart. The
      // abbreviation and offset still come from the platform — the seam fixes
      // *when* the reading is taken, not what the device says about it.
      final zone = readDeviceZone(clock: () => fixedNow);

      expect(zone.at, fixedNow);
      expect(zone.abbreviation, fixedNow.timeZoneName);
      expect(zone.offsetAt(fixedNow), fixedNow.timeZoneOffset);
    });

    test('answers for instants other than now', () {
      // The member the rule-set scoring depends on: the platform's offset at a
      // future instant, which is how the device's own daylight-saving
      // behaviour becomes observable without a zone name.
      final zone = readDeviceZone(clock: () => fixedNow);

      for (final ahead in const [
        Duration(days: 90),
        Duration(days: 180),
        Duration(days: 300),
      ]) {
        final instant = zone.at.add(ahead);
        expect(
          zone.offsetAt(instant),
          DateTime.fromMillisecondsSinceEpoch(
            instant.millisecondsSinceEpoch,
          ).timeZoneOffset,
        );
      }
    });
  });

  group('locationForDeviceZone', () {
    // UTC instants, so the fixtures do not depend on the host's own zone.
    final summer = DateTime.utc(2026, 7, 1, 12);
    final winter = DateTime.utc(2026, 1, 15, 12);

    setUpAll(tzdata.initializeTimeZones);

    /// A device whose platform rules are exactly [zoneName]'s — the shape
    /// `readDeviceZone` produces on a real device, without depending on the
    /// zone the suite happens to run in.
    DeviceZone deviceIn(String zoneName, DateTime at) {
      final location = tz.getLocation(zoneName);
      Duration offsetAt(DateTime instant) =>
          location.timeZone(instant.millisecondsSinceEpoch).offset;
      return (
        at: at,
        abbreviation: location.timeZone(at.millisecondsSinceEpoch).abbreviation,
        offsetAt: offsetAt,
      );
    }

    /// Whether [location] and [zoneName] keep the same clock at [at].
    void expectSameClockAs(
      String zoneName,
      tz.Location? location,
      DateTime at,
    ) {
      expect(location, isNotNull);
      expect(
        location!.timeZone(at.millisecondsSinceEpoch).offset,
        tz.getLocation(zoneName).timeZone(at.millisecondsSinceEpoch).offset,
      );
    }

    test('returns a zone that really keeps the requested wall clock', () {
      final location = locationForDeviceZone(deviceIn('Europe/Berlin', summer));

      expect(location, isNotNull);
      final zone = location!.timeZone(summer.millisecondsSinceEpoch);
      expect(zone.offset, const Duration(hours: 2));
      expect(zone.abbreviation, 'CEST');
    });

    test('the returned zone builds the same wall clock as Berlin', () {
      // The point of the fallback: a 09:00 reminder stays at 09:00 for the
      // user, even though the zone chosen is not the one they live in.
      final location = locationForDeviceZone(
        deviceIn('Europe/Berlin', summer),
      )!;

      expect(
        tz.TZDateTime(location, 2026, 7, 1, 9).toUtc(),
        tz.TZDateTime(tz.getLocation('Europe/Berlin'), 2026, 7, 1, 9).toUtc(),
      );
    });

    test(
      "a winter CST device keeps Chicago's spring transition, not Bahia "
      "Banderas' lack of one",
      () {
        // The regression. In January a device in Chicago reports CST/-06:00,
        // and so do twenty-five database zones; the alphabetically first,
        // America/Bahia_Banderas, abolished daylight saving and stays on CST
        // all year. Choosing on that one instant alone therefore put every
        // habit reminder an hour late from the March transition onward — the
        // very failure this fallback exists to prevent.
        final location = locationForDeviceZone(
          deviceIn('America/Chicago', winter),
        );

        expect(
          location?.name,
          isNot('America/Bahia_Banderas'),
          reason: 'the alphabetically first instantaneous match is the trap',
        );
        expectSameClockAs('America/Chicago', location, winter);
        expectSameClockAs('America/Chicago', location, summer);
      },
    );

    test('a CST device that never springs forward keeps that rule', () {
      // The mirror: same abbreviation and offset in January, opposite summer
      // behaviour. Proves the scoring follows the device rather than always
      // preferring a DST-observing zone.
      final location = locationForDeviceZone(
        deviceIn('America/Bahia_Banderas', winter),
      );

      expectSameClockAs('America/Bahia_Banderas', location, winter);
      expectSameClockAs('America/Bahia_Banderas', location, summer);
      expect(
        location!.timeZone(summer.millisecondsSinceEpoch).offset,
        const Duration(hours: -6),
        reason: 'still CST in July, unlike Chicago',
      );
    });

    test('southern-hemisphere rules are followed too', () {
      // Sydney's daylight saving runs opposite to the northern hemisphere, so
      // a zone scored only on northern transitions would get this backwards.
      final location = locationForDeviceZone(
        deviceIn('Australia/Sydney', summer),
      );

      expectSameClockAs('Australia/Sydney', location, summer);
      expectSameClockAs('Australia/Sydney', location, winter);
    });

    test('the abbreviation, not just the offset, narrows the field', () {
      // CEST and SAST are both +02:00 in July, and neither observes the
      // other's transitions.
      final european = locationForDeviceZone(
        deviceIn('Europe/Berlin', summer),
      )!;
      final southAfrican = locationForDeviceZone(
        deviceIn('Africa/Johannesburg', summer),
      )!;

      expect(southAfrican.name, 'Africa/Johannesburg');
      expect(european.name, isNot('Africa/Johannesburg'));
      expect(
        tz.TZDateTime(european, 2026, 1, 15, 9).toUtc().difference(
          tz.TZDateTime(southAfrican, 2026, 1, 15, 9).toUtc(),
        ),
        const Duration(hours: 1),
        reason: 'in January the two have diverged — different rule sets',
      );
    });

    test('a zone with a unique abbreviation resolves to exactly it', () {
      expect(
        locationForDeviceZone(deviceIn('Asia/Tokyo', summer))?.name,
        'Asia/Tokyo',
      );
    });

    test('an unrecognised abbreviation falls back to offset alone', () {
      // Android reports offsets such as "GMT+02:00" rather than an
      // abbreviation the database uses. No fallback at all would be worse than
      // a zone picked on offset and future rules.
      final berlin = tz.getLocation('Europe/Berlin');
      final location = locationForDeviceZone((
        at: summer,
        abbreviation: 'GMT+02:00',
        offsetAt: (instant) =>
            berlin.timeZone(instant.millisecondsSinceEpoch).offset,
      ));

      expectSameClockAs('Europe/Berlin', location, summer);
      expectSameClockAs('Europe/Berlin', location, winter);
    });

    test('is stable across repeated calls', () {
      expect(
        locationForDeviceZone(deviceIn('America/Chicago', winter))?.name,
        locationForDeviceZone(deviceIn('America/Chicago', winter))?.name,
      );
    });

    test('the instant is honoured, not ignored', () {
      // No zone is CEST in January — the abbreviation is CET then, so the
      // abbreviation tier finds nothing and the offset tier answers instead.
      final berlin = tz.getLocation('Europe/Berlin');
      final location = locationForDeviceZone((
        at: winter,
        abbreviation: 'CEST',
        offsetAt: (instant) =>
            berlin.timeZone(instant.millisecondsSinceEpoch).offset,
      ));

      expect(
        location?.timeZone(winter.millisecondsSinceEpoch).abbreviation,
        'CET',
      );
    });

    test('an offset no zone reports matches nothing', () {
      expect(
        locationForDeviceZone((
          at: summer,
          abbreviation: 'ZZZ',
          offsetAt: (_) => const Duration(minutes: 7),
        )),
        isNull,
      );
    });
  });

  group('configureLocalTimezone', () {
    // Without this the package's `local` is UTC — initializeTimeZones() loads
    // the database but chooses nothing — so anything building wall-clock
    // components against it schedules in the wrong zone.
    late tz.Location originalLocation;

    /// A device that knows its clock but cannot name its zone — the state
    /// every platform without a readable zoneinfo tree is in.
    DeviceZone berlinInJuly() {
      final berlin = tz.getLocation('Europe/Berlin');
      return (
        at: DateTime.utc(2026, 7, 1, 12),
        abbreviation: 'CEST',
        offsetAt: (instant) =>
            berlin.timeZone(instant.millisecondsSinceEpoch).offset,
      );
    }

    setUp(() {
      tzdata.initializeTimeZones();
      originalLocation = tz.local;
    });

    tearDown(() => tz.setLocalLocation(originalLocation));

    test('points the package at the resolved IANA zone', () async {
      await configureLocalTimezone(resolve: () async => 'Europe/Berlin');

      expect(tz.local.name, 'Europe/Berlin');
      // The point of setting it: a wall-clock time is built in the user's
      // zone, not two hours away in UTC.
      expect(
        tz.TZDateTime(tz.local, 2024, 7, 1, 9).toUtc().hour,
        7,
        reason: '09:00 in Berlin in July is 07:00 UTC',
      );
    });

    test('does not consult the device zone when the name resolves', () async {
      var consulted = false;

      await configureLocalTimezone(
        resolve: () async => 'Asia/Tokyo',
        deviceZone: () {
          consulted = true;
          return berlinInJuly();
        },
      );

      expect(tz.local.name, 'Asia/Tokyo');
      expect(consulted, isFalse);
    });

    test(
      'recovers the device wall clock when the zone is an abbreviation',
      () async {
        // getLocation rejects abbreviations. Start-up must survive that — but
        // surviving by leaving `local` at the package's UTC default is what
        // put a 09:00 reminder at 11:00 for a user in Berlin, so the offset
        // the device *does* know is used instead.
        tz.setLocalLocation(tz.UTC);

        await configureLocalTimezone(
          resolve: () async => 'CEST',
          deviceZone: berlinInJuly,
        );

        expect(tz.local.name, isNot('UTC'));
        expect(
          tz.TZDateTime(tz.local, 2026, 7, 1, 9).toUtc().hour,
          7,
          reason:
              'the whole point of the fallback: 09:00 stays 09:00 for the '
              'user instead of sliding to 11:00 via UTC',
        );
      },
    );

    test('reports the naming failure even when the fallback works', () async {
      tz.setLocalLocation(tz.UTC);
      Object? capturedError;
      StackTrace? capturedStackTrace;

      await configureLocalTimezone(
        resolve: () async => 'CEST',
        deviceZone: berlinInJuly,
        onError: (error, stackTrace) {
          capturedError = error;
          capturedStackTrace = stackTrace;
        },
      );

      expect(
        capturedError,
        isNotNull,
        reason:
            'a device that cannot name its own zone is worth a diagnostic '
            'even though the reminder is now scheduled correctly',
      );
      expect(capturedStackTrace, isNotNull);
      expect(
        tz.TZDateTime(tz.local, 2026, 7, 1, 9).toUtc().hour,
        7,
        reason: 'the diagnostic is in addition to the recovery, not instead',
      );
    });

    test('survives a resolver that throws', () async {
      final error = StateError('no tz');
      Object? capturedError;
      StackTrace? capturedStackTrace;

      await expectLater(
        configureLocalTimezone(
          resolve: () async => throw error,
          deviceZone: berlinInJuly,
          onError: (exception, stackTrace) {
            capturedError = exception;
            capturedStackTrace = stackTrace;
          },
        ),
        completes,
      );

      expect(capturedError, same(error));
      expect(capturedStackTrace, isNotNull);
      expect(
        tz.TZDateTime(tz.local, 2026, 7, 1, 9).toUtc().hour,
        7,
        reason: 'a thrown resolver is still a device with a known offset',
      );
    });

    test('survives an onError that throws', () async {
      // Reporting a failure is itself a caller-supplied call that can fail.
      // Left bare it would escape the catch block it sits in, turning a
      // diagnostic into an aborted start-up.
      tz.setLocalLocation(tz.UTC);

      await expectLater(
        configureLocalTimezone(
          resolve: () async => 'CEST',
          deviceZone: berlinInJuly,
          onError: (_, _) => throw StateError('logger unavailable'),
        ),
        completes,
      );

      expect(
        tz.TZDateTime(tz.local, 2026, 7, 1, 9).toUtc().hour,
        7,
        reason:
            'the fallback still ran — a broken logger must not cost the user '
            'a correctly scheduled reminder',
      );
    });

    test('survives a device-zone reader that throws', () async {
      // The fallback is the last line of defence, and `deviceZone` is supplied
      // by the caller — so it can throw. Start-up calls this fire-and-forget,
      // where an escaping error surfaces as an unhandled async error during
      // boot rather than as a missed reminder.
      await configureLocalTimezone(resolve: () async => 'Europe/Berlin');
      final previousLocation = tz.local;
      final failure = StateError('no device clock');
      final errors = <Object>[];

      await expectLater(
        configureLocalTimezone(
          resolve: () async => 'CEST',
          deviceZone: () => throw failure,
          onError: (error, _) => errors.add(error),
        ),
        completes,
      );

      expect(tz.local, same(previousLocation));
      expect(
        errors,
        [isA<Object>(), same(failure)],
        reason:
            'both the naming failure and the fallback failure are reported, '
            'in that order',
      );
    });

    test(
      'leaves the location alone when the device zone matches nothing',
      () async {
        await configureLocalTimezone(resolve: () async => 'Europe/Berlin');
        final previousLocation = tz.local;

        await configureLocalTimezone(
          resolve: () async => 'CEST',
          deviceZone: () => (
            at: DateTime.utc(2026, 7, 1, 12),
            abbreviation: 'ZZZ',
            offsetAt: (_) => const Duration(minutes: 7),
          ),
        );

        expect(
          tz.local,
          same(previousLocation),
          reason:
              'with nothing better to offer, keeping the current location '
              'beats replacing it with a guess',
        );
      },
    );

    test('reads the real device zone when none is injected', () async {
      // The production path: no seams at all beyond the resolver. Whatever the
      // host's zone is, the outcome must keep the host's wall clock.
      tz.setLocalLocation(tz.UTC);

      await configureLocalTimezone(resolve: () async => 'CEST');

      final now = DateTime.now();
      expect(
        tz.local.timeZone(now.millisecondsSinceEpoch).offset,
        now.timeZoneOffset,
      );
    });
  });
}
