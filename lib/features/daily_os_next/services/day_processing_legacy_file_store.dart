import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_job.dart';
import 'package:path/path.dart' as path;

/// Read-only view of the pre-ADR-0044 file-per-job outbox.
///
/// The live outbox is a device-local table now; this exists solely so the
/// one-off migration can drain the old directory, and it is deleted once the
/// job files are removed a release later.
///
/// It deliberately keeps the integrity machinery the table does not need:
/// interrupted atomic writes leave `.json.part` files that hold the newest
/// state of a job, and a file whose checksum fails must be set aside rather
/// than aborting the whole import. Both only matter while reading a store that
/// was written by the old code.
class DayProcessingLegacyFileStore {
  DayProcessingLegacyFileStore({required this.rootDirectory});

  final Directory rootDirectory;

  /// Whether an old outbox directory is present at all.
  ///
  /// A fresh install has none, so the migration can record itself as complete
  /// without touching the filesystem.
  bool get exists => rootDirectory.existsSync();

  /// Every job readable from the directory, newest state first resolved.
  ///
  /// Recovers orphaned partials before reading so a job whose last write was
  /// interrupted is imported at its newest state rather than its previous one.
  /// Unreadable files are quarantined and omitted — the same outcome the live
  /// repository produced for them, and safe because a job that cannot be read
  /// cannot be executed either.
  Future<List<DayProcessingJob>> readAll() async {
    if (!exists) return const [];
    await _recoverPartials();
    final jobs = <DayProcessingJob>[];
    for (final file in rootDirectory.listSync().whereType<File>()) {
      if (!file.path.endsWith('.json')) continue;
      try {
        jobs.add(await readFile(file));
      } catch (_) {
        await quarantine(file);
      }
    }
    jobs.sort((a, b) {
      final byCreated = a.createdAt.compareTo(b.createdAt);
      return byCreated != 0 ? byCreated : a.id.compareTo(b.id);
    });
    return List<DayProcessingJob>.unmodifiable(jobs);
  }

  /// Decodes one envelope, verifying its digest.
  Future<DayProcessingJob> readFile(File file) async {
    final envelope =
        jsonDecode(await file.readAsString())! as Map<String, Object?>;
    final payload = envelope['payload']! as String;
    final expected = envelope['sha256']! as String;
    final actual = sha256.convert(utf8.encode(payload)).toString();
    if (actual != expected) {
      throw const FormatException('Invalid processing job digest');
    }
    return DayProcessingJob.fromJson(
      jsonDecode(payload)! as Map<String, Object?>,
    );
  }

  /// Moves an unreadable file aside so a later read does not retry it.
  Future<void> quarantine(File file) async {
    final directory = Directory(path.join(rootDirectory.path, 'quarantine'));
    await directory.create(recursive: true);
    final destination = File(
      path.join(directory.path, path.basename(file.path)),
    );
    if (destination.existsSync()) await destination.delete();
    await file.rename(destination.path);
  }

  Future<void> _recoverPartials() async {
    for (final partial in rootDirectory.listSync().whereType<File>().where(
      (file) => file.path.endsWith('.json.part'),
    )) {
      final destination = File(
        partial.path.substring(0, partial.path.length - '.part'.length),
      );
      // The published file won the race; the partial is leftover scratch.
      if (destination.existsSync()) {
        await partial.delete();
        continue;
      }
      try {
        await readFile(partial);
        await partial.rename(destination.path);
      } catch (_) {
        await quarantine(partial);
      }
    }
  }
}
