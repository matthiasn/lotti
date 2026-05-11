import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
}
