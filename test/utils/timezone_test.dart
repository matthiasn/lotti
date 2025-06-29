import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/utils/timezone.dart';
import 'package:mocktail/mocktail.dart';

class MockFile extends Mock implements File {}

void main() {
  group('getLocalTimezone', () {
    test('returns timezone from provided file path on Linux', () async {
      // This test won't run on linux, so we can't test the linux-specific code.
      // However, we can test the logic of the function by providing a fake file path.
      if (Platform.isLinux) {
        final result = await getLocalTimezone(
            linuxTimezoneFilePath: 'test/utils/fake_timezone');
        expect(result, 'America/New_York');
      }
    });

    test('returns timezone from DateTime on other platforms', () async {
      if (!Platform.isLinux) {
        final timezone = await getLocalTimezone();
        expect(timezone, isNotNull);
      }
    });
  });
}
