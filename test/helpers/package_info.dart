import 'package:package_info_plus/package_info_plus.dart';

/// Installs mock app metadata for the current test.
///
/// `package_info_plus` caches the first platform response in a static field
/// (`PackageInfo._fromPlatform`) that lives for the whole isolate. Under
/// `flutter test` every file gets its own isolate, so mocking the platform
/// channel in `setUpAll` looks correct — but the release lane runs the entire
/// suite as one bundled isolate, where the first file to touch `PackageInfo`
/// pins the version for every file after it.
///
/// [PackageInfo.setMockInitialValues] writes that static directly, so calling
/// this from `setUp` (per test, not per file) makes the reported metadata
/// independent of what ran before.
void mockPackageInfo({
  String appName = 'Lotti',
  String packageName = 'com.matthiasn.lotti',
  String version = '1.0.0',
  String buildNumber = '1',
  String buildSignature = '',
}) {
  PackageInfo.setMockInitialValues(
    appName: appName,
    packageName: packageName,
    version: version,
    buildNumber: buildNumber,
    buildSignature: buildSignature,
  );
}
