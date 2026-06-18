import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart' show XFile;
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

/// Sanitizes an untrusted dropped-file name down to a safe basename.
///
/// Drag payload metadata is untrusted, so [rawName] may contain path
/// separators or traversal tokens (`../`, `..\\`, absolute paths) that could
/// redirect a write outside the temp dir. Keeping only [p.basename] strips
/// those; a `null` or empty result falls back to `'dropped_file'`.
String sanitizeDropFileName(String? rawName) {
  final base = p.basename(rawName ?? '');
  return base.isEmpty ? 'dropped_file' : base;
}

/// Drop target for media files, built on `super_drag_and_drop` on every
/// platform.
///
/// The app already bundles `super_native_extensions`, which registers a GTK
/// drag-dest on the Flutter view at startup. `desktop_drop` did the same
/// (`gtk_drag_dest_set(GTK_DEST_DEFAULT_ALL)`) the moment its plugin
/// registered, so on Linux the two fought over the single GTK drag
/// destination and drops were silently swallowed. Standardizing on one drag
/// stack removes that conflict.
///
/// Dropped items are normalized to a list of [XFile]s (each dropped file's
/// stream is written to a temp file) and handed to [onFiles]. [onFiles] returns
/// a `Future` so the temp files can be awaited and cleaned up once the caller
/// has finished importing them.
class MediaDropTarget extends StatelessWidget {
  const MediaDropTarget({
    required this.onFiles,
    required this.child,
    super.key,
  });

  final Future<void> Function(List<XFile> files) onFiles;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DropRegion(
      formats: Formats.standardFormats,
      hitTestBehavior: HitTestBehavior.translucent,
      onDropOver: (event) {
        final ops = event.session.allowedOperations;
        if (ops.contains(DropOperation.copy)) return DropOperation.copy;
        return ops.isNotEmpty ? ops.first : DropOperation.none;
      },
      onPerformDrop: (event) async {
        final futures = <Future<XFile?>>[];
        for (final item in event.session.items) {
          final reader = item.dataReader;
          if (reader == null) continue;
          final completer = Completer<XFile?>();
          final progress = reader.getFile(
            null,
            (file) async {
              try {
                // Drag payload metadata is untrusted — keep only the basename
                // so path separators / traversal tokens in `fileName` can't
                // redirect the write outside the temp dir.
                final name = sanitizeDropFileName(file.fileName);
                final dir = await Directory.systemTemp.createTemp(
                  'lotti_drop_',
                );
                final tmp = File(p.join(dir.path, name));
                // Stream straight to disk rather than buffering the whole file
                // in memory, so large drops don't cause memory pressure.
                final sink = tmp.openWrite();
                try {
                  await file.getStream().forEach(sink.add);
                } finally {
                  await sink.close();
                }
                if (!completer.isCompleted) {
                  completer.complete(XFile(tmp.path, name: name));
                }
              } on Object {
                if (!completer.isCompleted) completer.complete(null);
              }
            },
            onError: (_) {
              if (!completer.isCompleted) completer.complete(null);
            },
          );
          if (progress == null) completer.complete(null);
          futures.add(completer.future);
        }
        final files = (await Future.wait(futures)).whereType<XFile>().toList();
        if (files.isEmpty) return;
        try {
          await onFiles(files);
        } finally {
          // Best-effort cleanup of the per-file `lotti_drop_` temp dirs created
          // above, so dropped files don't accumulate in systemTemp over time.
          // The importer copies into the app's media dir, so the temps are
          // safe to remove once onFiles completes.
          for (final file in files) {
            try {
              final parent = File(file.path).parent;
              if (p.basename(parent.path).startsWith('lotti_drop_')) {
                await parent.delete(recursive: true);
              } else {
                await File(file.path).delete();
              }
            } on Object {
              // best-effort
            }
          }
        }
      },
      child: child,
    );
  }
}
