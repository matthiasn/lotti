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
