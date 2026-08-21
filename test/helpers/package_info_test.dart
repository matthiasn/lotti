import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package_info.dart';

void main() {
  test(
    'the last call wins, so a per-test seed survives an earlier one',
    () async {
      // ignore: avoid_redundant_argument_values
    mockPackageInfo(version: '1.0.0', packageName: 'first.app');
      expect((await PackageInfo.fromPlatform()).version, '1.0.0');

      // The point of the helper: `PackageInfo` caches the first platform answer
      // for the whole isolate, so a second seed must still take effect — that is
      // what makes a bundled run order-independent.
      mockPackageInfo(version: '99.99.99', packageName: 'second.app');

      final info = await PackageInfo.fromPlatform();
      expect(info.version, '99.99.99');
      expect(info.packageName, 'second.app');
      expect(info.appName, 'Lotti');
      expect(info.buildNumber, '1');
    },
  );
}
