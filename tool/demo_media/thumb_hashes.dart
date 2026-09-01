// Backfills the ThumbHash map for the demo-media catalog.
//
// Usage:
//   dart run tool/demo_media/thumb_hashes.dart [--force] [--output <path>]
//
// Every catalog object without a hash is downloaded from the public R2
// origin, shrunk, hashed and written into
// lib/features/demo/media/generated/demo_media_thumb_hashes.g.dart (or
// `--output`). Objects already in the map are skipped unless `--force`;
// one failing object is reported and the rest still run. Exits 1 when
// anything failed, so a partial backfill cannot pass unnoticed.
//
// The rules and the report live in thumb_hash_backfill.dart.

import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:lotti/features/demo/media/demo_media_asset.dart';
import 'package:lotti/features/demo/media/generated/demo_media_thumb_hashes.g.dart';

import 'thumb_hash_backfill.dart';

Future<void> main(List<String> args) async {
  final force = args.contains('--force');
  final outputFlag = args.indexOf('--output');
  if (outputFlag >= 0 && outputFlag + 1 >= args.length) {
    // A forgotten value must not fall through to the checked-in map.
    stderr.writeln('--output needs a path');
    exitCode = 2;
    return;
  }
  final output = outputFlag >= 0
      ? args[outputFlag + 1]
      : demoMediaThumbHashesPath;

  final client = http.Client();
  try {
    final report = await runThumbHashBackfill(
      catalog: demoMediaAssets,
      existing: demoMediaThumbHashes,
      download: (uri) => downloadWithClient(client, uri),
      delay: Future<void>.delayed,
      log: stdout,
      force: force,
    );
    File(output).writeAsStringSync(renderThumbHashMap(report.hashes));
    stdout
      ..writeln()
      ..writeln('${report.summary}; wrote $output');
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
