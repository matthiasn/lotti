import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Copies a bundled audio asset to a temporary file of its own, for
/// [TtsPlaybackController.playClip]: the player plays files, her lip-sync
/// reads one, and the controller deletes it like any synthesized clip.
typedef TtsBundledClipCopier = Future<File> Function(String asset);

/// The copier `playClip` uses; a test swaps it for one that needs no bundle.
final ttsBundledClipCopierProvider = Provider<TtsBundledClipCopier>(
  (ref) => copyBundledClip,
  name: 'ttsBundledClipCopierProvider',
);

var _copies = 0;

/// Copies [asset] from [bundle] (the app's own by default) into a new file
/// under [tempDirectory], named after the asset so a log shows which clip it
/// was. Each call writes a fresh file, so a clip still playing is never
/// overwritten by the next.
Future<File> copyBundledClip(
  String asset, {
  AssetBundle? bundle,
  Future<Directory> Function()? tempDirectory,
}) async {
  final data = await (bundle ?? rootBundle).load(asset);
  final directory = await (tempDirectory ?? getTemporaryDirectory)();
  final name = asset.split('/').last;
  final file = File(
    '${directory.path}/bundled_clip_${DateTime.now().microsecondsSinceEpoch}_'
    '${_copies++}_$name',
  );
  return file.writeAsBytes(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    flush: true,
  );
}
