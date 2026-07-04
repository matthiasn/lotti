import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart' show XFile;
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:super_clipboard/super_clipboard.dart'
    show DataReader, DataReaderFile;
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

/// Sanitizes an untrusted dropped-file name down to a safe basename.
///
/// Drag payload metadata is untrusted, so [rawName] may contain path
/// separators or traversal tokens (`../`, `..\\`, absolute paths) that could
/// redirect a write outside the temp dir. Backslashes are normalized to `/`
/// first because `package:path`'s POSIX context (Linux/macOS) does not treat
/// `\\` as a separator — so a Windows-style or malicious `..\\..\\evil` payload
/// would otherwise survive [p.basename]. A `null`/empty result falls back to
/// `'dropped_file'`.
String sanitizeDropFileName(String? rawName) {
  final normalized = (rawName ?? '').replaceAll(r'\', '/');
  final base = p.basename(normalized);
  return base.isEmpty ? 'dropped_file' : base;
}

/// Whether [uri] points at a local file and can be read directly instead of
/// falling back to streaming the drag payload into a temp file.
///
/// `Formats.fileUri`'s platform codecs already filter to `file:`-scheme URIs
/// before returning a value, but a `null` [uri] (no local path available for
/// this item) or a non-`file` scheme (defensive — e.g. a decoder bug, or a
/// future codec that also decodes `http:`/`content:` URIs into this format)
/// must never be handed to [File.fromUri].
bool isUsableLocalFileUri(Uri? uri) => uri != null && uri.isScheme('file');

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
/// Dropped items are normalized to a list of [XFile]s and handed to
/// [onFiles]. For items dragged from a local file manager (Finder/Explorer/
/// Nautilus), the real on-disk path is used directly — this preserves the
/// file's true `lastModified` timestamp (and thus the correct capture-time
/// fallback for screenshots with no EXIF data). Only items with no resolvable
/// local path (e.g. an image dragged from a browser tab) are streamed into a
/// temp file, whose mtime is necessarily the drop time. [onFiles] returns a
/// `Future` so any temp files can be awaited and cleaned up once the caller
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
      // The drop callbacks are driven by super_native_extensions' real GTK/OS
      // drag session — a DropEvent/DataReader can't be synthesized under the
      // headless test binding, so this native-gated handling is exercised
      // manually rather than in widget tests. The pure parts it relies on
      // (sanitizeDropFileName) and the widget's build are unit-tested.
      // coverage:ignore-start
      onDropOver: (event) {
        final ops = event.session.allowedOperations;
        if (ops.contains(DropOperation.copy)) return DropOperation.copy;
        return ops.isNotEmpty ? ops.first : DropOperation.none;
      },
      onPerformDrop: (event) async {
        final futures = <Future<_ResolvedDrop?>>[];
        for (final item in event.session.items) {
          final reader = item.dataReader;
          if (reader == null) continue;
          // Defend against a native reader that never fires success/onError, so
          // a stuck channel call can't hang `Future.wait` (and the drop) forever.
          futures.add(
            _resolveDroppedItem(reader).timeout(
              const Duration(seconds: 15),
              onTimeout: () => null,
            ),
          );
        }
        final resolved = (await Future.wait(
          futures,
        )).whereType<_ResolvedDrop>().toList();
        if (resolved.isEmpty) return;
        final files = resolved.map((r) => r.file).toList(growable: false);
        try {
          await onFiles(files);
        } finally {
          // Best-effort cleanup of the per-file `lotti_drop_` temp dirs created
          // for items that had no resolvable local path, so dropped files
          // don't accumulate in systemTemp over time. Items resolved to a real
          // on-disk path (`isTemp == false`) are the user's original files and
          // must never be deleted.
          for (final r in resolved) {
            if (!r.isTemp) continue;
            try {
              final parent = File(r.file.path).parent;
              if (p.basename(parent.path).startsWith('lotti_drop_')) {
                await parent.delete(recursive: true);
              }
            } on Object {
              // best-effort
            }
          }
        }
      },
      // coverage:ignore-end
      child: child,
    );
  }
}

/// A dropped item resolved to a local [file] path, ready to hand to
/// [XFile]-based importers.
///
/// [isTemp] marks whether [file] lives in a `lotti_drop_` temp dir created by
/// [_streamToTempFile] (and must be cleaned up after import) or is the user's
/// original file resolved via [_resolveDroppedItem] (and must never be
/// deleted).
///
/// Only ever constructed inside the native-gated drop-resolution functions
/// below, so it shares their `coverage:ignore` — a test that only constructs
/// this holder to "cover" the line would be a constructor smoke test with no
/// behavioral value; the resolution logic that produces it is what matters,
/// and that can't run under the headless test binding (see the class doc on
/// [MediaDropTarget]).
// coverage:ignore-start
class _ResolvedDrop {
  const _ResolvedDrop({required this.file, required this.isTemp});

  final XFile file;
  final bool isTemp;
}

/// Resolves one dropped [reader] item to a local file.
///
/// Prefers the item's real on-disk path (via [Formats.fileUri], populated
/// for drags originating in a local file manager) so the file's true
/// `lastModified` timestamp survives — streaming into a temp file otherwise
/// stamps it with the drop time instead. Some sources (a browser tab, a
/// virtual/generated file) never expose a local path, and on a sandboxed
/// platform direct access to the resolved path can be denied even when it
/// exists; both cases fall back to [_streamToTempFile] so the drop still
/// succeeds, just without a meaningful timestamp.
Future<_ResolvedDrop?> _resolveDroppedItem(DataReader reader) async {
  try {
    final fileUri = await _readFileUri(reader);
    if (isUsableLocalFileUri(fileUri)) {
      final file = File.fromUri(fileUri!);
      if (file.existsSync()) {
        return _ResolvedDrop(
          file: XFile(file.path, name: p.basename(file.path)),
          isTemp: false,
        );
      }
    }
  } on Object {
    // Fall through to the temp-file copy below.
  }
  return _streamToTempFile(reader);
}

/// Reads the `Formats.fileUri` value for [reader], if the platform exposes
/// one for this item (`null` otherwise). Bounded by a short timeout since
/// this should be a near-instant local lookup, not a data transfer.
Future<Uri?> _readFileUri(DataReader reader) {
  final completer = Completer<Uri?>();
  final progress = reader.getValue<Uri>(
    Formats.fileUri,
    (Uri? uri) {
      if (!completer.isCompleted) completer.complete(uri);
    },
    onError: (_) {
      if (!completer.isCompleted) completer.complete(null);
    },
  );
  if (progress == null) return Future<Uri?>.value();
  return completer.future.timeout(
    const Duration(seconds: 5),
    onTimeout: () => null,
  );
}

/// Streams [reader]'s file payload into a fresh temp file. This is the
/// fallback used when no real local path could be resolved for the item, so
/// the resulting file's mtime is the drop time rather than the original
/// file's — callers should prefer EXIF or another source-of-truth timestamp
/// over this file's `lastModified` where possible.
Future<_ResolvedDrop?> _streamToTempFile(DataReader reader) {
  final completer = Completer<_ResolvedDrop?>();
  final progress = reader.getFile(
    null,
    (DataReaderFile file) async {
      Directory? dir;
      try {
        // Drag payload metadata is untrusted — keep only the basename
        // so path separators / traversal tokens in `fileName` can't
        // redirect the write outside the temp dir.
        final name = sanitizeDropFileName(file.fileName);
        dir = await Directory.systemTemp.createTemp('lotti_drop_');
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
          completer.complete(
            _ResolvedDrop(file: XFile(tmp.path, name: name), isTemp: true),
          );
        }
      } on Object {
        // The temp dir may have been created before the failure (e.g. the
        // stream errored mid-write, or the disk filled up) — clean it up so
        // a failed drop doesn't leave an orphaned directory behind.
        if (dir != null) {
          try {
            await dir.delete(recursive: true);
          } on Object {
            // best-effort
          }
        }
        if (!completer.isCompleted) completer.complete(null);
      }
    },
    onError: (_) {
      if (!completer.isCompleted) completer.complete(null);
    },
  );
  if (progress == null) completer.complete(null);
  return completer.future;
}

// coverage:ignore-end
