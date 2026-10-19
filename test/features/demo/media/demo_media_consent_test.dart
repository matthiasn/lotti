import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/demo/media/demo_media_asset.dart';
import 'package:lotti/features/demo/media/demo_media_consent.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('demo_media_consent_');
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  File consentFile() => File(p.join(root.path, demoMediaConsentFileName));

  group('DemoMediaConsent', () {
    test('a world without a record has not chosen to download', () async {
      expect(await DemoMediaConsent.isGranted(root), isFalse);
    });

    test('grant records the choice in the world root', () async {
      await DemoMediaConsent.grant(root);

      expect(consentFile().existsSync(), isTrue);
      expect(await DemoMediaConsent.isGranted(root), isTrue);
    });

    test('grant creates a world root that does not exist yet', () async {
      final nested = Directory(p.join(root.path, 'guest_profiles', 'demo'));

      await DemoMediaConsent.grant(nested);

      expect(await DemoMediaConsent.isGranted(nested), isTrue);
    });

    test('a malformed record counts as not chosen', () async {
      consentFile().writeAsStringSync('{not json');

      expect(await DemoMediaConsent.isGranted(root), isFalse);
    });

    test('a record that does not say granted counts as not chosen', () async {
      consentFile().writeAsStringSync('{"granted": false}');
      expect(await DemoMediaConsent.isGranted(root), isFalse);

      consentFile().writeAsStringSync('["granted"]');
      expect(await DemoMediaConsent.isGranted(root), isFalse);
    });
  });

  group('demo media byte counts', () {
    final first = demoMediaAssets[0];
    final second = demoMediaAssets[1];

    test('totalDemoMediaBytes sums the catalog sizes', () {
      expect(
        totalDemoMediaBytes([first, second]),
        first.byteSize! + second.byteSize!,
      );
      expect(totalDemoMediaBytes(const []), 0);
    });

    test('an asset without a known size adds nothing', () {
      const unsized = DemoMediaAsset(
        id: 'image-unsized',
        fileName: 'unsized.webp',
        sha256:
            'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
        taskId: 'task',
        categoryId: 'category',
        capturedDaysAgo: 0,
        capturedHour: 0,
        isCover: false,
      );

      expect(totalDemoMediaBytes([first, unsized]), first.byteSize);
    });

    test('pendingDemoMediaBytes counts only the files not on disk', () {
      expect(
        pendingDemoMediaBytes(root, [first, second]),
        first.byteSize! + second.byteSize!,
      );

      first.localFile(root)
        ..createSync(recursive: true)
        ..writeAsBytesSync([1, 2, 3]);

      expect(pendingDemoMediaBytes(root, [first, second]), second.byteSize);
    });

    test('a world root that does not exist yet still owes every file', () {
      final missing = Directory(p.join(root.path, 'not-created'));

      expect(
        pendingDemoMediaBytes(missing, [first, second]),
        totalDemoMediaBytes([first, second]),
      );
    });
  });
}
