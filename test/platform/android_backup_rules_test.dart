import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/client.dart';

/// Pins the Android Auto Backup and device-transfer exclusions (SEC-016).
///
/// Nothing compiles these XML files against the code, so a renamed Matrix
/// directory or a dropped rule would silently put this device's E2EE keys
/// back into Google Drive backups. The Matrix path is checked against the
/// constant the client actually uses.
void main() {
  const res = 'android/app/src/main/res/xml';
  const matrixPath = 'app_flutter/$matrixDatabaseDirectoryName';
  final excluded = <(String, String)>[
    ('file', matrixPath),
    ('sharedpref', 'FlutterSecureStorage.xml'),
    ('sharedpref', 'FlutterSecureStorageConfiguration.xml'),
  ];

  Set<(String, String)> excludesIn(String xml) => {
    for (final m in RegExp(
      r'<exclude\s+domain="([^"]+)"\s+path="([^"]+)"\s*/>',
    ).allMatches(xml))
      (m.group(1)!, m.group(2)!),
  };

  String section(String xml, String tag) {
    final match = RegExp('<$tag>(.*?)</$tag>', dotAll: true).firstMatch(xml);
    expect(match, isNotNull, reason: 'missing <$tag>');
    return match!.group(1)!;
  }

  test('the manifest points both backup mechanisms at the rules', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final application = RegExp(
      '<application(.*?)>',
      dotAll: true,
    ).firstMatch(manifest)!.group(1)!;

    expect(
      application,
      contains('android:fullBackupContent="@xml/backup_rules"'),
    );
    expect(
      application,
      contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
    );
    expect(application, isNot(contains('android:allowBackup="false"')));
  });

  test('Android 11 and lower exclude the Matrix store and secure storage', () {
    final rules = File('$res/backup_rules.xml').readAsStringSync();

    expect(excludesIn(section(rules, 'full-backup-content')), excluded.toSet());
  });

  for (final tag in ['cloud-backup', 'device-transfer']) {
    test('Android 12+ $tag excludes the same paths', () {
      final rules = File('$res/data_extraction_rules.xml').readAsStringSync();

      expect(excludesIn(section(rules, tag)), excluded.toSet());
    });
  }
}
