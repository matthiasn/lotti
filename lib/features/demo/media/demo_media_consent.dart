import 'dart:convert';
import 'dart:io';

import 'package:lotti/features/demo/media/demo_media_asset.dart';
import 'package:path/path.dart' as p;

/// File at a demo world's root recording that the user chose to download
/// that world's R2 media.
const demoMediaConsentFileName = 'demo_media_consent.json';

/// The user's choice to download a demo world's photos.
///
/// The photos are an additional download the app may only start once the
/// user has seen its size and chosen to (App Store guideline 4.2.3(ii)), so
/// startup hydration runs only for a world that carries this record. The
/// record lives in the world's own root and is wiped with it; its absence
/// means "not chosen", which includes every world seeded before it existed.
abstract final class DemoMediaConsent {
  static File _file(Directory root) =>
      File(p.join(root.path, demoMediaConsentFileName));

  /// Whether the user chose to download the photos of the world at [root].
  /// A missing, unreadable or malformed record counts as not chosen: the
  /// safe direction is to download nothing.
  static Future<bool> isGranted(Directory root) async {
    try {
      final file = _file(root);
      if (!file.existsSync()) return false;
      final json = jsonDecode(await file.readAsString());
      return json is Map<String, dynamic> && json['granted'] == true;
    } on Object {
      return false;
    }
  }

  /// Records that the user chose to download the photos of the world at
  /// [root].
  static Future<void> grant(Directory root) async {
    await root.create(recursive: true);
    await _file(root).writeAsString(jsonEncode({'granted': true}));
  }
}

/// Bytes a download of every one of [assets] costs.
int totalDemoMediaBytes(Iterable<DemoMediaAsset> assets) =>
    assets.fold(0, (sum, asset) => sum + (asset.byteSize ?? 0));

/// Bytes a download of [assets] into the world at [root] would still fetch:
/// the size of every asset whose file is not on disk yet.
///
/// Presence is the test, not the digest: hashing every file before a prompt
/// would cost more than the answer is worth. A present but corrupt file is
/// therefore not counted; hydration repairs it once the user has chosen to
/// download.
int pendingDemoMediaBytes(Directory root, Iterable<DemoMediaAsset> assets) {
  var bytes = 0;
  for (final asset in assets) {
    if (!asset.localFile(root).existsSync()) bytes += asset.byteSize ?? 0;
  }
  return bytes;
}
