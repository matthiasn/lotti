import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/utils/timezone.dart';

void main() {
  // Fixed reference moment used to assert the function returns the same
  // timezone name the underlying [DateTime] would expose for the injected
  // clock — without depending on real wall-clock time.
  final fixedNow = DateTime(2024, 3, 15, 12);
  DateTime clock() => fixedNow;

  group('getLocalTimezone', () {
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

    test(
      'returns system timezone on non-Linux when isTestEnv is false',
      () async {
        if (Platform.isLinux) return;

        final tz = await getLocalTimezone(
          overrideIsTestEnv: false,
          clock: clock,
        );
        expect(tz, fixedNow.timeZoneName);
      },
    );

    test('reads timezone from file on Linux when isTestEnv is false', () async {
      if (!Platform.isLinux) return;

      final tempDir = await Directory.systemTemp.createTemp('tz_test');
      final tzFile = File('${tempDir.path}/timezone');
      await tzFile.writeAsString('Europe/Berlin\n');

      try {
        final tz = await getLocalTimezone(
          linuxTimezoneFilePath: tzFile.path,
          overrideIsTestEnv: false,
        );
        expect(tz, 'Europe/Berlin');
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('trims whitespace from timezone file on Linux', () async {
      if (!Platform.isLinux) return;

      final tempDir = await Directory.systemTemp.createTemp('tz_test');
      final tzFile = File('${tempDir.path}/timezone');
      await tzFile.writeAsString('  America/New_York  \n');

      try {
        final tz = await getLocalTimezone(
          linuxTimezoneFilePath: tzFile.path,
          overrideIsTestEnv: false,
        );
        expect(tz, 'America/New_York');
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });

  group('getLocalTimezone — IANA resolution via /etc/localtime', () {
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

    test('falls back to the abbreviation when the link is missing', () async {
      final fixedNow = DateTime(2024, 3, 15, 12);

      final tz = await getLocalTimezone(
        linuxTimezoneFilePath: '${tempDir.path}/absent',
        localtimeLinkPath: '${tempDir.path}/no-such-link',
        overrideIsTestEnv: false,
        clock: () => fixedNow,
      );

      expect(
        tz,
        fixedNow.timeZoneName,
        reason: 'unresolvable is not a crash — callers must tolerate this',
      );
    });

    test(
      'falls back when the link points outside a zoneinfo tree',
      () async {
        // Some systems copy the zoneinfo file rather than linking it, and a
        // link into an unrecognised location yields no derivable name.
        final stray = File('${tempDir.path}/stray-tzfile');
        await stray.writeAsString('TZif');
        final link = Link('${tempDir.path}/localtime');
        await link.create(stray.path);
        final fixedNow = DateTime(2024, 3, 15, 12);

        final tz = await getLocalTimezone(
          linuxTimezoneFilePath: '${tempDir.path}/absent',
          localtimeLinkPath: link.path,
          overrideIsTestEnv: false,
          clock: () => fixedNow,
        );

        expect(tz, fixedNow.timeZoneName);
      },
    );

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
      );

      expect(tz, Platform.isLinux ? 'Asia/Tokyo' : 'Asia/Tokyo');
    });
  });

  // ---------------------------------------------------------------------------
  // Glados property tests for the Linux whitespace-trim path
  //
  // The review identified that only two concrete whitespace examples are tested.
  // This property proves that `.trim()` is correct for any combination of
  // leading/trailing whitespace from the representative set.
  // ---------------------------------------------------------------------------
  group('getLocalTimezone — properties (Linux only)', () {
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
        if (!Platform.isLinux) return;

        await tzFile0.writeAsString('$leadingWs$timezone$trailingWs');
        final result = await getLocalTimezone(
          linuxTimezoneFilePath: tzFile0.path,
          overrideIsTestEnv: false,
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
}
