import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/utils/platform.dart' as platform;

void main() {
  group('platform flags', () {
    test('isTestEnv is true under flutter test', () {
      // The test runner exports FLUTTER_TEST — production code branches on
      // this to skip timers/IO, so the detection itself must hold here.
      expect(platform.isTestEnv, isTrue);
    });

    test('desktop and mobile classification are mutually exclusive', () {
      expect(platform.isDesktop, isNot(platform.isMobile));
      // CI and dev machines run the suite on desktop platforms.
      expect(
        platform.isDesktop,
        platform.isWindows || platform.isLinux || platform.isMacOS,
      );
    });
  });
}
