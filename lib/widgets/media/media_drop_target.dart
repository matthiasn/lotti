import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart' as dd;
import 'package:file_selector/file_selector.dart' show XFile;
import 'package:flutter/widgets.dart';
import 'package:lotti/utils/platform.dart';
import 'package:path/path.dart' as p;
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

/// Drop target for media files.
///
/// On Linux it uses `super_drag_and_drop` (over `super_native_extensions`,
/// which the app already bundles): plain `desktop_drop` drop events never
/// arrive on Linux because the two drag stacks conflict over the GTK
/// drag-dest. Everywhere else it keeps the verified `desktop_drop` path so
/// macOS/Windows behavior is unchanged.
///
/// Dropped items are normalized to a list of [XFile]s (Linux reads the dropped
/// file stream into a temp file) and handed to [onFiles].
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
    if (!isLinux) {
      return dd.DropTarget(
        onDragDone: (details) => onFiles(details.files),
        child: child,
      );
    }

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
