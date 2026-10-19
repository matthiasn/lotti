// Backfills the ThumbHash and byte-size maps for the demo-media catalog.
//
// Usage:
//   dart run tool/demo_media/thumb_hashes.dart [--force] [--output <path>]
//       [--sizes-output <path>]
//
// Every catalog object without a hash or a size is downloaded from the public
// R2 origin, shrunk, hashed and written into
// lib/features/demo/media/generated/demo_media_thumb_hashes.g.dart (or
// `--output`), and its size into
// lib/features/demo/media/generated/demo_media_byte_sizes.g.dart (or
// `--sizes-output`). Objects already in both maps are skipped unless `--force`;
// one failing object is reported and the rest still run. Exits 1 when
// anything failed, so a partial backfill cannot pass unnoticed.
//
// The rules and the report live in thumb_hash_backfill.dart.

import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:lotti/features/demo/media/demo_media_asset.dart';
import 'package:lotti/features/demo/media/generated/demo_media_byte_sizes.g.dart';
import 'package:lotti/features/demo/media/generated/demo_media_thumb_hashes.g.dart';

import 'thumb_hash_backfill.dart';

Future<void> main(List<String> args) async {
  final force = args.contains('--force');
  final output = _pathFlag(args, '--output', demoMediaThumbHashesPath);
  final sizesOutput = _pathFlag(args, '--sizes-output', demoMediaByteSizesPath);
  if (output == null || sizesOutput == null) {
    exitCode = 2;
    return;
  }

  final client = http.Client();
  try {
    final report = await runThumbHashBackfill(
      catalog: demoMediaAssets,
      existing: demoMediaThumbHashes,
      existingSizes: demoMediaByteSizes,
      download: (uri) => downloadWithClient(client, uri),
      delay: Future<void>.delayed,
      log: stdout,
      force: force,
    );
    File(output).writeAsStringSync(renderThumbHashMap(report.hashes));
    File(sizesOutput).writeAsStringSync(renderByteSizeMap(report.sizes));
    stdout
      ..writeln()
      ..writeln('${report.summary}; wrote $output and $sizesOutput');
    if (report.hasFailures) {
      stdout.writeln('Failed:');
      for (final entry in report.failures.entries) {
        stdout.writeln('  ${entry.key}: ${entry.value}');
      }
      exitCode = 1;
    }
  } finally {
    client.close();
  }
}

/// The value of [flag] in [args], [fallback] when the flag is absent, or null
/// — after reporting it — when the flag is present without a value.
String? _pathFlag(List<String> args, String flag, String fallback) {
  final index = args.indexOf(flag);
  if (index < 0) return fallback;
  if (index + 1 >= args.length) {
    // A forgotten value must not fall through to the checked-in map.
    stderr.writeln('$flag needs a path');
    return null;
  }
  return args[index + 1];
}
