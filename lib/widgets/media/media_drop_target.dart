import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart' show XFile;
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

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
/// stream is read into a temp file) and handed to [onFiles].
class MediaDropTarget extends StatelessWidget {
  const MediaDropTarget({
    required this.onFiles,
    required this.child,
    super.key,
  });

  final void Function(List<XFile> files) onFiles;
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
                final name = file.fileName ?? 'dropped_file';
                final builder = BytesBuilder(copy: false);
                await file.getStream().forEach(builder.add);
                final dir = await Directory.systemTemp.createTemp(
                  'lotti_drop_',
                );
                final tmp = File(p.join(dir.path, name));
                await tmp.writeAsBytes(builder.takeBytes());
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
        if (files.isNotEmpty) onFiles(files);
      },
      child: child,
    );
  }
}
