import 'dart:io';

import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/system_health/domain/system_health_report.dart';
import 'package:path/path.dart' as p;

/// Keeps every generated report as a Markdown file so it outlives the app.
///
/// Files are named `system-health-<yyyy-MM-dd-HHmmss>.md` inside [directory],
/// which sits next to the log files they were built from. The name carries
/// the generation time, so restoring the newest one needs no index.
class SystemHealthReportStore {
  const SystemHealthReportStore({required this.directory});

  final Directory directory;

  static const String filePrefix = 'system-health-';
  static const String fileSuffix = '.md';
  static final DateFormat _stamp = DateFormat('yyyy-MM-dd-HHmmss');

  /// Writes [report] and returns it as a document that knows its path.
  Future<SystemHealthReportDocument> save(SystemHealthReport report) async {
    await directory.create(recursive: true);
    final name = '$filePrefix${_stamp.format(report.generatedAt)}$fileSuffix';
    final file = File(p.join(directory.path, name));
    await file.writeAsString(report.markdown, flush: true);
    return report.toDocument(path: file.path);
  }

  /// Every saved report, newest first. A file that cannot be read is left
  /// out rather than failing the listing.
  Future<List<SystemHealthReportDocument>> list() async {
    if (!directory.existsSync()) return const [];
    final files = <(DateTime, File)>[];
    await for (final entity in directory.list()) {
      if (entity is! File) continue;
      final at = _generatedAtFromName(p.basename(entity.path));
      if (at != null) files.add((at, entity));
    }
    files.sort((a, b) => b.$1.compareTo(a.$1));
    final documents = <SystemHealthReportDocument>[];
    for (final (at, file) in files) {
      try {
        documents.add(
          SystemHealthReportDocument.fromMarkdown(
            await file.readAsString(),
            generatedAt: at,
            path: file.path,
          ),
        );
      } on FileSystemException {
        continue;
      }
    }
    return documents;
  }

  /// The most recently generated saved report, or `null` when none exists.
  Future<SystemHealthReportDocument?> loadLatest() async =>
      (await list()).firstOrNull;

  static final RegExp _fileName = RegExp(
    '^$filePrefix'
    r'(\d{4})-(\d{2})-(\d{2})-(\d{2})(\d{2})(\d{2})'
    '${RegExp.escape(fileSuffix)}\$',
  );

  static DateTime? _generatedAtFromName(String name) {
    final match = _fileName.firstMatch(name);
    if (match == null) return null;
    int part(int group) => int.parse(match.group(group)!);
    final at = DateTime(
      part(1),
      part(2),
      part(3),
      part(4),
      part(5),
      part(6),
    );
    // A stamp like month 13 rolls over in DateTime; reject what did not
    // round-trip.
    return _stamp.format(at) ==
            name.substring(
              filePrefix.length,
              name.length - fileSuffix.length,
            )
        ? at
        : null;
  }
}
