import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/demo/media/demo_media_asset.dart';
import 'package:lotti/features/demo/media/generated/demo_media_thumb_hashes.g.dart';
import 'package:lotti/utils/thumbhash.dart';

void main() {
  test('catalog gives every demo task one immutable R2 cover', () {
    final ids = demoMediaAssets.map((asset) => asset.id).toSet();
    final fileNames = demoMediaAssets.map((asset) => asset.fileName).toSet();
    final objectKeys = demoMediaAssets.map((asset) => asset.objectKey).toSet();
    final covers = demoMediaAssets.where((asset) => asset.isCover).toList();
    final taskIds = demoMediaAssets.map((asset) => asset.taskId).toSet();

    expect(demoMediaAssets, hasLength(91));
    expect(ids, hasLength(demoMediaAssets.length));
    expect(fileNames, hasLength(demoMediaAssets.length));
    expect(objectKeys, hasLength(demoMediaAssets.length));
    expect(covers, hasLength(29));
    expect(taskIds, hasLength(29));
    expect(
      covers.map((asset) => asset.taskId).toSet(),
      taskIds,
    );
    for (final taskId in taskIds) {
      expect(
        covers.where((asset) => asset.taskId == taskId),
        hasLength(1),
      );
    }
  });

  test('catalog entries use checksummed versioned R2 locations', () {
    final digestPattern = RegExp(r'^[0-9a-f]{64}$');

    for (final asset in demoMediaAssets) {
      expect(asset.sha256, matches(digestPattern));
      expect(asset.fileName, endsWith('.webp'));
      expect(asset.objectKey, startsWith('$demoMediaR2Prefix/'));
      expect(asset.uri.scheme, 'https');
      expect(asset.uri.toString(), startsWith('$demoMediaPublicBaseUrl/'));
      expect(asset.relativePath, startsWith('$demoMediaDirectory/'));
      expect(asset.imageDirectory, '/$demoMediaDirectory/');
    }
  });

  test('every task has two attachments and hub tasks have a third', () {
    final attachments = demoMediaAssets.where((asset) => !asset.isCover);
    final attachmentCountByTask = <String, int>{};
    for (final attachment in attachments) {
      attachmentCountByTask.update(
        attachment.taskId,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }

    expect(attachments, hasLength(62));
    expect(attachmentCountByTask.values, everyElement(greaterThanOrEqualTo(2)));
    expect(
      attachmentCountByTask.values.where((count) => count == 3),
      hasLength(4),
    );
    for (final asset in attachments) {
      expect(asset.caption((english, _) => english), isNotEmpty);
      expect(asset.caption((_, german) => german), isNotEmpty);
    }
  });

  test('every catalog object carries a ThumbHash that decodes', () {
    for (final asset in demoMediaAssets) {
      final hash = ThumbHash.tryParse(asset.thumbHash);
      expect(hash, isNotNull, reason: '${asset.fileName} has no usable hash');
      // The catalog is 16:9 throughout; the stand-in must be, roughly.
      expect(hash!.aspectRatio, greaterThan(1), reason: asset.fileName);
    }
  });

  test('the generated map holds exactly the catalog digests', () {
    expect(
      demoMediaThumbHashes.keys.toSet(),
      demoMediaAssets.map((asset) => asset.sha256).toSet(),
    );
  });

  test('thumbHash is looked up by digest, and is null for an unknown one', () {
    final known = demoMediaAssets.first;
    const unknown = DemoMediaAsset(
      id: 'image-unknown',
      fileName: 'unknown.webp',
      sha256:
          'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
      taskId: 'task',
      categoryId: 'category',
      capturedDaysAgo: 0,
      capturedHour: 0,
      isCover: false,
    );

    expect(known.thumbHash, demoMediaThumbHashes[known.sha256]);
    expect(unknown.thumbHash, isNull);
  });
}
