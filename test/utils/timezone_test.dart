import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/utils/timezone.dart';

void main() {
  group('getLocalTimezone', () {
    test('returns system timezone name in test environment', () async {
      final tz = await getLocalTimezone();
      final expected = DateTime.now().timeZoneName;
      expect(tz, expected);
    });

    test(
      'returns system timezone name when isTestEnv is true explicitly',
      () async {
        final tz = await getLocalTimezone(overrideIsTestEnv: true);
        final expected = DateTime.now().timeZoneName;
        expect(tz, expected);
      },
    );

    test(
      'returns system timezone on non-Linux when isTestEnv is false',
      () async {
        if (Platform.isLinux) return;

        final tz = await getLocalTimezone(overrideIsTestEnv: false);
        final expected = DateTime.now().timeZoneName;
        expect(tz, expected);
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
