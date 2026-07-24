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
/// Being the *last* read of that directory, it is deliberately more thorough
/// than the live repository ever was: it considers every encoding of a job the
/// old store could leave behind and keeps the newest readable state of each,
/// rather than trusting one filename convention.
class DayProcessingLegacyFileStore {
  DayProcessingLegacyFileStore({required this.rootDirectory});

  final Directory rootDirectory;

  /// Whether an old outbox directory is present at all.
  ///
  /// A fresh install has none, so the migration can record itself as complete
  /// without touching the filesystem.
  bool get exists => rootDirectory.existsSync();

  /// The newest readable state of every job in the directory, oldest first.
  ///
  /// A job can appear on disk more than once:
  ///
  /// - `<id>.json` — the published file.
  /// - `<id>.json.part` — an unpublished write from a store version that used
  ///   that suffix.
  /// - `<id>.json.tmp.<micros>.<pid>.media` — what `atomicWriteBytes` actually
  ///   writes before renaming over the destination. A crash in that window
  ///   leaves it behind, holding a *newer* state than the published file — and
  ///   for a job's very first write, holding the only copy.
  ///
  /// Rather than deciding by filename which one wins, every candidate is
  /// decoded and the highest `generation` (then `updatedAt`) per job id is
  /// kept. Unreadable files are quarantined and skipped, since a job that
  /// cannot be read cannot be executed either.
  Future<List<DayProcessingJob>> readAll() async {
    if (!exists) return const [];
    final newest = <String, DayProcessingJob>{};
    for (final file in rootDirectory.listSync().whereType<File>()) {
      if (!_isJobCandidate(file.path)) continue;
      final DayProcessingJob job;
      try {
        job = await readFile(file);
      } catch (_) {
        // Scratch files are expected to be truncated or half-written; only
        // something that claims to be a published job is worth setting aside
        // for inspection.
        if (!_isScratch(file.path)) await quarantine(file);
        continue;
      }
      final existing = newest[job.id];
      if (existing == null || _isNewer(job, existing)) newest[job.id] = job;
    }
    final jobs = newest.values.toList()
      ..sort((a, b) {
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

  /// Every write the old store could have produced for a job.
  static bool _isJobCandidate(String filePath) =>
      filePath.endsWith('.json') || _isScratch(filePath);

  /// An unpublished write: either suffix the store has used for one.
  static bool _isScratch(String filePath) =>
      filePath.endsWith('.json.part') ||
      (filePath.endsWith('.media') && filePath.contains('.json.tmp.'));

  /// `generation` is the store's own monotonic counter and is authoritative;
  /// `updatedAt` only breaks ties between writes that never diverged.
  static bool _isNewer(DayProcessingJob candidate, DayProcessingJob current) {
    if (candidate.generation != current.generation) {
      return candidate.generation > current.generation;
    }
    return candidate.updatedAt.isAfter(current.updatedAt);
  }
}
